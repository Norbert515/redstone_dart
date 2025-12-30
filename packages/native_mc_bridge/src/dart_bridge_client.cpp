#include "dart_bridge_client.h"
#include "callback_registry.h"
#include "object_registry.h"
#include "generic_jni.h"
#include <flutter_embedder.h>

#include <iostream>
#include <string>
#include <cstring>
#include <mutex>
#include <thread>
#include <queue>
#include <chrono>

// ==========================================================================
// Flutter Engine State
// ==========================================================================

static FlutterEngine g_client_engine = nullptr;
static bool g_client_initialized = false;
static bool g_client_shutdown_requested = false;
static std::mutex g_client_engine_mutex;

// ==========================================================================
// Custom Task Runner State (for merged thread approach)
// ==========================================================================

static std::thread::id g_client_platform_thread_id;
static std::mutex g_client_task_mutex;
static std::queue<std::pair<FlutterTask, uint64_t>> g_client_pending_flutter_tasks;

// Frame callback for client-side rendering
static FrameCallback g_client_frame_callback = nullptr;

// Window metrics state
static int32_t g_client_window_width = 800;
static int32_t g_client_window_height = 600;
static double g_client_pixel_ratio = 1.0;

// JVM reference
static JavaVM* g_client_jvm_ref = nullptr;

// ==========================================================================
// Client Callback Registry (separate from server)
// ==========================================================================

namespace dart_mc_bridge {

class ClientCallbackRegistry {
public:
    static ClientCallbackRegistry& instance() {
        static ClientCallbackRegistry registry;
        return registry;
    }

    // Screen handlers
    void setScreenInitHandler(ScreenInitCallback cb) { screen_init_handler_ = cb; }
    void setScreenTickHandler(ScreenTickCallback cb) { screen_tick_handler_ = cb; }
    void setScreenRenderHandler(ScreenRenderCallback cb) { screen_render_handler_ = cb; }
    void setScreenCloseHandler(ScreenCloseCallback cb) { screen_close_handler_ = cb; }
    void setScreenKeyPressedHandler(ScreenKeyPressedCallback cb) { screen_key_pressed_handler_ = cb; }
    void setScreenKeyReleasedHandler(ScreenKeyReleasedCallback cb) { screen_key_released_handler_ = cb; }
    void setScreenCharTypedHandler(ScreenCharTypedCallback cb) { screen_char_typed_handler_ = cb; }
    void setScreenMouseClickedHandler(ScreenMouseClickedCallback cb) { screen_mouse_clicked_handler_ = cb; }
    void setScreenMouseReleasedHandler(ScreenMouseReleasedCallback cb) { screen_mouse_released_handler_ = cb; }
    void setScreenMouseDraggedHandler(ScreenMouseDraggedCallback cb) { screen_mouse_dragged_handler_ = cb; }
    void setScreenMouseScrolledHandler(ScreenMouseScrolledCallback cb) { screen_mouse_scrolled_handler_ = cb; }

    // Widget handlers
    void setWidgetPressedHandler(WidgetPressedCallback cb) { widget_pressed_handler_ = cb; }
    void setWidgetTextChangedHandler(WidgetTextChangedCallback cb) { widget_text_changed_handler_ = cb; }

    // Container screen handlers
    void setContainerScreenInitHandler(ContainerScreenInitCallback cb) { container_screen_init_handler_ = cb; }
    void setContainerScreenRenderBgHandler(ContainerScreenRenderBgCallback cb) { container_screen_render_bg_handler_ = cb; }
    void setContainerScreenCloseHandler(ContainerScreenCloseCallback cb) { container_screen_close_handler_ = cb; }

    // Container menu handlers
    void setContainerSlotClickHandler(ContainerSlotClickCallback cb) { container_slot_click_handler_ = cb; }
    void setContainerQuickMoveHandler(ContainerQuickMoveCallback cb) { container_quick_move_handler_ = cb; }
    void setContainerMayPlaceHandler(ContainerMayPlaceCallback cb) { container_may_place_handler_ = cb; }
    void setContainerMayPickupHandler(ContainerMayPickupCallback cb) { container_may_pickup_handler_ = cb; }

