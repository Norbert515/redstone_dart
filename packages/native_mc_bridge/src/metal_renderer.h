#pragma once

#include <cstdint>
#include <flutter_embedder.h>

// ==========================================================================
// Metal Renderer for Flutter on macOS
// ==========================================================================
// This provides Metal-based rendering for Flutter instead of OpenGL.
// The Flutter engine on macOS requires Metal as OpenGL is deprecated.
//
// Architecture:
// - Uses IOSurface for zero-copy sharing between Metal (Flutter) and OpenGL (Minecraft)
// - Flutter renders to a Metal texture backed by an IOSurface
// - Minecraft's OpenGL binds the same IOSurface to an OpenGL texture
// ==========================================================================

#ifdef __APPLE__

extern "C" {

// ==========================================================================
// Initialization and Cleanup
// ==========================================================================

// Initialize Metal device and command queue
// Must be called before Flutter engine is initialized
bool metal_renderer_init();

// Clean up Metal resources
void metal_renderer_shutdown();

// ==========================================================================
// Flutter Metal Callbacks
// ==========================================================================

// Get the Metal device handle for Flutter
void* metal_renderer_get_device();

// Get the Metal command queue for Flutter
void* metal_renderer_get_command_queue();

// Flutter callback: Get next drawable (texture to render to)
// Returns a FlutterMetalTexture structure
FlutterMetalTexture metal_renderer_get_next_drawable(void* user_data, const FlutterFrameInfo* frame_info);

// Flutter callback: Present drawable
// Called after Flutter finishes rendering to the texture
bool metal_renderer_present_drawable(void* user_data, const FlutterMetalTexture* texture);

// ==========================================================================
// IOSurface Sharing (for OpenGL interop)
// ==========================================================================

// Get the IOSurfaceRef for sharing with OpenGL
// Returns nullptr if no surface exists
// Note: Prefer metal_renderer_get_iosurface_info() for thread-safe access
void* metal_renderer_get_iosurface();

// Thread-safe IOSurface access with dimensions - preferred for OpenGL interop
// Returns false if IOSurface is not ready (null or invalid dimensions)
// All output parameters are optional (can be nullptr)
bool metal_renderer_get_iosurface_info(void** out_surface, int32_t* out_width, int32_t* out_height);

// Get the current texture dimensions
int32_t metal_renderer_get_texture_width();
int32_t metal_renderer_get_texture_height();

// Check if a new frame has been rendered and clear the flag
bool metal_renderer_has_new_frame();

// ==========================================================================
// Status and Error Handling
// ==========================================================================

// Check if Metal renderer is initialized and ready
bool metal_renderer_is_initialized();

// Check if Metal renderer is in an error state
bool metal_renderer_has_error();

// Clear error state to allow retry (e.g., after system changes)
void metal_renderer_clear_error();

// ==========================================================================
// Window Size Updates
// ==========================================================================

// Update the render size (triggers texture recreation if size changed)
void metal_renderer_set_size(int32_t width, int32_t height);

// ==========================================================================
// Metal Synchronization for OpenGL Interop
// ==========================================================================

// Ensure all pending Metal work is complete before OpenGL reads the IOSurface.
// Call this before CGLTexImageIOSurface2D to guarantee Metal has finished writing.
void metal_renderer_flush_and_wait();

} // extern "C"

#endif // __APPLE__
