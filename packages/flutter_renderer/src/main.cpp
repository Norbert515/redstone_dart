/**
 * Flutter Renderer Subprocess
 *
 * This is a standalone process that runs the Flutter engine and renders
 * frames to shared memory. It communicates with the main Minecraft process
 * via shared memory commands.
 *
 * Usage: flutter_renderer <shm_name> <assets_path> <icu_data_path>
 *
 * The process:
 * 1. Opens the shared memory created by the parent process
 * 2. Initializes Flutter with the software renderer
 * 3. Enters a main loop processing commands and rendering frames
 * 4. Exits when CMD_SHUTDOWN is received
 */

#include "shared_memory.h"

#include <FlutterEmbedder.h>

#include <chrono>
#include <cstring>
#include <iostream>
#include <string>
#include <thread>
#include <atomic>
#include <csignal>

// ============================================================================
// Global State
// ============================================================================

static FlutterSharedMemoryHandle g_shm_handle;
static FlutterSharedMemory* g_shm = nullptr;
static FlutterEngine g_engine = nullptr;
static std::atomic<bool> g_running{true};
static double g_pixel_ratio = 1.0;
static int g_width = 800;
static int g_height = 600;

// ============================================================================
// Signal Handling
// ============================================================================

static void signal_handler(int signal) {
    std::cout << "[FlutterRenderer] Received signal " << signal << ", shutting down..." << std::endl;
    g_running = false;
}

// ============================================================================
// Timing
// ============================================================================

static uint64_t GetCurrentTimeMicros() {
    // Use Flutter's own time function to ensure timestamps match Flutter's expectations
    if (g_engine) {
        return FlutterEngineGetCurrentTime();
    }
    // Fallback to steady_clock if engine not initialized
    auto now = std::chrono::steady_clock::now();
    return std::chrono::duration_cast<std::chrono::microseconds>(
        now.time_since_epoch()).count();
}

// ============================================================================
// Software Renderer Callback
// ============================================================================

/**
 * Called by Flutter when a frame is ready.
 * Copies the pixel data to shared memory and signals frame ready.
 */
static bool OnSoftwareSurfacePresent(void* user_data,
                                     const void* allocation,
                                     size_t row_bytes,
                                     size_t height) {
    if (!allocation || height == 0 || row_bytes == 0 || !g_shm) {
        return false;
    }

    // Calculate dimensions
    size_t width = row_bytes / 4;  // RGBA = 4 bytes per pixel

    // Validate size fits in shared memory
    if (width > FLUTTER_SHM_MAX_WIDTH || height > FLUTTER_SHM_MAX_HEIGHT) {
        std::cerr << "[FlutterRenderer] Frame too large: " << width << "x" << height << std::endl;
        return false;
    }

    // Copy pixel data to shared memory
    size_t buffer_size = row_bytes * height;
    std::memcpy(g_shm->pixels, allocation, buffer_size);

    // Update dimensions and signal new frame
    g_shm->width.store(static_cast<uint32_t>(width), std::memory_order_relaxed);
    g_shm->height.store(static_cast<uint32_t>(height), std::memory_order_relaxed);
    flutter_shm_signal_frame(g_shm);

    return true;
}

// ============================================================================
// Flutter Engine Management
// ============================================================================

static void SendWindowMetrics() {
    if (!g_engine) return;

    FlutterWindowMetricsEvent event = {};
    event.struct_size = sizeof(FlutterWindowMetricsEvent);
    event.width = static_cast<size_t>(g_width * g_pixel_ratio);
    event.height = static_cast<size_t>(g_height * g_pixel_ratio);
    event.pixel_ratio = g_pixel_ratio;

    FlutterEngineSendWindowMetricsEvent(g_engine, &event);
}

static bool InitializeFlutterEngine(const char* assets_path, const char* icu_data_path) {
    std::cout << "[FlutterRenderer] Initializing Flutter engine..." << std::endl;
    std::cout << "[FlutterRenderer] Assets: " << assets_path << std::endl;
    std::cout << "[FlutterRenderer] ICU data: " << icu_data_path << std::endl;

    // Configure software renderer
    FlutterRendererConfig renderer_config = {};
    renderer_config.type = kSoftware;
    renderer_config.software.struct_size = sizeof(FlutterSoftwareRendererConfig);
    renderer_config.software.surface_present_callback = OnSoftwareSurfacePresent;

    // Configure project
    FlutterProjectArgs project_args = {};
    project_args.struct_size = sizeof(FlutterProjectArgs);
    project_args.assets_path = assets_path;
    project_args.icu_data_path = icu_data_path;

    // Platform message callback
    project_args.platform_message_callback = [](
        const FlutterPlatformMessage* message,
        void* user_data
    ) {
        if (message->channel) {
            std::cout << "[FlutterRenderer] Platform message: " << message->channel << std::endl;
        }
    };

    // Run the engine
    FlutterEngineResult result = FlutterEngineRun(
        FLUTTER_ENGINE_VERSION,
        &renderer_config,
        &project_args,
        nullptr,
        &g_engine
    );

    if (result != kSuccess) {
        std::cerr << "[FlutterRenderer] Failed to start engine: " << result << std::endl;
        return false;
    }

    std::cout << "[FlutterRenderer] Engine started successfully!" << std::endl;

    // Send initial metrics
    SendWindowMetrics();

    return true;
}

static void ShutdownFlutterEngine() {
    if (g_engine) {
        FlutterEngineShutdown(g_engine);
        g_engine = nullptr;
        std::cout << "[FlutterRenderer] Engine shut down" << std::endl;
    }
}

// ============================================================================
// Command Processing
// ============================================================================