    // Network packet handler
    void setPacketReceivedHandler(ClientPacketReceivedCallback cb) { packet_received_handler_ = cb; }

    // Dispatch methods
    void dispatchScreenInit(int64_t screen_id, int32_t width, int32_t height) {
        if (screen_init_handler_) screen_init_handler_(screen_id, width, height);
    }

    void dispatchScreenTick(int64_t screen_id) {
        if (screen_tick_handler_) screen_tick_handler_(screen_id);
    }

    void dispatchScreenRender(int64_t screen_id, int32_t mouse_x, int32_t mouse_y, float partial_tick) {
        if (screen_render_handler_) screen_render_handler_(screen_id, mouse_x, mouse_y, partial_tick);
    }

    void dispatchScreenClose(int64_t screen_id) {
        if (screen_close_handler_) screen_close_handler_(screen_id);
    }

    bool dispatchScreenKeyPressed(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers) {
        if (screen_key_pressed_handler_) return screen_key_pressed_handler_(screen_id, key_code, scan_code, modifiers);
        return false;
    }

    bool dispatchScreenKeyReleased(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers) {
        if (screen_key_released_handler_) return screen_key_released_handler_(screen_id, key_code, scan_code, modifiers);
        return false;
    }

    bool dispatchScreenCharTyped(int64_t screen_id, int32_t code_point, int32_t modifiers) {
        if (screen_char_typed_handler_) return screen_char_typed_handler_(screen_id, code_point, modifiers);
        return false;
    }

    bool dispatchScreenMouseClicked(int64_t screen_id, double mouse_x, double mouse_y, int32_t button) {
        if (screen_mouse_clicked_handler_) return screen_mouse_clicked_handler_(screen_id, mouse_x, mouse_y, button);
        return false;
    }

    bool dispatchScreenMouseReleased(int64_t screen_id, double mouse_x, double mouse_y, int32_t button) {
        if (screen_mouse_released_handler_) return screen_mouse_released_handler_(screen_id, mouse_x, mouse_y, button);
        return false;
    }

    bool dispatchScreenMouseDragged(int64_t screen_id, double mouse_x, double mouse_y, int32_t button, double drag_x, double drag_y) {
        if (screen_mouse_dragged_handler_) return screen_mouse_dragged_handler_(screen_id, mouse_x, mouse_y, button, drag_x, drag_y);
        return false;
    }

    bool dispatchScreenMouseScrolled(int64_t screen_id, double mouse_x, double mouse_y, double delta_x, double delta_y) {
        if (screen_mouse_scrolled_handler_) return screen_mouse_scrolled_handler_(screen_id, mouse_x, mouse_y, delta_x, delta_y);
        return false;
    }

    void dispatchWidgetPressed(int64_t screen_id, int64_t widget_id) {
        if (widget_pressed_handler_) widget_pressed_handler_(screen_id, widget_id);
    }

    void dispatchWidgetTextChanged(int64_t screen_id, int64_t widget_id, const char* text) {
        if (widget_text_changed_handler_) widget_text_changed_handler_(screen_id, widget_id, text);
    }

    void dispatchContainerScreenInit(int64_t screen_id, int32_t width, int32_t height,
                                     int32_t left_pos, int32_t top_pos, int32_t image_width, int32_t image_height) {
        if (container_screen_init_handler_) container_screen_init_handler_(screen_id, width, height, left_pos, top_pos, image_width, image_height);
    }

    void dispatchContainerScreenRenderBg(int64_t screen_id, int32_t mouse_x, int32_t mouse_y,
                                         float partial_tick, int32_t left_pos, int32_t top_pos) {
        if (container_screen_render_bg_handler_) container_screen_render_bg_handler_(screen_id, mouse_x, mouse_y, partial_tick, left_pos, top_pos);
    }

    void dispatchContainerScreenClose(int64_t screen_id) {
        if (container_screen_close_handler_) container_screen_close_handler_(screen_id);
    }

