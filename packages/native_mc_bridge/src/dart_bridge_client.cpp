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
#include <atomic>

// ==========================================================================
// Renderer Headers and Platform Detection
// ==========================================================================

// Feature flag for hardware-accelerated vs software rendering
// On macOS: Metal (OpenGL is deprecated)
// On Windows/Linux: OpenGL
static bool g_use_hardware_renderer = true;

#ifdef __APPLE__
    // macOS uses Metal for Flutter rendering (OpenGL is deprecated since 2018)
    #include "metal_renderer.h"
    #define METAL_SUPPORTED 1
    #define OPENGL_SUPPORTED 0

    // Still need OpenGL headers for IOSurface -> OpenGL texture binding
    // (Minecraft uses OpenGL via LWJGL)
    #include <dlfcn.h>
    #define GL_SILENCE_DEPRECATION
    #include <OpenGL/gl3.h>
    #include <OpenGL/OpenGL.h>
    #include <OpenGL/CGLIOSurface.h>
    #include <IOSurface/IOSurface.h>

    // GL_TEXTURE_RECTANGLE and related constants are not defined in gl3.h
    // but are required for CGLTexImageIOSurface2D. Define them manually.
    #ifndef GL_TEXTURE_RECTANGLE
    #define GL_TEXTURE_RECTANGLE 0x84F5
    #endif
    #ifndef GL_BGRA
    #define GL_BGRA 0x80E1
    #endif
    #ifndef GL_UNSIGNED_INT_8_8_8_8_REV
    #define GL_UNSIGNED_INT_8_8_8_8_REV 0x8367
    #endif
#elif defined(_WIN32)
    #include <windows.h>
    #include <GL/gl.h>
    #include <GL/glext.h>
    #define OPENGL_SUPPORTED 1
    // Windows OpenGL extension function pointers
    static PFNGLGENFRAMEBUFFERSPROC glGenFramebuffers = nullptr;
    static PFNGLBINDFRAMEBUFFERPROC glBindFramebuffer = nullptr;
    static PFNGLFRAMEBUFFERTEXTURE2DPROC glFramebufferTexture2D = nullptr;
    static PFNGLCHECKFRAMEBUFFERSTATUSPROC glCheckFramebufferStatus = nullptr;
    static PFNGLDELETEFRAMEBUFFERSPROC glDeleteFramebuffers = nullptr;
#elif defined(__linux__)
    #include <GL/glx.h>
    #include <GL/gl.h>
    #define OPENGL_SUPPORTED 1
#else
    #define OPENGL_SUPPORTED 0
#endif

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
// Renderer State
// ==========================================================================

#if OPENGL_SUPPORTED
// FBO and texture for OpenGL rendering (Windows/Linux)
static GLuint g_flutter_fbo = 0;
static GLuint g_flutter_texture = 0;
static int g_texture_width = 0;
static int g_texture_height = 0;
static std::atomic<bool> g_frame_ready{false};
#endif // OPENGL_SUPPORTED

#if METAL_SUPPORTED
// macOS Metal renderer state
// The actual Metal objects are in metal_renderer.mm
// Here we just need the OpenGL texture for Minecraft to sample
static GLuint g_iosurface_gl_texture = 0;
static int g_iosurface_texture_width = 0;
static int g_iosurface_texture_height = 0;
// Track the IOSurface ID to avoid recreating texture every frame
static IOSurfaceID g_cached_iosurface_id = 0;