static void ProcessCommand() {
    if (!flutter_shm_has_command(g_shm)) {
        return;
    }

    uint32_t cmd = g_shm->cmd_type.load(std::memory_order_acquire);

    switch (cmd) {
        case CMD_RESIZE: {
            g_width = g_shm->cmd_width;
            g_height = g_shm->cmd_height;
            g_pixel_ratio = g_shm->cmd_pixel_ratio;
            std::cout << "[FlutterRenderer] Resize: " << g_width << "x" << g_height
                      << " @ " << g_pixel_ratio << "x" << std::endl;
            SendWindowMetrics();
            break;
        }

        case CMD_POINTER: {
            if (!g_engine) break;

            uint64_t timestamp = GetCurrentTimeMicros();
            std::cout << "[FlutterRenderer] Pointer: phase=" << g_shm->cmd_pointer_phase
                      << " x=" << g_shm->cmd_pointer_x
                      << " y=" << g_shm->cmd_pointer_y
                      << " buttons=" << g_shm->cmd_pointer_buttons
                      << " timestamp=" << timestamp << std::endl;

            FlutterPointerEvent event = {};
            event.struct_size = sizeof(FlutterPointerEvent);
            event.phase = static_cast<FlutterPointerPhase>(g_shm->cmd_pointer_phase);
            event.timestamp = timestamp;
            event.x = g_shm->cmd_pointer_x * g_pixel_ratio;
            event.y = g_shm->cmd_pointer_y * g_pixel_ratio;
            event.device = 0;
            event.signal_kind = kFlutterPointerSignalKindNone;
            event.device_kind = kFlutterPointerDeviceKindMouse;
            event.buttons = g_shm->cmd_pointer_buttons;

            FlutterEngineResult result = FlutterEngineSendPointerEvent(g_engine, &event, 1);
            if (result != kSuccess) {
                std::cerr << "[FlutterRenderer] ERROR: FlutterEngineSendPointerEvent failed: " << result << std::endl;
            }
            break;
        }

        case CMD_SCROLL: {
            if (!g_engine) break;

            FlutterPointerEvent event = {};
            event.struct_size = sizeof(FlutterPointerEvent);
            event.phase = kHover;
            event.timestamp = GetCurrentTimeMicros();
            event.x = g_shm->cmd_scroll_x * g_pixel_ratio;
            event.y = g_shm->cmd_scroll_y * g_pixel_ratio;
            event.device = 0;
            event.signal_kind = kFlutterPointerSignalKindScroll;
            event.scroll_delta_x = g_shm->cmd_scroll_delta_x;
            event.scroll_delta_y = g_shm->cmd_scroll_delta_y;
            event.device_kind = kFlutterPointerDeviceKindMouse;

            FlutterEngineSendPointerEvent(g_engine, &event, 1);
            break;
        }

        case CMD_SHUTDOWN: {
            std::cout << "[FlutterRenderer] Received shutdown command" << std::endl;
            g_running = false;
            break;
        }

        case CMD_INIT: {
            std::cout << "[FlutterRenderer] Received init command" << std::endl;
            break;
        }

        default:
            break;
    }

    flutter_shm_ack_command(g_shm);
}

// ============================================================================
// Main Entry Point
// ============================================================================

static void PrintUsage(const char* program) {
    std::cerr << "Usage: " << program << " <shm_name> <assets_path> <icu_data_path>" << std::endl;
    std::cerr << std::endl;
    std::cerr << "Arguments:" << std::endl;
    std::cerr << "  shm_name       Shared memory name (created by parent process)" << std::endl;
    std::cerr << "  assets_path    Path to Flutter app's flutter_assets directory" << std::endl;
    std::cerr << "  icu_data_path  Path to icudtl.dat file" << std::endl;
}

int main(int argc, char* argv[]) {
    std::cout << "[FlutterRenderer] Flutter Renderer Subprocess starting..." << std::endl;

    // Parse arguments
    if (argc < 4) {
        PrintUsage(argv[0]);
        return 1;
    }

    const char* shm_name = argv[1];
    const char* assets_path = argv[2];
    const char* icu_data_path = argv[3];

    std::cout << "[FlutterRenderer] Shared memory: " << shm_name << std::endl;

    // Set up signal handlers
    std::signal(SIGINT, signal_handler);
    std::signal(SIGTERM, signal_handler);
#ifndef _WIN32
    std::signal(SIGHUP, signal_handler);
#endif

    // Open shared memory
    if (!g_shm_handle.open(shm_name)) {
        std::cerr << "[FlutterRenderer] Failed to open shared memory" << std::endl;
        return 1;
    }

    g_shm = g_shm_handle.get();

    // Update status to initializing
    g_shm->status.store(STATUS_INITIALIZING, std::memory_order_release);

    // Initialize Flutter engine
    if (!InitializeFlutterEngine(assets_path, icu_data_path)) {
        g_shm->status.store(STATUS_ERROR, std::memory_order_release);
        g_shm_handle.close();
        return 1;
    }

    // Update status to ready
    g_shm->status.store(STATUS_READY, std::memory_order_release);
    std::cout << "[FlutterRenderer] Ready and running" << std::endl;

    // Main loop
    while (g_running) {
        // Process any pending commands
        ProcessCommand();

        // Small sleep to avoid busy-waiting
        // The Flutter engine handles its own timing for rendering
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    // Cleanup
    std::cout << "[FlutterRenderer] Shutting down..." << std::endl;

    g_shm->status.store(STATUS_SHUTDOWN, std::memory_order_release);

    ShutdownFlutterEngine();
    g_shm_handle.close();

    std::cout << "[FlutterRenderer] Goodbye!" << std::endl;
    return 0;
}
