// Multi-Surface Flutter Renderer Implementation
// Manages multiple independent Flutter surfaces for macOS using Metal/IOSurface

#ifdef __APPLE__

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <IOSurface/IOSurface.h>
#include <flutter_embedder.h>
#include <iostream>
#include <unordered_map>
#include <mutex>
#include <queue>
#include <atomic>
#include <chrono>
#include <thread>

// OpenGL headers for IOSurface binding
#define GL_SILENCE_DEPRECATION
#include <OpenGL/gl3.h>
#include <OpenGL/OpenGL.h>
#include <OpenGL/CGLIOSurface.h>

#ifndef GL_TEXTURE_RECTANGLE
#define GL_TEXTURE_RECTANGLE 0x84F5
#endif
#ifndef GL_BGRA
#define GL_BGRA 0x80E1
#endif
#ifndef GL_UNSIGNED_INT_8_8_8_8_REV
#define GL_UNSIGNED_INT_8_8_8_8_REV 0x8367
#endif

#include "multi_surface_renderer.h"

// ==========================================================================
// Forward declarations
// ==========================================================================

// Get Metal device/queue from the existing renderer (defined in metal_renderer.mm)
extern "C" void* metal_renderer_get_device();
extern "C" void* metal_renderer_get_command_queue();
extern "C" void metal_renderer_flush_and_wait();

// ==========================================================================
// FlutterSurface: Per-surface state
// ==========================================================================

struct FlutterSurface {
    int64_t id;
    FlutterEngine engine = nullptr;

    // Metal resources (stored as void* for C++ compatibility, cast to id<MTLTexture> when used)
    void* metal_texture = nullptr;  // Actually id<MTLTexture>
    IOSurfaceRef io_surface = nullptr;

    // Dimensions
    int32_t width = 0;
    int32_t height = 0;
    int32_t requested_width = 0;
    int32_t requested_height = 0;
    double pixel_ratio = 1.0;

    // OpenGL texture (bound to IOSurface)
    GLuint gl_texture = 0;

    // Pixel readback buffer
    void* pixel_buffer = nullptr;
    size_t pixel_buffer_size = 0;
    int32_t pixel_width = 0;
    int32_t pixel_height = 0;

    // Frame state
    std::atomic<bool> has_new_frame{false};

    // Task queue for custom task runner
    std::mutex task_mutex;
    std::queue<std::pair<FlutterTask, uint64_t>> pending_tasks;
    std::thread::id platform_thread_id;

    // Shutdown flag
    std::atomic<bool> shutdown_requested{false};
};

// ==========================================================================
// Global State
// ==========================================================================

static std::mutex g_surfaces_mutex;
static std::unordered_map<int64_t, std::unique_ptr<FlutterSurface>> g_surfaces;
static std::atomic<int64_t> g_next_surface_id{1};  // Start at 1, 0 is reserved for main surface
static std::atomic<bool> g_multi_surface_initialized{false};

// Metal resources (shared from main renderer)
static id<MTLDevice> g_metal_device = nil;
static id<MTLCommandQueue> g_metal_command_queue = nil;

// ==========================================================================
// Helper Functions
// ==========================================================================

static FlutterSurface* GetSurface(int64_t surface_id) {
    auto it = g_surfaces.find(surface_id);
    return (it != g_surfaces.end()) ? it->second.get() : nullptr;
}

// ==========================================================================
// Custom Task Runner Callbacks (per-surface)
// ==========================================================================

static bool SurfaceTaskRunnerRunsOnCurrentThread(void* user_data) {
    auto* surface = static_cast<FlutterSurface*>(user_data);
    if (!surface) return false;
    return std::this_thread::get_id() == surface->platform_thread_id;
}

static void SurfaceTaskRunnerPostTask(FlutterTask task, uint64_t target_time, void* user_data) {
    auto* surface = static_cast<FlutterSurface*>(user_data);
    if (!surface || surface->shutdown_requested) return;

    std::lock_guard<std::mutex> lock(surface->task_mutex);
    surface->pending_tasks.push({task, target_time});
}

// ==========================================================================
// Metal Texture Creation (per-surface)
// ==========================================================================

