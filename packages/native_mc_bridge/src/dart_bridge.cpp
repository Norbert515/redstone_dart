#include "dart_bridge.h"
#include "dart_bridge_server.h"
#include "callback_registry.h"
#include "object_registry.h"
#include "generic_jni.h"
#include <flutter_embedder.h>

#include <jni.h>
#include <iostream>
#include <string>
#include <cstring>
#include <mutex>
#include <thread>
#include <chrono>
#include <atomic>
#include <queue>
#include <vector>

// ==========================================================================
// Flutter Engine State
// ==========================================================================

static FlutterEngine g_engine = nullptr;
static bool g_initialized = false;
static bool g_rendering_enabled = false;
static std::mutex g_engine_mutex;

// ==========================================================================
// Custom Task Runner State (for merged thread approach)
// ==========================================================================
// By using custom task runners with the same identifier for platform, render,
// and UI, we make Flutter run the UI isolate on the platform thread. This
// allows FFI callbacks to be invoked directly from any thread since the Dart
// isolate runs on the same thread as the JNI calls.

static std::thread::id g_platform_thread_id;
static std::mutex g_task_mutex;
static std::queue<std::pair<FlutterTask, uint64_t>> g_pending_flutter_tasks;

// ==========================================================================
// Registration Queue System
// ==========================================================================
// When Flutter engine runs, Dart executes on a separate thread (Thread-3).
// Minecraft registry calls must happen on the Render thread.
// This queue system allows Dart to queue registrations from any thread,
// and Java processes them on the correct thread after FlutterEngineRun() returns.

struct BlockRegistrationRequest {
    int64_t handler_id;
    std::string namespace_id;
    std::string path;
    float hardness;
    float resistance;
    bool requires_tool;
    int32_t luminance;
    double slipperiness;
    double velocity_multiplier;
    double jump_velocity_multiplier;
    bool ticks_randomly;
    bool collidable;
    bool replaceable;
    bool burnable;
};

struct ItemRegistrationRequest {
    int64_t handler_id;
    std::string namespace_id;
    std::string path;
    int32_t max_stack_size;
    int32_t max_damage;
    bool fire_resistant;
    double attack_damage;
    double attack_speed;
    double attack_knockback;
};

struct EntityRegistrationRequest {
    int64_t handler_id;
    std::string namespace_id;
    std::string path;
    double width;
    double height;
    double max_health;
    double movement_speed;
    double attack_damage;
    int32_t spawn_group;
    int32_t base_type;
    std::string breeding_item;  // Empty if not applicable
    std::string model_type;     // Empty if no model
    std::string texture_path;   // Empty if no model
    double model_scale;
    std::string goals_json;        // Empty if no goals
    std::string target_goals_json; // Empty if no target goals
};

// Thread-safe queues for registration requests
static std::queue<BlockRegistrationRequest> g_block_registration_queue;
static std::queue<ItemRegistrationRequest> g_item_registration_queue;
static std::queue<EntityRegistrationRequest> g_entity_registration_queue;
static std::mutex g_registration_mutex;
static std::atomic<bool> g_registrations_complete{false};
static std::atomic<int64_t> g_next_block_handler_id{1};
static std::atomic<int64_t> g_next_item_handler_id{1};
static std::atomic<int64_t> g_next_entity_handler_id{1};

// Frame callback for client-side rendering
static FlutterFrameCallback g_frame_callback = nullptr;

// Window metrics state
static int32_t g_window_width = 800;
static int32_t g_window_height = 600;
static double g_pixel_ratio = 1.0;

// JVM reference for cleanup operations
static JavaVM* g_jvm_ref = nullptr;

// Java callback for sending chat messages
static SendChatMessageCallback g_send_chat_callback = nullptr;

// Registry ready callback - called when Java signals it's safe to register items/blocks
typedef void (*RegistryReadyCallback)();
static RegistryReadyCallback g_registry_ready_callback = nullptr;
static bool g_registry_ready_signaled = false;

// Debug: Call counters for profiling
static int g_tick_count = 0;
static int g_entity_tick_count = 0;
static int g_other_callback_count = 0;
static auto g_last_report_time = std::chrono::steady_clock::now();

// ==========================================================================
// Direct Callback System for Java→Dart Callbacks
// ==========================================================================
// With the merged thread approach using custom task runners, the Dart isolate
// runs on the same thread as JNI calls. This means FFI callbacks can be
// invoked directly without any queuing mechanism.

// ==========================================================================
// Custom Task Runner Callbacks (for merged thread approach)
// ==========================================================================

// Callback to check if we're on the platform thread
static bool TaskRunnerRunsOnCurrentThread(void* user_data) {
    return std::this_thread::get_id() == g_platform_thread_id;
}

// Callback to post a task - we store tasks and run them during processFlutterTasks
static void TaskRunnerPostTask(FlutterTask task, uint64_t target_time, void* user_data) {
    std::lock_guard<std::mutex> lock(g_task_mutex);
    g_pending_flutter_tasks.push({task, target_time});
}

// ==========================================================================
// Flutter Embedder Callbacks
// ==========================================================================

// Software renderer callback - called when Flutter has a frame ready
static bool OnSoftwareSurfacePresent(void* user_data,
                                      const void* allocation,
                                      size_t row_bytes,
                                      size_t height) {
    if (g_frame_callback && g_rendering_enabled) {
        size_t width = row_bytes / 4;  // RGBA = 4 bytes per pixel
        g_frame_callback(allocation, width, height, row_bytes);
    }
    return true;
}

