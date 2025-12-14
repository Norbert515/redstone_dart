#include "dart_bridge.h"

#include <jni.h>
#include <iostream>

// JNI function naming convention:
// Java_<package>_<class>_<method>
// Package: com.example.dartbridge
// Class: DartBridge

// Global references for Java callback
static JavaVM* g_jvm = nullptr;
static jclass g_dart_bridge_class = nullptr;
static jmethodID g_on_chat_message_method = nullptr;

// Callback function that gets called from Dart
static void jni_send_chat_message(int64_t player_id, const char* message) {
    if (g_jvm == nullptr || g_dart_bridge_class == nullptr || g_on_chat_message_method == nullptr) {
        std::cerr << "JNI: Chat callback not properly initialized" << std::endl;
        return;
    }

    JNIEnv* env = nullptr;
    bool needs_detach = false;

    // Check if we're already attached to the JVM
    int status = g_jvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_8);
    if (status == JNI_EDETACHED) {
        // Need to attach this thread
        if (g_jvm->AttachCurrentThread(reinterpret_cast<void**>(&env), nullptr) != JNI_OK) {
            std::cerr << "JNI: Failed to attach thread to JVM" << std::endl;
            return;
        }
        needs_detach = true;
    } else if (status != JNI_OK) {
        std::cerr << "JNI: Failed to get JNI environment" << std::endl;
        return;
    }

    // Create Java string from message
    jstring jmessage = env->NewStringUTF(message);
    if (jmessage == nullptr) {
        std::cerr << "JNI: Failed to create Java string" << std::endl;
        if (needs_detach) g_jvm->DetachCurrentThread();
        return;
    }

    // Call the Java method
    env->CallStaticVoidMethod(g_dart_bridge_class, g_on_chat_message_method,
                               static_cast<jlong>(player_id), jmessage);

    // Clean up
    env->DeleteLocalRef(jmessage);

    // Check for exceptions
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
    }

    if (needs_detach) {
        g_jvm->DetachCurrentThread();
    }
}

extern "C" {

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    init
 * Signature: (Ljava/lang/String;)Z
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_init(
    JNIEnv* env, jclass /* cls */, jstring kernel_path) {

    const char* path = env->GetStringUTFChars(kernel_path, nullptr);
    if (!path) {
        std::cerr << "JNI: Failed to get kernel path string" << std::endl;
        return JNI_FALSE;
    }

    bool result = dart_bridge_init(path);
    env->ReleaseStringUTFChars(kernel_path, path);

    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    shutdown
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_shutdown(
    JNIEnv* /* env */, jclass /* cls */) {

    dart_bridge_shutdown();
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onBlockBreak
 * Signature: (IIIJ)I
 */
JNIEXPORT jint JNICALL Java_com_example_dartbridge_DartBridge_onBlockBreak(
    JNIEnv* /* env */, jclass /* cls */,
    jint x, jint y, jint z, jlong player_id) {

    return dispatch_block_break(x, y, z, player_id);
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onBlockInteract
 * Signature: (IIIJI)I
 */
JNIEXPORT jint JNICALL Java_com_example_dartbridge_DartBridge_onBlockInteract(
    JNIEnv* /* env */, jclass /* cls */,
    jint x, jint y, jint z, jlong player_id, jint hand) {

    return dispatch_block_interact(x, y, z, player_id, hand);
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onTick
 * Signature: (J)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onTick(
    JNIEnv* /* env */, jclass /* cls */, jlong tick) {

    dispatch_tick(tick);
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    tick
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_tick(
    JNIEnv* /* env */, jclass /* cls */) {

    dart_bridge_tick();
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    setSendChatCallback
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_setSendChatCallback(
    JNIEnv* env, jclass cls) {

    // Get JVM reference
    if (g_jvm == nullptr) {
        env->GetJavaVM(&g_jvm);
    }

    // Create global reference to DartBridge class
    if (g_dart_bridge_class == nullptr) {
        g_dart_bridge_class = static_cast<jclass>(env->NewGlobalRef(cls));
    }

    // Get method ID for onChatMessage
    g_on_chat_message_method = env->GetStaticMethodID(
        g_dart_bridge_class, "onChatMessage", "(JLjava/lang/String;)V");

    if (g_on_chat_message_method == nullptr) {
        std::cerr << "JNI: Failed to find onChatMessage method" << std::endl;
        return;
    }

    // Register the callback with the native bridge
    set_send_chat_message_callback(jni_send_chat_message);
    std::cout << "JNI: Chat message callback set up successfully" << std::endl;
}

} // extern "C"