static bool CreateOrResizeSurfaceTexture(FlutterSurface* surface, int32_t width, int32_t height) {
    if (!surface || width <= 0 || height <= 0) return false;
    if (g_metal_device == nil) return false;

    // Check if resize needed
    if (width == surface->width && height == surface->height && surface->metal_texture != nullptr) {
        return true;
    }

    std::cout << "[MultiSurface] Creating texture for surface " << surface->id
              << ": " << width << "x" << height << std::endl;

    @try {
        // Release old resources
        id<MTLTexture> oldTexture = (__bridge_transfer id<MTLTexture>)surface->metal_texture;
        surface->metal_texture = nullptr;
        oldTexture = nil;  // Release
        if (surface->io_surface != nullptr) {
            CFRelease(surface->io_surface);
            surface->io_surface = nullptr;
        }
        if (surface->gl_texture != 0) {
            glDeleteTextures(1, &surface->gl_texture);
            surface->gl_texture = 0;
        }

        // Create IOSurface
        NSDictionary* surfaceProperties = @{
            (__bridge NSString*)kIOSurfaceWidth: @(width),
            (__bridge NSString*)kIOSurfaceHeight: @(height),
            (__bridge NSString*)kIOSurfaceBytesPerElement: @4,
        };

        surface->io_surface = IOSurfaceCreate((__bridge CFDictionaryRef)surfaceProperties);
        if (surface->io_surface == nullptr) {
            std::cerr << "[MultiSurface] Failed to create IOSurface for surface " << surface->id << std::endl;
            return false;
        }

        // Create Metal texture backed by IOSurface
        MTLTextureDescriptor* textureDesc = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
            width:width
            height:height
            mipmapped:NO];
        textureDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;

        id<MTLTexture> newTexture = [g_metal_device newTextureWithDescriptor:textureDesc
                                                                iosurface:surface->io_surface
                                                                    plane:0];
        surface->metal_texture = (__bridge_retained void*)newTexture;

        if (newTexture == nil) {
            std::cerr << "[MultiSurface] Failed to create Metal texture for surface " << surface->id << std::endl;
            CFRelease(surface->io_surface);
            surface->io_surface = nullptr;
            return false;
        }

        surface->width = width;
        surface->height = height;

        std::cout << "[MultiSurface] Texture created for surface " << surface->id << std::endl;
        return true;
    }
    @catch (NSException* exception) {
        std::cerr << "[MultiSurface] Exception creating texture: "
                  << [[exception name] UTF8String] << " - "
                  << [[exception reason] UTF8String] << std::endl;
        return false;
    }
}

// ==========================================================================
// Flutter Metal Callbacks (per-surface)
// ==========================================================================

static FlutterMetalTexture SurfaceGetNextDrawable(void* user_data, const FlutterFrameInfo* frame_info) {
    auto* surface = static_cast<FlutterSurface*>(user_data);

    FlutterMetalTexture result = {};
    result.struct_size = sizeof(FlutterMetalTexture);

    if (!surface || !frame_info) return result;

    int32_t width = static_cast<int32_t>(frame_info->size.width);
    int32_t height = static_cast<int32_t>(frame_info->size.height);

    if (width <= 0 || height <= 0) return result;

    if (!CreateOrResizeSurfaceTexture(surface, width, height)) {
        return result;
    }

    id<MTLTexture> metalTex = (__bridge id<MTLTexture>)surface->metal_texture;
    result.texture = (__bridge FlutterMetalTextureHandle)metalTex;
    result.user_data = surface;
    result.destruction_callback = nullptr;

    return result;
}

static bool SurfacePresentDrawable(void* user_data, const FlutterMetalTexture* texture) {
    if (!texture || !texture->user_data) return false;

    auto* surface = static_cast<FlutterSurface*>(texture->user_data);
    surface->has_new_frame = true;
    return true;
}

// ==========================================================================
// Flutter Vsync Callback (per-surface)
// ==========================================================================

static void SurfaceVsyncCallback(void* user_data, intptr_t baton) {
    auto* surface = static_cast<FlutterSurface*>(user_data);
    if (!surface || surface->shutdown_requested || surface->engine == nullptr) return;

    uint64_t now = FlutterEngineGetCurrentTime();
    FlutterEngineOnVsync(surface->engine, baton, now, now + 1);
}

// ==========================================================================
// Lifecycle
// ==========================================================================