    int32_t dispatchContainerSlotClick(int64_t menu_id, int32_t slot_index, int32_t button, int32_t click_type, const char* carried_item) {
        if (container_slot_click_handler_) return container_slot_click_handler_(menu_id, slot_index, button, click_type, carried_item);
        return 0;
    }

    const char* dispatchContainerQuickMove(int64_t menu_id, int32_t slot_index) {
        if (container_quick_move_handler_) return container_quick_move_handler_(menu_id, slot_index);
        return nullptr;
    }

    bool dispatchContainerMayPlace(int64_t menu_id, int32_t slot_index, const char* item_data) {
        if (container_may_place_handler_) return container_may_place_handler_(menu_id, slot_index, item_data);
        return true;
    }

    bool dispatchContainerMayPickup(int64_t menu_id, int32_t slot_index) {
        if (container_may_pickup_handler_) return container_may_pickup_handler_(menu_id, slot_index);
        return true;
    }

    // Network packet dispatch
    void dispatchPacketReceived(int32_t packet_type, const uint8_t* data, int32_t data_length) {
        if (packet_received_handler_) packet_received_handler_(packet_type, data, data_length);
    }

    void clear() {
        screen_init_handler_ = nullptr;
        screen_tick_handler_ = nullptr;
        screen_render_handler_ = nullptr;
        screen_close_handler_ = nullptr;
        screen_key_pressed_handler_ = nullptr;
        screen_key_released_handler_ = nullptr;
        screen_char_typed_handler_ = nullptr;
        screen_mouse_clicked_handler_ = nullptr;
        screen_mouse_released_handler_ = nullptr;
        screen_mouse_dragged_handler_ = nullptr;
        screen_mouse_scrolled_handler_ = nullptr;
        widget_pressed_handler_ = nullptr;
        widget_text_changed_handler_ = nullptr;
        container_screen_init_handler_ = nullptr;
        container_screen_render_bg_handler_ = nullptr;
        container_screen_close_handler_ = nullptr;
        container_slot_click_handler_ = nullptr;
        container_quick_move_handler_ = nullptr;
        container_may_place_handler_ = nullptr;
        container_may_pickup_handler_ = nullptr;
        packet_received_handler_ = nullptr;
    }

private:
    ClientCallbackRegistry() = default;
    ~ClientCallbackRegistry() = default;

    ScreenInitCallback screen_init_handler_ = nullptr;
    ScreenTickCallback screen_tick_handler_ = nullptr;
    ScreenRenderCallback screen_render_handler_ = nullptr;
    ScreenCloseCallback screen_close_handler_ = nullptr;
    ScreenKeyPressedCallback screen_key_pressed_handler_ = nullptr;
    ScreenKeyReleasedCallback screen_key_released_handler_ = nullptr;
    ScreenCharTypedCallback screen_char_typed_handler_ = nullptr;
    ScreenMouseClickedCallback screen_mouse_clicked_handler_ = nullptr;
    ScreenMouseReleasedCallback screen_mouse_released_handler_ = nullptr;
    ScreenMouseDraggedCallback screen_mouse_dragged_handler_ = nullptr;
    ScreenMouseScrolledCallback screen_mouse_scrolled_handler_ = nullptr;
    WidgetPressedCallback widget_pressed_handler_ = nullptr;
    WidgetTextChangedCallback widget_text_changed_handler_ = nullptr;
    ContainerScreenInitCallback container_screen_init_handler_ = nullptr;
    ContainerScreenRenderBgCallback container_screen_render_bg_handler_ = nullptr;
    ContainerScreenCloseCallback container_screen_close_handler_ = nullptr;
    ContainerSlotClickCallback container_slot_click_handler_ = nullptr;
    ContainerQuickMoveCallback container_quick_move_handler_ = nullptr;
    ContainerMayPlaceCallback container_may_place_handler_ = nullptr;
    ContainerMayPickupCallback container_may_pickup_handler_ = nullptr;
    ClientPacketReceivedCallback packet_received_handler_ = nullptr;
};

} // namespace dart_mc_bridge