// Buffer for IOSurface readback (software fallback display path)
static void* g_metal_readback_buffer = nullptr;
static size_t g_metal_readback_buffer_size = 0;
static int32_t g_metal_frame_width = 0;
static int32_t g_metal_frame_height = 0;
#endif // METAL_SUPPORTED

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

    // Container lifecycle event handlers (for event-driven container open/close)
    void setContainerOpenHandler(ContainerOpenCallback cb) { container_open_handler_ = cb; }
    void setContainerCloseHandler(ContainerCloseCallback cb) { container_close_handler_ = cb; }

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

    // Container lifecycle event dispatch (for event-driven container open/close)
    void dispatchContainerOpen(int32_t menu_id, int32_t slot_count) {
        if (container_open_handler_) container_open_handler_(menu_id, slot_count);
    }

    void dispatchContainerClose(int32_t menu_id) {
        if (container_close_handler_) container_close_handler_(menu_id);
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
        container_open_handler_ = nullptr;
        container_close_handler_ = nullptr;
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
    ContainerOpenCallback container_open_handler_ = nullptr;
    ContainerCloseCallback container_close_handler_ = nullptr;
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
// OpenGL Renderer Callbacks and Helpers
// ==========================================================================

#if OPENGL_SUPPORTED

// Platform-specific GL proc resolver
static void* OnGLProcResolver(void* user_data, const char* name) {
#ifdef __APPLE__
    // macOS: Use dlsym on the OpenGL framework
    static void* lib = nullptr;
    if (!lib) {
        lib = dlopen("/System/Library/Frameworks/OpenGL.framework/OpenGL", RTLD_LAZY);
    }
    return lib ? dlsym(lib, name) : nullptr;
#elif defined(_WIN32)
    // Windows: Try wglGetProcAddress first, then opengl32.dll
    void* proc = (void*)wglGetProcAddress(name);
    if (!proc) {
        static HMODULE lib = LoadLibraryA("opengl32.dll");
        if (lib) {
            proc = (void*)GetProcAddress(lib, name);
        }
    }
    return proc;
#else
    // Linux: Use glXGetProcAddress
    return (void*)glXGetProcAddress((const GLubyte*)name);
#endif
}

// Initialize Windows OpenGL extension function pointers
#ifdef _WIN32
static bool InitWindowsGLExtensions() {
    glGenFramebuffers = (PFNGLGENFRAMEBUFFERSPROC)wglGetProcAddress("glGenFramebuffers");
    glBindFramebuffer = (PFNGLBINDFRAMEBUFFERPROC)wglGetProcAddress("glBindFramebuffer");
    glFramebufferTexture2D = (PFNGLFRAMEBUFFERTEXTURE2DPROC)wglGetProcAddress("glFramebufferTexture2D");
    glCheckFramebufferStatus = (PFNGLCHECKFRAMEBUFFERSTATUSPROC)wglGetProcAddress("glCheckFramebufferStatus");
    glDeleteFramebuffers = (PFNGLDELETEFRAMEBUFFERSPROC)wglGetProcAddress("glDeleteFramebuffers");
    return glGenFramebuffers && glBindFramebuffer && glFramebufferTexture2D &&
           glCheckFramebufferStatus && glDeleteFramebuffers;
}
#endif

// Create or resize the Flutter FBO and texture
static bool CreateOrResizeFlutterFBO(int width, int height) {
    if (width <= 0 || height <= 0) {
        return false;
    }

    // Check if resize is needed
    if (width == g_texture_width && height == g_texture_height && g_flutter_fbo != 0) {
        return true; // No change needed
    }

    std::cout << "Creating Flutter FBO: " << width << "x" << height << std::endl;

    // Delete old resources if they exist
    if (g_flutter_fbo != 0) {
        glDeleteFramebuffers(1, &g_flutter_fbo);
        g_flutter_fbo = 0;
    }
    if (g_flutter_texture != 0) {
        glDeleteTextures(1, &g_flutter_texture);
        g_flutter_texture = 0;
    }

    // Create new texture
    glGenTextures(1, &g_flutter_texture);
    glBindTexture(GL_TEXTURE_2D, g_flutter_texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    // Create FBO and attach texture
    glGenFramebuffers(1, &g_flutter_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, g_flutter_fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, g_flutter_texture, 0);

    // Verify FBO completeness
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        std::cerr << "Flutter FBO not complete! Status: " << status << std::endl;
        glDeleteFramebuffers(1, &g_flutter_fbo);
        glDeleteTextures(1, &g_flutter_texture);
        g_flutter_fbo = 0;
        g_flutter_texture = 0;
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        return false;
    }

    g_texture_width = width;
    g_texture_height = height;

    // Restore default framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);

    std::cout << "Flutter FBO created successfully: texture=" << g_flutter_texture
              << ", fbo=" << g_flutter_fbo << std::endl;
    return true;
}

// Cleanup OpenGL resources
static void CleanupFlutterGL() {
    if (g_flutter_fbo != 0) {
        glDeleteFramebuffers(1, &g_flutter_fbo);
        g_flutter_fbo = 0;
    }
    if (g_flutter_texture != 0) {
        glDeleteTextures(1, &g_flutter_texture);
        g_flutter_texture = 0;
    }
    g_texture_width = 0;
    g_texture_height = 0;
    g_frame_ready = false;
}

// Flutter OpenGL callbacks
static bool OnGLMakeCurrent(void* user_data) {
    // We're borrowing Minecraft's GL context on the render thread.
    // The context is captured lazily on first call because onInitializeClient()
    // runs BEFORE Minecraft creates its OpenGL context.
#ifdef __APPLE__
    // Lazy capture: if we don't have a stored context yet, capture it now
    if (!g_minecraft_gl_context) {
        g_minecraft_gl_context = CGLGetCurrentContext();
        if (g_minecraft_gl_context) {
            std::cout << "OpenGL context captured lazily at first render" << std::endl;
        }
    }

    if (g_minecraft_gl_context) {
        CGLError err = CGLSetCurrentContext(g_minecraft_gl_context);
        return err == kCGLNoError;
    }
    // If we still don't have a context, assume it's already current
    return true;
#elif defined(_WIN32)
    // Windows: lazily initialize GL extension functions on first render call
    static bool gl_extensions_initialized = false;
    if (!gl_extensions_initialized) {
        if (InitWindowsGLExtensions()) {
            std::cout << "Windows OpenGL extensions initialized lazily at first render" << std::endl;
            gl_extensions_initialized = true;
        } else {
            std::cerr << "Failed to initialize Windows GL extensions" << std::endl;
            return false;
        }
    }
    return true;
#else
    // On Linux/other platforms, assume context is already current
    return true;
#endif
}

static bool OnGLClearCurrent(void* user_data) {
    // Don't actually clear the context - Minecraft still needs it
    return true;
}

static uint32_t OnGLFboCallback(void* user_data) {
    // Ensure FBO exists with current dimensions
    if (g_flutter_fbo == 0) {
        int width = static_cast<int>(g_client_window_width * g_client_pixel_ratio);
        int height = static_cast<int>(g_client_window_height * g_client_pixel_ratio);
        if (!CreateOrResizeFlutterFBO(width, height)) {
            std::cerr << "Failed to create Flutter FBO in fbo_callback" << std::endl;
            return 0;
        }
    }
    return g_flutter_fbo;
}

static bool OnGLPresent(void* user_data) {
    // Signal that a new frame is ready
    g_frame_ready = true;
    return true;
}

static bool OnGLMakeResourceCurrent(void* user_data) {
    // For resource loading - we use the same context
    return OnGLMakeCurrent(user_data);
}

static FlutterTransformation OnGLSurfaceTransformation(void* user_data) {
    // Identity transformation - Flutter renders with Y-axis pointing down
    // We may need to flip this when sampling in Minecraft
    FlutterTransformation transform = {};
    transform.scaleX = 1.0;
    transform.scaleY = 1.0;
    transform.transX = 0.0;
    transform.transY = 0.0;
    transform.pers0 = 0.0;
    transform.pers1 = 0.0;
    transform.pers2 = 1.0;
    return transform;
}

#endif // OPENGL_SUPPORTED

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

    // Configure renderer based on platform
    FlutterRendererConfig renderer = {};

#if METAL_SUPPORTED
    // macOS: Use Metal renderer (OpenGL is deprecated on macOS)
    if (g_use_hardware_renderer) {
        std::cout << "  Renderer: Metal (attempting hardware acceleration)" << std::endl;

        // Initialize Metal renderer
        if (!metal_renderer_init()) {
            std::cerr << "Failed to initialize Metal renderer, falling back to software rendering" << std::endl;
            std::cerr << "  This may happen on unsupported hardware or in virtualized environments" << std::endl;
            g_use_hardware_renderer = false;
        } else {
            // Verify Metal device and command queue are valid
            void* metal_device = metal_renderer_get_device();
            void* metal_queue = metal_renderer_get_command_queue();
            if (metal_device == nullptr || metal_queue == nullptr) {
                std::cerr << "Metal renderer initialized but device/queue is null, falling back to software" << std::endl;
                metal_renderer_shutdown();
                g_use_hardware_renderer = false;
            }
        }
    }

    if (g_use_hardware_renderer) {
        std::cout << "  Using Metal hardware renderer" << std::endl;
        renderer.type = kMetal;
        renderer.metal.struct_size = sizeof(FlutterMetalRendererConfig);
        renderer.metal.device = metal_renderer_get_device();
        renderer.metal.present_command_queue = metal_renderer_get_command_queue();
        renderer.metal.get_next_drawable_callback = metal_renderer_get_next_drawable;
        renderer.metal.present_drawable_callback = metal_renderer_present_drawable;
    } else
#elif OPENGL_SUPPORTED
    // Windows/Linux: Use OpenGL renderer
    if (g_use_hardware_renderer) {
        std::cout << "  Renderer: OpenGL (context will be captured lazily at first render)" << std::endl;
        // NOTE: We don't check for or capture the OpenGL context here because
        // onInitializeClient() runs BEFORE Minecraft creates its OpenGL context.
        // The context will be captured lazily in OnGLMakeCurrent() when Flutter
        // first tries to render (at which point Minecraft's GL context exists).
    }

    if (g_use_hardware_renderer) {
        renderer.type = kOpenGL;
        renderer.open_gl.struct_size = sizeof(FlutterOpenGLRendererConfig);
        renderer.open_gl.make_current = OnGLMakeCurrent;
        renderer.open_gl.clear_current = OnGLClearCurrent;
        renderer.open_gl.fbo_callback = OnGLFboCallback;
        renderer.open_gl.present = OnGLPresent;
        renderer.open_gl.make_resource_current = OnGLMakeResourceCurrent;
        renderer.open_gl.gl_proc_resolver = OnGLProcResolver;
        renderer.open_gl.fbo_reset_after_present = true;
        renderer.open_gl.surface_transformation = OnGLSurfaceTransformation;
    } else
#endif // OPENGL_SUPPORTED
    {
        std::cout << "  Renderer: Software" << std::endl;
        renderer.type = kSoftware;
        renderer.software.struct_size = sizeof(FlutterSoftwareRendererConfig);
        renderer.software.surface_present_callback = OnClientSoftwareSurfacePresent;
    }

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

#if METAL_SUPPORTED
    // Cleanup Metal resources
    std::cout << "Client shutdown: cleaning up Metal resources..." << std::endl;
    metal_renderer_shutdown();
    if (g_iosurface_gl_texture != 0) {
        glDeleteTextures(1, &g_iosurface_gl_texture);
        g_iosurface_gl_texture = 0;
    }
    g_iosurface_texture_width = 0;
    g_iosurface_texture_height = 0;
    g_cached_iosurface_id = 0;

    // Cleanup Metal readback buffer
    if (g_metal_readback_buffer) {
        free(g_metal_readback_buffer);
        g_metal_readback_buffer = nullptr;
        g_metal_readback_buffer_size = 0;
    }
    g_metal_frame_width = 0;
    g_metal_frame_height = 0;
#elif OPENGL_SUPPORTED
    // Cleanup OpenGL resources
    std::cout << "Client shutdown: cleaning up OpenGL resources..." << std::endl;
    CleanupFlutterGL();
#endif

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
    // Also initialize generic_jni so Flutter can call Java methods via JNI
    // This shares the same JVM with the server runtime - both should use the same g_jvm
    extern void generic_jni_init(JavaVM* jvm);
    generic_jni_init(jvm);
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

#if OPENGL_SUPPORTED
    // Resize FBO if using OpenGL and dimensions changed
    if (g_use_opengl_renderer) {
        int tex_width = static_cast<int>(width * pixel_ratio);
        int tex_height = static_cast<int>(height * pixel_ratio);
        if (tex_width != g_texture_width || tex_height != g_texture_height) {
            CreateOrResizeFlutterFBO(tex_width, tex_height);
        }
    }
#endif

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

// Container lifecycle event callback registration
void client_register_container_open_handler(ContainerOpenCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setContainerOpenHandler(cb); }
void client_register_container_close_handler(ContainerCloseCallback cb) { dart_mc_bridge::ClientCallbackRegistry::instance().setContainerCloseHandler(cb); }

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

// Container lifecycle event dispatch (for event-driven container open/close)
void client_dispatch_container_open(int32_t menu_id, int32_t slot_count) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchContainerOpen(menu_id, slot_count);
}

