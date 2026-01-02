// Metal Renderer for Flutter on macOS
// Uses IOSurface for zero-copy sharing between Metal and OpenGL

#ifdef __APPLE__

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <IOSurface/IOSurface.h>
#import <CoreVideo/CoreVideo.h>
#include <flutter_embedder.h>
#include <iostream>
#include <atomic>
#include <mutex>

// ==========================================================================
// Global Metal State
// ==========================================================================

static id<MTLDevice> g_metal_device = nil;
static id<MTLCommandQueue> g_metal_command_queue = nil;
static id<MTLTexture> g_flutter_texture = nil;
static IOSurfaceRef g_io_surface = nullptr;

static int32_t g_texture_width = 0;
static int32_t g_texture_height = 0;
static int32_t g_requested_width = 800;
static int32_t g_requested_height = 600;

static std::atomic<bool> g_frame_ready{false};
static std::atomic<bool> g_metal_initialized{false};
static std::atomic<bool> g_metal_error_state{false};  // Set when Metal fails, prevents further attempts
static std::mutex g_metal_mutex;
static std::mutex g_iosurface_mutex;  // Separate mutex for IOSurface access from OpenGL thread

// ==========================================================================
// Metal Initialization
// ==========================================================================

extern "C" bool metal_renderer_init() {
    std::lock_guard<std::mutex> lock(g_metal_mutex);

    // If we're in an error state, don't try to reinitialize
    if (g_metal_error_state.load()) {
        std::cerr << "Metal renderer in error state, not reinitializing" << std::endl;
        return false;
    }

    if (g_metal_device != nil) {
        std::cout << "Metal renderer already initialized" << std::endl;
        return true;
    }

    std::cout << "Initializing Metal renderer..." << std::endl;

    @try {
        // Create Metal device
        g_metal_device = MTLCreateSystemDefaultDevice();
        if (g_metal_device == nil) {
            std::cerr << "Failed to create Metal device - no Metal-compatible GPU available" << std::endl;
            g_metal_error_state = true;
            return false;
        }

        std::cout << "Metal device: " << [[g_metal_device name] UTF8String] << std::endl;

        // Check if device supports IOSurface (required for OpenGL interop)
        // All modern macOS GPUs support this, but check anyway
        if (![g_metal_device supportsFamily:MTLGPUFamilyMac2]) {
            std::cerr << "Warning: Metal device may not fully support IOSurface interop" << std::endl;
        }

        // Create command queue
        g_metal_command_queue = [g_metal_device newCommandQueue];
        if (g_metal_command_queue == nil) {
            std::cerr << "Failed to create Metal command queue" << std::endl;
            g_metal_device = nil;
            g_metal_error_state = true;
            return false;
        }

        g_metal_initialized = true;
        std::cout << "Metal renderer initialized successfully" << std::endl;
        return true;
    }
    @catch (NSException* exception) {
        std::cerr << "Exception during Metal initialization: "
                  << [[exception name] UTF8String] << " - "
                  << [[exception reason] UTF8String] << std::endl;
        g_metal_device = nil;
        g_metal_command_queue = nil;
        g_metal_error_state = true;
        return false;
    }
}

extern "C" void metal_renderer_shutdown() {
    std::cout << "Shutting down Metal renderer..." << std::endl;

    // Lock both mutexes in consistent order to prevent deadlock
    std::lock_guard<std::mutex> lock1(g_metal_mutex);
    std::lock_guard<std::mutex> lock2(g_iosurface_mutex);

    @try {
        // Release Metal texture
        g_flutter_texture = nil;

        // Release IOSurface
        if (g_io_surface != nullptr) {
            CFRelease(g_io_surface);
            g_io_surface = nullptr;
        }

        // Release Metal objects
        g_metal_command_queue = nil;
        g_metal_device = nil;

        g_texture_width = 0;
        g_texture_height = 0;
        g_frame_ready = false;
        g_metal_initialized = false;
        // Note: Don't clear g_metal_error_state so we know Metal failed previously

        std::cout << "Metal renderer shutdown complete" << std::endl;
    }
    @catch (NSException* exception) {
        std::cerr << "Exception during Metal shutdown: "
                  << [[exception name] UTF8String] << " - "
                  << [[exception reason] UTF8String] << std::endl;
    }
}

// ==========================================================================
// Device and Command Queue Access
// ==========================================================================

extern "C" void* metal_renderer_get_device() {
    return (__bridge void*)g_metal_device;
}

extern "C" void* metal_renderer_get_command_queue() {
    return (__bridge void*)g_metal_command_queue;
}

// ==========================================================================
// IOSurface-Backed Texture Creation
// ==========================================================================