// Global callback for sending packets to Java/server
static SendPacketToServerCallback g_client_send_packet_callback = nullptr;

// ==========================================================================
// Custom Task Runner Callbacks (for merged thread approach)
// ==========================================================================

static bool ClientTaskRunnerRunsOnCurrentThread(void* user_data) {
    return std::this_thread::get_id() == g_client_platform_thread_id;
}

static void ClientTaskRunnerPostTask(FlutterTask task, uint64_t target_time, void* user_data) {
    // Don't accept new tasks if shutdown is requested
    if (g_client_shutdown_requested) {
        return;
    }
    std::lock_guard<std::mutex> lock(g_client_task_mutex);
    g_client_pending_flutter_tasks.push({task, target_time});
}

// ==========================================================================
// Flutter Embedder Callbacks
// ==========================================================================

static bool OnClientSoftwareSurfacePresent(void* user_data,
                                            const void* allocation,
                                            size_t row_bytes,
                                            size_t height) {
    if (g_client_frame_callback) {
        size_t width = row_bytes / 4;  // RGBA = 4 bytes per pixel
        g_client_frame_callback(allocation, width, height, row_bytes);
    }
    return true;
}

static void OnClientPlatformMessage(const FlutterPlatformMessage* message, void* user_data) {
    // Handle platform channel messages if needed
}

static void OnClientVsync(void* user_data, intptr_t baton) {
    // Don't trigger more frames if shutdown is requested
    if (g_client_shutdown_requested || g_client_engine == nullptr) {
        return;
    }
    uint64_t now = FlutterEngineGetCurrentTime();
    uint64_t frame_interval = 16666667;  // ~60fps in nanoseconds
    FlutterEngineOnVsync(g_client_engine, baton, now, now + frame_interval);
}

static void OnClientRootIsolateCreate(void* user_data) {
    std::cout << "Flutter client root isolate created" << std::endl;
}

// ==========================================================================
// Lifecycle Functions
// ==========================================================================