void client_dispatch_container_close(int32_t menu_id) {
    CLIENT_DISPATCH_CHECK();
    dart_mc_bridge::ClientCallbackRegistry::instance().dispatchContainerClose(menu_id);
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

// ==========================================================================
// Slot Position Reporting (Flutter -> Java)
// ==========================================================================

void client_update_slot_positions(int32_t menu_id, const int32_t* data, int32_t data_length) {
    if (!g_client_initialized || g_client_jvm_ref == nullptr) return;

    JNIEnv* env = nullptr;
    bool needs_detach = false;

    int status = g_client_jvm_ref->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_8);
    if (status == JNI_EDETACHED) {
        if (g_client_jvm_ref->AttachCurrentThread(reinterpret_cast<void**>(&env), nullptr) != JNI_OK) {
            return;
        }
        needs_detach = true;
    }

    if (env == nullptr) {
        if (needs_detach) g_client_jvm_ref->DetachCurrentThread();
        return;
    }

    // Find the DartBridgeClient class and method
    jclass bridgeClass = env->FindClass("com/redstone/DartBridgeClient");
    if (bridgeClass == nullptr) {
        env->ExceptionClear();
        if (needs_detach) g_client_jvm_ref->DetachCurrentThread();
        return;
    }

    jmethodID method = env->GetStaticMethodID(bridgeClass, "onSlotPositionsUpdate", "(I[I)V");
    if (method == nullptr) {
        env->ExceptionClear();
        env->DeleteLocalRef(bridgeClass);
        if (needs_detach) g_client_jvm_ref->DetachCurrentThread();
        return;
    }

    // Create Java int array from data
    jintArray jdata = env->NewIntArray(data_length);
    if (jdata != nullptr) {
        env->SetIntArrayRegion(jdata, 0, data_length, reinterpret_cast<const jint*>(data));
        env->CallStaticVoidMethod(bridgeClass, method, menu_id, jdata);
        env->DeleteLocalRef(jdata);
    }

    env->DeleteLocalRef(bridgeClass);
    if (needs_detach) g_client_jvm_ref->DetachCurrentThread();
}

