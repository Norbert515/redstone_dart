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
#include <chrono>

// Dart VM state
static Dart_Isolate g_isolate = nullptr;
static bool g_initialized = false;

// Thread synchronization for isolate access
// Using recursive_mutex to allow the same thread to check ownership while holding the lock
static std::recursive_mutex g_isolate_mutex;
static std::thread::id g_isolate_owner_thread;
static int g_isolate_entry_count = 0;  // For re-entrant calls from same thread

// JVM reference for cleanup operations
static JavaVM* g_jvm_ref = nullptr;

// Java callback for sending chat messages
static SendChatMessageCallback g_send_chat_callback = nullptr;

// Debug: Call counters for profiling
static int g_tick_count = 0;
static int g_entity_tick_count = 0;
static int g_other_callback_count = 0;
static auto g_last_report_time = std::chrono::steady_clock::now();

// Helper to safely enter isolate with thread synchronization
// Returns true if we entered (and thus need to exit), false if already entered by this thread
static bool safe_enter_isolate() {
    std::thread::id this_thread = std::this_thread::get_id();

    // Check if we already own the isolate on this thread (re-entrant call)
    {
        std::lock_guard<std::recursive_mutex> lock(g_isolate_mutex);
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
        std::lock_guard<std::recursive_mutex> lock(g_isolate_mutex);
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

void register_proxy_block_stepped_on_handler(ProxyBlockSteppedOnCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyBlockSteppedOnHandler(cb);
}

void register_proxy_block_fallen_upon_handler(ProxyBlockFallenUponCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyBlockFallenUponHandler(cb);
}

void register_proxy_block_random_tick_handler(ProxyBlockRandomTickCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyBlockRandomTickHandler(cb);
}

void register_proxy_block_placed_handler(ProxyBlockPlacedCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyBlockPlacedHandler(cb);
}

void register_proxy_block_removed_handler(ProxyBlockRemovedCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyBlockRemovedHandler(cb);
}

void register_proxy_block_neighbor_changed_handler(ProxyBlockNeighborChangedCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyBlockNeighborChangedHandler(cb);
}

void register_proxy_block_entity_inside_handler(ProxyBlockEntityInsideCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyBlockEntityInsideHandler(cb);
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

    g_tick_count++;

    // Report stats every second
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - g_last_report_time).count();
    if (elapsed >= 1) {
        std::cerr << "[PROFILE] tick=" << g_tick_count
                  << " entity_tick=" << g_entity_tick_count
                  << " other=" << g_other_callback_count
                  << " (per " << elapsed << "s)" << std::endl;
        g_tick_count = 0;
        g_entity_tick_count = 0;
        g_other_callback_count = 0;
        g_last_report_time = now;
    }

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

void dispatch_proxy_block_stepped_on(int64_t handler_id, int64_t world_id,
                                      int32_t x, int32_t y, int32_t z, int32_t entity_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockSteppedOn(
        handler_id, world_id, x, y, z, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_proxy_block_fallen_upon(int64_t handler_id, int64_t world_id,
                                       int32_t x, int32_t y, int32_t z, int32_t entity_id, float fall_distance) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockFallenUpon(
        handler_id, world_id, x, y, z, entity_id, fall_distance);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_proxy_block_random_tick(int64_t handler_id, int64_t world_id,
                                       int32_t x, int32_t y, int32_t z) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockRandomTick(
        handler_id, world_id, x, y, z);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_proxy_block_placed(int64_t handler_id, int64_t world_id,
                                  int32_t x, int32_t y, int32_t z, int64_t player_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockPlaced(
        handler_id, world_id, x, y, z, player_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_proxy_block_removed(int64_t handler_id, int64_t world_id,
                                   int32_t x, int32_t y, int32_t z) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockRemoved(
        handler_id, world_id, x, y, z);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_proxy_block_neighbor_changed(int64_t handler_id, int64_t world_id,
                                            int32_t x, int32_t y, int32_t z,
                                            int32_t neighbor_x, int32_t neighbor_y, int32_t neighbor_z) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockNeighborChanged(
        handler_id, world_id, x, y, z, neighbor_x, neighbor_y, neighbor_z);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_proxy_block_entity_inside(int64_t handler_id, int64_t world_id,
                                         int32_t x, int32_t y, int32_t z, int32_t entity_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockEntityInside(
        handler_id, world_id, x, y, z, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
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
    DartDll_DrainMicrotaskQueue(); // Process async tasks from server started handlers
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

// ==========================================================================
// Screen Callback Registration (called from Dart via FFI)
// ==========================================================================

void register_screen_init_callback(ScreenInitCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setScreenInitHandler(callback);
}

void register_screen_tick_callback(ScreenTickCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setScreenTickHandler(callback);
}

void register_screen_render_callback(ScreenRenderCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setScreenRenderHandler(callback);
}

void register_screen_close_callback(ScreenCloseCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setScreenCloseHandler(callback);
}

void register_screen_key_pressed_callback(ScreenKeyPressedCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setScreenKeyPressedHandler(callback);
}

void register_screen_key_released_callback(ScreenKeyReleasedCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setScreenKeyReleasedHandler(callback);
}

void register_screen_char_typed_callback(ScreenCharTypedCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setScreenCharTypedHandler(callback);
}

void register_screen_mouse_clicked_callback(ScreenMouseClickedCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setScreenMouseClickedHandler(callback);
}

void register_screen_mouse_released_callback(ScreenMouseReleasedCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setScreenMouseReleasedHandler(callback);
}

void register_screen_mouse_dragged_callback(ScreenMouseDraggedCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setScreenMouseDraggedHandler(callback);
}

void register_screen_mouse_scrolled_callback(ScreenMouseScrolledCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setScreenMouseScrolledHandler(callback);
}

// ==========================================================================
// Screen Event Dispatch (called from Java via JNI)
// ==========================================================================

void dispatch_screen_init(int64_t screen_id, int32_t width, int32_t height) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchScreenInit(screen_id, width, height);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_screen_tick(int64_t screen_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchScreenTick(screen_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_screen_render(int64_t screen_id, int32_t mouse_x, int32_t mouse_y, float partial_tick) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchScreenRender(screen_id, mouse_x, mouse_y, partial_tick);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_screen_close(int64_t screen_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchScreenClose(screen_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

bool dispatch_screen_key_pressed(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers) {
    if (!g_initialized || g_isolate == nullptr) return false;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchScreenKeyPressed(screen_id, key_code, scan_code, modifiers);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_screen_key_released(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers) {
    if (!g_initialized || g_isolate == nullptr) return false;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchScreenKeyReleased(screen_id, key_code, scan_code, modifiers);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_screen_char_typed(int64_t screen_id, int32_t code_point, int32_t modifiers) {
    if (!g_initialized || g_isolate == nullptr) return false;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchScreenCharTyped(screen_id, code_point, modifiers);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_screen_mouse_clicked(int64_t screen_id, double mouse_x, double mouse_y, int32_t button) {
    if (!g_initialized || g_isolate == nullptr) return false;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchScreenMouseClicked(screen_id, mouse_x, mouse_y, button);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_screen_mouse_released(int64_t screen_id, double mouse_x, double mouse_y, int32_t button) {
    if (!g_initialized || g_isolate == nullptr) return false;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchScreenMouseReleased(screen_id, mouse_x, mouse_y, button);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_screen_mouse_dragged(int64_t screen_id, double mouse_x, double mouse_y, int32_t button, double drag_x, double drag_y) {
    if (!g_initialized || g_isolate == nullptr) return false;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchScreenMouseDragged(screen_id, mouse_x, mouse_y, button, drag_x, drag_y);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_screen_mouse_scrolled(int64_t screen_id, double mouse_x, double mouse_y, double delta_x, double delta_y) {
    if (!g_initialized || g_isolate == nullptr) return false;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchScreenMouseScrolled(screen_id, mouse_x, mouse_y, delta_x, delta_y);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

// ==========================================================================
// Widget Callback Registration (called from Dart via FFI)
// ==========================================================================

void register_widget_pressed_callback(WidgetPressedCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setWidgetPressedHandler(callback);
}

void register_widget_text_changed_callback(WidgetTextChangedCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setWidgetTextChangedHandler(callback);
}

// ==========================================================================
// Widget Event Dispatch (called from Java via JNI)
// ==========================================================================

void dispatch_widget_pressed(int64_t screen_id, int64_t widget_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchWidgetPressed(screen_id, widget_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_widget_text_changed(int64_t screen_id, int64_t widget_id, const char* text) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchWidgetTextChanged(screen_id, widget_id, text);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

// ==========================================================================
// Container Screen Callback Registration (called from Dart via FFI)
// ==========================================================================

void register_container_screen_init_callback(ContainerScreenInitCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setContainerScreenInitHandler(callback);
}

void register_container_screen_render_bg_callback(ContainerScreenRenderBgCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setContainerScreenRenderBgHandler(callback);
}

void register_container_screen_close_callback(ContainerScreenCloseCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setContainerScreenCloseHandler(callback);
}

// ==========================================================================
// Container Screen Event Dispatch (called from Java via JNI)
// ==========================================================================

void dispatch_container_screen_init(int64_t screen_id, int32_t width, int32_t height,
                                    int32_t left_pos, int32_t top_pos, int32_t image_width, int32_t image_height) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchContainerScreenInit(
        screen_id, width, height, left_pos, top_pos, image_width, image_height);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_container_screen_render_bg(int64_t screen_id, int32_t mouse_x, int32_t mouse_y,
                                         float partial_tick, int32_t left_pos, int32_t top_pos) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchContainerScreenRenderBg(
        screen_id, mouse_x, mouse_y, partial_tick, left_pos, top_pos);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_container_screen_close(int64_t screen_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchContainerScreenClose(screen_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

// ==========================================================================
// Container Menu Callback Registration (called from Dart via FFI)
// ==========================================================================

void register_container_slot_click_callback(ContainerSlotClickCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setContainerSlotClickHandler(callback);
}

void register_container_quick_move_callback(ContainerQuickMoveCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setContainerQuickMoveHandler(callback);
}

void register_container_may_place_callback(ContainerMayPlaceCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setContainerMayPlaceHandler(callback);
}

void register_container_may_pickup_callback(ContainerMayPickupCallback callback) {
    dart_mc_bridge::CallbackRegistry::instance().setContainerMayPickupHandler(callback);
}

// ==========================================================================
// Container Menu Event Dispatch (called from Java via JNI)
// ==========================================================================

int32_t dispatch_container_slot_click(int64_t menu_id, int32_t slot_index,
                                       int32_t button, int32_t click_type, const char* carried_item) {
    if (!g_initialized || g_isolate == nullptr) return 0;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::CallbackRegistry::instance().dispatchContainerSlotClick(
        menu_id, slot_index, button, click_type, carried_item);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

const char* dispatch_container_quick_move(int64_t menu_id, int32_t slot_index) {
    if (!g_initialized || g_isolate == nullptr) return nullptr;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    const char* result = dart_mc_bridge::CallbackRegistry::instance().dispatchContainerQuickMove(
        menu_id, slot_index);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_container_may_place(int64_t menu_id, int32_t slot_index, const char* item_data) {
    if (!g_initialized || g_isolate == nullptr) return true;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchContainerMayPlace(
        menu_id, slot_index, item_data);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_container_may_pickup(int64_t menu_id, int32_t slot_index) {
    if (!g_initialized || g_isolate == nullptr) return true;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchContainerMayPickup(
        menu_id, slot_index);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

// ==========================================================================
// Container Item Access APIs (Dart -> Java via C++)
// These functions call into Java to get/set container items
// ==========================================================================

// Helper to get JNIEnv from stored JVM
static JNIEnv* get_jni_env_for_container() {
    if (g_jvm_ref == nullptr) return nullptr;
    JNIEnv* env = nullptr;
    int status = g_jvm_ref->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_8);
    if (status == JNI_EDETACHED) {
        if (g_jvm_ref->AttachCurrentThread(reinterpret_cast<void**>(&env), nullptr) != JNI_OK) {
            return nullptr;
        }
    }
    return env;
}

// Cached method IDs for container item access
static jclass g_dart_container_menu_class = nullptr;
static jmethodID g_get_container_item_impl = nullptr;
static jmethodID g_set_container_item_impl = nullptr;
static jmethodID g_get_container_slot_count_impl = nullptr;
static jmethodID g_clear_container_slot_impl = nullptr;

static bool init_container_jni_cache(JNIEnv* env) {
    if (g_dart_container_menu_class != nullptr) return true;

    jclass localClass = env->FindClass("com/redstone/DartContainerMenu");
    if (localClass == nullptr) {
        std::cerr << "Failed to find DartContainerMenu class" << std::endl;
        env->ExceptionClear();
        return false;
    }
    g_dart_container_menu_class = static_cast<jclass>(env->NewGlobalRef(localClass));
    env->DeleteLocalRef(localClass);

    g_get_container_item_impl = env->GetStaticMethodID(g_dart_container_menu_class,
        "getContainerItemImpl", "(JI)Ljava/lang/String;");
    g_set_container_item_impl = env->GetStaticMethodID(g_dart_container_menu_class,
        "setContainerItemImpl", "(JILjava/lang/String;I)V");
    g_get_container_slot_count_impl = env->GetStaticMethodID(g_dart_container_menu_class,
        "getContainerSlotCountImpl", "(J)I");
    g_clear_container_slot_impl = env->GetStaticMethodID(g_dart_container_menu_class,
        "clearContainerSlotImpl", "(JI)V");

    if (g_get_container_item_impl == nullptr || g_set_container_item_impl == nullptr ||
        g_get_container_slot_count_impl == nullptr || g_clear_container_slot_impl == nullptr) {
        std::cerr << "Failed to find container item methods" << std::endl;
        env->ExceptionClear();
        return false;
    }

    return true;
}

const char* dart_get_container_item(int64_t menu_id, int32_t slot_index) {
    JNIEnv* env = get_jni_env_for_container();
    if (env == nullptr) return strdup("");

    if (!init_container_jni_cache(env)) return strdup("");

    jstring result = (jstring)env->CallStaticObjectMethod(g_dart_container_menu_class,
        g_get_container_item_impl, static_cast<jlong>(menu_id), static_cast<jint>(slot_index));

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return strdup("");
    }

    if (result == nullptr) return strdup("");

    const char* str = env->GetStringUTFChars(result, nullptr);
    char* copy = strdup(str);
    env->ReleaseStringUTFChars(result, str);
    env->DeleteLocalRef(result);

    return copy;
}

void dart_set_container_item(int64_t menu_id, int32_t slot_index, const char* item_id, int32_t count) {
    JNIEnv* env = get_jni_env_for_container();
    if (env == nullptr) return;

    if (!init_container_jni_cache(env)) return;

    jstring jItemId = env->NewStringUTF(item_id);
    env->CallStaticVoidMethod(g_dart_container_menu_class, g_set_container_item_impl,
        static_cast<jlong>(menu_id), static_cast<jint>(slot_index), jItemId, static_cast<jint>(count));
    env->DeleteLocalRef(jItemId);

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
    }
}

int32_t dart_get_container_slot_count(int64_t menu_id) {
    JNIEnv* env = get_jni_env_for_container();
    if (env == nullptr) return 0;

    if (!init_container_jni_cache(env)) return 0;

    jint result = env->CallStaticIntMethod(g_dart_container_menu_class,
        g_get_container_slot_count_impl, static_cast<jlong>(menu_id));

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return 0;
    }

    return static_cast<int32_t>(result);
}

void dart_clear_container_slot(int64_t menu_id, int32_t slot_index) {
    JNIEnv* env = get_jni_env_for_container();
    if (env == nullptr) return;

    if (!init_container_jni_cache(env)) return;

    env->CallStaticVoidMethod(g_dart_container_menu_class, g_clear_container_slot_impl,
        static_cast<jlong>(menu_id), static_cast<jint>(slot_index));

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
    }
}

// Free a string allocated by dart_get_container_item
void dart_free_string(const char* str) {
    if (str != nullptr) {
        free(const_cast<char*>(str));
    }
}

// ==========================================================================
// Container Opening API (Dart -> Java via C++)
// ==========================================================================

// Cached method ID for openContainerForPlayer
static jmethodID g_open_container_for_player = nullptr;

bool dart_open_container_for_player(int32_t player_id, const char* container_id) {
    JNIEnv* env = get_jni_env_for_container();
    if (env == nullptr) {
        std::cerr << "dart_open_container_for_player: Failed to get JNI environment" << std::endl;
        return false;
    }

    // Find DartBridge class if not cached
    static jclass dart_bridge_class = nullptr;
    if (dart_bridge_class == nullptr) {
        jclass localClass = env->FindClass("com/redstone/DartBridge");
        if (localClass == nullptr) {
            std::cerr << "dart_open_container_for_player: Failed to find DartBridge class" << std::endl;
            env->ExceptionClear();
            return false;
        }
        dart_bridge_class = static_cast<jclass>(env->NewGlobalRef(localClass));
        env->DeleteLocalRef(localClass);
    }

    // Get method ID if not cached
    if (g_open_container_for_player == nullptr) {
        g_open_container_for_player = env->GetStaticMethodID(
            dart_bridge_class, "openContainerForPlayer", "(ILjava/lang/String;)Z");
        if (g_open_container_for_player == nullptr) {
            std::cerr << "dart_open_container_for_player: Failed to find openContainerForPlayer method" << std::endl;
            env->ExceptionClear();
            return false;
        }
    }

    // Create Java string for container ID
    jstring jContainerId = env->NewStringUTF(container_id);
    if (jContainerId == nullptr) {
        std::cerr << "dart_open_container_for_player: Failed to create container ID string" << std::endl;
        return false;
    }

    // Call the Java method
    jboolean result = env->CallStaticBooleanMethod(
        dart_bridge_class, g_open_container_for_player,
        static_cast<jint>(player_id), jContainerId);

    env->DeleteLocalRef(jContainerId);

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return false;
    }

    return result == JNI_TRUE;
}

// ==========================================================================
// Entity Proxy Callback Registration (called from Dart via FFI)
// ==========================================================================

void register_proxy_entity_spawn_handler(ProxyEntitySpawnCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyEntitySpawnHandler(cb);
}

void register_proxy_entity_tick_handler(ProxyEntityTickCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyEntityTickHandler(cb);
}

void register_proxy_entity_death_handler(ProxyEntityDeathCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyEntityDeathHandler(cb);
}

void register_proxy_entity_damage_handler(ProxyEntityDamageCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyEntityDamageHandler(cb);
}

void register_proxy_entity_attack_handler(ProxyEntityAttackCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyEntityAttackHandler(cb);
}

void register_proxy_entity_target_handler(ProxyEntityTargetCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyEntityTargetHandler(cb);
}

// ==========================================================================
// Item Proxy Callback Registration (called from Dart via FFI)
// ==========================================================================

void register_proxy_item_attack_entity_handler(ProxyItemAttackEntityCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyItemAttackEntityHandler(cb);
}

// ==========================================================================
// Entity Proxy Dispatch (called from Java via JNI)
// ==========================================================================

void dispatch_proxy_entity_spawn(int64_t handler_id, int32_t entity_id, int64_t world_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntitySpawn(handler_id, entity_id, world_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_proxy_entity_tick(int64_t handler_id, int32_t entity_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntityTick(handler_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_proxy_entity_death(int64_t handler_id, int32_t entity_id, const char* damage_source) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntityDeath(handler_id, entity_id, damage_source);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

bool dispatch_proxy_entity_damage(int64_t handler_id, int32_t entity_id, const char* damage_source, double amount) {
    if (!g_initialized || g_isolate == nullptr) return true; // Allow damage if not initialized
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntityDamage(
        handler_id, entity_id, damage_source, amount);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

void dispatch_proxy_entity_attack(int64_t handler_id, int32_t entity_id, int32_t target_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntityAttack(handler_id, entity_id, target_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_proxy_entity_target(int64_t handler_id, int32_t entity_id, int32_t target_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntityTarget(handler_id, entity_id, target_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

// ==========================================================================
// Item Proxy Dispatch (called from Java via JNI)
// ==========================================================================

bool dispatch_proxy_item_attack_entity(int64_t handler_id, int32_t world_id, int32_t attacker_id, int32_t target_id) {
    if (!g_initialized || g_isolate == nullptr) return true; // Allow attack if not initialized
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchProxyItemAttackEntity(
        handler_id, world_id, attacker_id, target_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

// ==========================================================================
// Command System Registration and Dispatch
// ==========================================================================

void register_command_execute_handler(CommandExecuteCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setCommandExecuteHandler(cb);
}

int32_t dispatch_command_execute(int64_t command_id, int32_t player_id, const char* args_json) {
    if (!g_initialized || g_isolate == nullptr) return 0; // Failure if not initialized
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::CallbackRegistry::instance().dispatchCommandExecute(
        command_id, player_id, args_json);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

// ==========================================================================
// Custom Goal Callback Registration (called from Dart via FFI)
// ==========================================================================

void register_custom_goal_can_use_handler(CustomGoalCanUseCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setCustomGoalCanUseHandler(cb);
}

void register_custom_goal_can_continue_to_use_handler(CustomGoalCanContinueToUseCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setCustomGoalCanContinueToUseHandler(cb);
}

void register_custom_goal_start_handler(CustomGoalStartCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setCustomGoalStartHandler(cb);
}

void register_custom_goal_tick_handler(CustomGoalTickCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setCustomGoalTickHandler(cb);
}

void register_custom_goal_stop_handler(CustomGoalStopCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setCustomGoalStopHandler(cb);
}

// ==========================================================================
// Custom Goal Dispatch (called from Java via JNI)
// ==========================================================================

bool dispatch_custom_goal_can_use(const char* goal_id, int32_t entity_id) {
    if (!g_initialized || g_isolate == nullptr) return false;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchCustomGoalCanUse(goal_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool dispatch_custom_goal_can_continue_to_use(const char* goal_id, int32_t entity_id) {
    if (!g_initialized || g_isolate == nullptr) return false;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::CallbackRegistry::instance().dispatchCustomGoalCanContinueToUse(goal_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

void dispatch_custom_goal_start(const char* goal_id, int32_t entity_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchCustomGoalStart(goal_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_custom_goal_tick(const char* goal_id, int32_t entity_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchCustomGoalTick(goal_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dispatch_custom_goal_stop(const char* goal_id, int32_t entity_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchCustomGoalStop(goal_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

} // extern "C"