extern "C" bool multi_surface_init() {
    if (g_multi_surface_initialized.load()) {
        return true;
    }

    // Get shared Metal resources from main renderer
    g_metal_device = (__bridge id<MTLDevice>)metal_renderer_get_device();
    g_metal_command_queue = (__bridge id<MTLCommandQueue>)metal_renderer_get_command_queue();

    if (g_metal_device == nil || g_metal_command_queue == nil) {
        std::cerr << "[MultiSurface] Failed to get Metal device/queue from main renderer" << std::endl;
        return false;
    }

    g_multi_surface_initialized = true;
    std::cout << "[MultiSurface] Initialized with shared Metal device" << std::endl;
    return true;
}

extern "C" void multi_surface_shutdown() {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    std::cout << "[MultiSurface] Shutting down " << g_surfaces.size() << " surfaces..." << std::endl;

    // Destroy all surfaces
    for (auto& pair : g_surfaces) {
        auto* surface = pair.second.get();
        surface->shutdown_requested = true;

        if (surface->engine != nullptr) {
            FlutterEngineShutdown(surface->engine);
            surface->engine = nullptr;
        }

        // Release Metal resources
        if (surface->metal_texture != nullptr) {
            id<MTLTexture> tex = (__bridge_transfer id<MTLTexture>)surface->metal_texture;
            surface->metal_texture = nullptr;
            tex = nil;  // Release
        }
        if (surface->io_surface != nullptr) {
            CFRelease(surface->io_surface);
            surface->io_surface = nullptr;
        }
        if (surface->gl_texture != 0) {
            glDeleteTextures(1, &surface->gl_texture);
            surface->gl_texture = 0;
        }
        if (surface->pixel_buffer != nullptr) {
            free(surface->pixel_buffer);
            surface->pixel_buffer = nullptr;
        }
    }

    g_surfaces.clear();
    g_multi_surface_initialized = false;

    std::cout << "[MultiSurface] Shutdown complete" << std::endl;
}

extern "C" bool multi_surface_is_initialized() {
    return g_multi_surface_initialized.load();
}

// ==========================================================================
// Surface Management
// ==========================================================================

// External: Get Flutter assets path from main client runtime
extern const char* dart_client_get_assets_path();
extern const char* dart_client_get_icu_path();