// ==========================================================================
// Texture Access Functions (for Java/Minecraft to sample Flutter output)
// ==========================================================================

#if METAL_SUPPORTED
// Track consecutive failures to avoid spamming logs
static int g_iosurface_bind_failures = 0;
static constexpr int MAX_BIND_FAILURE_LOGS = 5;

// Helper: Get CGL error string for better diagnostics
// Named differently from system's CGLErrorString to avoid conflicts
static const char* GetCGLErrorDescription(CGLError err) {
    switch (err) {
        case kCGLNoError: return "No error";
        case kCGLBadAttribute: return "Invalid attribute";
        case kCGLBadProperty: return "Invalid property";
        case kCGLBadPixelFormat: return "Invalid pixel format";
        case kCGLBadRendererInfo: return "Invalid renderer info";
        case kCGLBadContext: return "Invalid context";
        case kCGLBadDrawable: return "Invalid drawable";
        case kCGLBadDisplay: return "Invalid display";
        case kCGLBadState: return "Invalid state";
        case kCGLBadValue: return "Invalid value";
        case kCGLBadMatch: return "Invalid match";
        case kCGLBadEnumeration: return "Invalid enumeration";
        case kCGLBadOffScreen: return "Invalid off-screen";
        case kCGLBadFullScreen: return "Invalid full-screen";
        case kCGLBadWindow: return "Invalid window";
        case kCGLBadAddress: return "Invalid address";
        case kCGLBadCodeModule: return "Invalid code module";
        case kCGLBadAlloc: return "Memory allocation failed";
        case kCGLBadConnection: return "Invalid connection";
        default: return "Unknown error";
    }
}

