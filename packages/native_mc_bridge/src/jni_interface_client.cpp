// ==========================================================================
// Client-side JNI Interface
// ==========================================================================
// This file contains all JNI functions for Java_com_redstone_DartBridgeClient_*
// (client-side operations).
//
// COMPILE-TIME SAFETY: Only dart_bridge_client.h is included, making it
// impossible to accidentally call server functions.
// ==========================================================================

#include "dart_bridge_client.h"  // Client functions ONLY - no dart_bridge.h!
#include "generic_jni.h"          // For generic_jni_capture_classloader

#ifdef __APPLE__
#include "multi_surface_renderer.h"  // Multi-surface support (macOS only)
#endif

#include <jni.h>
#include <iostream>
#include <mutex>
#include <vector>
#include <cstring>

// JNI function naming convention:
// Java_<package>_<class>_<method>
// Package: com.redstone
// Class: DartBridgeClient (client-side)

// External JVM getter from server file
extern JavaVM* jni_get_jvm();

// ==========================================================================
// Frame Buffer Storage (for Flutter rendering)
// ==========================================================================

static std::mutex g_frame_mutex;
static std::vector<uint8_t> g_frame_buffer;
static size_t g_frame_width = 0;
static size_t g_frame_height = 0;
static bool g_has_new_frame = false;

// Frame callback that stores pixels for Java to retrieve
static void jni_frame_callback(const void* pixels, size_t width, size_t height, size_t row_bytes) {
    std::lock_guard<std::mutex> lock(g_frame_mutex);

    size_t size = height * row_bytes;
    if (g_frame_buffer.size() != size) {
        g_frame_buffer.resize(size);
    }

    memcpy(g_frame_buffer.data(), pixels, size);
    g_frame_width = width;
    g_frame_height = height;
    g_has_new_frame = true;
}