extern "C" {

bool dart_client_init(const char* assets_path, const char* icu_data_path, const char* aot_library_path) {
    std::lock_guard<std::mutex> lock(g_client_engine_mutex);

    if (g_client_initialized) {
        std::cerr << "Client Dart bridge already initialized" << std::endl;
        return false;
    }

    // Reset shutdown flag in case of reinitialization
    g_client_shutdown_requested = false;

    std::cout << "Initializing Flutter engine (client)..." << std::endl;
    std::cout << "  Assets path: " << (assets_path ? assets_path : "null") << std::endl;
    std::cout << "  ICU data path: " << (icu_data_path ? icu_data_path : "null") << std::endl;
    std::cout << "  AOT library: " << (aot_library_path ? aot_library_path : "JIT mode") << std::endl;

    // Configure renderer - client always uses rendering
    FlutterRendererConfig renderer = {};
    renderer.type = kSoftware;
    renderer.software.struct_size = sizeof(FlutterSoftwareRendererConfig);
    renderer.software.surface_present_callback = OnClientSoftwareSurfacePresent;

    // Configure project args
    FlutterProjectArgs args = {};
    args.struct_size = sizeof(FlutterProjectArgs);
    args.assets_path = assets_path;
    args.icu_data_path = icu_data_path;

    // Enable VM service for hot reload in debug mode
    const char* vm_args[] = {
        "--enable-dart-profiling",
        "--enable-asserts",
    };
    args.command_line_argc = 2;
    args.command_line_argv = vm_args;

    args.vsync_callback = OnClientVsync;
    args.platform_message_callback = OnClientPlatformMessage;
    args.root_isolate_create_callback = OnClientRootIsolateCreate;

    // Set up custom task runners
    g_client_platform_thread_id = std::this_thread::get_id();
    std::cout << "Client platform thread ID captured" << std::endl;

    static FlutterTaskRunnerDescription client_task_runner = {};
    client_task_runner.struct_size = sizeof(FlutterTaskRunnerDescription);
    client_task_runner.user_data = nullptr;
    client_task_runner.runs_task_on_current_thread_callback = ClientTaskRunnerRunsOnCurrentThread;
    client_task_runner.post_task_callback = ClientTaskRunnerPostTask;
    client_task_runner.identifier = 2;  // Different from server
    client_task_runner.destruction_callback = nullptr;

    static FlutterCustomTaskRunners client_custom_task_runners = {};
    client_custom_task_runners.struct_size = sizeof(FlutterCustomTaskRunners);
    client_custom_task_runners.platform_task_runner = &client_task_runner;
    client_custom_task_runners.render_task_runner = &client_task_runner;
    client_custom_task_runners.ui_task_runner = &client_task_runner;
    client_custom_task_runners.thread_priority_setter = nullptr;

    args.custom_task_runners = &client_custom_task_runners;

    std::cout << "Client custom task runners configured" << std::endl;

    // Run the Flutter engine
    FlutterEngineResult result = FlutterEngineRun(
        FLUTTER_ENGINE_VERSION,
        &renderer,
        &args,
        nullptr,
        &g_client_engine
    );

    if (result != kSuccess) {
        std::cerr << "Failed to start Flutter client engine, error code: " << result << std::endl;
        return false;
    }

    // Send initial window metrics
    FlutterWindowMetricsEvent metrics = {};
    metrics.struct_size = sizeof(FlutterWindowMetricsEvent);
    metrics.width = g_client_window_width;
    metrics.height = g_client_window_height;
    metrics.pixel_ratio = g_client_pixel_ratio;

    FlutterEngineSendWindowMetricsEvent(g_client_engine, &metrics);

    g_client_initialized = true;
    std::cout << "Flutter client engine initialized successfully" << std::endl;
    return true;
}

void dart_client_shutdown() {
    std::cout << "Client shutdown: setting shutdown flag..." << std::endl;
    // Set shutdown flag BEFORE acquiring lock to stop vsync/task callbacks immediately
    g_client_shutdown_requested = true;

    std::cout << "Client shutdown: acquiring lock..." << std::endl;
    std::lock_guard<std::mutex> lock(g_client_engine_mutex);

    if (!g_client_initialized) {
        std::cout << "Client shutdown: not initialized, returning" << std::endl;
        g_client_shutdown_requested = false;
        return;
    }

    std::cout << "Client shutdown: clearing callbacks..." << std::endl;
    // Clear all callbacks
    dart_mc_bridge::ClientCallbackRegistry::instance().clear();

    std::cout << "Client shutdown: releasing JNI objects..." << std::endl;
    // Release object handles
    if (g_client_jvm_ref != nullptr) {
        JNIEnv* env = nullptr;
        bool needs_detach = false;

        int status = g_client_jvm_ref->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_8);
        if (status == JNI_EDETACHED) {
            if (g_client_jvm_ref->AttachCurrentThread(reinterpret_cast<void**>(&env), nullptr) == JNI_OK) {
                needs_detach = true;
            }
        }

        if (env != nullptr) {
            dart_mc_bridge::ObjectRegistry::instance().releaseAll(env);
        }

        if (needs_detach) {
            g_client_jvm_ref->DetachCurrentThread();
        }
    }

    std::cout << "Client shutdown: shutting down Flutter engine..." << std::endl;
    // Shutdown Flutter engine
    if (g_client_engine != nullptr) {
        FlutterEngineResult result = FlutterEngineShutdown(g_client_engine);
        std::cout << "Client shutdown: FlutterEngineShutdown returned " << result << std::endl;
        if (result != kSuccess) {
            std::cerr << "Warning: Flutter client engine shutdown returned error: " << result << std::endl;
        }
        g_client_engine = nullptr;
    }

    g_client_initialized = false;
    g_client_jvm_ref = nullptr;
    g_client_frame_callback = nullptr;

    std::cout << "Client Dart bridge shutdown complete" << std::endl;
}