// Helper: Check for OpenGL errors and log them
static bool CheckGLError(const char* operation) {
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        if (g_iosurface_bind_failures < MAX_BIND_FAILURE_LOGS) {
            std::cerr << "OpenGL error during " << operation << ": 0x" << std::hex << err << std::dec << std::endl;
        }
        return false;
    }
    return true;
}

// Helper: Create/update OpenGL texture from IOSurface
// This is called from the render thread when Minecraft needs to sample the Flutter texture
//
// IMPORTANT: CGLTexImageIOSurface2D REQUIRES GL_TEXTURE_RECTANGLE as the target.
// It returns kCGLBadValue (error 10008) with GL_TEXTURE_2D.
// GL_TEXTURE_RECTANGLE uses pixel coordinates (0 to width/height) not normalized (0 to 1).
static bool UpdateIOSurfaceGLTexture() {
    // Check if Metal renderer is in error state
    if (metal_renderer_has_error()) {
        if (g_iosurface_bind_failures == 0) {
            std::cerr << "UpdateIOSurfaceGLTexture: Metal renderer is in error state" << std::endl;
        }
        g_iosurface_bind_failures++;
        return false;
    }

    // Use thread-safe API to get IOSurface info atomically
    void* surface_ptr = nullptr;
    int32_t width = 0;
    int32_t height = 0;

    if (!metal_renderer_get_iosurface_info(&surface_ptr, &width, &height)) {
        // IOSurface not ready yet - this is normal during startup
        static bool logged_waiting = false;
        if (!logged_waiting) {
            std::cout << "UpdateIOSurfaceGLTexture: Waiting for IOSurface to be ready..." << std::endl;
            logged_waiting = true;
        }
        return false;
    }

    IOSurfaceRef surface = (IOSurfaceRef)surface_ptr;

    // Validate dimensions (should be guaranteed by metal_renderer_get_iosurface_info, but double-check)
    if (width <= 0 || height <= 0) {
        if (g_iosurface_bind_failures < MAX_BIND_FAILURE_LOGS) {
            std::cerr << "UpdateIOSurfaceGLTexture: Invalid dimensions " << width << "x" << height << std::endl;
        }
        g_iosurface_bind_failures++;
        return false;
    }

    // Get IOSurface ID for logging
    IOSurfaceID currentId = IOSurfaceGetID(surface);

    // Always rebind the IOSurface to ensure fresh texture data each frame.
    // Caching was causing "unloadable" texture errors on macOS Apple Silicon
    // where the cached IOSurface-backed GL_TEXTURE_RECTANGLE would become stale.

    // Only log when dimensions change to avoid spam
    static int32_t last_logged_width = 0;
    static int32_t last_logged_height = 0;
    if (width != last_logged_width || height != last_logged_height) {
        std::cout << "UpdateIOSurfaceGLTexture: Rebinding GL texture from IOSurface "
              << width << "x" << height << " (ID: " << currentId << ")" << std::endl;
        last_logged_width = width;
        last_logged_height = height;
    }

    // Clear any pending GL errors before we start
    while (glGetError() != GL_NO_ERROR) {}

    // Delete old texture if exists
    if (g_iosurface_gl_texture != 0) {
        glDeleteTextures(1, &g_iosurface_gl_texture);
        g_iosurface_gl_texture = 0;
        g_cached_iosurface_id = 0;
    }

    // Get current CGL context
    CGLContextObj cglContext = CGLGetCurrentContext();
    if (cglContext == nullptr) {
        if (g_iosurface_bind_failures < MAX_BIND_FAILURE_LOGS) {
            std::cerr << "UpdateIOSurfaceGLTexture: No CGL context available" << std::endl;
            std::cerr << "  This may happen if called from wrong thread or before Minecraft creates GL context" << std::endl;
        }
        g_iosurface_bind_failures++;
        return false;
    }

    // GL_TEXTURE_RECTANGLE is core in OpenGL 3.1+
    // On macOS with Core Profile 4.1 (which Minecraft uses), it's always available.
    // Skip extension check since glGetString(GL_EXTENSIONS) doesn't work in Core Profile
    // and would generate GL_INVALID_ENUM errors.

    // Create new OpenGL texture
    glGenTextures(1, &g_iosurface_gl_texture);
    if (!CheckGLError("glGenTextures") || g_iosurface_gl_texture == 0) {
        g_iosurface_bind_failures++;
        return false;
    }

    // CGLTexImageIOSurface2D REQUIRES GL_TEXTURE_RECTANGLE - it returns kCGLBadValue with GL_TEXTURE_2D
    glBindTexture(GL_TEXTURE_RECTANGLE, g_iosurface_gl_texture);
    if (!CheckGLError("glBindTexture GL_TEXTURE_RECTANGLE")) {
        glDeleteTextures(1, &g_iosurface_gl_texture);
        g_iosurface_gl_texture = 0;
        g_iosurface_bind_failures++;
        return false;
    }

    // Verify IOSurface is still valid before binding
    // (it could have been released between getting info and now)
    size_t surface_width = IOSurfaceGetWidth(surface);
    size_t surface_height = IOSurfaceGetHeight(surface);
    if (surface_width == 0 || surface_height == 0) {
        if (g_iosurface_bind_failures < MAX_BIND_FAILURE_LOGS) {
            std::cerr << "UpdateIOSurfaceGLTexture: IOSurface became invalid" << std::endl;
        }
        glBindTexture(GL_TEXTURE_RECTANGLE, 0);
        glDeleteTextures(1, &g_iosurface_gl_texture);
        g_iosurface_gl_texture = 0;
        g_iosurface_bind_failures++;
        return false;
    }

    // Pre-flight checks before CGLTexImageIOSurface2D
    // 1. Verify the CGL context is valid and current
    CGLContextObj currentContext = CGLGetCurrentContext();
    if (currentContext != cglContext) {
        if (g_iosurface_bind_failures < MAX_BIND_FAILURE_LOGS) {
            std::cerr << "UpdateIOSurfaceGLTexture: Context mismatch! Expected " << cglContext
                      << " but current is " << currentContext << std::endl;
        }
        glBindTexture(GL_TEXTURE_RECTANGLE, 0);
        glDeleteTextures(1, &g_iosurface_gl_texture);
        g_iosurface_gl_texture = 0;
        g_iosurface_bind_failures++;
        return false;
    }

    // 2. Log OpenGL version/profile for diagnostics (only on first success or after failures)
    static bool logged_gl_info = false;
    if (!logged_gl_info || g_iosurface_bind_failures > 0) {
        const GLubyte* version = glGetString(GL_VERSION);
        const GLubyte* renderer = glGetString(GL_RENDERER);
        std::cout << "UpdateIOSurfaceGLTexture: GL Version: " << (version ? (const char*)version : "unknown")
                  << ", Renderer: " << (renderer ? (const char*)renderer : "unknown") << std::endl;
        logged_gl_info = true;
    }

    // Ensure Metal has finished writing to the IOSurface before OpenGL reads it
    metal_renderer_flush_and_wait();

    // Bind IOSurface to OpenGL texture using CGLTexImageIOSurface2D
    // MUST use GL_TEXTURE_RECTANGLE - GL_TEXTURE_2D returns kCGLBadValue
    CGLError err = CGLTexImageIOSurface2D(
        cglContext,
        GL_TEXTURE_RECTANGLE,  // REQUIRED - GL_TEXTURE_2D returns kCGLBadValue
        GL_RGBA8,
        width,
        height,
        GL_BGRA,
        GL_UNSIGNED_INT_8_8_8_8_REV,
        surface,
        0  // plane
    );

    if (err != kCGLNoError) {
        if (g_iosurface_bind_failures < MAX_BIND_FAILURE_LOGS) {
            std::cerr << "CGLTexImageIOSurface2D failed: " << GetCGLErrorDescription(err)
                      << " (error code: " << err << ")" << std::endl;

            // Additional diagnostics
            if (err == kCGLBadMatch) {
                std::cerr << "  Possible causes: format mismatch between IOSurface and GL texture" << std::endl;
                std::cerr << "  IOSurface format: " << IOSurfaceGetPixelFormat(surface) << std::endl;
                std::cerr << "  IOSurface dimensions: " << surface_width << "x" << surface_height << std::endl;
            } else if (err == kCGLBadContext) {
                std::cerr << "  The CGL context may be invalid or not current" << std::endl;
            } else if (err == kCGLBadAlloc) {
                std::cerr << "  Memory allocation failed - system may be low on VRAM" << std::endl;
            } else if (err == kCGLBadValue) {
                std::cerr << "  Invalid value - this usually means wrong texture target (must be GL_TEXTURE_RECTANGLE)" << std::endl;
            }
        }
        glBindTexture(GL_TEXTURE_RECTANGLE, 0);
        glDeleteTextures(1, &g_iosurface_gl_texture);
        g_iosurface_gl_texture = 0;
        g_iosurface_bind_failures++;
        return false;
    }

    // Check for GL errors after CGL call
    if (!CheckGLError("CGLTexImageIOSurface2D")) {
        glBindTexture(GL_TEXTURE_RECTANGLE, 0);
        glDeleteTextures(1, &g_iosurface_gl_texture);
        g_iosurface_gl_texture = 0;
        g_iosurface_bind_failures++;
        return false;
    }

    // Set texture parameters for GL_TEXTURE_RECTANGLE
    // Note: GL_TEXTURE_RECTANGLE doesn't support mipmaps or repeat wrap modes
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    if (!CheckGLError("glTexParameteri")) {
        // Non-fatal, texture may still work
        std::cerr << "Warning: Failed to set texture parameters" << std::endl;
    }

    // Ensure Metal render is complete before OpenGL can read the texture.
    // This synchronizes the IOSurface between Metal and OpenGL contexts.
    glFlush();

    glBindTexture(GL_TEXTURE_RECTANGLE, 0);

    g_iosurface_texture_width = width;
    g_iosurface_texture_height = height;
    g_cached_iosurface_id = currentId;

    // Reset failure counter on success
    g_iosurface_bind_failures = 0;

    return true;
}
#endif // METAL_SUPPORTED

