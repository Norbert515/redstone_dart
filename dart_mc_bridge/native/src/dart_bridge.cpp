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

// ==========================================================================
// New Event Callback Registration (called from Dart via FFI)
// ==========================================================================

void register_player_join_handler(PlayerJoinCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setPlayerJoinHandler(cb);
}

void register_player_leave_handler(PlayerLeaveCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setPlayerLeaveHandler(cb);
}

void register_player_respawn_handler(PlayerRespawnCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setPlayerRespawnHandler(cb);
}

void register_player_death_handler(PlayerDeathCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setPlayerDeathHandler(cb);
}

void register_entity_damage_handler(EntityDamageCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setEntityDamageHandler(cb);
}

void register_entity_death_handler(EntityDeathCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setEntityDeathHandler(cb);
}

void register_player_attack_entity_handler(PlayerAttackEntityCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setPlayerAttackEntityHandler(cb);
}

void register_player_chat_handler(PlayerChatCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setPlayerChatHandler(cb);
}

void register_player_command_handler(PlayerCommandCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setPlayerCommandHandler(cb);
}

void register_item_use_handler(ItemUseCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setItemUseHandler(cb);
}

void register_item_use_on_block_handler(ItemUseOnBlockCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setItemUseOnBlockHandler(cb);
}

void register_item_use_on_entity_handler(ItemUseOnEntityCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setItemUseOnEntityHandler(cb);
}

void register_block_place_handler(BlockPlaceCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setBlockPlaceHandler(cb);
}

void register_player_pickup_item_handler(PlayerPickupItemCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setPlayerPickupItemHandler(cb);
}

void register_player_drop_item_handler(PlayerDropItemCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setPlayerDropItemHandler(cb);
}

void register_server_starting_handler(ServerStartingCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setServerStartingHandler(cb);
}

void register_server_started_handler(ServerStartedCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setServerStartedHandler(cb);
}

void register_server_stopping_handler(ServerStoppingCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setServerStoppingHandler(cb);
}

// ==========================================================================
// New Event Dispatch (called from Java via JNI)
// ==========================================================================

void dispatch_player_join(int32_t player_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerJoin(player_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_player_leave(int32_t player_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerLeave(player_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_player_respawn(int32_t player_id, bool end_conquered) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerRespawn(player_id, end_conquered);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

char* dispatch_player_death(int32_t player_id, const char* damage_source) {
    if (!g_initialized || g_isolate == nullptr) return nullptr;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    char* result = dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerDeath(player_id, damage_source);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_entity_damage(int32_t entity_id, const char* damage_source, double amount) {
    if (!g_initialized || g_isolate == nullptr) return true;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchEntityDamage(entity_id, damage_source, amount);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

void dispatch_entity_death(int32_t entity_id, const char* damage_source) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchEntityDeath(entity_id, damage_source);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

bool dispatch_player_attack_entity(int32_t player_id, int32_t target_id) {
    if (!g_initialized || g_isolate == nullptr) return true;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerAttackEntity(player_id, target_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

char* dispatch_player_chat(int32_t player_id, const char* message) {
    if (!g_initialized || g_isolate == nullptr) return nullptr;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    char* result = dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerChat(player_id, message);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_player_command(int32_t player_id, const char* command) {
    if (!g_initialized || g_isolate == nullptr) return true;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerCommand(player_id, command);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_item_use(int32_t player_id, const char* item_id, int32_t count, int32_t hand) {
    if (!g_initialized || g_isolate == nullptr) return true;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchItemUse(player_id, item_id, count, hand);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t dispatch_item_use_on_block(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                    int32_t x, int32_t y, int32_t z, int32_t face) {
    if (!g_initialized || g_isolate == nullptr) return 1;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::CallbackRegistry::instance().dispatchItemUseOnBlock(
        player_id, item_id, count, hand, x, y, z, face);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t dispatch_item_use_on_entity(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                     int32_t target_id) {
    if (!g_initialized || g_isolate == nullptr) return 1;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::CallbackRegistry::instance().dispatchItemUseOnEntity(
        player_id, item_id, count, hand, target_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_block_place(int32_t player_id, int32_t x, int32_t y, int32_t z, const char* block_id) {
    if (!g_initialized || g_isolate == nullptr) return true;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchBlockPlace(player_id, x, y, z, block_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_player_pickup_item(int32_t player_id, int32_t item_entity_id) {
    if (!g_initialized || g_isolate == nullptr) return true;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerPickupItem(player_id, item_entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_player_drop_item(int32_t player_id, const char* item_id, int32_t count) {
    if (!g_initialized || g_isolate == nullptr) return true;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerDropItem(player_id, item_id, count);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

void dispatch_server_starting() {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchServerStarting();
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_server_started() {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchServerStarted();
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_server_stopping() {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchServerStopping();
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

} // extern "C"