void dart_client_process_tasks() {
    if (!g_client_initialized || g_client_engine == nullptr) return;

    // Extract all tasks that are ready to run
    std::queue<std::pair<FlutterTask, uint64_t>> tasks_to_run;
    {
        std::lock_guard<std::mutex> lock(g_client_task_mutex);
        std::swap(tasks_to_run, g_client_pending_flutter_tasks);
    }

    uint64_t current_time = FlutterEngineGetCurrentTime();

    while (!tasks_to_run.empty()) {
        auto& task_pair = tasks_to_run.front();
        if (task_pair.second <= current_time) {
            FlutterEngineRunTask(g_client_engine, &task_pair.first);
        } else {
            std::lock_guard<std::mutex> lock(g_client_task_mutex);
            g_client_pending_flutter_tasks.push(task_pair);
        }
        tasks_to_run.pop();
    }
}

void dart_client_set_jvm(JavaVM* jvm) {
    g_client_jvm_ref = jvm;
}

void dart_client_set_frame_callback(FrameCallback callback) {
    g_client_frame_callback = callback;
}

const char* dart_client_get_service_url() {
    if (g_client_initialized) {
        return "flutter://vm-service-client";
    }
    return nullptr;
}

// ==========================================================================
// Window/Input Events
// ==========================================================================

void dart_client_send_window_metrics(int32_t width, int32_t height, double pixel_ratio) {
    if (!g_client_initialized || g_client_engine == nullptr) return;

    g_client_window_width = width;
    g_client_window_height = height;
    g_client_pixel_ratio = pixel_ratio;

    FlutterWindowMetricsEvent metrics = {};
    metrics.struct_size = sizeof(FlutterWindowMetricsEvent);
    metrics.width = width;
    metrics.height = height;
    metrics.pixel_ratio = pixel_ratio;

    FlutterEngineSendWindowMetricsEvent(g_client_engine, &metrics);
}

void dart_client_send_pointer_event(int32_t phase, double x, double y, int64_t buttons) {
    if (!g_client_initialized || g_client_engine == nullptr) return;

    // Flutter expects coordinates in physical pixels (framebuffer pixels)
    // Java sends logical pixels (GUI coordinates), so scale by pixel_ratio
    FlutterPointerEvent event = {};
    event.struct_size = sizeof(FlutterPointerEvent);
    event.phase = static_cast<FlutterPointerPhase>(phase);
    event.timestamp = FlutterEngineGetCurrentTime() / 1000;
    event.x = x * g_client_pixel_ratio;
    event.y = y * g_client_pixel_ratio;
    event.buttons = buttons;
    event.device_kind = kFlutterPointerDeviceKindMouse;

    FlutterEngineSendPointerEvent(g_client_engine, &event, 1);
}

void dart_client_send_key_event(int32_t type, int64_t physical_key, int64_t logical_key,
                                  const char* character, int32_t modifiers) {
    if (!g_client_initialized || g_client_engine == nullptr) return;

    FlutterKeyEvent event = {};
    event.struct_size = sizeof(FlutterKeyEvent);
    event.timestamp = static_cast<double>(FlutterEngineGetCurrentTime()) / 1000000000.0;
    event.type = static_cast<FlutterKeyEventType>(type);
    event.physical = physical_key;
    event.logical = logical_key;
    event.character = character;
    event.synthesized = false;

    FlutterEngineSendKeyEvent(g_client_engine, &event, nullptr, nullptr);
}

// ==========================================================================
// Callback Registration (called from Dart via FFI)
// ==========================================================================

void client_register_screen_init_handler(ScreenInitCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setScreenInitHandler(cb); }
void client_register_screen_tick_handler(ScreenTickCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setScreenTickHandler(cb); }
void client_register_screen_render_handler(ScreenRenderCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setScreenRenderHandler(cb); }
void client_register_screen_close_handler(ScreenCloseCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setScreenCloseHandler(cb); }
void client_register_screen_key_pressed_handler(ScreenKeyPressedCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setScreenKeyPressedHandler(cb); }
void client_register_screen_key_released_handler(ScreenKeyReleasedCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setScreenKeyReleasedHandler(cb); }
void client_register_screen_char_typed_handler(ScreenCharTypedCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setScreenCharTypedHandler(cb); }
void client_register_screen_mouse_clicked_handler(ScreenMouseClickedCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setScreenMouseClickedHandler(cb); }
void client_register_screen_mouse_released_handler(ScreenMouseReleasedCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setScreenMouseReleasedHandler(cb); }
void client_register_screen_mouse_dragged_handler(ScreenMouseDraggedCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setScreenMouseDraggedHandler(cb); }
void client_register_screen_mouse_scrolled_handler(ScreenMouseScrolledCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setScreenMouseScrolledHandler(cb); }

