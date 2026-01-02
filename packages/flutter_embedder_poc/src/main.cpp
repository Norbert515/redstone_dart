/**
 * Flutter Embedder Proof of Concept
 *
 * This is a minimal embedder that renders Flutter using software rendering
 * and displays the result via OpenGL texture. This approach works on all
 * platforms and demonstrates the texture-sharing pattern needed for Minecraft.
 *
 * Key concepts:
 * 1. Creating an OpenGL context (via GLFW in this PoC)
 * 2. Initializing the Flutter Engine with Software renderer
 * 3. Receiving rendered frames as pixel buffers
 * 4. Uploading to OpenGL texture and displaying
 * 5. Forwarding input events to Flutter
 */

#include <FlutterEmbedder.h>

// Silence OpenGL deprecation warnings on macOS
#define GL_SILENCE_DEPRECATION
#include <GLFW/glfw3.h>

#include <chrono>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

// ============================================================================
// Configuration
// ============================================================================

#ifndef FLUTTER_ASSETS_PATH
#define FLUTTER_ASSETS_PATH "./flutter_app/build/flutter_assets"
#endif

#ifndef FLUTTER_ICU_DATA_PATH
#define FLUTTER_ICU_DATA_PATH ""
#endif

constexpr int kWindowWidth = 800;
constexpr int kWindowHeight = 600;
constexpr char kWindowTitle[] = "Flutter Embedder PoC";

// ============================================================================
// Global State
// ============================================================================

struct EmbedderState {
    GLFWwindow* window = nullptr;
    FlutterEngine engine = nullptr;
    double pixel_ratio = 1.0;
    int width = kWindowWidth;
    int height = kWindowHeight;

    // OpenGL texture for displaying Flutter output
    GLuint texture_id = 0;
    bool texture_dirty = false;

    // Pixel buffer received from Flutter
    std::vector<uint8_t> pixel_buffer;
    size_t buffer_width = 0;
    size_t buffer_height = 0;
};

static EmbedderState g_state;
static int64_t g_mouse_buttons = 0;
static bool g_pointer_inside = false;

// ============================================================================
// Timing
// ============================================================================

static uint64_t FlutterGetCurrentTime() {
    auto now = std::chrono::steady_clock::now();
    auto duration = now.time_since_epoch();
    return std::chrono::duration_cast<std::chrono::microseconds>(duration).count();
}

// ============================================================================
// Software Renderer Callback
// ============================================================================

/**
 * Called by Flutter when a frame is ready.
 * The allocation contains RGBA pixel data.
 */
static bool OnSoftwareSurfacePresent(void* user_data,
                                     const void* allocation,
                                     size_t row_bytes,
                                     size_t height) {
    if (!allocation || height == 0 || row_bytes == 0) {
        return false;
    }

    // Calculate width from row_bytes (RGBA = 4 bytes per pixel)
    size_t width = row_bytes / 4;

    // Copy pixel data to our buffer
    size_t buffer_size = row_bytes * height;
    g_state.pixel_buffer.resize(buffer_size);
    memcpy(g_state.pixel_buffer.data(), allocation, buffer_size);
    g_state.buffer_width = width;
    g_state.buffer_height = height;
    g_state.texture_dirty = true;

    return true;
}

// ============================================================================
// OpenGL Texture Management
// ============================================================================

static void InitializeTexture() {
    glGenTextures(1, &g_state.texture_id);
    glBindTexture(GL_TEXTURE_2D, g_state.texture_id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
}

static void UpdateTexture() {
    if (!g_state.texture_dirty || g_state.pixel_buffer.empty()) {
        return;
    }

    glBindTexture(GL_TEXTURE_2D, g_state.texture_id);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
                 static_cast<GLsizei>(g_state.buffer_width),
                 static_cast<GLsizei>(g_state.buffer_height),
                 0, GL_RGBA, GL_UNSIGNED_BYTE,
                 g_state.pixel_buffer.data());
    glBindTexture(GL_TEXTURE_2D, 0);

    g_state.texture_dirty = false;
}

static void RenderTextureToScreen() {
    if (g_state.texture_id == 0 || g_state.pixel_buffer.empty()) {
        return;
    }

    // Update texture if needed
    UpdateTexture();

    // Simple fullscreen quad rendering using fixed-function pipeline
    // (For production, you'd use shaders)
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, g_state.texture_id);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, 1, 1, 0, -1, 1);  // Flip Y for correct orientation

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glBegin(GL_QUADS);
    glTexCoord2f(0, 0); glVertex2f(0, 0);
    glTexCoord2f(1, 0); glVertex2f(1, 0);
    glTexCoord2f(1, 1); glVertex2f(1, 1);
    glTexCoord2f(0, 1); glVertex2f(0, 1);
    glEnd();

    glDisable(GL_TEXTURE_2D);
}