extern "C" {

// ==========================================================================
// Client Lifecycle JNI Entry Points
// ==========================================================================

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    initClient
 * Signature: (Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Z
 *
 * Initialize the client-side Flutter runtime.
 * @param assets_path Path to Flutter app assets (flutter_assets directory)
 * @param icu_data_path Path to icudtl.dat file
 * @param aot_library_path Path to AOT compiled library (can be null for JIT mode)
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_initClient(
    JNIEnv* env, jclass /* cls */,
    jstring assets_path, jstring icu_data_path, jstring aot_library_path) {

    // Capture JVM reference
    JavaVM* jvm = jni_get_jvm();
    if (jvm == nullptr) {
        env->GetJavaVM(&jvm);
    }
    dart_client_set_jvm(jvm);

    // Register the frame callback before initializing
    dart_client_set_frame_callback(jni_frame_callback);

    const char* assets = assets_path ? env->GetStringUTFChars(assets_path, nullptr) : nullptr;
    const char* icu = icu_data_path ? env->GetStringUTFChars(icu_data_path, nullptr) : nullptr;
    const char* aot = aot_library_path ? env->GetStringUTFChars(aot_library_path, nullptr) : nullptr;

    if (!assets) {
        std::cerr << "JNI: Failed to get assets path string for client" << std::endl;
        return JNI_FALSE;
    }

    bool result = dart_client_init(assets, icu, aot);

    env->ReleaseStringUTFChars(assets_path, assets);
    if (icu) env->ReleaseStringUTFChars(icu_data_path, icu);
    if (aot) env->ReleaseStringUTFChars(aot_library_path, aot);

    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    shutdownClient
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_shutdownClient(
    JNIEnv* /* env */, jclass /* cls */) {
    dart_client_shutdown();
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    processClientTasks
 * Signature: ()V
 *
 * Process pending Flutter tasks (pump the event loop)
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_processClientTasks(
    JNIEnv* /* env */, jclass /* cls */) {
    dart_client_process_tasks();
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getClientServiceUrl
 * Signature: ()Ljava/lang/String;
 *
 * Get the Flutter VM service URL for client-side hot reload/debugging.
 */
JNIEXPORT jstring JNICALL Java_com_redstone_DartBridgeClient_getClientServiceUrl(
    JNIEnv* env, jclass /* cls */) {
    const char* url = dart_client_get_service_url();
    if (url != nullptr) {
        return env->NewStringUTF(url);
    }
    return nullptr;
}

// ==========================================================================
// Flutter Rendering JNI Entry Points
// ==========================================================================

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getFramePixels
 * Signature: ()Ljava/nio/ByteBuffer;
 *
 * Returns a direct ByteBuffer containing the latest frame pixels (RGBA).
 * When Metal rendering is active, this reads back from the IOSurface.
 */
JNIEXPORT jobject JNICALL Java_com_redstone_DartBridgeClient_getFramePixels(
    JNIEnv* env, jclass /* cls */) {

    // Check if using hardware renderer (Metal on macOS)
    if (dart_client_is_opengl_renderer()) {
        // Metal/hardware path - read back from IOSurface
        void* pixels = dart_client_get_frame_pixels();
        if (pixels == nullptr) {
            return nullptr;
        }

        int32_t width = dart_client_get_frame_width();
        int32_t height = dart_client_get_frame_height();
        if (width <= 0 || height <= 0) {
            return nullptr;
        }

        // Calculate buffer size (4 bytes per pixel for RGBA/BGRA)
        // Note: IOSurface may have padding, so we use bytesPerRow from the surface
        // For simplicity, assume 4 * width as the row stride
        size_t size = static_cast<size_t>(width) * static_cast<size_t>(height) * 4;

        return env->NewDirectByteBuffer(pixels, static_cast<jlong>(size));
    }

    // Software renderer path - use local buffer
    std::lock_guard<std::mutex> lock(g_frame_mutex);

    if (g_frame_buffer.empty() || g_frame_width == 0 || g_frame_height == 0) {
        return nullptr;
    }

    // Create a direct ByteBuffer wrapping the frame data
    // Note: This buffer is only valid until the next frame callback
    return env->NewDirectByteBuffer(g_frame_buffer.data(), g_frame_buffer.size());
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getFrameWidth
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridgeClient_getFrameWidth(
    JNIEnv* /* env */, jclass /* cls */) {

    // Check if using hardware renderer (Metal on macOS)
    if (dart_client_is_opengl_renderer()) {
        return static_cast<jint>(dart_client_get_frame_width());
    }

    // Software renderer path
    std::lock_guard<std::mutex> lock(g_frame_mutex);
    return static_cast<jint>(g_frame_width);
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getFrameHeight
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridgeClient_getFrameHeight(
    JNIEnv* /* env */, jclass /* cls */) {

    // Check if using hardware renderer (Metal on macOS)
    if (dart_client_is_opengl_renderer()) {
        return static_cast<jint>(dart_client_get_frame_height());
    }

    // Software renderer path
    std::lock_guard<std::mutex> lock(g_frame_mutex);
    return static_cast<jint>(g_frame_height);
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    hasNewFrame
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_hasNewFrame(
    JNIEnv* /* env */, jclass /* cls */) {

    // Check if using OpenGL renderer first
    if (dart_client_is_opengl_renderer()) {
        return dart_client_has_new_frame() ? JNI_TRUE : JNI_FALSE;
    }

    // Software renderer path
    std::lock_guard<std::mutex> lock(g_frame_mutex);
    bool result = g_has_new_frame;
    g_has_new_frame = false;  // Clear the flag after reading
    return result ? JNI_TRUE : JNI_FALSE;
}

// ==========================================================================
// OpenGL Texture Access JNI Entry Points
// ==========================================================================

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getFlutterTextureId
 * Signature: ()I
 *
 * Get the OpenGL texture ID for Flutter's rendered output.
 * Returns 0 if OpenGL rendering is not enabled or no texture exists.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridgeClient_getFlutterTextureId(
    JNIEnv* /* env */, jclass /* cls */) {
    return static_cast<jint>(dart_client_get_flutter_texture_id());
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getFlutterTextureWidth
 * Signature: ()I
 *
 * Get the width of the Flutter texture in pixels.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridgeClient_getFlutterTextureWidth(
    JNIEnv* /* env */, jclass /* cls */) {
    return static_cast<jint>(dart_client_get_texture_width());
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getFlutterTextureHeight
 * Signature: ()I
 *
 * Get the height of the Flutter texture in pixels.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridgeClient_getFlutterTextureHeight(
    JNIEnv* /* env */, jclass /* cls */) {
    return static_cast<jint>(dart_client_get_texture_height());
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    isOpenGLRenderer
 * Signature: ()Z
 *
 * Check if OpenGL rendering is enabled.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_isOpenGLRenderer(
    JNIEnv* /* env */, jclass /* cls */) {
    return dart_client_is_opengl_renderer() ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    setOpenGLEnabled
 * Signature: (Z)V
 *
 * Enable or disable hardware-accelerated rendering (must be called before initClient).
 * On macOS, this controls Metal rendering. On Windows/Linux, this controls OpenGL.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_setOpenGLEnabled(
    JNIEnv* /* env */, jclass /* cls */, jboolean enabled) {
    dart_client_set_opengl_enabled(enabled == JNI_TRUE);
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    isMetalRenderer
 * Signature: ()Z
 *
 * Check if Metal rendering is being used (macOS only).
 * Metal textures are shared via IOSurface and use GL_TEXTURE_RECTANGLE.
 * Returns false on Windows/Linux (which use regular OpenGL).
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_isMetalRenderer(
    JNIEnv* /* env */, jclass /* cls */) {
    return dart_client_is_metal_renderer() ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    sendWindowMetrics
 * Signature: (IID)V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_sendWindowMetrics(
    JNIEnv* /* env */, jclass /* cls */,
    jint width, jint height, jdouble pixelRatio) {

    dart_client_send_window_metrics(
        static_cast<int32_t>(width),
        static_cast<int32_t>(height),
        static_cast<double>(pixelRatio)
    );
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    sendPointerEvent
 * Signature: (IDDJ)V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_sendPointerEvent(
    JNIEnv* /* env */, jclass /* cls */,
    jint phase, jdouble x, jdouble y, jlong buttons) {

    dart_client_send_pointer_event(
        static_cast<int32_t>(phase),
        static_cast<double>(x),
        static_cast<double>(y),
        static_cast<int64_t>(buttons)
    );
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    sendKeyEvent
 * Signature: (IJJLjava/lang/String;I)V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_sendKeyEvent(
    JNIEnv* env, jclass /* cls */,
    jint type, jlong physicalKey, jlong logicalKey, jstring characters, jint modifiers) {

    const char* chars = characters ? env->GetStringUTFChars(characters, nullptr) : nullptr;

    dart_client_send_key_event(
        static_cast<int32_t>(type),
        static_cast<int64_t>(physicalKey),
        static_cast<int64_t>(logicalKey),
        chars,
        static_cast<int32_t>(modifiers)
    );

    if (chars) {
        env->ReleaseStringUTFChars(characters, chars);
    }
}

// ==========================================================================
// Client-side Screen Event Dispatching
// ==========================================================================

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    onClientScreenInit
 * Signature: (JII)V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_onClientScreenInit(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jint width, jint height) {
    client_dispatch_screen_init(static_cast<int64_t>(screenId),
                                 static_cast<int32_t>(width),
                                 static_cast<int32_t>(height));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    onClientScreenTick
 * Signature: (J)V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_onClientScreenTick(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId) {
    client_dispatch_screen_tick(static_cast<int64_t>(screenId));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    onClientScreenRender
 * Signature: (JIIF)V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_onClientScreenRender(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jint mouseX, jint mouseY, jfloat partialTick) {
    client_dispatch_screen_render(static_cast<int64_t>(screenId),
                                   static_cast<int32_t>(mouseX),
                                   static_cast<int32_t>(mouseY),
                                   static_cast<float>(partialTick));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    onClientScreenClose
 * Signature: (J)V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_onClientScreenClose(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId) {
    client_dispatch_screen_close(static_cast<int64_t>(screenId));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    onClientScreenMouseClicked
 * Signature: (JDDI)Z
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_onClientScreenMouseClicked(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jdouble mouseX, jdouble mouseY, jint button) {
    bool result = client_dispatch_screen_mouse_clicked(static_cast<int64_t>(screenId),
                                                        static_cast<double>(mouseX),
                                                        static_cast<double>(mouseY),
                                                        static_cast<int32_t>(button));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    onClientScreenKeyPressed
 * Signature: (JIII)Z
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_onClientScreenKeyPressed(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jint keyCode, jint scanCode, jint modifiers) {
    bool result = client_dispatch_screen_key_pressed(static_cast<int64_t>(screenId),
                                                      static_cast<int32_t>(keyCode),
                                                      static_cast<int32_t>(scanCode),
                                                      static_cast<int32_t>(modifiers));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    captureClassloader
 * Signature: ()Z
 *
 * Capture the classloader from the current thread (render thread).
 * This allows JNI calls from other threads (like Flutter) to load classes
 * from the correct classloader (Fabric's KnotClassLoader).
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_captureClassloader(
    JNIEnv* /* env */, jclass /* cls */) {
    int32_t result = generic_jni_capture_classloader();
    return result ? JNI_TRUE : JNI_FALSE;
}

// ==========================================================================
// Container Lifecycle Event Dispatching (for event-driven container open/close)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    dispatchContainerScreenOpen
 * Signature: (IILjava/lang/String;Ljava/lang/String;)V
 *
 * Dispatch container open event to Dart.
 * Called from FlutterContainerScreen.init().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_dispatchContainerScreenOpen(
    JNIEnv* env, jclass /* cls */, jint menuId, jint slotCount, jstring containerId, jstring title) {
    const char* containerIdStr = containerId ? env->GetStringUTFChars(containerId, nullptr) : "";
    const char* titleStr = title ? env->GetStringUTFChars(title, nullptr) : "";

    client_dispatch_container_open(
        static_cast<int32_t>(menuId),
        static_cast<int32_t>(slotCount),
        containerIdStr,
        titleStr
    );

    if (containerId && containerIdStr) env->ReleaseStringUTFChars(containerId, containerIdStr);
    if (title && titleStr) env->ReleaseStringUTFChars(title, titleStr);
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    dispatchContainerScreenClose
 * Signature: (I)V
 *
 * Dispatch container close event to Dart.
 * Called from FlutterContainerScreen.removed().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_dispatchContainerScreenClose(
    JNIEnv* /* env */, jclass /* cls */, jint menuId) {
    client_dispatch_container_close(static_cast<int32_t>(menuId));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    scheduleFrame
 * Signature: ()V
 *
 * Schedule Flutter to render a frame immediately.
 * Used to pre-warm Flutter before opening screens.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_scheduleFrame(
    JNIEnv* /* env */, jclass /* cls */) {
    dart_client_schedule_frame();
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    nativeSignalContainerFrameReady
 * Signature: ()V
 *
 * Signal that the container UI frame is ready (called from Dart via JNI).
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_nativeSignalContainerFrameReady(
    JNIEnv* /* env */, jclass /* cls */) {
    dart_client_signal_container_frame_ready();
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    isContainerFrameReady
 * Signature: ()Z
 *
 * Check if Dart has signaled that a container UI frame is ready.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_isContainerFrameReady(
    JNIEnv* /* env */, jclass /* cls */) {
    return dart_client_is_container_frame_ready() ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    clearContainerFrameReady
 * Signature: ()V
 *
 * Clear the container frame ready flag after consuming it.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_clearContainerFrameReady(
    JNIEnv* /* env */, jclass /* cls */) {
    dart_client_clear_container_frame_ready();
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    nativeDispatchContainerDataChanged
 * Signature: (III)V
 *
 * Dispatch container data change event to Dart.
 * Called from DartBlockEntityMenu.setData() when ContainerData changes.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_nativeDispatchContainerDataChanged(
    JNIEnv* /* env */, jclass /* cls */, jint menuId, jint slotIndex, jint value) {
    client_dispatch_container_data_changed(
        static_cast<int32_t>(menuId),
        static_cast<int32_t>(slotIndex),
        static_cast<int32_t>(value)
    );
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    dispatchContainerPrewarmNative
 * Signature: (Ljava/lang/String;)V
 *
 * Dispatch container prewarm event to Dart.
 * Called from ContainerPrewarmManager when player looks at a container block.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_dispatchContainerPrewarmNative(
    JNIEnv* env, jclass /* cls */, jstring containerId) {
    const char* containerIdStr = containerId ? env->GetStringUTFChars(containerId, nullptr) : "";

    client_dispatch_container_prewarm(containerIdStr);

    if (containerId && containerIdStr) env->ReleaseStringUTFChars(containerId, containerIdStr);
}

// ==========================================================================
// HUD Overlay Event Dispatching
// ==========================================================================

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    dispatchHudShowNative
 * Signature: (Ljava/lang/String;)V
 *
 * Dispatch HUD overlay show event to Dart.
 * Called when a HUD overlay should be displayed.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_dispatchHudShowNative(
    JNIEnv* env, jclass /* cls */, jstring overlayId) {
    const char* overlayIdStr = overlayId ? env->GetStringUTFChars(overlayId, nullptr) : "";

    client_dispatch_hud_show(overlayIdStr);

    if (overlayId && overlayIdStr) env->ReleaseStringUTFChars(overlayId, overlayIdStr);
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    dispatchHudHideNative
 * Signature: (Ljava/lang/String;)V
 *
 * Dispatch HUD overlay hide event to Dart.
 * Called when a HUD overlay should be hidden.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_dispatchHudHideNative(
    JNIEnv* env, jclass /* cls */, jstring overlayId) {
    const char* overlayIdStr = overlayId ? env->GetStringUTFChars(overlayId, nullptr) : "";

    client_dispatch_hud_hide(overlayIdStr);

    if (overlayId && overlayIdStr) env->ReleaseStringUTFChars(overlayId, overlayIdStr);
}

// ==========================================================================
// Custom Screen Event Dispatching
// ==========================================================================

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    dispatchCustomScreenOpenNative
 * Signature: (ILjava/lang/String;II)V
 *
 * Dispatch custom screen open event to Dart.
 * Called when a custom (non-container) screen should be opened.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_dispatchCustomScreenOpenNative(
    JNIEnv* env, jclass /* cls */, jint screenId, jstring screenType, jint width, jint height) {
    const char* screenTypeStr = screenType ? env->GetStringUTFChars(screenType, nullptr) : "";

    client_dispatch_custom_screen_open(
        static_cast<int32_t>(screenId),
        screenTypeStr,
        static_cast<int32_t>(width),
        static_cast<int32_t>(height)
    );

    if (screenType && screenTypeStr) env->ReleaseStringUTFChars(screenType, screenTypeStr);
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    dispatchCustomScreenCloseNative
 * Signature: (I)V
 *
 * Dispatch custom screen close event to Dart.
 * Called when a custom screen should be closed.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_dispatchCustomScreenCloseNative(
    JNIEnv* /* env */, jclass /* cls */, jint screenId) {
    client_dispatch_custom_screen_close(static_cast<int32_t>(screenId));
}

// ==========================================================================
// Screen Frame Ready Signal JNI Entry Points
// ==========================================================================

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    nativeSignalScreenFrameReady
 * Signature: ()V
 *
 * Signal that the custom screen UI frame is ready (called from Dart via JNI).
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_nativeSignalScreenFrameReady(
    JNIEnv* /* env */, jclass /* cls */) {
    dart_client_signal_screen_frame_ready();
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    isScreenFrameReady
 * Signature: ()Z
 *
 * Check if Dart has signaled that a custom screen UI frame is ready.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_isScreenFrameReady(
    JNIEnv* /* env */, jclass /* cls */) {
    return dart_client_is_screen_frame_ready() ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    clearScreenFrameReady
 * Signature: ()V
 *
 * Clear the screen frame ready flag after consuming it.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_clearScreenFrameReady(
    JNIEnv* /* env */, jclass /* cls */) {
    dart_client_clear_screen_frame_ready();
}

// ==========================================================================
// Multi-Surface JNI Entry Points (macOS only)
// ==========================================================================

#ifdef __APPLE__

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    multiSurfaceInit
 * Signature: ()Z
 *
 * Initialize the multi-surface system.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_multiSurfaceInit(
    JNIEnv* /* env */, jclass /* cls */) {
    return multi_surface_init() ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    multiSurfaceShutdown
 * Signature: ()V
 *
 * Shutdown the multi-surface system.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_multiSurfaceShutdown(
    JNIEnv* /* env */, jclass /* cls */) {
    multi_surface_shutdown();
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    createSurface
 * Signature: (IILjava/lang/String;)J
 *
 * Create a new Flutter surface with the specified dimensions.
 * Returns the surface ID (> 0) or 0 on failure.
 */
JNIEXPORT jlong JNICALL Java_com_redstone_DartBridgeClient_createSurface(
    JNIEnv* env, jclass /* cls */, jint width, jint height, jstring initialRoute) {

    const char* route = nullptr;
    if (initialRoute != nullptr) {
        route = env->GetStringUTFChars(initialRoute, nullptr);
        std::cout << "[JNI] createSurface called with route: '" << (route ? route : "NULL") << "'" << std::endl;
    } else {
        std::cout << "[JNI] createSurface called with NULL initialRoute" << std::endl;
    }

    int64_t surface_id = multi_surface_create(
        static_cast<int32_t>(width),
        static_cast<int32_t>(height),
        route
    );

    std::cout << "[JNI] multi_surface_create returned surface_id=" << surface_id << std::endl;

    if (route) {
        env->ReleaseStringUTFChars(initialRoute, route);
    }

    return static_cast<jlong>(surface_id);
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    destroySurface
 * Signature: (J)V
 *
 * Destroy a surface and release all associated resources.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_destroySurface(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId) {
    multi_surface_destroy(static_cast<int64_t>(surfaceId));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    surfaceExists
 * Signature: (J)Z
 *
 * Check if a surface exists.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_surfaceExists(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId) {
    return multi_surface_exists(static_cast<int64_t>(surfaceId)) ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    setSurfaceSize
 * Signature: (JII)V
 *
 * Update window metrics for a surface.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_setSurfaceSize(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId, jint width, jint height) {
    multi_surface_set_size(
        static_cast<int64_t>(surfaceId),
        static_cast<int32_t>(width),
        static_cast<int32_t>(height)
    );
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    processSurfaceTasks
 * Signature: (J)V
 *
 * Process pending tasks for a specific surface.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_processSurfaceTasks(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId) {
    multi_surface_process_tasks(static_cast<int64_t>(surfaceId));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    processAllSurfaceTasks
 * Signature: ()V
 *
 * Process pending tasks for ALL surfaces.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_processAllSurfaceTasks(
    JNIEnv* /* env */, jclass /* cls */) {
    multi_surface_process_all_tasks();
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    scheduleSurfaceFrame
 * Signature: (J)V
 *
 * Schedule a frame to be rendered for a surface.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_scheduleSurfaceFrame(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId) {
    multi_surface_schedule_frame(static_cast<int64_t>(surfaceId));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getSurfaceTextureId
 * Signature: (J)I
 *
 * Get the OpenGL texture ID for a surface.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridgeClient_getSurfaceTextureId(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId) {
    return static_cast<jint>(multi_surface_get_texture_id(static_cast<int64_t>(surfaceId)));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    updateSurfaceGLTexture
 * Signature: (J)Z
 *
 * Update the OpenGL texture binding for a surface.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_updateSurfaceGLTexture(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId) {
    return multi_surface_update_gl_texture(static_cast<int64_t>(surfaceId)) ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getSurfaceTextureWidth
 * Signature: (J)I
 *
 * Get the texture width for a surface.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridgeClient_getSurfaceTextureWidth(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId) {
    return static_cast<jint>(multi_surface_get_texture_width(static_cast<int64_t>(surfaceId)));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getSurfaceTextureHeight
 * Signature: (J)I
 *
 * Get the texture height for a surface.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridgeClient_getSurfaceTextureHeight(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId) {
    return static_cast<jint>(multi_surface_get_texture_height(static_cast<int64_t>(surfaceId)));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    surfaceHasNewFrame
 * Signature: (J)Z
 *
 * Check if a surface has a new frame ready.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_surfaceHasNewFrame(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId) {
    return multi_surface_has_new_frame(static_cast<int64_t>(surfaceId)) ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getSurfacePixels
 * Signature: (J)Ljava/nio/ByteBuffer;
 *
 * Get pixel data for a surface.
 */
JNIEXPORT jobject JNICALL Java_com_redstone_DartBridgeClient_getSurfacePixels(
    JNIEnv* env, jclass /* cls */, jlong surfaceId) {

    void* pixels = multi_surface_get_pixels(static_cast<int64_t>(surfaceId));
    if (pixels == nullptr) {
        return nullptr;
    }

    int32_t width = multi_surface_get_pixel_width(static_cast<int64_t>(surfaceId));
    int32_t height = multi_surface_get_pixel_height(static_cast<int64_t>(surfaceId));
    if (width <= 0 || height <= 0) {
        return nullptr;
    }

    size_t size = static_cast<size_t>(width) * static_cast<size_t>(height) * 4;
    return env->NewDirectByteBuffer(pixels, static_cast<jlong>(size));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getSurfacePixelWidth
 * Signature: (J)I
 *
 * Get pixel width for a surface (after readback).
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridgeClient_getSurfacePixelWidth(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId) {
    return static_cast<jint>(multi_surface_get_pixel_width(static_cast<int64_t>(surfaceId)));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    getSurfacePixelHeight
 * Signature: (J)I
 *
 * Get pixel height for a surface (after readback).
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridgeClient_getSurfacePixelHeight(
    JNIEnv* /* env */, jclass /* cls */, jlong surfaceId) {
    return static_cast<jint>(multi_surface_get_pixel_height(static_cast<int64_t>(surfaceId)));
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    sendSurfacePointerEvent
 * Signature: (JIDDJ)V
 *
 * Send a pointer event to a specific surface.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_sendSurfacePointerEvent(
    JNIEnv* /* env */, jclass /* cls */,
    jlong surfaceId, jint phase, jdouble x, jdouble y, jlong buttons) {
    multi_surface_send_pointer_event(
        static_cast<int64_t>(surfaceId),
        static_cast<int32_t>(phase),
        static_cast<double>(x),
        static_cast<double>(y),
        static_cast<int64_t>(buttons)
    );
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    sendSurfaceKeyEvent
 * Signature: (JIJJLjava/lang/String;I)V
 *
 * Send a key event to a specific surface.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_sendSurfaceKeyEvent(
    JNIEnv* env, jclass /* cls */,
    jlong surfaceId, jint type, jlong physicalKey, jlong logicalKey,
    jstring character, jint modifiers) {

    const char* chars = character ? env->GetStringUTFChars(character, nullptr) : nullptr;

    multi_surface_send_key_event(
        static_cast<int64_t>(surfaceId),
        static_cast<int32_t>(type),
        static_cast<int64_t>(physicalKey),
        static_cast<int64_t>(logicalKey),
        chars,
        static_cast<int32_t>(modifiers)
    );

    if (chars) {
        env->ReleaseStringUTFChars(character, chars);
    }
}

#endif // __APPLE__

// ==========================================================================
// Packet Send Callback (Dart -> Java -> Server)
// ==========================================================================

// Static references for callback
static JavaVM* g_packet_jvm = nullptr;
static jclass g_packet_class = nullptr;
static jmethodID g_packet_method = nullptr;

// Callback function that will be called by native when Dart sends a packet
static void jni_send_packet_to_server_callback(int32_t packet_type, const uint8_t* data, int32_t data_length) {
    std::cout << "[JNI] jni_send_packet_to_server_callback called: type=0x"
              << std::hex << packet_type << std::dec << ", length=" << data_length << std::endl;

    if (!g_packet_jvm || !g_packet_class || !g_packet_method) {
        std::cerr << "[JNI] send_packet_to_server_callback: Not initialized" << std::endl;
        return;
    }

    JNIEnv* env = nullptr;
    bool attached = false;

    jint result = g_packet_jvm->GetEnv((void**)&env, JNI_VERSION_1_6);
    if (result == JNI_EDETACHED) {
        if (g_packet_jvm->AttachCurrentThread((void**)&env, nullptr) != 0) {
            std::cerr << "[JNI] send_packet_to_server_callback: Failed to attach thread" << std::endl;
            return;
        }
        attached = true;
    } else if (result != JNI_OK) {
        std::cerr << "[JNI] send_packet_to_server_callback: GetEnv failed" << std::endl;
        return;
    }

    // Create byte array from data
    jbyteArray jdata = env->NewByteArray(data_length);
    if (jdata != nullptr) {
        env->SetByteArrayRegion(jdata, 0, data_length, reinterpret_cast<const jbyte*>(data));

        // Call Java method: onSendPacketToServer(int packetType, byte[] data)
        env->CallStaticVoidMethod(g_packet_class, g_packet_method,
                                   static_cast<jint>(packet_type), jdata);

        env->DeleteLocalRef(jdata);
    }

    if (attached) {
        g_packet_jvm->DetachCurrentThread();
    }
}

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    registerClientSendPacketCallback
 * Signature: ()V
 *
 * Register the callback for sending packets from Dart to Java/server.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_registerClientSendPacketCallback(
    JNIEnv* env, jclass cls) {

    // Get JVM reference
    env->GetJavaVM(&g_packet_jvm);

    // Create global reference to the class
    g_packet_class = (jclass)env->NewGlobalRef(cls);

    // Get the method ID for onSendPacketToServer(int, byte[])
    g_packet_method = env->GetStaticMethodID(cls, "onSendPacketToServer", "(I[B)V");
    if (g_packet_method == nullptr) {
        std::cerr << "[JNI] registerClientSendPacketCallback: Failed to find onSendPacketToServer method" << std::endl;
        return;
    }

    // Register our callback with the native bridge
    client_set_send_packet_to_server_callback(jni_send_packet_to_server_callback);

    std::cout << "[JNI] Client send packet callback registered successfully" << std::endl;
}

// ==========================================================================
// Server-to-Client Packet Dispatch
// ==========================================================================

/*
 * Class:     com_redstone_DartBridgeClient
 * Method:    dispatchServerPacketNative
 * Signature: (I[B)V
 *
 * Dispatch a packet received from the server to the Dart client runtime.
 * This is called by the networking layer when an S2C packet is received.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_dispatchServerPacketNative(
    JNIEnv* env, jclass /* cls */, jint packetType, jbyteArray data) {

    if (data == nullptr) {
        std::cerr << "[JNI] dispatchServerPacketNative: data is null" << std::endl;
        return;
    }

    jsize dataLength = env->GetArrayLength(data);
    jbyte* dataBytes = env->GetByteArrayElements(data, nullptr);
    if (dataBytes == nullptr) {
        std::cerr << "[JNI] dispatchServerPacketNative: Failed to get byte array elements" << std::endl;
        return;
    }

    std::cout << "[JNI] dispatchServerPacketNative: packetType=0x" << std::hex << packetType
              << std::dec << ", length=" << dataLength << std::endl;

    // Dispatch to native client runtime -> Dart
    client_dispatch_server_packet(
        static_cast<int32_t>(packetType),
        reinterpret_cast<const uint8_t*>(dataBytes),
        static_cast<int32_t>(dataLength)
    );

    env->ReleaseByteArrayElements(data, dataBytes, JNI_ABORT);
}

} // extern "C"
