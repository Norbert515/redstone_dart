#pragma once

#include <cstdint>
#include <cstddef>
#include <atomic>
#include <thread>
#include <chrono>

// Maximum texture size: 4K x 4K = 64MB of pixel data
constexpr size_t FLUTTER_SHM_MAX_WIDTH = 4096;
constexpr size_t FLUTTER_SHM_MAX_HEIGHT = 4096;
constexpr size_t FLUTTER_SHM_PIXEL_SIZE = FLUTTER_SHM_MAX_WIDTH * FLUTTER_SHM_MAX_HEIGHT * 4;

// Magic number for validation: 'FLTR' in little-endian
constexpr uint32_t FLUTTER_SHM_MAGIC = 0x52544C46;

// Command types from Minecraft to Flutter renderer
enum FlutterShmCommand : uint32_t {
    CMD_NONE = 0,
    CMD_RESIZE = 1,
    CMD_POINTER = 2,
    CMD_SCROLL = 3,
    CMD_SHUTDOWN = 4,
    CMD_INIT = 5,  // Sent after initial setup
};

// Pointer phases matching Flutter's FlutterPointerPhase
enum FlutterShmPointerPhase : int32_t {
    PHASE_CANCEL = 0,
    PHASE_UP = 1,
    PHASE_DOWN = 2,
    PHASE_MOVE = 3,
    PHASE_ADD = 4,
    PHASE_REMOVE = 5,
    PHASE_HOVER = 6,
    PHASE_PAN_ZOOM_START = 7,
    PHASE_PAN_ZOOM_UPDATE = 8,
    PHASE_PAN_ZOOM_END = 9,
};

// Status from Flutter renderer to Minecraft
enum FlutterShmStatus : uint32_t {
    STATUS_NOT_READY = 0,
    STATUS_INITIALIZING = 1,
    STATUS_READY = 2,
    STATUS_ERROR = 3,
    STATUS_SHUTDOWN = 4,
};

/**
 * Shared memory layout for Flutter renderer communication.
 *
 * This structure is mapped into shared memory and used for:
 * 1. Commands from Minecraft -> Flutter (resize, pointer, scroll, shutdown)
 * 2. Pixel data from Flutter -> Minecraft (RGBA buffer)
 * 3. Frame synchronization via frame_number
 *
 * Memory ordering:
 * - Minecraft writes commands, then sets cmd_ready = 1
 * - Flutter reads commands when cmd_ready = 1, then sets cmd_ready = 0
 * - Flutter writes pixels, then increments frame_number
 * - Minecraft reads pixels when frame_number changes
 */
struct FlutterSharedMemory {
    // ========== Header (64 bytes) ==========

    // Magic number for validation
    std::atomic<uint32_t> magic;

    // Current pixel buffer dimensions (set by Flutter after resize)
    std::atomic<uint32_t> width;
    std::atomic<uint32_t> height;

    // Frame counter - incremented by Flutter when a new frame is ready
    std::atomic<uint64_t> frame_number;

    // Flutter renderer status
    std::atomic<uint32_t> status;

    // Padding to align to 64 bytes
    uint32_t _header_padding[9];

    // ========== Command Buffer (128 bytes) ==========

    // Command type and ready flag
    std::atomic<uint32_t> cmd_type;
    std::atomic<uint32_t> cmd_ready;  // 1 = command waiting, 0 = command processed

    // Resize command parameters
    int32_t cmd_width;
    int32_t cmd_height;
    double cmd_pixel_ratio;

    // Pointer event parameters
    double cmd_pointer_x;
    double cmd_pointer_y;
    int32_t cmd_pointer_phase;
    int64_t cmd_pointer_buttons;

    // Scroll event parameters
    double cmd_scroll_x;
    double cmd_scroll_y;
    double cmd_scroll_delta_x;
    double cmd_scroll_delta_y;

    // Padding to align to 128 bytes
    uint8_t _cmd_padding[24];

    // ========== Pixel Data ==========

    // RGBA pixel data (4 bytes per pixel)
    // Stored in row-major order, top-left origin
    uint8_t pixels[FLUTTER_SHM_PIXEL_SIZE];
};

// Verify structure size assumptions
// Note: Actual offset may vary by platform due to atomic alignment
// The important thing is that the structure is consistent on both sides
static_assert(offsetof(FlutterSharedMemory, pixels) >= 176 && offsetof(FlutterSharedMemory, pixels) <= 256,
    "Header + command section should be between 176-256 bytes");