void client_register_widget_pressed_handler(WidgetPressedCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setWidgetPressedHandler(cb); }
void client_register_widget_text_changed_handler(WidgetTextChangedCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setWidgetTextChangedHandler(cb); }

void client_register_container_screen_init_handler(ContainerScreenInitCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setContainerScreenInitHandler(cb); }
void client_register_container_screen_render_bg_handler(ContainerScreenRenderBgCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setContainerScreenRenderBgHandler(cb); }
void client_register_container_screen_close_handler(ContainerScreenCloseCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setContainerScreenCloseHandler(cb); }

void client_register_container_slot_click_handler(ContainerSlotClickCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setContainerSlotClickHandler(cb); }
void client_register_container_quick_move_handler(ContainerQuickMoveCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setContainerQuickMoveHandler(cb); }
void client_register_container_may_place_handler(ContainerMayPlaceCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setContainerMayPlaceHandler(cb); }
void client_register_container_may_pickup_handler(ContainerMayPickupCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setContainerMayPickupHandler(cb); }

// ==========================================================================
// Event Dispatch (called from Java via JNI)
// Client-side uses direct FFI calls (single thread, no isolate switching)
// ==========================================================================

#define CLIENT_DISPATCH_CHECK() \
    if (!g_client_initialized || g_client_engine == nullptr) return
#define CLIENT_DISPATCH_CHECK_RET(default_ret) \
    if (!g_client_initialized || g_client_engine == nullptr) return default_ret

void client_dispatch_screen_init(int64_t screen_id, int32_t width, int32_t height) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchScreenInit(screen_id, width, height);
}

void client_dispatch_screen_tick(int64_t screen_id) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchScreenTick(screen_id);
}

void client_dispatch_screen_render(int64_t screen_id, int32_t mouse_x, int32_t mouse_y, float partial_tick) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchScreenRender(screen_id, mouse_x, mouse_y, partial_tick);
}

void client_dispatch_screen_close(int64_t screen_id) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchScreenClose(screen_id);
}

bool client_dispatch_screen_key_pressed(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers) {
    CLIENT_DISPATCH_CHECK_RET(false);
    return dart_mc_bridge::ClientCallbackRegistry::instance().dispatchScreenKeyPressed(screen_id, key_code, scan_code, modifiers);
}

bool client_dispatch_screen_key_released(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers) {
    CLIENT_DISPATCH_CHECK_RET(false);
    return dart_mc_bridge::ClientCallbackRegistry::instance().dispatchScreenKeyReleased(screen_id, key_code, scan_code, modifiers);
}

bool client_dispatch_screen_char_typed(int64_t screen_id, int32_t code_point, int32_t modifiers) {
    CLIENT_DISPATCH_CHECK_RET(false);
    return dart_mc_bridge::ClientCallbackRegistry::instance().dispatchScreenCharTyped(screen_id, code_point, modifiers);
}

bool client_dispatch_screen_mouse_clicked(int64_t screen_id, double mouse_x, double mouse_y, int32_t button) {
    CLIENT_DISPATCH_CHECK_RET(false);
    return dart_mc_bridge::ClientCallbackRegistry::instance().dispatchScreenMouseClicked(screen_id, mouse_x, mouse_y, button);
}

bool client_dispatch_screen_mouse_released(int64_t screen_id, double mouse_x, double mouse_y, int32_t button) {
    CLIENT_DISPATCH_CHECK_RET(false);
    return dart_mc_bridge::ClientCallbackRegistry::instance().dispatchScreenMouseReleased(screen_id, mouse_x, mouse_y, button);
}