// No-op callback for headless mode - discards frames
// Flutter requires a valid callback even when not rendering
static bool OnSoftwareSurfacePresentNoop(void* user_data,
                                          const void* allocation,
                                          size_t row_bytes,
                                          size_t height) {
    // Discard the frame - return true to indicate success
    return true;
}

// Platform message callback - handles messages from Dart to the native side
static void OnPlatformMessage(const FlutterPlatformMessage* message, void* user_data) {
    // Handle platform channel messages here if needed
    // For now, we don't need any platform channels for the Minecraft bridge
    // The callback system works through FFI, not platform channels
}

// Vsync callback - provides vsync timing to Flutter
static void OnVsync(void* user_data, intptr_t baton) {
    // For headless/software rendering, we don't have vsync
    // Just signal immediately
    uint64_t now = FlutterEngineGetCurrentTime();
    uint64_t frame_interval = 16666667;  // ~60fps in nanoseconds
    FlutterEngineOnVsync(g_engine, baton, now, now + frame_interval);
}

// Root isolate create callback - called when root isolate is created
static void OnRootIsolateCreate(void* user_data) {
    std::cout << "Flutter root isolate created" << std::endl;
}

// ==========================================================================
// Lifecycle Functions
// ==========================================================================

extern "C" {

bool dart_bridge_init(const char* assets_path, const char* icu_data_path,
                      const char* aot_library_path, bool enable_rendering) {
    std::lock_guard<std::mutex> lock(g_engine_mutex);

    if (g_initialized) {
        std::cerr << "Dart bridge already initialized" << std::endl;
        return false;
    }

    g_rendering_enabled = enable_rendering;

    std::cout << "Initializing Flutter engine..." << std::endl;
    std::cout << "  Assets path: " << (assets_path ? assets_path : "null") << std::endl;
    std::cout << "  ICU data path: " << (icu_data_path ? icu_data_path : "null") << std::endl;
    std::cout << "  AOT library: " << (aot_library_path ? aot_library_path : "JIT mode") << std::endl;
    std::cout << "  Rendering enabled: " << (enable_rendering ? "yes" : "no (headless)") << std::endl;

    // Configure renderer
    FlutterRendererConfig renderer = {};
    renderer.type = kSoftware;
    renderer.software.struct_size = sizeof(FlutterSoftwareRendererConfig);
    // Use no-op callback for headless mode - Flutter requires a valid callback
    renderer.software.surface_present_callback = enable_rendering ? OnSoftwareSurfacePresent : OnSoftwareSurfacePresentNoop;

    // Configure project args
    FlutterProjectArgs args = {};
    args.struct_size = sizeof(FlutterProjectArgs);
    args.assets_path = assets_path;
    args.icu_data_path = icu_data_path;

    // Set AOT library path if provided (for release mode)
    if (aot_library_path != nullptr && strlen(aot_library_path) > 0) {
        args.aot_data = nullptr;  // Will be loaded from the library path
        // Note: For AOT, we might need to load the library differently
        // depending on the platform. For now, assume assets_path contains the AOT data.
    }

    // Enable VM service for hot reload in debug mode
    // Note: In Flutter embedder, this is handled differently than dart_dll
    const char* vm_args[] = {
        "--enable-dart-profiling",
        "--enable-asserts",  // Enable asserts in debug mode
    };
    args.command_line_argc = 2;
    args.command_line_argv = vm_args;

    // Set up vsync callback
    args.vsync_callback = OnVsync;

    // Set up platform message callback
    args.platform_message_callback = OnPlatformMessage;

    // Set up root isolate create callback
    args.root_isolate_create_callback = OnRootIsolateCreate;

    // ==========================================================================
    // Set up custom task runners to run Flutter UI on the calling thread
    // This allows FFI callbacks to be invoked directly from the Java thread
    // since the Dart isolate runs on the same thread as the platform.
    // ==========================================================================

    // Remember the platform thread ID (the calling thread)
    g_platform_thread_id = std::this_thread::get_id();
    std::cout << "Platform thread ID captured" << std::endl;

    // Create the task runner description - all task runners use the same configuration
    // because we want everything to run on the same thread
    static FlutterTaskRunnerDescription platform_task_runner = {};
    platform_task_runner.struct_size = sizeof(FlutterTaskRunnerDescription);
    platform_task_runner.user_data = nullptr;
    platform_task_runner.runs_task_on_current_thread_callback = TaskRunnerRunsOnCurrentThread;
    platform_task_runner.post_task_callback = TaskRunnerPostTask;
    platform_task_runner.identifier = 1;  // All task runners with same identifier run on same thread
    platform_task_runner.destruction_callback = nullptr;

    // Create custom task runners - use same runner for platform, render, and UI
    static FlutterCustomTaskRunners custom_task_runners = {};
    custom_task_runners.struct_size = sizeof(FlutterCustomTaskRunners);
    custom_task_runners.platform_task_runner = &platform_task_runner;
    custom_task_runners.render_task_runner = &platform_task_runner;  // Same as platform
    custom_task_runners.ui_task_runner = &platform_task_runner;      // Run UI on platform thread
    custom_task_runners.thread_priority_setter = nullptr;

    args.custom_task_runners = &custom_task_runners;

    std::cout << "Custom task runners configured for merged thread approach" << std::endl;

    // Run the Flutter engine
    FlutterEngineResult result = FlutterEngineRun(
        FLUTTER_ENGINE_VERSION,
        &renderer,
        &args,
        nullptr,  // user_data
        &g_engine
    );

    if (result != kSuccess) {
        std::cerr << "Failed to start Flutter engine, error code: " << result << std::endl;
        return false;
    }

    // Send initial window metrics if rendering is enabled
    if (enable_rendering) {
        FlutterWindowMetricsEvent metrics = {};
        metrics.struct_size = sizeof(FlutterWindowMetricsEvent);
        metrics.width = g_window_width;
        metrics.height = g_window_height;
        metrics.pixel_ratio = g_pixel_ratio;

        FlutterEngineSendWindowMetricsEvent(g_engine, &metrics);
    }

    g_initialized = true;
    std::cout << "Flutter engine initialized successfully" << std::endl;
    return true;
}

void dart_bridge_shutdown() {
    std::lock_guard<std::mutex> lock(g_engine_mutex);

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

    // Shutdown Flutter engine
    if (g_engine != nullptr) {
        FlutterEngineResult result = FlutterEngineShutdown(g_engine);
        if (result != kSuccess) {
            std::cerr << "Warning: Flutter engine shutdown returned error: " << result << std::endl;
        }
        g_engine = nullptr;
    }

    g_initialized = false;
    g_jvm_ref = nullptr;
    g_frame_callback = nullptr;

    std::cout << "Dart bridge shutdown complete" << std::endl;
}

void dart_bridge_set_jvm(JavaVM* jvm) {
    g_jvm_ref = jvm;
    // Initialize generic JNI system with JVM reference
    generic_jni_init(jvm);
}

void dart_bridge_tick() {
    // In Flutter embedder mode, there's no explicit microtask queue draining needed.
    // Flutter handles its own event loop internally.
    // This function is kept for API compatibility but does nothing.

    // However, we might want to pump events here if Flutter isn't running its own thread
    // For now, this is a no-op as Flutter should handle its own scheduling
}

// ==========================================================================
// Flutter Rendering Support
// ==========================================================================

void dart_bridge_set_frame_callback(FlutterFrameCallback callback) {
    g_frame_callback = callback;
}

void dart_bridge_send_window_metrics(int32_t width, int32_t height, double pixel_ratio) {
    if (!g_initialized || g_engine == nullptr || !g_rendering_enabled) return;

    g_window_width = width;
    g_window_height = height;
    g_pixel_ratio = pixel_ratio;

    FlutterWindowMetricsEvent metrics = {};
    metrics.struct_size = sizeof(FlutterWindowMetricsEvent);
    metrics.width = width;
    metrics.height = height;
    metrics.pixel_ratio = pixel_ratio;

    FlutterEngineSendWindowMetricsEvent(g_engine, &metrics);
}

void dart_bridge_send_pointer_event(int32_t phase, double x, double y, int64_t buttons) {
    if (!g_initialized || g_engine == nullptr || !g_rendering_enabled) return;

    FlutterPointerEvent event = {};
    event.struct_size = sizeof(FlutterPointerEvent);
    event.phase = static_cast<FlutterPointerPhase>(phase);
    event.timestamp = FlutterEngineGetCurrentTime() / 1000;  // Convert to microseconds
    event.x = x;
    event.y = y;
    event.buttons = buttons;
    event.device_kind = kFlutterPointerDeviceKindMouse;

    FlutterEngineSendPointerEvent(g_engine, &event, 1);
}

void dart_bridge_send_key_event(int32_t type, int64_t physical_key, int64_t logical_key,
                                const char* character, int32_t modifiers) {
    if (!g_initialized || g_engine == nullptr || !g_rendering_enabled) return;

    FlutterKeyEvent event = {};
    event.struct_size = sizeof(FlutterKeyEvent);
    event.timestamp = static_cast<double>(FlutterEngineGetCurrentTime()) / 1000000000.0;  // Convert to seconds
    event.type = static_cast<FlutterKeyEventType>(type);
    event.physical = physical_key;
    event.logical = logical_key;
    event.character = character;
    event.synthesized = false;

    FlutterEngineSendKeyEvent(g_engine, &event, nullptr, nullptr);
}

// ==========================================================================
// Callback registration (called from Dart via FFI)
// Note: These work through FFI which is supported by Flutter's Dart VM
// ==========================================================================

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

// ==========================================================================
// Event dispatch (called from Java via JNI)
// Note: With Flutter embedder, we don't need manual isolate management.
// Flutter handles its own isolate and message loop internally.
// FFI callbacks registered from Dart will be called on the correct isolate.
// ==========================================================================

int32_t dispatch_block_break(int32_t x, int32_t y, int32_t z, int64_t player_id) {
    if (!g_initialized || g_engine == nullptr) return 1;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchBlockBreak(x, y, z, player_id);
}

int32_t dispatch_block_interact(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand) {
    if (!g_initialized || g_engine == nullptr) return 1;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchBlockInteract(x, y, z, player_id, hand);
}

void dispatch_tick(int64_t tick_value) {
    if (!g_initialized || g_engine == nullptr) return;

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

    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchTick(tick_value);
}

// Proxy block dispatch (called from Java proxy classes via JNI)
// Returns true if break should be allowed, false to cancel
bool dispatch_proxy_block_break(int64_t handler_id, int64_t world_id,
                                 int32_t x, int32_t y, int32_t z, int64_t player_id) {
    if (!g_initialized || g_engine == nullptr) return true; // Allow break if not initialized
    return dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockBreak(
        handler_id, world_id, x, y, z, player_id);
}

int32_t dispatch_proxy_block_use(int64_t handler_id, int64_t world_id,
                                  int32_t x, int32_t y, int32_t z,
                                  int64_t player_id, int32_t hand) {
    if (!g_initialized || g_engine == nullptr) return 3; // ActionResult.pass
    return dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockUse(
        handler_id, world_id, x, y, z, player_id, hand);
}

void dispatch_proxy_block_stepped_on(int64_t handler_id, int64_t world_id,
                                      int32_t x, int32_t y, int32_t z, int32_t entity_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockSteppedOn(
        handler_id, world_id, x, y, z, entity_id);
}

void dispatch_proxy_block_fallen_upon(int64_t handler_id, int64_t world_id,
                                       int32_t x, int32_t y, int32_t z, int32_t entity_id, float fall_distance) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockFallenUpon(
        handler_id, world_id, x, y, z, entity_id, fall_distance);
}