extern "C" int64_t multi_surface_create(int32_t width, int32_t height, const char* initial_route) {
    if (!g_multi_surface_initialized.load()) {
        std::cerr << "[MultiSurface] System not initialized" << std::endl;
        return 0;
    }

    if (width <= 0 || height <= 0) {
        std::cerr << "[MultiSurface] Invalid dimensions: " << width << "x" << height << std::endl;
        return 0;
    }

    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    int64_t surface_id = g_next_surface_id++;
    auto surface = std::make_unique<FlutterSurface>();
    surface->id = surface_id;
    surface->requested_width = width;
    surface->requested_height = height;
    surface->platform_thread_id = std::this_thread::get_id();

    std::cout << "[MultiSurface] Creating surface " << surface_id
              << " (" << width << "x" << height << ")" << std::endl;

    // Configure Metal renderer
    FlutterRendererConfig renderer = {};
    renderer.type = kMetal;
    renderer.metal.struct_size = sizeof(FlutterMetalRendererConfig);
    renderer.metal.device = (__bridge FlutterMetalDeviceHandle)g_metal_device;
    renderer.metal.present_command_queue = (__bridge FlutterMetalCommandQueueHandle)g_metal_command_queue;
    renderer.metal.get_next_drawable_callback = SurfaceGetNextDrawable;
    renderer.metal.present_drawable_callback = SurfacePresentDrawable;

    // Configure project args
    // Note: In a full implementation, we would use FlutterEngineGroup to spawn
    // child engines that share the Dart isolate. For now, we create independent
    // engines (each with its own isolate).
    //
    // TODO: Implement FlutterEngineGroup once Flutter embedder API supports it
    // properly for headless/offscreen rendering scenarios.

    FlutterProjectArgs args = {};
    args.struct_size = sizeof(FlutterProjectArgs);

    // Get assets paths from main runtime
    // For now, these need to be passed in or shared from the main engine
    // This is a limitation - ideally we'd use FlutterEngineGroup
    args.assets_path = "/path/to/flutter_assets";  // TODO: Get from main engine
    args.icu_data_path = "/path/to/icudtl.dat";    // TODO: Get from main engine

    // Set initial route if provided
    if (initial_route && initial_route[0] != '\0') {
        args.custom_dart_entrypoint = initial_route;
    }

    // Configure vsync
    args.vsync_callback = SurfaceVsyncCallback;

    // Configure custom task runner
    FlutterTaskRunnerDescription task_runner = {};
    task_runner.struct_size = sizeof(FlutterTaskRunnerDescription);
    task_runner.user_data = surface.get();
    task_runner.runs_task_on_current_thread_callback = SurfaceTaskRunnerRunsOnCurrentThread;
    task_runner.post_task_callback = SurfaceTaskRunnerPostTask;
    task_runner.identifier = static_cast<size_t>(surface_id + 100);  // Unique identifier

    FlutterCustomTaskRunners custom_task_runners = {};
    custom_task_runners.struct_size = sizeof(FlutterCustomTaskRunners);
    custom_task_runners.platform_task_runner = &task_runner;
    custom_task_runners.render_task_runner = &task_runner;
    custom_task_runners.ui_task_runner = &task_runner;

    args.custom_task_runners = &custom_task_runners;

    // Note: For now, we skip actual engine creation since we need the main
    // engine's assets paths and ideally FlutterEngineGroup support.
    // This is a stub implementation that sets up the infrastructure.
    //
    // In a real implementation with FlutterEngineGroup:
    // 1. Create engine group from main engine
    // 2. Spawn child engine with custom entry point
    // 3. Child engines share isolate, fonts, GPU context

    std::cout << "[MultiSurface] Surface " << surface_id << " created (stub - engine not started)" << std::endl;
    std::cout << "[MultiSurface] NOTE: Full implementation requires FlutterEngineGroup support" << std::endl;

    // Store surface
    auto* surface_ptr = surface.get();
    g_surfaces[surface_id] = std::move(surface);

    // Send initial window metrics
    if (surface_ptr->engine != nullptr) {
        FlutterWindowMetricsEvent metrics = {};
        metrics.struct_size = sizeof(FlutterWindowMetricsEvent);
        metrics.width = width;
        metrics.height = height;
        metrics.pixel_ratio = 1.0;
        FlutterEngineSendWindowMetricsEvent(surface_ptr->engine, &metrics);
    }

    return surface_id;
}

extern "C" void multi_surface_destroy(int64_t surface_id) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto it = g_surfaces.find(surface_id);
    if (it == g_surfaces.end()) {
        std::cerr << "[MultiSurface] Surface " << surface_id << " not found" << std::endl;
        return;
    }

    auto* surface = it->second.get();
    surface->shutdown_requested = true;

    std::cout << "[MultiSurface] Destroying surface " << surface_id << std::endl;

    // Shutdown engine
    if (surface->engine != nullptr) {
        FlutterEngineShutdown(surface->engine);
        surface->engine = nullptr;
    }

    // Release Metal resources
    if (surface->metal_texture != nullptr) {
        id<MTLTexture> tex = (__bridge_transfer id<MTLTexture>)surface->metal_texture;
        surface->metal_texture = nullptr;
        tex = nil;  // Release
    }
    if (surface->io_surface != nullptr) {
        CFRelease(surface->io_surface);
        surface->io_surface = nullptr;
    }
    if (surface->gl_texture != 0) {
        glDeleteTextures(1, &surface->gl_texture);
        surface->gl_texture = 0;
    }
    if (surface->pixel_buffer != nullptr) {
        free(surface->pixel_buffer);
        surface->pixel_buffer = nullptr;
    }

    g_surfaces.erase(it);
    std::cout << "[MultiSurface] Surface " << surface_id << " destroyed" << std::endl;
}

extern "C" bool multi_surface_exists(int64_t surface_id) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);
    return g_surfaces.find(surface_id) != g_surfaces.end();
}

// ==========================================================================
// Surface Rendering
// ==========================================================================