bool client_dispatch_screen_mouse_dragged(int64_t screen_id, double mouse_x, double mouse_y, int32_t button, double drag_x, double drag_y) {
    CLIENT_DISPATCH_CHECK_RET(false);
    return dart_mc_bridge::ClientCallbackRegistry::instance().dispatchScreenMouseDragged(screen_id, mouse_x, mouse_y, button, drag_x, drag_y);
}

bool client_dispatch_screen_mouse_scrolled(int64_t screen_id, double mouse_x, double mouse_y, double delta_x, double delta_y) {
    CLIENT_DISPATCH_CHECK_RET(false);
    return dart_mc_bridge::ClientCallbackRegistry::instance().dispatchScreenMouseScrolled(screen_id, mouse_x, mouse_y, delta_x, delta_y);
}

void client_dispatch_widget_pressed(int64_t screen_id, int64_t widget_id) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchWidgetPressed(screen_id, widget_id);
}

void client_dispatch_widget_text_changed(int64_t screen_id, int64_t widget_id, const char* text) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchWidgetTextChanged(screen_id, widget_id, text);
}

void client_dispatch_container_screen_init(int64_t screen_id, int32_t width, int32_t height,
                                            int32_t left_pos, int32_t top_pos, int32_t image_width, int32_t image_height) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchContainerScreenInit(screen_id, width, height, left_pos, top_pos, image_width, image_height);
}

void client_dispatch_container_screen_render_bg(int64_t screen_id, int32_t mouse_x, int32_t mouse_y,
                                                  float partial_tick, int32_t left_pos, int32_t top_pos) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchContainerScreenRenderBg(screen_id, mouse_x, mouse_y, partial_tick, left_pos, top_pos);
}

void client_dispatch_container_screen_close(int64_t screen_id) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchContainerScreenClose(screen_id);
}

int32_t client_dispatch_container_slot_click(int64_t menu_id, int32_t slot_index, int32_t button, int32_t click_type, const char* carried_item) {
    CLIENT_DISPATCH_CHECK_RET(0);
    return dart_mc_bridge::ClientCallbackRegistry::instance().dispatchContainerSlotClick(menu_id, slot_index, button, click_type, carried_item);
}

const char* client_dispatch_container_quick_move(int64_t menu_id, int32_t slot_index) {
    CLIENT_DISPATCH_CHECK_RET(nullptr);
    return dart_mc_bridge::ClientCallbackRegistry::instance().dispatchContainerQuickMove(menu_id, slot_index);
}

bool client_dispatch_container_may_place(int64_t menu_id, int32_t slot_index, const char* item_data) {
    CLIENT_DISPATCH_CHECK_RET(true);
    return dart_mc_bridge::ClientCallbackRegistry::instance().dispatchContainerMayPlace(menu_id, slot_index, item_data);
}

bool client_dispatch_container_may_pickup(int64_t menu_id, int32_t slot_index) {
    CLIENT_DISPATCH_CHECK_RET(true);
    return dart_mc_bridge::ClientCallbackRegistry::instance().dispatchContainerMayPickup(menu_id, slot_index);
}

// ==========================================================================
// Network Packet Functions (Client-side)
// ==========================================================================

void client_register_packet_received_handler(ClientPacketReceivedCallback cb) {
    dart_mc_bridge::ClientCallbackRegistry::instance().setPacketReceivedHandler(cb);
}

void client_set_send_packet_to_server_callback(SendPacketToServerCallback cb) {
    g_client_send_packet_callback = cb;
}

void client_dispatch_server_packet(int32_t packet_type, const uint8_t* data, int32_t data_length) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchPacketReceived(packet_type, data, data_length);
}

void client_send_packet_to_server(int32_t packet_type, const uint8_t* data, int32_t data_length) {
    if (g_client_send_packet_callback) {
        g_client_send_packet_callback(packet_type, data, data_length);
    }
}

} // extern "C"