static void CleanupTexture() {
    if (g_state.texture_id != 0) {
        glDeleteTextures(1, &g_state.texture_id);
        g_state.texture_id = 0;
    }
}

// ============================================================================
// Window Metrics
// ============================================================================

static void SendWindowMetrics() {
    if (!g_state.engine) return;

    int fb_width, fb_height;
    glfwGetFramebufferSize(g_state.window, &fb_width, &fb_height);

    FlutterWindowMetricsEvent event = {};
    event.struct_size = sizeof(FlutterWindowMetricsEvent);
    event.width = fb_width;
    event.height = fb_height;
    event.pixel_ratio = g_state.pixel_ratio;

    FlutterEngineSendWindowMetricsEvent(g_state.engine, &event);
}

// ============================================================================
// Input Handling
// ============================================================================

static int64_t GetFlutterButton(int glfw_button) {
    switch (glfw_button) {
        case GLFW_MOUSE_BUTTON_LEFT: return 1;
        case GLFW_MOUSE_BUTTON_RIGHT: return 2;
        case GLFW_MOUSE_BUTTON_MIDDLE: return 4;
        default: return 0;
    }
}

static void SendPointerEvent(FlutterPointerPhase phase, double x, double y, int64_t buttons = 0) {
    if (!g_state.engine) return;

    FlutterPointerEvent event = {};
    event.struct_size = sizeof(FlutterPointerEvent);
    event.phase = phase;
    event.timestamp = FlutterGetCurrentTime();
    event.x = x * g_state.pixel_ratio;
    event.y = y * g_state.pixel_ratio;
    event.device = 0;
    event.signal_kind = kFlutterPointerSignalKindNone;
    event.scroll_delta_x = 0;
    event.scroll_delta_y = 0;
    event.device_kind = kFlutterPointerDeviceKindMouse;
    event.buttons = buttons;

    FlutterEngineSendPointerEvent(g_state.engine, &event, 1);
}

static void SendScrollEvent(double x, double y, double scroll_x, double scroll_y) {
    if (!g_state.engine) return;

    FlutterPointerEvent event = {};
    event.struct_size = sizeof(FlutterPointerEvent);
    event.phase = kHover;
    event.timestamp = FlutterGetCurrentTime();
    event.x = x * g_state.pixel_ratio;
    event.y = y * g_state.pixel_ratio;
    event.device = 0;
    event.signal_kind = kFlutterPointerSignalKindScroll;
    event.scroll_delta_x = scroll_x * 100;
    event.scroll_delta_y = scroll_y * 100;
    event.device_kind = kFlutterPointerDeviceKindMouse;
    event.buttons = g_mouse_buttons;

    FlutterEngineSendPointerEvent(g_state.engine, &event, 1);
}

// ============================================================================
// GLFW Callbacks
// ============================================================================

static void OnWindowResize(GLFWwindow* window, int width, int height) {
    g_state.width = width;
    g_state.height = height;
    SendWindowMetrics();
}

static void OnFramebufferResize(GLFWwindow* window, int width, int height) {
    glViewport(0, 0, width, height);
    SendWindowMetrics();
}

static void OnCursorPos(GLFWwindow* window, double x, double y) {
    if (!g_pointer_inside) {
        SendPointerEvent(kAdd, x, y);
        g_pointer_inside = true;
    }

    if (g_mouse_buttons != 0) {
        SendPointerEvent(kMove, x, y, g_mouse_buttons);
    } else {
        SendPointerEvent(kHover, x, y);
    }
}

static void OnCursorEnter(GLFWwindow* window, int entered) {
    if (!entered && g_pointer_inside) {
        double x, y;
        glfwGetCursorPos(window, &x, &y);
        SendPointerEvent(kRemove, x, y);
        g_pointer_inside = false;
    }
}

static void OnMouseButton(GLFWwindow* window, int button, int action, int mods) {
    double x, y;
    glfwGetCursorPos(window, &x, &y);

    int64_t flutter_button = GetFlutterButton(button);

    if (action == GLFW_PRESS) {
        g_mouse_buttons |= flutter_button;
        SendPointerEvent(kDown, x, y, g_mouse_buttons);
    } else if (action == GLFW_RELEASE) {
        g_mouse_buttons &= ~flutter_button;
        SendPointerEvent(kUp, x, y, g_mouse_buttons);
    }
}

static void OnScroll(GLFWwindow* window, double offset_x, double offset_y) {
    double x, y;
    glfwGetCursorPos(window, &x, &y);
    SendScrollEvent(x, y, offset_x, -offset_y);
}

static void OnKey(GLFWwindow* window, int key, int scancode, int action, int mods) {
    if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
        glfwSetWindowShouldClose(window, GLFW_TRUE);
    }
}

// ============================================================================
// Flutter Engine Setup
// ============================================================================