static bool CreateOrResizeTexture(int32_t width, int32_t height) {
    // Validate input dimensions
    if (width <= 0 || height <= 0) {
        std::cerr << "CreateOrResizeTexture: Invalid dimensions " << width << "x" << height << std::endl;
        return false;
    }

    // Sanity check for reasonable texture size (prevent allocation errors)
    constexpr int32_t MAX_TEXTURE_SIZE = 16384;
    if (width > MAX_TEXTURE_SIZE || height > MAX_TEXTURE_SIZE) {
        std::cerr << "CreateOrResizeTexture: Dimensions too large " << width << "x" << height
                  << " (max: " << MAX_TEXTURE_SIZE << ")" << std::endl;
        return false;
    }

    // Check Metal device is valid
    if (g_metal_device == nil) {
        std::cerr << "CreateOrResizeTexture: Metal device is nil" << std::endl;
        return false;
    }

    // Check if resize is needed
    if (width == g_texture_width && height == g_texture_height && g_flutter_texture != nil) {
        return true; // No change needed
    }

    std::cout << "Creating Metal texture: " << width << "x" << height << std::endl;

    @try {
        // Lock IOSurface mutex since we're modifying the shared IOSurface
        std::lock_guard<std::mutex> iosurface_lock(g_iosurface_mutex);

        // Release old resources
        g_flutter_texture = nil;
        if (g_io_surface != nullptr) {
            CFRelease(g_io_surface);
            g_io_surface = nullptr;
        }

        // Create IOSurface properties
        // Using BGRA8 format which is supported by both Metal and OpenGL
        // NOTE: Keep properties minimal - the system handles alignment automatically
        NSDictionary* surfaceProperties = @{
            (__bridge NSString*)kIOSurfaceWidth: @(width),
            (__bridge NSString*)kIOSurfaceHeight: @(height),
            (__bridge NSString*)kIOSurfaceBytesPerElement: @4,
        };

        g_io_surface = IOSurfaceCreate((__bridge CFDictionaryRef)surfaceProperties);
        if (g_io_surface == nullptr) {
            std::cerr << "Failed to create IOSurface - system may be low on memory" << std::endl;
            g_texture_width = 0;
            g_texture_height = 0;
            return false;
        }

        // Verify IOSurface properties
        size_t actual_width = IOSurfaceGetWidth(g_io_surface);
        size_t actual_height = IOSurfaceGetHeight(g_io_surface);
        if (actual_width != (size_t)width || actual_height != (size_t)height) {
            std::cerr << "IOSurface size mismatch: requested " << width << "x" << height
                      << " but got " << actual_width << "x" << actual_height << std::endl;
            CFRelease(g_io_surface);
            g_io_surface = nullptr;
            return false;
        }

        std::cout << "IOSurface created: ID=" << IOSurfaceGetID(g_io_surface)
                  << " size=" << actual_width << "x" << actual_height << std::endl;

        // Create Metal texture descriptor
        // NOTE: Do NOT set storageMode explicitly - when creating a texture from IOSurface,
        // the system determines the correct storage mode automatically. Setting it explicitly
        // can cause compatibility issues with OpenGL on Apple Silicon.
        MTLTextureDescriptor* textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                               width:width
                                                                                              height:height
                                                                                           mipmapped:NO];
        textureDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;

        // Create Metal texture backed by IOSurface
        g_flutter_texture = [g_metal_device newTextureWithDescriptor:textureDesc
                                                           iosurface:g_io_surface
                                                               plane:0];

        if (g_flutter_texture == nil) {
            std::cerr << "Failed to create Metal texture from IOSurface" << std::endl;
            CFRelease(g_io_surface);
            g_io_surface = nullptr;
            g_texture_width = 0;
            g_texture_height = 0;
            return false;
        }

        g_texture_width = width;
        g_texture_height = height;

        std::cout << "Metal texture created successfully: " << width << "x" << height << std::endl;
        return true;
    }
    @catch (NSException* exception) {
        std::cerr << "Exception creating Metal texture: "
                  << [[exception name] UTF8String] << " - "
                  << [[exception reason] UTF8String] << std::endl;
        // Clean up on exception
        if (g_io_surface != nullptr) {
            CFRelease(g_io_surface);
            g_io_surface = nullptr;
        }
        g_flutter_texture = nil;
        g_texture_width = 0;
        g_texture_height = 0;
        return false;
    }
}

// ==========================================================================
// Flutter Metal Callbacks
// ==========================================================================

