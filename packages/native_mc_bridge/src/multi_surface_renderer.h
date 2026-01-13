#pragma once

#include <cstdint>
#include <unordered_map>
#include <mutex>
#include <atomic>
#include <flutter_embedder.h>

// ==========================================================================
// Multi-Surface Flutter Renderer
// ==========================================================================
// This module manages multiple independent Flutter surfaces (engines) that
// each render to their own texture. This is used for rendering multiple
// Flutter views simultaneously (e.g., in-world HUDs, multiple screens).
//
// Architecture:
// - Uses FlutterEngineGroup to spawn child engines (sharing GPU context/fonts)
// - Each surface has its own IOSurface (macOS) for Metal->OpenGL sharing
// - Surfaces are identified by unique int64_t IDs
//
// Note: The "main" GUI surface (surfaceId=0) continues to use the existing
// single-engine implementation in dart_bridge_client.cpp for backwards
// compatibility. This module handles additional surfaces (surfaceId > 0).
// ==========================================================================

#ifdef __APPLE__

extern "C" {

// ==========================================================================
// Surface Management
// ==========================================================================

// Create a new Flutter surface with the specified dimensions and initial route.
// Returns a unique surface ID (> 0), or 0 on failure.
// The surface renders to an IOSurface-backed texture.
int64_t multi_surface_create(int32_t width, int32_t height, const char* initial_route);

// Destroy a surface and release all associated resources.
// After this call, the surface ID is no longer valid.
void multi_surface_destroy(int64_t surface_id);

// Check if a surface exists.
bool multi_surface_exists(int64_t surface_id);

// ==========================================================================
// Surface Rendering
// ==========================================================================

// Update window metrics for a surface (triggers resize if size changed).
void multi_surface_set_size(int64_t surface_id, int32_t width, int32_t height);

// Process pending tasks for a specific surface (pumps its event loop).
void multi_surface_process_tasks(int64_t surface_id);

// Process pending tasks for ALL surfaces.
void multi_surface_process_all_tasks();

// Schedule a frame to be rendered for a surface.
void multi_surface_schedule_frame(int64_t surface_id);

// ==========================================================================
// Texture Access (for OpenGL interop)
// ==========================================================================

// Get the OpenGL texture ID for a surface (GL_TEXTURE_RECTANGLE on macOS).
// Returns 0 if no texture is available.
// The texture must be updated/bound before each use via multi_surface_update_gl_texture().
int32_t multi_surface_get_texture_id(int64_t surface_id);

// Update the OpenGL texture binding for a surface (rebinds IOSurface to GL).
// Call this before rendering if the surface may have new content.
// Returns true if successful, false on failure.
bool multi_surface_update_gl_texture(int64_t surface_id);

// Get the texture width for a surface.
int32_t multi_surface_get_texture_width(int64_t surface_id);

// Get the texture height for a surface.
int32_t multi_surface_get_texture_height(int64_t surface_id);

// Check if a surface has a new frame ready since last check.
// Clears the "new frame" flag on read.
bool multi_surface_has_new_frame(int64_t surface_id);

// ==========================================================================
// Pixel Access (for software rendering fallback)
// ==========================================================================

// Get pixel data for a surface (reads back from IOSurface).
// Returns a pointer to RGBA pixel data (width * height * 4 bytes).
// The pointer is valid until the next call to this function for the same surface.
// Returns nullptr if no frame is available.
void* multi_surface_get_pixels(int64_t surface_id);

// Get pixel dimensions (after readback).
int32_t multi_surface_get_pixel_width(int64_t surface_id);
int32_t multi_surface_get_pixel_height(int64_t surface_id);

// ==========================================================================
// Input Events
// ==========================================================================

// Send a pointer event to a specific surface.
// phase: 0=cancel, 1=up, 2=down, 3=move, 4=add, 5=remove, 6=hover
void multi_surface_send_pointer_event(int64_t surface_id, int32_t phase, double x, double y, int64_t buttons);

// Send a key event to a specific surface.
void multi_surface_send_key_event(int64_t surface_id, int32_t type, int64_t physical_key,
                                   int64_t logical_key, const char* character, int32_t modifiers);

// ==========================================================================
// Lifecycle
// ==========================================================================

// Initialize the multi-surface system.
// This should be called after the main Flutter engine is initialized.
// Uses the main engine as the parent for FlutterEngineGroup.
bool multi_surface_init();

// Shutdown the multi-surface system and destroy all surfaces.
void multi_surface_shutdown();

// Check if the multi-surface system is initialized.
bool multi_surface_is_initialized();

} // extern "C"

#endif // __APPLE__
