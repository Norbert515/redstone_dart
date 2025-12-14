#include "dart_bridge.h"
#include "callback_registry.h"
#include "object_registry.h"
#include "generic_jni.h"
#include "dart_dll.h"  // From dart_shared_library
#include "dart_api.h"  // Dart SDK header

#include <jni.h>
#include <iostream>
#include <string>
#include <cstring>
#include <mutex>
#include <thread>

// Dart VM state
static Dart_Isolate g_isolate = nullptr;
static bool g_initialized = false;

// Thread synchronization for isolate access
static std::mutex g_isolate_mutex;
static std::thread::id g_isolate_owner_thread;
static int g_isolate_entry_count = 0;  // For re-entrant calls from same thread

// JVM reference for cleanup operations
static JavaVM* g_jvm_ref = nullptr;

// Java callback for sending chat messages
static SendChatMessageCallback g_send_chat_callback = nullptr;

// Helper to safely enter isolate with thread synchronization
// Returns true if we entered (and thus need to exit), false if already entered by this thread
static bool safe_enter_isolate() {
    std::thread::id this_thread = std::this_thread::get_id();

    // Check if we already own the isolate on this thread (re-entrant call)
    {
        std::lock_guard<std::mutex> lock(g_isolate_mutex);
        if (g_isolate_owner_thread == this_thread && g_isolate_entry_count > 0) {
            // Already entered on this thread, just bump the count
            g_isolate_entry_count++;
            return false;  // Don't need to exit later
        }
    }

    // Need to acquire the isolate - lock and enter
    g_isolate_mutex.lock();
    Dart_EnterIsolate(g_isolate);
    g_isolate_owner_thread = this_thread;
    g_isolate_entry_count = 1;
    return true;  // Will need to exit
}

static void safe_exit_isolate(bool did_enter) {
    if (did_enter) {
        // We actually entered, so exit and release
        g_isolate_entry_count = 0;
        g_isolate_owner_thread = std::thread::id();  // Reset to default
        Dart_ExitIsolate();
        g_isolate_mutex.unlock();
    } else {
        // Re-entrant call - we already own the mutex, just decrement count
        // No lock needed since we're the owning thread
        g_isolate_entry_count--;
    }
}

extern "C" {

bool dart_bridge_init(const char* script_path) {
    if (g_initialized) {
        std::cerr << "Dart bridge already initialized" << std::endl;
        return false;
    }

    // Configure Dart VM
    DartDllConfig config;
    config.start_service_isolate = true;  // Enable for hot reload
    config.service_port = 5858;           // Debug/hot reload port

    // Initialize VM
    DartDll_Initialize(config);

    // Build package config path (at package root, which is parent of lib/)
    // Script is typically at: package_root/lib/dart_mod.dart
    // Package config is at: package_root/.dart_tool/package_config.json
    std::string script_str(script_path);
    std::string package_config;
    size_t last_slash = script_str.find_last_of("/\\");
    if (last_slash != std::string::npos) {
        std::string script_dir = script_str.substr(0, last_slash);
        // Check if we're in a lib/ directory
        size_t lib_pos = script_dir.rfind("/lib");
        if (lib_pos != std::string::npos && lib_pos == script_dir.length() - 4) {
            // Script is in lib/, go up to package root
            package_config = script_dir.substr(0, lib_pos) + "/.dart_tool/package_config.json";
        } else {
            // Script is at package root
            package_config = script_dir + "/.dart_tool/package_config.json";
        }
    } else {
        package_config = ".dart_tool/package_config.json";
    }

    std::cout << "Package config path: " << package_config << std::endl;

    // Load the Dart script
    g_isolate = DartDll_LoadScript(script_path, package_config.c_str());
    if (g_isolate == nullptr) {
        std::cerr << "Failed to load Dart script: " << script_path << std::endl;
        DartDll_Shutdown();
        return false;
    }

    // Enter isolate and run main()
    Dart_EnterIsolate(g_isolate);
    Dart_EnterScope();

    Dart_Handle library = Dart_RootLibrary();
    if (Dart_IsError(library)) {
        std::cerr << "Failed to get root library: " << Dart_GetError(library) << std::endl;
        Dart_ExitScope();
        Dart_ShutdownIsolate();
        DartDll_Shutdown();
        return false;
    }

    // Run main() - this will register callbacks
    Dart_Handle result = Dart_Invoke(library, Dart_NewStringFromCString("main"), 0, nullptr);
    if (Dart_IsError(result)) {
        std::cerr << "Failed to invoke main(): " << Dart_GetError(result) << std::endl;
        Dart_ExitScope();
        Dart_ShutdownIsolate();
        DartDll_Shutdown();
        return false;
    }

    // Process any pending microtasks from initialization
    DartDll_DrainMicrotaskQueue();

    Dart_ExitScope();
    Dart_ExitIsolate();

    g_initialized = true;
    std::cout << "Dart bridge initialized successfully" << std::endl;
    return true;
}

void dart_bridge_shutdown() {
    if (!g_initialized) return;

    // Clear all callbacks
    dart_mc_bridge::CallbackRegistry::instance().clear();

    // Shutdown generic JNI system (clears class/method caches)
    generic_jni_shutdown();

    // Release all object handles
    if (g_jvm_ref != nullptr) {
        JNIEnv* env = nullptr;
        bool needs_detach = false;

        int status = g_jvm_ref->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_8);
        if (status == JNI_EDETACHED) {
            if (g_jvm_ref->AttachCurrentThread(reinterpret_cast<void**>(&env), nullptr) == JNI_OK) {
                needs_detach = true;
            } else {
                std::cerr << "Failed to attach thread for object cleanup" << std::endl;
            }
        }

        if (env != nullptr) {
            dart_mc_bridge::ObjectRegistry::instance().releaseAll(env);
        }

        if (needs_detach) {
            g_jvm_ref->DetachCurrentThread();
        }
    }

    // Shutdown Dart
    if (g_isolate != nullptr) {
        std::lock_guard<std::mutex> lock(g_isolate_mutex);
        Dart_EnterIsolate(g_isolate);
        Dart_ShutdownIsolate();
        g_isolate = nullptr;
    }

    DartDll_Shutdown();
    g_initialized = false;
    g_jvm_ref = nullptr;

    std::cout << "Dart bridge shutdown complete" << std::endl;
}