void dispatch_proxy_block_random_tick(int64_t handler_id, int64_t world_id,
                                       int32_t x, int32_t y, int32_t z) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockRandomTick(
        handler_id, world_id, x, y, z);
}

void dispatch_proxy_block_placed(int64_t handler_id, int64_t world_id,
                                  int32_t x, int32_t y, int32_t z, int64_t player_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockPlaced(
        handler_id, world_id, x, y, z, player_id);
}

void dispatch_proxy_block_removed(int64_t handler_id, int64_t world_id,
                                   int32_t x, int32_t y, int32_t z) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockRemoved(
        handler_id, world_id, x, y, z);
}

void dispatch_proxy_block_neighbor_changed(int64_t handler_id, int64_t world_id,
                                            int32_t x, int32_t y, int32_t z,
                                            int32_t neighbor_x, int32_t neighbor_y, int32_t neighbor_z) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockNeighborChanged(
        handler_id, world_id, x, y, z, neighbor_x, neighbor_y, neighbor_z);
}

void dispatch_proxy_block_entity_inside(int64_t handler_id, int64_t world_id,
                                         int32_t x, int32_t y, int32_t z, int32_t entity_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyBlockEntityInside(
        handler_id, world_id, x, y, z, entity_id);
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
// Note: With Flutter embedder, the observatory/DevTools URL is different
// It's typically ws://127.0.0.1:<port>/ws for Flutter DevTools
const char* get_dart_service_url() {
    // TODO: Get the actual VM service URI from Flutter engine
    // For now, return a placeholder that indicates Flutter mode
    if (g_initialized) {
        return "flutter://vm-service";
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
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerJoin(player_id);
}

void dispatch_player_leave(int32_t player_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerLeave(player_id);
}

void dispatch_player_respawn(int32_t player_id, bool end_conquered) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerRespawn(player_id, end_conquered);
}

char* dispatch_player_death(int32_t player_id, const char* damage_source) {
    if (!g_initialized || g_engine == nullptr) return nullptr;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerDeath(player_id, damage_source);
}

bool dispatch_entity_damage(int32_t entity_id, const char* damage_source, double amount) {
    if (!g_initialized || g_engine == nullptr) return true;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchEntityDamage(entity_id, damage_source, amount);
}

void dispatch_entity_death(int32_t entity_id, const char* damage_source) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchEntityDeath(entity_id, damage_source);
}