extern "C" void multi_surface_set_size(int64_t surface_id, int32_t width, int32_t height) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    if (!surface) return;

    surface->requested_width = width;
    surface->requested_height = height;

    if (surface->engine != nullptr) {
        FlutterWindowMetricsEvent metrics = {};
        metrics.struct_size = sizeof(FlutterWindowMetricsEvent);
        metrics.width = width;
        metrics.height = height;
        metrics.pixel_ratio = surface->pixel_ratio;
        FlutterEngineSendWindowMetricsEvent(surface->engine, &metrics);
    }
}

extern "C" void multi_surface_process_tasks(int64_t surface_id) {
    FlutterSurface* surface = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_surfaces_mutex);
        surface = GetSurface(surface_id);
    }

    if (!surface || surface->engine == nullptr) return;

    std::queue<std::pair<FlutterTask, uint64_t>> tasks_to_run;
    {
        std::lock_guard<std::mutex> lock(surface->task_mutex);
        std::swap(tasks_to_run, surface->pending_tasks);
    }

    uint64_t current_time = FlutterEngineGetCurrentTime();

    while (!tasks_to_run.empty()) {
        auto& task_pair = tasks_to_run.front();
        if (task_pair.second <= current_time) {
            FlutterEngineRunTask(surface->engine, &task_pair.first);
        } else {
            std::lock_guard<std::mutex> lock(surface->task_mutex);
            surface->pending_tasks.push(task_pair);
        }
        tasks_to_run.pop();
    }
}

extern "C" void multi_surface_process_all_tasks() {
    std::vector<int64_t> surface_ids;
    {
        std::lock_guard<std::mutex> lock(g_surfaces_mutex);
        for (const auto& pair : g_surfaces) {
            surface_ids.push_back(pair.first);
        }
    }

    for (int64_t id : surface_ids) {
        multi_surface_process_tasks(id);
    }
}

extern "C" void multi_surface_schedule_frame(int64_t surface_id) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    if (!surface || surface->engine == nullptr) return;

    FlutterEngineScheduleFrame(surface->engine);
}

// ==========================================================================
// Texture Access
// ==========================================================================

extern "C" bool multi_surface_update_gl_texture(int64_t surface_id) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    if (!surface || surface->io_surface == nullptr) return false;

    int32_t width = surface->width;
    int32_t height = surface->height;
    if (width <= 0 || height <= 0) return false;

    // Ensure Metal has finished writing
    metal_renderer_flush_and_wait();

    // Delete old GL texture
    if (surface->gl_texture != 0) {
        glDeleteTextures(1, &surface->gl_texture);
        surface->gl_texture = 0;
    }

    // Get CGL context
    CGLContextObj cglContext = CGLGetCurrentContext();
    if (cglContext == nullptr) {
        std::cerr << "[MultiSurface] No CGL context for surface " << surface_id << std::endl;
        return false;
    }

    // Clear GL errors
    while (glGetError() != GL_NO_ERROR) {}

    // Create GL texture
    glGenTextures(1, &surface->gl_texture);
    glBindTexture(GL_TEXTURE_RECTANGLE, surface->gl_texture);

    // Bind IOSurface to GL texture
    CGLError err = CGLTexImageIOSurface2D(
        cglContext,
        GL_TEXTURE_RECTANGLE,
        GL_RGBA8,
        width, height,
        GL_BGRA,
        GL_UNSIGNED_INT_8_8_8_8_REV,
        surface->io_surface,
        0
    );

    if (err != kCGLNoError) {
        std::cerr << "[MultiSurface] CGLTexImageIOSurface2D failed for surface " << surface_id
                  << ": error " << err << std::endl;
        glDeleteTextures(1, &surface->gl_texture);
        surface->gl_texture = 0;
        return false;
    }

    // Set texture parameters
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glBindTexture(GL_TEXTURE_RECTANGLE, 0);
    glFlush();

    return true;
}

extern "C" int32_t multi_surface_get_texture_id(int64_t surface_id) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    if (!surface) return 0;

    return static_cast<int32_t>(surface->gl_texture);
}

extern "C" int32_t multi_surface_get_texture_width(int64_t surface_id) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    return surface ? surface->width : 0;
}

extern "C" int32_t multi_surface_get_texture_height(int64_t surface_id) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    return surface ? surface->height : 0;
}

extern "C" bool multi_surface_has_new_frame(int64_t surface_id) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    if (!surface) return false;

    bool expected = true;
    return surface->has_new_frame.compare_exchange_strong(expected, false);
}