void dart_bridge_set_jvm(JavaVM* jvm) {
    g_jvm_ref = jvm;
    // Initialize generic JNI system with JVM reference
    generic_jni_init(jvm);
}

void dart_bridge_tick() {
    if (!g_initialized || g_isolate == nullptr) return;

    bool did_enter = safe_enter_isolate();
    DartDll_DrainMicrotaskQueue();
    safe_exit_isolate(did_enter);
}

// Callback registration (called from Dart via FFI)
void register_block_break_handler(BlockBreakCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setBlockBreakHandler(cb);
}

void register_block_interact_handler(BlockInteractCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setBlockInteractHandler(cb);
}

void register_tick_handler(TickCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setTickHandler(cb);
}

void register_proxy_block_break_handler(ProxyBlockBreakCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyBlockBreakHandler(cb);
}

void register_proxy_block_use_handler(ProxyBlockUseCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyBlockUseHandler(cb);
}

// Event dispatch (called from Java via JNI)
// These functions must enter/exit the isolate to invoke Dart callbacks
int32_t dispatch_block_break(int32_t x, int32_t y, int32_t z, int64_t player_id) {
    if (!g_initialized || g_isolate == nullptr) return 1;

    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::CallbackRegistry::instance().dispatchBlockBreak(x, y, z, player_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t dispatch_block_interact(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand) {
    if (!g_initialized || g_isolate == nullptr) return 1;

    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::CallbackRegistry::instance().dispatchBlockInteract(x, y, z, player_id, hand);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

void dispatch_tick(int64_t tick) {
    if (!g_initialized || g_isolate == nullptr) return;

    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchTick(tick);
    DartDll_DrainMicrotaskQueue(); // Process async tasks while we're in the isolate
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

// Proxy block dispatch (called from Java proxy classes via JNI)
// Returns true if break should be allowed, false to cancel
bool dispatch_proxy_block_break(int64_t handler_id, int64_t world_id,
                                 int32_t x, int32_t y, int32_t z, int64_t player_id) {
    if (!g_initialized || g_isolate == nullptr) return true; // Allow break if not initialized

    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockBreak(
        handler_id, world_id, x, y, z, player_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t dispatch_proxy_block_use(int64_t handler_id, int64_t world_id,
                                  int32_t x, int32_t y, int32_t z,
                                  int64_t player_id, int32_t hand) {
    if (!g_initialized || g_isolate == nullptr) return 3; // ActionResult.pass

    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockUse(
        handler_id, world_id, x, y, z, player_id, hand);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

// Dart -> Java communication
void set_send_chat_message_callback(SendChatMessageCallback cb) {
    g_send_chat_callback = cb;
    std::cout << "Chat message callback registered" << std::endl;
}

void send_chat_message(int64_t player_id, const char* message) {
    if (g_send_chat_callback != nullptr) {
        g_send_chat_callback(player_id, message);
    } else {
        std::cerr << "Warning: send_chat_message called but no callback registered" << std::endl;
    }
}

// Service URL for hot reload/debugging
static const char* DART_SERVICE_URL = "http://127.0.0.1:5858/";

const char* get_dart_service_url() {
    if (g_initialized) {
        return DART_SERVICE_URL;
    }
    return nullptr;
}

} // extern "C"