bool dispatch_player_attack_entity(int32_t player_id, int32_t target_id) {
    if (!g_initialized || g_engine == nullptr) return true;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerAttackEntity(player_id, target_id);
}

char* dispatch_player_chat(int32_t player_id, const char* message) {
    if (!g_initialized || g_engine == nullptr) return nullptr;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerChat(player_id, message);
}

bool dispatch_player_command(int32_t player_id, const char* command) {
    if (!g_initialized || g_engine == nullptr) return true;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerCommand(player_id, command);
}

bool dispatch_item_use(int32_t player_id, const char* item_id, int32_t count, int32_t hand) {
    if (!g_initialized || g_engine == nullptr) return true;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchItemUse(player_id, item_id, count, hand);
}

int32_t dispatch_item_use_on_block(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                    int32_t x, int32_t y, int32_t z, int32_t face) {
    if (!g_initialized || g_engine == nullptr) return 1;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchItemUseOnBlock(
        player_id, item_id, count, hand, x, y, z, face);
}

int32_t dispatch_item_use_on_entity(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                     int32_t target_id) {
    if (!g_initialized || g_engine == nullptr) return 1;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchItemUseOnEntity(
        player_id, item_id, count, hand, target_id);
}

bool dispatch_block_place(int32_t player_id, int32_t x, int32_t y, int32_t z, const char* block_id) {
    if (!g_initialized || g_engine == nullptr) return true;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchBlockPlace(player_id, x, y, z, block_id);
}

bool dispatch_player_pickup_item(int32_t player_id, int32_t item_entity_id) {
    if (!g_initialized || g_engine == nullptr) return true;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerPickupItem(player_id, item_entity_id);
}

bool dispatch_player_drop_item(int32_t player_id, const char* item_id, int32_t count) {
    if (!g_initialized || g_engine == nullptr) return true;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchPlayerDropItem(player_id, item_id, count);
}

void dispatch_server_starting() {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchServerStarting();
}

void dispatch_server_started() {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchServerStarted();
}

void dispatch_server_stopping() {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchServerStopping();
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
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchScreenInit(screen_id, width, height);
}