int32_t dart_client_get_flutter_texture_id() {
#if METAL_SUPPORTED
    if (g_use_hardware_renderer) {
        // Ensure IOSurface-backed GL texture exists
        if (!UpdateIOSurfaceGLTexture()) {
            return 0;
        }
        return static_cast<int32_t>(g_iosurface_gl_texture);
    }
#elif OPENGL_SUPPORTED
    if (g_use_hardware_renderer) {
        return static_cast<int32_t>(g_flutter_texture);
    }
#endif
    return 0;
}

int32_t dart_client_get_texture_width() {
#if METAL_SUPPORTED
    if (g_use_hardware_renderer) {
        return metal_renderer_get_texture_width();
    }
#elif OPENGL_SUPPORTED
    if (g_use_hardware_renderer) {
        return static_cast<int32_t>(g_texture_width);
    }
#endif
    return 0;
}

int32_t dart_client_get_texture_height() {
#if METAL_SUPPORTED
    if (g_use_hardware_renderer) {
        return metal_renderer_get_texture_height();
    }
#elif OPENGL_SUPPORTED
    if (g_use_hardware_renderer) {
        return static_cast<int32_t>(g_texture_height);
    }
#endif
    return 0;
}

bool dart_client_has_new_frame() {
#if METAL_SUPPORTED
    if (g_use_hardware_renderer) {
        return metal_renderer_has_new_frame();
    }
#elif OPENGL_SUPPORTED
    if (g_use_hardware_renderer) {
        bool expected = true;
        return g_frame_ready.compare_exchange_strong(expected, false);
    }
#endif
    return false;
}

