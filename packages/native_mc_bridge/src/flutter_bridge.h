#pragma once

#include <cstdint>
#include <cstddef>

extern "C" {
    // Lifecycle - called from Java via JNI
    bool flutter_bridge_init(const char* assets_path, const char* icu_data_path);
    void flutter_bridge_shutdown();

    // Rendering - called from render thread
    void flutter_bridge_resize(int width, int height, double pixel_ratio);
    void flutter_bridge_render_frame();

    // Get pixel buffer for texture upload (software renderer approach)
    // Returns pointer to RGBA pixel data, sets width/height
    const void* flutter_bridge_get_pixels(size_t* width, size_t* height, size_t* row_bytes);
    bool flutter_bridge_has_new_frame();

    // Input events
    void flutter_bridge_send_pointer_event(int phase, double x, double y, int64_t buttons);
    void flutter_bridge_send_scroll_event(double x, double y, double scroll_x, double scroll_y);

    // State queries
    bool flutter_bridge_is_initialized();

    // Subprocess mode configuration
    // Set the path to the flutter_renderer executable (must be called before init)
    void flutter_bridge_set_renderer_path(const char* path);
    // Check if the renderer subprocess is still running
    bool flutter_bridge_is_renderer_running();
}