void dispatch_screen_tick(int64_t screen_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchScreenTick(screen_id);
}

void dispatch_screen_render(int64_t screen_id, int32_t mouse_x, int32_t mouse_y, float partial_tick) {
    if (!g_initialized || g_engine == nullptr) return;
    dart_mc_bridge::CallbackRegistry::instance().dispatchScreenRender(screen_id, mouse_x, mouse_y, partial_tick);
}

void dispatch_screen_close(int64_t screen_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchScreenClose(screen_id);
}

bool dispatch_screen_key_pressed(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers) {
    if (!g_initialized || g_engine == nullptr) return false;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchScreenKeyPressed(screen_id, key_code, scan_code, modifiers);
}

bool dispatch_screen_key_released(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers) {
    if (!g_initialized || g_engine == nullptr) return false;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchScreenKeyReleased(screen_id, key_code, scan_code, modifiers);
}

bool dispatch_screen_char_typed(int64_t screen_id, int32_t code_point, int32_t modifiers) {
    if (!g_initialized || g_engine == nullptr) return false;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchScreenCharTyped(screen_id, code_point, modifiers);
}

bool dispatch_screen_mouse_clicked(int64_t screen_id, double mouse_x, double mouse_y, int32_t button) {
    if (!g_initialized || g_engine == nullptr) return false;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchScreenMouseClicked(screen_id, mouse_x, mouse_y, button);
}

bool dispatch_screen_mouse_released(int64_t screen_id, double mouse_x, double mouse_y, int32_t button) {
    if (!g_initialized || g_engine == nullptr) return false;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchScreenMouseReleased(screen_id, mouse_x, mouse_y, button);
}

bool dispatch_screen_mouse_dragged(int64_t screen_id, double mouse_x, double mouse_y, int32_t button, double drag_x, double drag_y) {
    if (!g_initialized || g_engine == nullptr) return false;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchScreenMouseDragged(screen_id, mouse_x, mouse_y, button, drag_x, drag_y);
}

bool dispatch_screen_mouse_scrolled(int64_t screen_id, double mouse_x, double mouse_y, double delta_x, double delta_y) {
    if (!g_initialized || g_engine == nullptr) return false;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchScreenMouseScrolled(screen_id, mouse_x, mouse_y, delta_x, delta_y);
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
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchWidgetPressed(screen_id, widget_id);
}

void dispatch_widget_text_changed(int64_t screen_id, int64_t widget_id, const char* text) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchWidgetTextChanged(screen_id, widget_id, text);
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
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchContainerScreenInit(
        screen_id, width, height, left_pos, top_pos, image_width, image_height);
}

void dispatch_container_screen_render_bg(int64_t screen_id, int32_t mouse_x, int32_t mouse_y,
                                         float partial_tick, int32_t left_pos, int32_t top_pos) {
    if (!g_initialized || g_engine == nullptr) return;
    dart_mc_bridge::CallbackRegistry::instance().dispatchContainerScreenRenderBg(
        screen_id, mouse_x, mouse_y, partial_tick, left_pos, top_pos);
}

void dispatch_container_screen_close(int64_t screen_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchContainerScreenClose(screen_id);
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
    if (!g_initialized || g_engine == nullptr) return 0;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchContainerSlotClick(
        menu_id, slot_index, button, click_type, carried_item);
}

const char* dispatch_container_quick_move(int64_t menu_id, int32_t slot_index) {
    if (!g_initialized || g_engine == nullptr) return nullptr;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchContainerQuickMove(
        menu_id, slot_index);
}

bool dispatch_container_may_place(int64_t menu_id, int32_t slot_index, const char* item_data) {
    if (!g_initialized || g_engine == nullptr) return true;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchContainerMayPlace(
        menu_id, slot_index, item_data);
}

bool dispatch_container_may_pickup(int64_t menu_id, int32_t slot_index) {
    if (!g_initialized || g_engine == nullptr) return true;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchContainerMayPickup(
        menu_id, slot_index);
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

void register_proxy_item_use_handler(ProxyItemUseCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyItemUseHandler(cb);
}

void register_proxy_item_use_on_block_handler(ProxyItemUseOnBlockCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyItemUseOnBlockHandler(cb);
}

void register_proxy_item_use_on_entity_handler(ProxyItemUseOnEntityCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyItemUseOnEntityHandler(cb);
}

// ==========================================================================
// Entity Proxy Dispatch (called from Java via JNI)
// ==========================================================================

void dispatch_proxy_entity_spawn(int64_t handler_id, int32_t entity_id, int64_t world_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntitySpawn(
        handler_id, entity_id, world_id);
}

void dispatch_proxy_entity_tick(int64_t handler_id, int32_t entity_id) {
    if (!g_initialized || g_engine == nullptr) return;
    g_entity_tick_count++;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntityTick(
        handler_id, entity_id);
}

void dispatch_proxy_entity_death(int64_t handler_id, int32_t entity_id, const char* damage_source) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntityDeath(
        handler_id, entity_id, damage_source);
}

bool dispatch_proxy_entity_damage(int64_t handler_id, int32_t entity_id, const char* damage_source, double amount) {
    if (!g_initialized || g_engine == nullptr) return true; // Allow damage if not initialized
    return dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntityDamage(
        handler_id, entity_id, damage_source, amount);
}

void dispatch_proxy_entity_attack(int64_t handler_id, int32_t entity_id, int32_t target_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntityAttack(
        handler_id, entity_id, target_id);
}