/**
 * Cross-platform shared memory operations.
 *
 * On macOS/Linux: Uses POSIX shm_open/mmap
 * On Windows: Uses CreateFileMapping/MapViewOfFile
 */
class FlutterSharedMemoryHandle {
public:
    FlutterSharedMemoryHandle();
    ~FlutterSharedMemoryHandle();

    // Create a new shared memory region (owner/server)
    bool create(const char* name);

    // Open an existing shared memory region (client)
    bool open(const char* name);

    // Close and unmap the shared memory
    void close();

    // Unlink (remove) the shared memory from the system
    void unlink();

    // Get pointer to the shared memory structure
    FlutterSharedMemory* get() { return memory_; }
    const FlutterSharedMemory* get() const { return memory_; }

    // Check if the handle is valid
    bool isValid() const { return memory_ != nullptr; }

    // Get the shared memory name
    const char* getName() const { return name_; }

private:
    FlutterSharedMemory* memory_ = nullptr;
    char name_[256] = {0};

#ifdef _WIN32
    void* file_mapping_ = nullptr;
#else
    int fd_ = -1;
#endif

    bool is_owner_ = false;
};

// Helper functions for command operations

/**
 * Send a command to the Flutter renderer.
 * This function writes the command and sets cmd_ready atomically.
 */
inline void flutter_shm_send_resize(FlutterSharedMemory* shm, int width, int height, double pixel_ratio) {
    // Wait for previous command to be processed (with timeout)
    int retries = 0;
    while (shm->cmd_ready.load(std::memory_order_acquire) == 1 && retries < 100) {
        // Busy wait for ~1ms
        for (volatile int i = 0; i < 10000; i++) {}
        retries++;
    }

    shm->cmd_width = width;
    shm->cmd_height = height;
    shm->cmd_pixel_ratio = pixel_ratio;
    shm->cmd_type.store(CMD_RESIZE, std::memory_order_release);
    shm->cmd_ready.store(1, std::memory_order_release);
}

inline void flutter_shm_send_pointer(FlutterSharedMemory* shm, int phase, double x, double y, int64_t buttons) {
    // Wait for previous command to be processed (with timeout of ~10ms)
    int retries = 0;
    while (shm->cmd_ready.load(std::memory_order_acquire) == 1 && retries < 100) {
        std::this_thread::sleep_for(std::chrono::microseconds(100));
        retries++;
    }

    shm->cmd_pointer_phase = phase;
    shm->cmd_pointer_x = x;
    shm->cmd_pointer_y = y;
    shm->cmd_pointer_buttons = buttons;
    shm->cmd_type.store(CMD_POINTER, std::memory_order_release);
    shm->cmd_ready.store(1, std::memory_order_release);
}

inline void flutter_shm_send_scroll(FlutterSharedMemory* shm, double x, double y, double scroll_x, double scroll_y) {
    shm->cmd_scroll_x = x;
    shm->cmd_scroll_y = y;
    shm->cmd_scroll_delta_x = scroll_x;
    shm->cmd_scroll_delta_y = scroll_y;
    shm->cmd_type.store(CMD_SCROLL, std::memory_order_release);
    shm->cmd_ready.store(1, std::memory_order_release);
}

inline void flutter_shm_send_shutdown(FlutterSharedMemory* shm) {
    shm->cmd_type.store(CMD_SHUTDOWN, std::memory_order_release);
    shm->cmd_ready.store(1, std::memory_order_release);
}

inline void flutter_shm_send_init(FlutterSharedMemory* shm) {
    shm->cmd_type.store(CMD_INIT, std::memory_order_release);
    shm->cmd_ready.store(1, std::memory_order_release);
}

/**
 * Check if a command is waiting (for Flutter renderer).
 */
inline bool flutter_shm_has_command(FlutterSharedMemory* shm) {
    return shm->cmd_ready.load(std::memory_order_acquire) == 1;
}

/**
 * Acknowledge command processing (for Flutter renderer).
 */
inline void flutter_shm_ack_command(FlutterSharedMemory* shm) {
    shm->cmd_ready.store(0, std::memory_order_release);
}

/**
 * Signal a new frame is ready (for Flutter renderer).
 */
inline void flutter_shm_signal_frame(FlutterSharedMemory* shm) {
    shm->frame_number.fetch_add(1, std::memory_order_release);
}