static bool InitializeFlutterEngine() {
    // Configure Software renderer
    FlutterRendererConfig renderer_config = {};
    renderer_config.type = kSoftware;
    renderer_config.software.struct_size = sizeof(FlutterSoftwareRendererConfig);
    renderer_config.software.surface_present_callback = OnSoftwareSurfacePresent;

    // Configure project
    std::string assets_path = FLUTTER_ASSETS_PATH;
    std::string icu_data_path = FLUTTER_ICU_DATA_PATH;

    FlutterProjectArgs project_args = {};
    project_args.struct_size = sizeof(FlutterProjectArgs);
    project_args.assets_path = assets_path.c_str();
    project_args.icu_data_path = icu_data_path.c_str();

    // Platform message callback
    project_args.platform_message_callback = [](
        const FlutterPlatformMessage* message,
        void* user_data
    ) {
        if (message->channel) {
            std::cout << "Platform message on channel: " << message->channel << std::endl;
        }
    };

    // Run the engine
    FlutterEngineResult result = FlutterEngineRun(
        FLUTTER_ENGINE_VERSION,
        &renderer_config,
        &project_args,
        nullptr,
        &g_state.engine
    );

    if (result != kSuccess) {
        std::cerr << "Failed to start Flutter engine: " << result << std::endl;
        return false;
    }

    std::cout << "Flutter engine started successfully!" << std::endl;
    return true;
}

static void ShutdownFlutterEngine() {
    if (g_state.engine) {
        FlutterEngineShutdown(g_state.engine);
        g_state.engine = nullptr;
        std::cout << "Flutter engine shut down." << std::endl;
    }
}

// ============================================================================
// Main Entry Point
// ============================================================================

int main(int argc, char* argv[]) {
    std::cout << "Flutter Embedder Proof of Concept (Software Renderer)" << std::endl;
    std::cout << "======================================================" << std::endl;

    // Initialize GLFW
    if (!glfwInit()) {
        std::cerr << "Failed to initialize GLFW" << std::endl;
        return EXIT_FAILURE;
    }

    // Request a compatibility profile for fixed-function pipeline
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);

    // Create window
    g_state.window = glfwCreateWindow(
        kWindowWidth, kWindowHeight,
        kWindowTitle,
        nullptr, nullptr
    );

    if (!g_state.window) {
        std::cerr << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return EXIT_FAILURE;
    }

    // Make context current
    glfwMakeContextCurrent(g_state.window);

    // Get pixel ratio for HiDPI displays
    float x_scale, y_scale;
    glfwGetWindowContentScale(g_state.window, &x_scale, &y_scale);
    g_state.pixel_ratio = x_scale;

    int fb_width, fb_height;
    glfwGetFramebufferSize(g_state.window, &fb_width, &fb_height);

    std::cout << "Window created: " << kWindowWidth << "x" << kWindowHeight << std::endl;
    std::cout << "Framebuffer size: " << fb_width << "x" << fb_height << std::endl;
    std::cout << "Pixel ratio: " << g_state.pixel_ratio << std::endl;
    std::cout << "Assets path: " << FLUTTER_ASSETS_PATH << std::endl;
    std::cout << "ICU data path: " << FLUTTER_ICU_DATA_PATH << std::endl;

    // Initialize OpenGL texture
    InitializeTexture();

    // Set up GLFW callbacks
    glfwSetWindowSizeCallback(g_state.window, OnWindowResize);
    glfwSetFramebufferSizeCallback(g_state.window, OnFramebufferResize);
    glfwSetCursorPosCallback(g_state.window, OnCursorPos);
    glfwSetCursorEnterCallback(g_state.window, OnCursorEnter);
    glfwSetMouseButtonCallback(g_state.window, OnMouseButton);
    glfwSetScrollCallback(g_state.window, OnScroll);
    glfwSetKeyCallback(g_state.window, OnKey);

    // Initialize Flutter engine
    if (!InitializeFlutterEngine()) {
        CleanupTexture();
        glfwDestroyWindow(g_state.window);
        glfwTerminate();
        return EXIT_FAILURE;
    }

    // Send initial window metrics
    SendWindowMetrics();

    std::cout << "Entering main loop. Press Escape to exit." << std::endl;

    // Main loop
    while (!glfwWindowShouldClose(g_state.window)) {
        // Poll for events
        glfwPollEvents();

        // Clear screen
        glClearColor(0.2f, 0.2f, 0.2f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        // Render Flutter texture to screen
        RenderTextureToScreen();

        // Swap buffers
        glfwSwapBuffers(g_state.window);
    }

    // Cleanup
    ShutdownFlutterEngine();
    CleanupTexture();
    glfwDestroyWindow(g_state.window);
    glfwTerminate();

    std::cout << "Goodbye!" << std::endl;
    return EXIT_SUCCESS;
}