void dispatch_proxy_entity_target(int64_t handler_id, int32_t entity_id, int32_t target_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntityTarget(
        handler_id, entity_id, target_id);
}

// ==========================================================================
// Item Proxy Dispatch (called from Java via JNI)
// ==========================================================================

bool dispatch_proxy_item_attack_entity(int64_t handler_id, int32_t world_id, int32_t attacker_id, int32_t target_id) {
    if (!g_initialized || g_engine == nullptr) return true; // Allow attack if not initialized
    return dart_mc_bridge::CallbackRegistry::instance().dispatchProxyItemAttackEntity(
        handler_id, world_id, attacker_id, target_id);
}

int32_t dispatch_proxy_item_use(int64_t handler_id, int64_t world_id, int32_t player_id, int32_t hand) {
    if (!g_initialized || g_engine == nullptr) return 4; // PASS if not initialized
    return dart_mc_bridge::CallbackRegistry::instance().dispatchProxyItemUse(
        handler_id, world_id, player_id, hand);
}

int32_t dispatch_proxy_item_use_on_block(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t player_id, int32_t hand) {
    if (!g_initialized || g_engine == nullptr) return 4; // PASS if not initialized
    return dart_mc_bridge::CallbackRegistry::instance().dispatchProxyItemUseOnBlock(
        handler_id, world_id, x, y, z, player_id, hand);
}

int32_t dispatch_proxy_item_use_on_entity(int64_t handler_id, int64_t world_id, int32_t entity_id, int32_t player_id, int32_t hand) {
    if (!g_initialized || g_engine == nullptr) return 4; // PASS if not initialized
    return dart_mc_bridge::CallbackRegistry::instance().dispatchProxyItemUseOnEntity(
        handler_id, world_id, entity_id, player_id, hand);
}

// ==========================================================================
// Command System Registration and Dispatch
// ==========================================================================

void register_command_execute_handler(CommandExecuteCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setCommandExecuteHandler(cb);
}

int32_t dispatch_command_execute(int64_t command_id, int32_t player_id, const char* args_json) {
    if (!g_initialized || g_engine == nullptr) return 0; // Failure if not initialized
    return dart_mc_bridge::CallbackRegistry::instance().dispatchCommandExecute(
        command_id, player_id, args_json);
}

// ==========================================================================
// Registry Ready Callback (for Flutter embedder timing)
// ==========================================================================

void register_registry_ready_callback(RegistryReadyCallback callback) {
    g_registry_ready_callback = callback;
    std::cout << "Registry ready callback registered" << std::endl;

    // If signal was already received, invoke callback immediately
    if (g_registry_ready_signaled && callback) {
        std::cout << "Registry already ready - invoking callback immediately" << std::endl;
        callback();
    }
}

void signal_registry_ready() {
    std::cout << "Registry ready signal received from Java" << std::endl;
    g_registry_ready_signaled = true;

    // In dual-runtime mode, delegate to server_dispatch_registry_ready which
    // properly enters the server isolate before calling the callback.
    // This is needed because Java calls signalRegistryReady from the Render thread,
    // but the Dart callback is registered in the Server isolate's thread.
    server_dispatch_registry_ready();
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
    if (!g_initialized || g_engine == nullptr) return false;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchCustomGoalCanUse(goal_id, entity_id);
}

bool dispatch_custom_goal_can_continue_to_use(const char* goal_id, int32_t entity_id) {
    if (!g_initialized || g_engine == nullptr) return false;
    return dart_mc_bridge::CallbackRegistry::instance().dispatchCustomGoalCanContinueToUse(goal_id, entity_id);
}

void dispatch_custom_goal_start(const char* goal_id, int32_t entity_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchCustomGoalStart(
        goal_id, entity_id);
}

void dispatch_custom_goal_tick(const char* goal_id, int32_t entity_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchCustomGoalTick(
        goal_id, entity_id);
}

void dispatch_custom_goal_stop(const char* goal_id, int32_t entity_id) {
    if (!g_initialized || g_engine == nullptr) return;
    // Direct callback - merged thread approach allows this
    dart_mc_bridge::CallbackRegistry::instance().dispatchCustomGoalStop(
        goal_id, entity_id);
}

// ==========================================================================
// Registration Queue Functions (called from Dart via FFI on Thread-3)
// ==========================================================================

// Queue a block registration - called from Dart (any thread)
// Returns the pre-allocated handler ID so Dart can use it immediately
int64_t queue_block_registration(
    const char* namespace_id,
    const char* path,
    float hardness,
    float resistance,
    bool requires_tool,
    int32_t luminance,
    double slipperiness,
    double velocity_multiplier,
    double jump_velocity_multiplier,
    bool ticks_randomly,
    bool collidable,
    bool replaceable,
    bool burnable
) {
    std::lock_guard<std::mutex> lock(g_registration_mutex);

    // Pre-allocate handler ID
    int64_t handler_id = g_next_block_handler_id.fetch_add(1);

    BlockRegistrationRequest req;
    req.handler_id = handler_id;
    req.namespace_id = namespace_id ? namespace_id : "";
    req.path = path ? path : "";
    req.hardness = hardness;
    req.resistance = resistance;
    req.requires_tool = requires_tool;
    req.luminance = luminance;
    req.slipperiness = slipperiness;
    req.velocity_multiplier = velocity_multiplier;
    req.jump_velocity_multiplier = jump_velocity_multiplier;
    req.ticks_randomly = ticks_randomly;
    req.collidable = collidable;
    req.replaceable = replaceable;
    req.burnable = burnable;

    g_block_registration_queue.push(req);

    std::cout << "Queued block registration: " << namespace_id << ":" << path
              << " (handler_id=" << handler_id << ")" << std::endl;

    return handler_id;
}

