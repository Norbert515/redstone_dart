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
 */
JNIEXPORT jobject JNICALL Java_com_redstone_DartBridgeClient_getFramePixels(
    JNIEnv* env, jclass /* cls */) {

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

    std::lock_guard<std::mutex> lock(g_frame_mutex);
    bool result = g_has_new_frame;
    g_has_new_frame = false;  // Clear the flag after reading
    return result ? JNI_TRUE : JNI_FALSE;
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

} // extern "C"