// ==========================================================================
// Pixel Access
// ==========================================================================

extern "C" void* multi_surface_get_pixels(int64_t surface_id) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    if (!surface || surface->io_surface == nullptr) return nullptr;

    int32_t width = surface->width;
    int32_t height = surface->height;
    if (width <= 0 || height <= 0) return nullptr;

    // Lock IOSurface for CPU read
    IOReturn lockResult = IOSurfaceLock(surface->io_surface, kIOSurfaceLockReadOnly, nullptr);
    if (lockResult != kIOReturnSuccess) {
        std::cerr << "[MultiSurface] Failed to lock IOSurface for surface " << surface_id << std::endl;
        return nullptr;
    }

    // Get pixel data
    void* baseAddress = IOSurfaceGetBaseAddress(surface->io_surface);
    size_t bytesPerRow = IOSurfaceGetBytesPerRow(surface->io_surface);
    size_t tightBytesPerRow = (size_t)width * 4;

    // Ensure buffer is big enough
    size_t requiredSize = tightBytesPerRow * height;
    if (surface->pixel_buffer_size < requiredSize) {
        if (surface->pixel_buffer) free(surface->pixel_buffer);
        surface->pixel_buffer = malloc(requiredSize);
        surface->pixel_buffer_size = requiredSize;
    }

    // Copy and convert BGRA to RGBA
    if (surface->pixel_buffer && baseAddress) {
        uint8_t* src = (uint8_t*)baseAddress;
        uint8_t* dst = (uint8_t*)surface->pixel_buffer;

        for (int32_t y = 0; y < height; y++) {
            for (int32_t x = 0; x < width; x++) {
                dst[x * 4 + 0] = src[x * 4 + 2];  // R <- B
                dst[x * 4 + 1] = src[x * 4 + 1];  // G <- G
                dst[x * 4 + 2] = src[x * 4 + 0];  // B <- R
                dst[x * 4 + 3] = src[x * 4 + 3];  // A <- A
            }
            src += bytesPerRow;
            dst += tightBytesPerRow;
        }
    }

    surface->pixel_width = width;
    surface->pixel_height = height;

    IOSurfaceUnlock(surface->io_surface, kIOSurfaceLockReadOnly, nullptr);

    return surface->pixel_buffer;
}

extern "C" int32_t multi_surface_get_pixel_width(int64_t surface_id) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    return surface ? surface->pixel_width : 0;
}

extern "C" int32_t multi_surface_get_pixel_height(int64_t surface_id) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    return surface ? surface->pixel_height : 0;
}

// ==========================================================================
// Input Events
// ==========================================================================

extern "C" void multi_surface_send_pointer_event(int64_t surface_id, int32_t phase,
                                                   double x, double y, int64_t buttons) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    if (!surface || surface->engine == nullptr) return;

    FlutterPointerEvent event = {};
    event.struct_size = sizeof(FlutterPointerEvent);
    event.phase = static_cast<FlutterPointerPhase>(phase);
    event.timestamp = FlutterEngineGetCurrentTime() / 1000;
    event.x = x * surface->pixel_ratio;
    event.y = y * surface->pixel_ratio;
    event.buttons = buttons;
    event.device_kind = kFlutterPointerDeviceKindMouse;

    FlutterEngineSendPointerEvent(surface->engine, &event, 1);
}

extern "C" void multi_surface_send_key_event(int64_t surface_id, int32_t type,
                                               int64_t physical_key, int64_t logical_key,
                                               const char* character, int32_t modifiers) {
    std::lock_guard<std::mutex> lock(g_surfaces_mutex);

    auto* surface = GetSurface(surface_id);
    if (!surface || surface->engine == nullptr) return;

    FlutterKeyEvent event = {};
    event.struct_size = sizeof(FlutterKeyEvent);
    event.timestamp = static_cast<double>(FlutterEngineGetCurrentTime()) / 1000000000.0;
    event.type = static_cast<FlutterKeyEventType>(type);
    event.physical = physical_key;
    event.logical = logical_key;
    event.character = character;
    event.synthesized = false;

    FlutterEngineSendKeyEvent(surface->engine, &event, nullptr, nullptr);
}

#endif // __APPLE__
