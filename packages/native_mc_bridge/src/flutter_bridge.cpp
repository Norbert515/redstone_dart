/**
 * Flutter Bridge - Subprocess-based Flutter Renderer
 *
 * This module spawns a separate process to run the Flutter engine,
 * avoiding Dart VM conflicts. Communication happens via shared memory.
 *
 * Architecture:
 * - This code runs in the Minecraft process (with its own Dart VM)
 * - flutter_renderer runs as a separate process (with Flutter's Dart VM)
 * - Shared memory is used for pixel data transfer (fast, zero-copy read)
 * - Commands (resize, pointer, scroll) are sent via shared memory
 */

#include "flutter_bridge.h"

// Include shared memory header from flutter_renderer
// This path is resolved via CMake include directories
#include "shared_memory.h"

#include <chrono>
#include <cstring>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#include <process.h>
#else
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <signal.h>
#endif

// ============================================================================
// Global State
// ============================================================================

static FlutterSharedMemoryHandle g_shm_handle;
static FlutterSharedMemory* g_shm = nullptr;
static bool g_initialized = false;
static uint64_t g_last_frame_number = 0;

// Subprocess state
#ifdef _WIN32
static HANDLE g_process_handle = nullptr;
#else
static pid_t g_renderer_pid = 0;
#endif

static std::string g_shm_name;
static std::string g_renderer_path;

// Cached pixel buffer (for thread-safety when reading from shared memory)
static std::vector<uint8_t> g_pixel_cache;
static size_t g_cache_width = 0;
static size_t g_cache_height = 0;
static bool g_has_new_frame = false;

// ============================================================================
// Helper Functions
// ============================================================================

static std::string GenerateShmName() {
#ifdef _WIN32
    return "flutter_shm_" + std::to_string(GetCurrentProcessId());
#else
    return "/flutter_shm_" + std::to_string(getpid());
#endif
}

static std::string FindRendererExecutable() {
    // Look for flutter_renderer in common locations relative to the bridge library

    // Get the path of this library
    // For now, we'll use a simple search strategy

    std::vector<std::string> search_paths;

#ifdef _WIN32
    search_paths.push_back("flutter_renderer.exe");
    search_paths.push_back("./flutter_renderer.exe");
    search_paths.push_back("../flutter_renderer/build/flutter_renderer.exe");
#else
    search_paths.push_back("flutter_renderer");
    search_paths.push_back("./flutter_renderer");
    search_paths.push_back("../flutter_renderer/build/flutter_renderer");
    // Relative to the native bridge build directory
    search_paths.push_back("../../flutter_renderer/build/flutter_renderer");
#endif

    for (const auto& path : search_paths) {
#ifdef _WIN32
        if (GetFileAttributesA(path.c_str()) != INVALID_FILE_ATTRIBUTES) {
            return path;
        }
#else
        if (access(path.c_str(), X_OK) == 0) {
            return path;
        }
#endif
    }

    // Not found - caller should handle this
    return "";
}

// ============================================================================
// Subprocess Management
// ============================================================================

static bool SpawnRendererProcess(const char* assets_path, const char* icu_data_path) {
    std::cout << "[FlutterBridge] Spawning renderer process..." << std::endl;

    if (g_renderer_path.empty()) {
        g_renderer_path = FindRendererExecutable();
        if (g_renderer_path.empty()) {
            std::cerr << "[FlutterBridge] Could not find flutter_renderer executable" << std::endl;
            return false;
        }
    }

    std::cout << "[FlutterBridge] Renderer: " << g_renderer_path << std::endl;
    std::cout << "[FlutterBridge] SHM name: " << g_shm_name << std::endl;
    std::cout << "[FlutterBridge] Assets: " << assets_path << std::endl;
    std::cout << "[FlutterBridge] ICU: " << icu_data_path << std::endl;

#ifdef _WIN32
    // Windows subprocess creation
    std::string cmd_line = g_renderer_path + " \"" + g_shm_name + "\" \""
                          + assets_path + "\" \"" + icu_data_path + "\"";

    STARTUPINFOA si = {};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi = {};

    if (!CreateProcessA(
        nullptr,
        const_cast<char*>(cmd_line.c_str()),
        nullptr,
        nullptr,
        FALSE,
        0,
        nullptr,
        nullptr,
        &si,
        &pi
    )) {
        std::cerr << "[FlutterBridge] Failed to spawn renderer: " << GetLastError() << std::endl;
        return false;
    }

    g_process_handle = pi.hProcess;
    CloseHandle(pi.hThread);

    std::cout << "[FlutterBridge] Renderer process started (PID: " << pi.dwProcessId << ")" << std::endl;
#else
    // POSIX subprocess creation
    g_renderer_pid = fork();

    if (g_renderer_pid == -1) {
        std::cerr << "[FlutterBridge] Failed to fork: " << strerror(errno) << std::endl;
        return false;
    }

    if (g_renderer_pid == 0) {
        // Child process - exec the renderer
        execl(g_renderer_path.c_str(), g_renderer_path.c_str(),
              g_shm_name.c_str(), assets_path, icu_data_path, nullptr);

        // If execl returns, it failed
        std::cerr << "[FlutterBridge] execl failed: " << strerror(errno) << std::endl;
        _exit(1);
    }

    std::cout << "[FlutterBridge] Renderer process started (PID: " << g_renderer_pid << ")" << std::endl;
#endif

    return true;
}