bool dart_client_is_opengl_renderer() {
    // This now returns true if hardware rendering is enabled
    // (Metal on macOS, OpenGL on Windows/Linux)
#if METAL_SUPPORTED || OPENGL_SUPPORTED
    return g_use_hardware_renderer;
#else
    return false;
#endif
}

void dart_client_set_opengl_enabled(bool enabled) {
#if METAL_SUPPORTED || OPENGL_SUPPORTED
    g_use_hardware_renderer = enabled;
#endif
}

// Check if using Metal renderer (macOS only)
bool dart_client_is_metal_renderer() {
#if METAL_SUPPORTED
    return g_use_hardware_renderer;
#else
    return false;
#endif
}

// Get the IOSurface ID for sharing (macOS only, for debugging)
uint32_t dart_client_get_iosurface_id() {
#if METAL_SUPPORTED
    IOSurfaceRef surface = (IOSurfaceRef)metal_renderer_get_iosurface();
    if (surface != nullptr) {
        return IOSurfaceGetID(surface);
    }
#endif
    return 0;
}

// ==========================================================================
// Frame Pixel Access (for software fallback display path)
// ==========================================================================

void* dart_client_get_frame_pixels() {
#if METAL_SUPPORTED
    if (g_use_hardware_renderer) {
        // Read back from IOSurface for the software display fallback
        void* surface = nullptr;
        int32_t width = 0;
        int32_t height = 0;

        if (!metal_renderer_get_iosurface_info(&surface, &width, &height)) {
            return nullptr;
        }

        IOSurfaceRef ioSurface = (IOSurfaceRef)surface;

        // Lock for CPU read
        IOReturn lockResult = IOSurfaceLock(ioSurface, kIOSurfaceLockReadOnly, nullptr);
        if (lockResult != kIOReturnSuccess) {
            std::cerr << "Failed to lock IOSurface for read: " << lockResult << std::endl;
            return nullptr;
        }

        // Get pixel data
        void* baseAddress = IOSurfaceGetBaseAddress(ioSurface);
        size_t bytesPerRow = IOSurfaceGetBytesPerRow(ioSurface);

        // Ensure our buffer is big enough
        size_t requiredSize = bytesPerRow * height;
        if (g_metal_readback_buffer_size < requiredSize) {
            if (g_metal_readback_buffer) {
                free(g_metal_readback_buffer);
            }
            g_metal_readback_buffer = malloc(requiredSize);
            g_metal_readback_buffer_size = requiredSize;
        }

        // Copy the pixels
        if (g_metal_readback_buffer && baseAddress) {
            memcpy(g_metal_readback_buffer, baseAddress, requiredSize);
        }

        // Update dimensions
        g_metal_frame_width = width;
        g_metal_frame_height = height;

        // Unlock
        IOSurfaceUnlock(ioSurface, kIOSurfaceLockReadOnly, nullptr);

        return g_metal_readback_buffer;
    }
#endif
    // Software path - pixels are delivered via the frame callback to jni_interface_client.cpp
    // Return nullptr here since the JNI layer handles its own buffer
    return nullptr;
}

int32_t dart_client_get_frame_width() {
#if METAL_SUPPORTED
    if (g_use_hardware_renderer) {
        return metal_renderer_get_texture_width();
    }
#endif
    // Software path - JNI layer tracks this itself
    return 0;
}

int32_t dart_client_get_frame_height() {
#if METAL_SUPPORTED
    if (g_use_hardware_renderer) {
        return metal_renderer_get_texture_height();
    }
#endif
    // Software path - JNI layer tracks this itself
    return 0;
}

} // extern "C"
