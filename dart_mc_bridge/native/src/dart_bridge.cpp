#include "dart_bridge.h"
#include "callback_registry.h"
#include "dart_dll.h"  // From dart_shared_library
#include "dart_api.h"  // Dart SDK header

#include <iostream>
#include <string>
#include <cstring>

// Dart VM state
static Dart_Isolate g_isolate = nullptr;
static bool g_initialized = false;

// Java callback for sending chat messages
static SendChatMessageCallback g_send_chat_callback = nullptr;

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

    // Build package config path (same directory as script)
    std::string script_str(script_path);
    std::string package_config;
    size_t last_slash = script_str.find_last_of("/\\");
    if (last_slash != std::string::npos) {
        package_config = script_str.substr(0, last_slash) + "/.dart_tool/package_config.json";
    } else {
        package_config = ".dart_tool/package_config.json";
    }

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

    // Shutdown Dart
    if (g_isolate != nullptr) {
        Dart_EnterIsolate(g_isolate);
        Dart_ShutdownIsolate();
        g_isolate = nullptr;
    }

    DartDll_Shutdown();
    g_initialized = false;

    std::cout << "Dart bridge shutdown complete" << std::endl;
}

void dart_bridge_tick() {
    if (!g_initialized || g_isolate == nullptr) return;

    Dart_EnterIsolate(g_isolate);
    DartDll_DrainMicrotaskQueue();
    Dart_ExitIsolate();
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

// Event dispatch (called from Java via JNI)
// These functions must enter/exit the isolate to invoke Dart callbacks
int32_t dispatch_block_break(int32_t x, int32_t y, int32_t z, int64_t player_id) {
    if (!g_initialized || g_isolate == nullptr) return 1;

    Dart_EnterIsolate(g_isolate);
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::CallbackRegistry::instance().dispatchBlockBreak(x, y, z, player_id);
    Dart_ExitScope();
    Dart_ExitIsolate();
    return result;
}

int32_t dispatch_block_interact(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand) {
    if (!g_initialized || g_isolate == nullptr) return 1;

    Dart_EnterIsolate(g_isolate);
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::CallbackRegistry::instance().dispatchBlockInteract(x, y, z, player_id, hand);
    Dart_ExitScope();
    Dart_ExitIsolate();
    return result;
}

void dispatch_tick(int64_t tick) {
    if (!g_initialized || g_isolate == nullptr) return;

    Dart_EnterIsolate(g_isolate);
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchTick(tick);
    DartDll_DrainMicrotaskQueue(); // Process async tasks while we're in the isolate
    Dart_ExitScope();
    Dart_ExitIsolate();
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

} // extern "C"
