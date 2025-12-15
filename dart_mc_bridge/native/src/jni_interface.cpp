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

    // Capture JVM reference early for object registry cleanup
    if (g_jvm == nullptr) {
        env->GetJavaVM(&g_jvm);
        dart_bridge_set_jvm(g_jvm);
    }

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
        // Also set JVM reference for dart bridge (needed for object registry cleanup)
        dart_bridge_set_jvm(g_jvm);
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

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onProxyBlockBreak
 * Signature: (JJIIIJ)Z
 *
 * Called from Java proxy blocks when they are broken.
 * Routes to Dart's BlockRegistry.dispatchBlockBreak().
 * Returns true if break should be allowed, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onProxyBlockBreak(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handler_id, jlong world_id,
    jint x, jint y, jint z, jlong player_id) {

    return dispatch_proxy_block_break(handler_id, world_id, x, y, z, player_id) ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onProxyBlockUse
 * Signature: (JJIIIJI)I
 *
 * Called from Java proxy blocks when they are used (right-clicked).
 * Routes to Dart's BlockRegistry.dispatchBlockUse().
 * Returns ActionResult ordinal.
 */
JNIEXPORT jint JNICALL Java_com_example_dartbridge_DartBridge_onProxyBlockUse(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handler_id, jlong world_id,
    jint x, jint y, jint z, jlong player_id, jint hand) {

    return dispatch_proxy_block_use(handler_id, world_id, x, y, z, player_id, hand);
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    getDartServiceUrl
 * Signature: ()Ljava/lang/String;
 *
 * Returns the Dart VM service URL for hot reload/debugging.
 */
JNIEXPORT jstring JNICALL Java_com_example_dartbridge_DartBridge_getDartServiceUrl(
    JNIEnv* env, jclass /* cls */) {

    const char* url = get_dart_service_url();
    if (url != nullptr) {
        return env->NewStringUTF(url);
    }
    return nullptr;
}

// ==========================================================================
// New Event JNI Entry Points
// ==========================================================================

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onPlayerJoin
 * Signature: (I)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onPlayerJoin(
    JNIEnv* /* env */, jclass /* cls */, jint playerId) {
    dispatch_player_join(static_cast<int32_t>(playerId));
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onPlayerLeave
 * Signature: (I)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onPlayerLeave(
    JNIEnv* /* env */, jclass /* cls */, jint playerId) {
    dispatch_player_leave(static_cast<int32_t>(playerId));
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onPlayerRespawn
 * Signature: (IZ)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onPlayerRespawn(
    JNIEnv* /* env */, jclass /* cls */, jint playerId, jboolean endConquered) {
    dispatch_player_respawn(static_cast<int32_t>(playerId), endConquered == JNI_TRUE);
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onPlayerDeath
 * Signature: (ILjava/lang/String;)Ljava/lang/String;
 *
 * Returns custom death message or null for default.
 */
JNIEXPORT jstring JNICALL Java_com_example_dartbridge_DartBridge_onPlayerDeath(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring damageSource) {
    const char* source = env->GetStringUTFChars(damageSource, nullptr);
    char* result = dispatch_player_death(static_cast<int32_t>(playerId), source);
    env->ReleaseStringUTFChars(damageSource, source);

    if (result != nullptr) {
        jstring jresult = env->NewStringUTF(result);
        // Note: If Dart allocated this string, it should be freed by Dart
        return jresult;
    }
    return nullptr;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onEntityDamage
 * Signature: (ILjava/lang/String;D)Z
 *
 * Returns true to allow damage, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onEntityDamage(
    JNIEnv* env, jclass /* cls */, jint entityId, jstring damageSource, jdouble amount) {
    const char* source = env->GetStringUTFChars(damageSource, nullptr);
    bool result = dispatch_entity_damage(static_cast<int32_t>(entityId), source, static_cast<double>(amount));
    env->ReleaseStringUTFChars(damageSource, source);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onEntityDeath
 * Signature: (ILjava/lang/String;)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onEntityDeath(
    JNIEnv* env, jclass /* cls */, jint entityId, jstring damageSource) {
    const char* source = env->GetStringUTFChars(damageSource, nullptr);
    dispatch_entity_death(static_cast<int32_t>(entityId), source);
    env->ReleaseStringUTFChars(damageSource, source);
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onPlayerAttackEntity
 * Signature: (II)Z
 *
 * Returns true to allow attack, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onPlayerAttackEntity(
    JNIEnv* /* env */, jclass /* cls */, jint playerId, jint targetId) {
    bool result = dispatch_player_attack_entity(static_cast<int32_t>(playerId), static_cast<int32_t>(targetId));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onPlayerChat
 * Signature: (ILjava/lang/String;)Ljava/lang/String;
 *
 * Returns modified message, original to pass through, or null to cancel.
 */
JNIEXPORT jstring JNICALL Java_com_example_dartbridge_DartBridge_onPlayerChat(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring message) {
    const char* msg = env->GetStringUTFChars(message, nullptr);
    char* result = dispatch_player_chat(static_cast<int32_t>(playerId), msg);
    env->ReleaseStringUTFChars(message, msg);

    if (result != nullptr) {
        jstring jresult = env->NewStringUTF(result);
        return jresult;
    }
    return nullptr;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onPlayerCommand
 * Signature: (ILjava/lang/String;)Z
 *
 * Returns true to allow command, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onPlayerCommand(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring command) {
    const char* cmd = env->GetStringUTFChars(command, nullptr);
    bool result = dispatch_player_command(static_cast<int32_t>(playerId), cmd);
    env->ReleaseStringUTFChars(command, cmd);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onItemUse
 * Signature: (ILjava/lang/String;II)Z
 *
 * Returns true to allow use, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onItemUse(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring itemId, jint count, jint hand) {
    const char* item = env->GetStringUTFChars(itemId, nullptr);
    bool result = dispatch_item_use(static_cast<int32_t>(playerId), item,
                                    static_cast<int32_t>(count), static_cast<int32_t>(hand));
    env->ReleaseStringUTFChars(itemId, item);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onItemUseOnBlock
 * Signature: (ILjava/lang/String;IIIIII)I
 *
 * Returns EventResult value.
 */
JNIEXPORT jint JNICALL Java_com_example_dartbridge_DartBridge_onItemUseOnBlock(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring itemId, jint count, jint hand,
    jint x, jint y, jint z, jint face) {
    const char* item = env->GetStringUTFChars(itemId, nullptr);
    int32_t result = dispatch_item_use_on_block(
        static_cast<int32_t>(playerId), item, static_cast<int32_t>(count), static_cast<int32_t>(hand),
        static_cast<int32_t>(x), static_cast<int32_t>(y), static_cast<int32_t>(z), static_cast<int32_t>(face));
    env->ReleaseStringUTFChars(itemId, item);
    return static_cast<jint>(result);
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onItemUseOnEntity
 * Signature: (ILjava/lang/String;III)I
 *
 * Returns EventResult value.
 */
JNIEXPORT jint JNICALL Java_com_example_dartbridge_DartBridge_onItemUseOnEntity(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring itemId, jint count, jint hand, jint targetId) {
    const char* item = env->GetStringUTFChars(itemId, nullptr);
    int32_t result = dispatch_item_use_on_entity(
        static_cast<int32_t>(playerId), item, static_cast<int32_t>(count), static_cast<int32_t>(hand),
        static_cast<int32_t>(targetId));
    env->ReleaseStringUTFChars(itemId, item);
    return static_cast<jint>(result);
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onBlockPlace
 * Signature: (IIIILjava/lang/String;)Z
 *
 * Returns true to allow placement, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onBlockPlace(
    JNIEnv* env, jclass /* cls */, jint playerId, jint x, jint y, jint z, jstring blockId) {
    const char* block = env->GetStringUTFChars(blockId, nullptr);
    bool result = dispatch_block_place(static_cast<int32_t>(playerId),
                                       static_cast<int32_t>(x), static_cast<int32_t>(y), static_cast<int32_t>(z),
                                       block);
    env->ReleaseStringUTFChars(blockId, block);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onPlayerPickupItem
 * Signature: (II)Z
 *
 * Returns true to allow pickup, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onPlayerPickupItem(
    JNIEnv* /* env */, jclass /* cls */, jint playerId, jint itemEntityId) {
    bool result = dispatch_player_pickup_item(static_cast<int32_t>(playerId), static_cast<int32_t>(itemEntityId));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onPlayerDropItem
 * Signature: (ILjava/lang/String;I)Z
 *
 * Returns true to allow drop, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onPlayerDropItem(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring itemId, jint count) {
    const char* item = env->GetStringUTFChars(itemId, nullptr);
    bool result = dispatch_player_drop_item(static_cast<int32_t>(playerId), item, static_cast<int32_t>(count));
    env->ReleaseStringUTFChars(itemId, item);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onServerStarting
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onServerStarting(
    JNIEnv* /* env */, jclass /* cls */) {
    dispatch_server_starting();
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onServerStarted
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onServerStarted(
    JNIEnv* /* env */, jclass /* cls */) {
    dispatch_server_started();
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onServerStopping
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onServerStopping(
    JNIEnv* /* env */, jclass /* cls */) {
    dispatch_server_stopping();
}

// ==========================================================================
// Screen/GUI JNI Entry Points
// ==========================================================================

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onScreenInit
 * Signature: (JII)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onScreenInit(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jint width, jint height) {
    dispatch_screen_init(static_cast<int64_t>(screenId),
                         static_cast<int32_t>(width),
                         static_cast<int32_t>(height));
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onScreenTick
 * Signature: (J)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onScreenTick(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId) {
    dispatch_screen_tick(static_cast<int64_t>(screenId));
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onScreenRender
 * Signature: (JIIF)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onScreenRender(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jint mouseX, jint mouseY, jfloat partialTick) {
    dispatch_screen_render(static_cast<int64_t>(screenId),
                           static_cast<int32_t>(mouseX),
                           static_cast<int32_t>(mouseY),
                           static_cast<float>(partialTick));
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onScreenClose
 * Signature: (J)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onScreenClose(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId) {
    dispatch_screen_close(static_cast<int64_t>(screenId));
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onScreenKeyPressed
 * Signature: (JIII)Z
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onScreenKeyPressed(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jint keyCode, jint scanCode, jint modifiers) {
    bool result = dispatch_screen_key_pressed(static_cast<int64_t>(screenId),
                                               static_cast<int32_t>(keyCode),
                                               static_cast<int32_t>(scanCode),
                                               static_cast<int32_t>(modifiers));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onScreenKeyReleased
 * Signature: (JIII)Z
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onScreenKeyReleased(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jint keyCode, jint scanCode, jint modifiers) {
    bool result = dispatch_screen_key_released(static_cast<int64_t>(screenId),
                                                static_cast<int32_t>(keyCode),
                                                static_cast<int32_t>(scanCode),
                                                static_cast<int32_t>(modifiers));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onScreenCharTyped
 * Signature: (JII)Z
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onScreenCharTyped(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jint codePoint, jint modifiers) {
    bool result = dispatch_screen_char_typed(static_cast<int64_t>(screenId),
                                              static_cast<int32_t>(codePoint),
                                              static_cast<int32_t>(modifiers));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onScreenMouseClicked
 * Signature: (JDDI)Z
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onScreenMouseClicked(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jdouble mouseX, jdouble mouseY, jint button) {
    bool result = dispatch_screen_mouse_clicked(static_cast<int64_t>(screenId),
                                                 static_cast<double>(mouseX),
                                                 static_cast<double>(mouseY),
                                                 static_cast<int32_t>(button));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onScreenMouseReleased
 * Signature: (JDDI)Z
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onScreenMouseReleased(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jdouble mouseX, jdouble mouseY, jint button) {
    bool result = dispatch_screen_mouse_released(static_cast<int64_t>(screenId),
                                                  static_cast<double>(mouseX),
                                                  static_cast<double>(mouseY),
                                                  static_cast<int32_t>(button));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onScreenMouseDragged
 * Signature: (JDDIDD)Z
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onScreenMouseDragged(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jdouble mouseX, jdouble mouseY,
    jint button, jdouble dragX, jdouble dragY) {
    bool result = dispatch_screen_mouse_dragged(static_cast<int64_t>(screenId),
                                                 static_cast<double>(mouseX),
                                                 static_cast<double>(mouseY),
                                                 static_cast<int32_t>(button),
                                                 static_cast<double>(dragX),
                                                 static_cast<double>(dragY));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onScreenMouseScrolled
 * Signature: (JDDDD)Z
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onScreenMouseScrolled(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jdouble mouseX, jdouble mouseY,
    jdouble deltaX, jdouble deltaY) {
    bool result = dispatch_screen_mouse_scrolled(static_cast<int64_t>(screenId),
                                                  static_cast<double>(mouseX),
                                                  static_cast<double>(mouseY),
                                                  static_cast<double>(deltaX),
                                                  static_cast<double>(deltaY));
    return result ? JNI_TRUE : JNI_FALSE;
}

// ==========================================================================
// Widget JNI Entry Points
// ==========================================================================

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onWidgetPressed
 * Signature: (JJ)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onWidgetPressed(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jlong widgetId) {
    dispatch_widget_pressed(static_cast<int64_t>(screenId), static_cast<int64_t>(widgetId));
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onWidgetTextChanged
 * Signature: (JJLjava/lang/String;)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onWidgetTextChanged(
    JNIEnv* env, jclass /* cls */, jlong screenId, jlong widgetId, jstring text) {
    const char* textStr = env->GetStringUTFChars(text, nullptr);
    dispatch_widget_text_changed(static_cast<int64_t>(screenId), static_cast<int64_t>(widgetId), textStr);
    env->ReleaseStringUTFChars(text, textStr);
}

// ==========================================================================
// Container Screen JNI Entry Points
// ==========================================================================

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onContainerScreenInit
 * Signature: (JIIIIII)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onContainerScreenInit(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jint width, jint height,
    jint leftPos, jint topPos, jint imageWidth, jint imageHeight) {
    dispatch_container_screen_init(static_cast<int64_t>(screenId),
                                   static_cast<int32_t>(width),
                                   static_cast<int32_t>(height),
                                   static_cast<int32_t>(leftPos),
                                   static_cast<int32_t>(topPos),
                                   static_cast<int32_t>(imageWidth),
                                   static_cast<int32_t>(imageHeight));
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onContainerScreenRenderBg
 * Signature: (JIIFII)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onContainerScreenRenderBg(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId, jint mouseX, jint mouseY,
    jfloat partialTick, jint leftPos, jint topPos) {
    dispatch_container_screen_render_bg(static_cast<int64_t>(screenId),
                                        static_cast<int32_t>(mouseX),
                                        static_cast<int32_t>(mouseY),
                                        static_cast<float>(partialTick),
                                        static_cast<int32_t>(leftPos),
                                        static_cast<int32_t>(topPos));
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onContainerScreenClose
 * Signature: (J)V
 */
JNIEXPORT void JNICALL Java_com_example_dartbridge_DartBridge_onContainerScreenClose(
    JNIEnv* /* env */, jclass /* cls */, jlong screenId) {
    dispatch_container_screen_close(static_cast<int64_t>(screenId));
}

// ==========================================================================
// Container Menu JNI Entry Points
// ==========================================================================

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onContainerSlotClick
 * Signature: (JIIILjava/lang/String;)I
 *
 * Called when a slot is clicked in a container menu.
 * Returns -1 to skip default handling, 0+ for custom result.
 */
JNIEXPORT jint JNICALL Java_com_example_dartbridge_DartBridge_onContainerSlotClick(
    JNIEnv* env, jclass /* cls */, jlong menuId, jint slotIndex,
    jint button, jint clickType, jstring carriedItem) {
    const char* item = env->GetStringUTFChars(carriedItem, nullptr);
    int32_t result = dispatch_container_slot_click(
        static_cast<int64_t>(menuId), static_cast<int32_t>(slotIndex),
        static_cast<int32_t>(button), static_cast<int32_t>(clickType), item);
    env->ReleaseStringUTFChars(carriedItem, item);
    return static_cast<jint>(result);
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onContainerQuickMove
 * Signature: (JI)Ljava/lang/String;
 *
 * Called when shift-click is used on a slot.
 * Returns custom ItemStack string or null for default behavior.
 */
JNIEXPORT jstring JNICALL Java_com_example_dartbridge_DartBridge_onContainerQuickMove(
    JNIEnv* env, jclass /* cls */, jlong menuId, jint slotIndex) {
    const char* result = dispatch_container_quick_move(
        static_cast<int64_t>(menuId), static_cast<int32_t>(slotIndex));

    if (result != nullptr && result[0] != '\0') {
        jstring jresult = env->NewStringUTF(result);
        return jresult;
    }
    return nullptr;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onContainerMayPlace
 * Signature: (JILjava/lang/String;)Z
 *
 * Called to check if an item may be placed in a slot.
 * Returns true to allow, false to deny.
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onContainerMayPlace(
    JNIEnv* env, jclass /* cls */, jlong menuId, jint slotIndex, jstring itemData) {
    const char* item = env->GetStringUTFChars(itemData, nullptr);
    bool result = dispatch_container_may_place(
        static_cast<int64_t>(menuId), static_cast<int32_t>(slotIndex), item);
    env->ReleaseStringUTFChars(itemData, item);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_example_dartbridge_DartBridge
 * Method:    onContainerMayPickup
 * Signature: (JI)Z
 *
 * Called to check if an item may be picked up from a slot.
 * Returns true to allow, false to deny.
 */
JNIEXPORT jboolean JNICALL Java_com_example_dartbridge_DartBridge_onContainerMayPickup(
    JNIEnv* env, jclass /* cls */, jlong menuId, jint slotIndex) {
    bool result = dispatch_container_may_pickup(
        static_cast<int64_t>(menuId), static_cast<int32_t>(slotIndex));
    return result ? JNI_TRUE : JNI_FALSE;
}

} // extern "C"