// Queue an item registration - called from Dart (any thread)
// Returns the pre-allocated handler ID so Dart can use it immediately
int64_t queue_item_registration(
    const char* namespace_id,
    const char* path,
    int32_t max_stack_size,
    int32_t max_damage,
    bool fire_resistant,
    double attack_damage,
    double attack_speed,
    double attack_knockback
) {
    std::lock_guard<std::mutex> lock(g_registration_mutex);

    // Pre-allocate handler ID
    int64_t handler_id = g_next_item_handler_id.fetch_add(1);

    ItemRegistrationRequest req;
    req.handler_id = handler_id;
    req.namespace_id = namespace_id ? namespace_id : "";
    req.path = path ? path : "";
    req.max_stack_size = max_stack_size;
    req.max_damage = max_damage;
    req.fire_resistant = fire_resistant;
    req.attack_damage = attack_damage;
    req.attack_speed = attack_speed;
    req.attack_knockback = attack_knockback;

    g_item_registration_queue.push(req);

    std::cout << "Queued item registration: " << namespace_id << ":" << path
              << " (handler_id=" << handler_id << ")" << std::endl;

    return handler_id;
}

// Signal that Dart has finished queueing registrations
void signal_registrations_queued() {
    std::cout << "Dart signaled registrations are queued" << std::endl;
    g_registrations_complete.store(true);
}

// Check if Dart has signaled completion
bool are_registrations_queued() {
    return g_registrations_complete.load();
}

// Check if there are pending block registrations
bool has_pending_block_registrations() {
    std::lock_guard<std::mutex> lock(g_registration_mutex);
    return !g_block_registration_queue.empty();
}

// Check if there are pending item registrations
bool has_pending_item_registrations() {
    std::lock_guard<std::mutex> lock(g_registration_mutex);
    return !g_item_registration_queue.empty();
}

// Get next block registration from queue
// Returns false if queue is empty
// out_* parameters are filled with the registration data
bool get_next_block_registration(
    int64_t* out_handler_id,
    char* out_namespace, int32_t namespace_len,
    char* out_path, int32_t path_len,
    float* out_hardness,
    float* out_resistance,
    bool* out_requires_tool,
    int32_t* out_luminance,
    double* out_slipperiness,
    double* out_velocity_multiplier,
    double* out_jump_velocity_multiplier,
    bool* out_ticks_randomly,
    bool* out_collidable,
    bool* out_replaceable,
    bool* out_burnable
) {
    std::lock_guard<std::mutex> lock(g_registration_mutex);

    if (g_block_registration_queue.empty()) return false;

    const auto& req = g_block_registration_queue.front();

    *out_handler_id = req.handler_id;
    strncpy(out_namespace, req.namespace_id.c_str(), namespace_len - 1);
    out_namespace[namespace_len - 1] = '\0';
    strncpy(out_path, req.path.c_str(), path_len - 1);
    out_path[path_len - 1] = '\0';
    *out_hardness = req.hardness;
    *out_resistance = req.resistance;
    *out_requires_tool = req.requires_tool;
    *out_luminance = req.luminance;
    *out_slipperiness = req.slipperiness;
    *out_velocity_multiplier = req.velocity_multiplier;
    *out_jump_velocity_multiplier = req.jump_velocity_multiplier;
    *out_ticks_randomly = req.ticks_randomly;
    *out_collidable = req.collidable;
    *out_replaceable = req.replaceable;
    *out_burnable = req.burnable;

    g_block_registration_queue.pop();
    return true;
}

// Get next item registration from queue
// Returns false if queue is empty
bool get_next_item_registration(
    int64_t* out_handler_id,
    char* out_namespace, int32_t namespace_len,
    char* out_path, int32_t path_len,
    int32_t* out_max_stack_size,
    int32_t* out_max_damage,
    bool* out_fire_resistant,
    double* out_attack_damage,
    double* out_attack_speed,
    double* out_attack_knockback
) {
    std::lock_guard<std::mutex> lock(g_registration_mutex);

    if (g_item_registration_queue.empty()) return false;

    const auto& req = g_item_registration_queue.front();

    *out_handler_id = req.handler_id;
    strncpy(out_namespace, req.namespace_id.c_str(), namespace_len - 1);
    out_namespace[namespace_len - 1] = '\0';
    strncpy(out_path, req.path.c_str(), path_len - 1);
    out_path[path_len - 1] = '\0';
    *out_max_stack_size = req.max_stack_size;
    *out_max_damage = req.max_damage;
    *out_fire_resistant = req.fire_resistant;
    *out_attack_damage = req.attack_damage;
    *out_attack_speed = req.attack_speed;
    *out_attack_knockback = req.attack_knockback;

    g_item_registration_queue.pop();
    return true;
}

// ==========================================================================
// Entity Registration Queue Functions (called from Dart via FFI on Thread-3)
// ==========================================================================