extern "C" FlutterMetalTexture metal_renderer_get_next_drawable(void* user_data, const FlutterFrameInfo* frame_info) {
    // Return empty texture if in error state
    if (g_metal_error_state.load()) {
        FlutterMetalTexture empty = {};
        empty.struct_size = sizeof(FlutterMetalTexture);
        return empty;
    }

    std::lock_guard<std::mutex> lock(g_metal_mutex);

    // Validate frame_info
    if (frame_info == nullptr) {
        std::cerr << "metal_renderer_get_next_drawable: frame_info is null" << std::endl;
        FlutterMetalTexture empty = {};
        empty.struct_size = sizeof(FlutterMetalTexture);
        return empty;
    }

    int32_t width = static_cast<int32_t>(frame_info->size.width);
    int32_t height = static_cast<int32_t>(frame_info->size.height);

    // Validate dimensions
    if (width <= 0 || height <= 0) {
        std::cerr << "metal_renderer_get_next_drawable: invalid frame size " << width << "x" << height << std::endl;
        FlutterMetalTexture empty = {};
        empty.struct_size = sizeof(FlutterMetalTexture);
        return empty;
    }

    // Create or resize texture if needed
    if (!CreateOrResizeTexture(width, height)) {
        std::cerr << "Failed to create/resize Metal texture for Flutter" << std::endl;
        FlutterMetalTexture empty = {};
        empty.struct_size = sizeof(FlutterMetalTexture);
        return empty;
    }

    // Verify texture is valid before returning
    if (g_flutter_texture == nil) {
        std::cerr << "metal_renderer_get_next_drawable: texture is nil after creation" << std::endl;
        FlutterMetalTexture empty = {};
        empty.struct_size = sizeof(FlutterMetalTexture);
        return empty;
    }

    FlutterMetalTexture result = {};
    result.struct_size = sizeof(FlutterMetalTexture);
    result.texture = (__bridge FlutterMetalTextureHandle)g_flutter_texture;
    result.user_data = nullptr;
    result.destruction_callback = nullptr;

    return result;
}

extern "C" bool metal_renderer_present_drawable(void* user_data, const FlutterMetalTexture* texture) {
    // Validate texture parameter
    if (texture == nullptr) {
        std::cerr << "metal_renderer_present_drawable: texture is null" << std::endl;
        return false;
    }

    // Signal that a new frame is ready
    // The IOSurface is automatically synchronized, so the texture data is already
    // available for OpenGL to read
    g_frame_ready = true;
    return true;
}

// ==========================================================================
// IOSurface Sharing
// ==========================================================================

extern "C" void* metal_renderer_get_iosurface() {
    // Lock to ensure we don't get the surface while it's being replaced
    std::lock_guard<std::mutex> lock(g_iosurface_mutex);
    return g_io_surface;
}

// Thread-safe IOSurface access with dimensions - preferred for OpenGL interop
// Returns false if IOSurface is not ready
extern "C" bool metal_renderer_get_iosurface_info(void** out_surface, int32_t* out_width, int32_t* out_height) {
    std::lock_guard<std::mutex> lock(g_iosurface_mutex);

    if (g_io_surface == nullptr || g_texture_width <= 0 || g_texture_height <= 0) {
        if (out_surface) *out_surface = nullptr;
        if (out_width) *out_width = 0;
        if (out_height) *out_height = 0;
        return false;
    }

    if (out_surface) *out_surface = g_io_surface;
    if (out_width) *out_width = g_texture_width;
    if (out_height) *out_height = g_texture_height;
    return true;
}

extern "C" int32_t metal_renderer_get_texture_width() {
    return g_texture_width;
}

extern "C" int32_t metal_renderer_get_texture_height() {
    return g_texture_height;
}

extern "C" bool metal_renderer_has_new_frame() {
    bool expected = true;
    return g_frame_ready.compare_exchange_strong(expected, false);
}

extern "C" bool metal_renderer_is_initialized() {
    return g_metal_initialized.load();
}

extern "C" bool metal_renderer_has_error() {
    return g_metal_error_state.load();
}

// Clear error state to allow retry (useful if conditions may have changed)
extern "C" void metal_renderer_clear_error() {
    g_metal_error_state = false;
}

// ==========================================================================
// Window Size Updates
// ==========================================================================

extern "C" void metal_renderer_set_size(int32_t width, int32_t height) {
    std::lock_guard<std::mutex> lock(g_metal_mutex);
    g_requested_width = width;
    g_requested_height = height;
    // Texture will be recreated on next get_next_drawable call
}

// ==========================================================================
// Metal Synchronization for OpenGL Interop
// ==========================================================================

// Ensure all pending Metal work is complete before OpenGL reads the IOSurface.
// This creates and commits an empty command buffer and waits for completion,
// which acts as a fence to guarantee all previous Metal rendering is done.
extern "C" void metal_renderer_flush_and_wait() {
    if (g_metal_command_queue == nil) return;

    @autoreleasepool {
        id<MTLCommandBuffer> commandBuffer = [g_metal_command_queue commandBuffer];
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];
    }
}

#endif // __APPLE__