static void TerminateRendererProcess() {
    // First, send shutdown command if shared memory is available
    if (g_shm) {
        flutter_shm_send_shutdown(g_shm);

        // Wait a bit for graceful shutdown
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

#ifdef _WIN32
    if (g_process_handle != nullptr) {
        // Check if still running
        DWORD exit_code;
        if (GetExitCodeProcess(g_process_handle, &exit_code) && exit_code == STILL_ACTIVE) {
            // Force terminate
            TerminateProcess(g_process_handle, 0);
        }
        CloseHandle(g_process_handle);
        g_process_handle = nullptr;
        std::cout << "[FlutterBridge] Renderer process terminated" << std::endl;
    }
#else
    if (g_renderer_pid > 0) {
        // Check if still running
        int status;
        pid_t result = waitpid(g_renderer_pid, &status, WNOHANG);

        if (result == 0) {
            // Still running, send SIGTERM
            kill(g_renderer_pid, SIGTERM);

            // Wait for up to 500ms
            for (int i = 0; i < 50; i++) {
                result = waitpid(g_renderer_pid, &status, WNOHANG);
                if (result != 0) break;
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }

            // If still running, force kill
            if (result == 0) {
                kill(g_renderer_pid, SIGKILL);
                waitpid(g_renderer_pid, &status, 0);
            }
        }

        g_renderer_pid = 0;
        std::cout << "[FlutterBridge] Renderer process terminated" << std::endl;
    }
#endif
}

static bool IsRendererRunning() {
#ifdef _WIN32
    if (g_process_handle == nullptr) return false;

    DWORD exit_code;
    if (!GetExitCodeProcess(g_process_handle, &exit_code)) {
        return false;
    }
    return exit_code == STILL_ACTIVE;
#else
    if (g_renderer_pid <= 0) return false;

    int status;
    pid_t result = waitpid(g_renderer_pid, &status, WNOHANG);

    if (result == 0) {
        // Still running
        return true;
    } else if (result == g_renderer_pid) {
        // Exited
        g_renderer_pid = 0;
        return false;
    } else {
        // Error
        return false;
    }
#endif
}

// ============================================================================
// Public API Implementation
// ============================================================================

bool flutter_bridge_init(const char* assets_path, const char* icu_data_path) {
    if (g_initialized) {
        std::cerr << "[FlutterBridge] Already initialized" << std::endl;
        return true;
    }

    std::cout << "[FlutterBridge] Initializing (subprocess mode)..." << std::endl;

    // Generate shared memory name
    g_shm_name = GenerateShmName();

    // Create shared memory
    if (!g_shm_handle.create(g_shm_name.c_str())) {
        std::cerr << "[FlutterBridge] Failed to create shared memory" << std::endl;
        return false;
    }

    g_shm = g_shm_handle.get();

    // Spawn renderer process
    if (!SpawnRendererProcess(assets_path, icu_data_path)) {
        g_shm_handle.unlink();
        g_shm_handle.close();
        g_shm = nullptr;
        return false;
    }

    // Wait for renderer to be ready (with timeout)
    std::cout << "[FlutterBridge] Waiting for renderer to initialize..." << std::endl;

    auto start_time = std::chrono::steady_clock::now();
    const auto timeout = std::chrono::seconds(10);

    while (true) {
        auto status = g_shm->status.load(std::memory_order_acquire);

        if (status == STATUS_READY) {
            std::cout << "[FlutterBridge] Renderer is ready!" << std::endl;
            break;
        }

        if (status == STATUS_ERROR) {
            std::cerr << "[FlutterBridge] Renderer reported error" << std::endl;
            TerminateRendererProcess();
            g_shm_handle.unlink();
            g_shm_handle.close();
            g_shm = nullptr;
            return false;
        }

        if (!IsRendererRunning()) {
            std::cerr << "[FlutterBridge] Renderer process died unexpectedly" << std::endl;
            g_shm_handle.unlink();
            g_shm_handle.close();
            g_shm = nullptr;
            return false;
        }

        auto elapsed = std::chrono::steady_clock::now() - start_time;
        if (elapsed > timeout) {
            std::cerr << "[FlutterBridge] Timeout waiting for renderer" << std::endl;
            TerminateRendererProcess();
            g_shm_handle.unlink();
            g_shm_handle.close();
            g_shm = nullptr;
            return false;
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    g_initialized = true;
    std::cout << "[FlutterBridge] Initialized successfully" << std::endl;

    return true;
}

void flutter_bridge_shutdown() {
    if (!g_initialized) return;

    std::cout << "[FlutterBridge] Shutting down..." << std::endl;

    TerminateRendererProcess();

    if (g_shm) {
        g_shm_handle.unlink();
        g_shm_handle.close();
        g_shm = nullptr;
    }

    g_pixel_cache.clear();
    g_cache_width = 0;
    g_cache_height = 0;
    g_has_new_frame = false;
    g_last_frame_number = 0;
    g_initialized = false;

    std::cout << "[FlutterBridge] Shut down complete" << std::endl;
}

void flutter_bridge_resize(int width, int height, double pixel_ratio) {
    if (!g_initialized || !g_shm) return;

    flutter_shm_send_resize(g_shm, width, height, pixel_ratio);
}

void flutter_bridge_render_frame() {
    // No-op for subprocess mode - rendering happens in the subprocess
}

const void* flutter_bridge_get_pixels(size_t* width, size_t* height, size_t* row_bytes) {
    if (!g_initialized || !g_shm) {
        *width = 0;
        *height = 0;
        *row_bytes = 0;
        return nullptr;
    }

    // Check for new frame
    uint64_t frame_num = g_shm->frame_number.load(std::memory_order_acquire);

    if (frame_num != g_last_frame_number) {
        // New frame available - copy to cache
        uint32_t w = g_shm->width.load(std::memory_order_acquire);
        uint32_t h = g_shm->height.load(std::memory_order_acquire);

        if (w > 0 && h > 0 && w <= FLUTTER_SHM_MAX_WIDTH && h <= FLUTTER_SHM_MAX_HEIGHT) {
            size_t buffer_size = w * h * 4;
            g_pixel_cache.resize(buffer_size);
            std::memcpy(g_pixel_cache.data(), g_shm->pixels, buffer_size);
            g_cache_width = w;
            g_cache_height = h;
            g_has_new_frame = true;
        }

        g_last_frame_number = frame_num;
    }

    if (g_pixel_cache.empty()) {
        *width = 0;
        *height = 0;
        *row_bytes = 0;
        return nullptr;
    }

    *width = g_cache_width;
    *height = g_cache_height;
    *row_bytes = g_cache_width * 4;

    return g_pixel_cache.data();
}

bool flutter_bridge_has_new_frame() {
    if (!g_initialized || !g_shm) return false;

    uint64_t frame_num = g_shm->frame_number.load(std::memory_order_acquire);
    bool result = (frame_num != g_last_frame_number) || g_has_new_frame;
    g_has_new_frame = false;
    return result;
}

void flutter_bridge_send_pointer_event(int phase, double x, double y, int64_t buttons) {
    if (!g_initialized || !g_shm) return;

    flutter_shm_send_pointer(g_shm, phase, x, y, buttons);
}

void flutter_bridge_send_scroll_event(double x, double y, double scroll_x, double scroll_y) {
    if (!g_initialized || !g_shm) return;

    flutter_shm_send_scroll(g_shm, x, y, scroll_x, scroll_y);
}

bool flutter_bridge_is_initialized() {
    return g_initialized && IsRendererRunning();
}

// ============================================================================
// Additional Configuration API
// ============================================================================

extern "C" {

/**
 * Set the path to the flutter_renderer executable.
 * Must be called before flutter_bridge_init().
 */
void flutter_bridge_set_renderer_path(const char* path) {
    if (path) {
        g_renderer_path = path;
        std::cout << "[FlutterBridge] Renderer path set to: " << path << std::endl;
    }
}

/**
 * Check if the renderer subprocess is running.
 */
bool flutter_bridge_is_renderer_running() {
    return IsRendererRunning();
}

}