// Queue an entity registration - called from Dart (any thread)
// Returns the pre-allocated handler ID so Dart can use it immediately
int64_t queue_entity_registration(
    const char* namespace_id,
    const char* path,
    double width,
    double height,
    double max_health,
    double movement_speed,
    double attack_damage,
    int32_t spawn_group,
    int32_t base_type,
    const char* breeding_item,
    const char* model_type,
    const char* texture_path,
    double model_scale,
    const char* goals_json,
    const char* target_goals_json
) {
    std::lock_guard<std::mutex> lock(g_registration_mutex);

    // Pre-allocate handler ID
    int64_t handler_id = g_next_entity_handler_id.fetch_add(1);

    EntityRegistrationRequest req;
    req.handler_id = handler_id;
    req.namespace_id = namespace_id ? namespace_id : "";
    req.path = path ? path : "";
    req.width = width;
    req.height = height;
    req.max_health = max_health;
    req.movement_speed = movement_speed;
    req.attack_damage = attack_damage;
    req.spawn_group = spawn_group;
    req.base_type = base_type;
    req.breeding_item = breeding_item ? breeding_item : "";
    req.model_type = model_type ? model_type : "";
    req.texture_path = texture_path ? texture_path : "";
    req.model_scale = model_scale;
    req.goals_json = goals_json ? goals_json : "";
    req.target_goals_json = target_goals_json ? target_goals_json : "";

    g_entity_registration_queue.push(req);

    std::cout << "Queued entity registration: " << namespace_id << ":" << path
              << " (handler_id=" << handler_id << ", base_type=" << base_type << ")" << std::endl;

    return handler_id;
}

// Check if there are pending entity registrations
bool has_pending_entity_registrations() {
    std::lock_guard<std::mutex> lock(g_registration_mutex);
    return !g_entity_registration_queue.empty();
}

// Get next entity registration from queue
// Returns false if queue is empty
bool get_next_entity_registration(
    int64_t* out_handler_id,
    char* out_namespace, int32_t namespace_len,
    char* out_path, int32_t path_len,
    double* out_width,
    double* out_height,
    double* out_max_health,
    double* out_movement_speed,
    double* out_attack_damage,
    int32_t* out_spawn_group,
    int32_t* out_base_type,
    char* out_breeding_item, int32_t breeding_item_len,
    char* out_model_type, int32_t model_type_len,
    char* out_texture_path, int32_t texture_path_len,
    double* out_model_scale,
    char* out_goals_json, int32_t goals_json_len,
    char* out_target_goals_json, int32_t target_goals_json_len
) {
    std::lock_guard<std::mutex> lock(g_registration_mutex);

    if (g_entity_registration_queue.empty()) return false;

    const auto& req = g_entity_registration_queue.front();

    *out_handler_id = req.handler_id;
    strncpy(out_namespace, req.namespace_id.c_str(), namespace_len - 1);
    out_namespace[namespace_len - 1] = '\0';
    strncpy(out_path, req.path.c_str(), path_len - 1);
    out_path[path_len - 1] = '\0';
    *out_width = req.width;
    *out_height = req.height;
    *out_max_health = req.max_health;
    *out_movement_speed = req.movement_speed;
    *out_attack_damage = req.attack_damage;
    *out_spawn_group = req.spawn_group;
    *out_base_type = req.base_type;
    strncpy(out_breeding_item, req.breeding_item.c_str(), breeding_item_len - 1);
    out_breeding_item[breeding_item_len - 1] = '\0';
    strncpy(out_model_type, req.model_type.c_str(), model_type_len - 1);
    out_model_type[model_type_len - 1] = '\0';
    strncpy(out_texture_path, req.texture_path.c_str(), texture_path_len - 1);
    out_texture_path[texture_path_len - 1] = '\0';
    *out_model_scale = req.model_scale;
    strncpy(out_goals_json, req.goals_json.c_str(), goals_json_len - 1);
    out_goals_json[goals_json_len - 1] = '\0';
    strncpy(out_target_goals_json, req.target_goals_json.c_str(), target_goals_json_len - 1);
    out_target_goals_json[target_goals_json_len - 1] = '\0';

    g_entity_registration_queue.pop();
    return true;
}

// ==========================================================================
// Flutter Task Processing (for merged thread approach)
// ==========================================================================
// Process pending Flutter tasks - call this from the game loop to pump
// the Flutter engine's event loop. This executes tasks that Flutter has
// scheduled (timers, UI updates, etc.)

void process_flutter_tasks() {
    if (!g_initialized || g_engine == nullptr) return;

    // Extract all tasks that are ready to run
    std::queue<std::pair<FlutterTask, uint64_t>> tasks_to_run;
    {
        std::lock_guard<std::mutex> lock(g_task_mutex);
        std::swap(tasks_to_run, g_pending_flutter_tasks);
    }

    uint64_t current_time = FlutterEngineGetCurrentTime();

    while (!tasks_to_run.empty()) {
        auto& task_pair = tasks_to_run.front();
        if (task_pair.second <= current_time) {
            // Task is ready to run
            FlutterEngineRunTask(g_engine, &task_pair.first);
        } else {
            // Task is not ready yet - re-queue it
            std::lock_guard<std::mutex> lock(g_task_mutex);
            g_pending_flutter_tasks.push(task_pair);
        }
        tasks_to_run.pop();
    }
}

} // extern "C"

// ==========================================================================
// JNI Interface for Flutter Task Processing
// ==========================================================================

// Process pending Flutter tasks - call this from Java's game loop
// This allows Flutter's scheduled tasks to execute on the correct thread
extern "C" JNIEXPORT void JNICALL
Java_com_redstone_DartBridge_processFlutterTasks(JNIEnv* env, jclass clazz) {
    process_flutter_tasks();
}
