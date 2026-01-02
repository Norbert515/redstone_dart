// ==========================================================================
// Server-side JNI Interface
// ==========================================================================
// This file contains all JNI functions for Java_com_redstone_DartBridge_*
// (server-side operations).
//
// COMPILE-TIME SAFETY: Only dart_bridge_server.h is included, making it
// impossible to accidentally call client functions like dispatch_tick().
// ==========================================================================

#include "dart_bridge_server.h"  // Server functions ONLY - no dart_bridge.h!
#include "jni_helpers.h"         // Shared JNI boxing helpers

#include <jni.h>
#include <iostream>
#include <cstring>

using namespace jni_helpers;

// JNI function naming convention:
// Java_<package>_<class>_<method>
// Package: com.redstone
// Class: DartBridge (server-side)

// ==========================================================================
// Global JVM reference and chat callback (shared state lives in server file)
// ==========================================================================

static JavaVM* g_jvm = nullptr;
static jclass g_dart_bridge_class = nullptr;
static jmethodID g_on_chat_message_method = nullptr;

// Callback function that gets called from Dart to send chat messages
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

// Expose JVM getter for client file to use
JavaVM* jni_get_jvm() {
    return g_jvm;
}

extern "C" {

// ==========================================================================
// JNI_OnLoad - Register callbacks when library is loaded
// ==========================================================================

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* /* reserved */) {
    // Store JVM reference
    if (g_jvm == nullptr) {
        g_jvm = vm;
        dart_server_set_jvm(vm);
    }

    return JNI_VERSION_1_8;
}

// ==========================================================================
// Server Lifecycle JNI Entry Points
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    initServer
 * Signature: (Ljava/lang/String;Ljava/lang/String;I)Z
 *
 * Initialize the server-side Dart runtime using dart_dll.
 * @param script_path Path to the Dart script to run
 * @param package_config Path to package_config.json (can be null)
 * @param service_port Port for Dart VM service (hot reload/debugging)
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_initServer(
    JNIEnv* env, jclass /* cls */,
    jstring script_path, jstring package_config, jint service_port) {

    // Capture JVM reference early for object registry cleanup
    if (g_jvm == nullptr) {
        env->GetJavaVM(&g_jvm);
        dart_server_set_jvm(g_jvm);
    }

    const char* script = script_path ? env->GetStringUTFChars(script_path, nullptr) : nullptr;
    const char* pkg_config = package_config ? env->GetStringUTFChars(package_config, nullptr) : nullptr;

    if (!script) {
        std::cerr << "JNI: Failed to get script path string" << std::endl;
        return JNI_FALSE;
    }

    bool result = dart_server_init(script, pkg_config, static_cast<int>(service_port));

    env->ReleaseStringUTFChars(script_path, script);
    if (pkg_config) env->ReleaseStringUTFChars(package_config, pkg_config);

    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    shutdownServer
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_shutdownServer(
    JNIEnv* /* env */, jclass /* cls */) {
    dart_server_shutdown();
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    tickServer
 * Signature: ()V
 *
 * Tick the server runtime (drain microtask queue)
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_tickServer(
    JNIEnv* /* env */, jclass /* cls */) {
    dart_server_tick();
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    getServerServiceUrl
 * Signature: ()Ljava/lang/String;
 *
 * Get the Dart VM service URL for server-side hot reload/debugging.
 */
JNIEXPORT jstring JNICALL Java_com_redstone_DartBridge_getServerServiceUrl(
    JNIEnv* env, jclass /* cls */) {
    const char* url = dart_server_get_service_url();
    if (url != nullptr) {
        return env->NewStringUTF(url);
    }
    return nullptr;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    getDartServiceUrl
 * Signature: ()Ljava/lang/String;
 *
 * Get the Dart VM service URL (returns server URL in server-only mode).
 * This is the legacy unified API that client code uses.
 */
JNIEXPORT jstring JNICALL Java_com_redstone_DartBridge_getDartServiceUrl(
    JNIEnv* env, jclass /* cls */) {
    // In server-only mode, return the server service URL
    const char* url = dart_server_get_service_url();
    if (url != nullptr) {
        return env->NewStringUTF(url);
    }
    return nullptr;
}

// ==========================================================================
// Chat Callback Setup
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    setSendChatCallback
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_setSendChatCallback(
    JNIEnv* env, jclass cls) {

    // Get JVM reference
    if (g_jvm == nullptr) {
        env->GetJavaVM(&g_jvm);
        dart_server_set_jvm(g_jvm);
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
    server_set_send_chat_message_callback(jni_send_chat_message);
    std::cout << "JNI: Chat message callback set up successfully" << std::endl;
}

// ==========================================================================
// Flutter Stubs (no-op in server-only mode)
// ==========================================================================

// Only compile the stub in server-only builds. In full builds, the real
// implementation exists in dart_bridge.cpp and we'd get duplicate symbols.
#ifdef SERVER_ONLY_BUILD
/*
 * Class:     com_redstone_DartBridge
 * Method:    processFlutterTasks
 * Signature: ()V
 *
 * In server-only mode, this is a no-op stub.
 * The full build has the real implementation in dart_bridge.cpp.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_processFlutterTasks(
    JNIEnv* /* env */, jclass /* cls */) {
    // No-op in server-only mode - Flutter is not available
}
#endif

// ==========================================================================
// Server-side Event Dispatching (routes to server runtime)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    onServerBlockBreak
 * Signature: (IIIJ)I
 *
 * Server-side block break event.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridge_onServerBlockBreak(
    JNIEnv* /* env */, jclass /* cls */,
    jint x, jint y, jint z, jlong player_id) {
    return server_dispatch_block_break(x, y, z, player_id);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onBlockBreak
 * Signature: (IIIJ)I
 *
 * Server-side block break event (alias for Java compatibility).
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridge_onBlockBreak(
    JNIEnv* /* env */, jclass /* cls */,
    jint x, jint y, jint z, jlong player_id) {
    return server_dispatch_block_break(x, y, z, player_id);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onBlockInteract
 * Signature: (IIIJI)I
 *
 * Server-side block interact event.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridge_onBlockInteract(
    JNIEnv* /* env */, jclass /* cls */,
    jint x, jint y, jint z, jlong player_id, jint hand) {
    return server_dispatch_block_interact(x, y, z, player_id, hand);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onTick
 * Signature: (J)V
 *
 * Server-side tick event (called from DartBridge.dispatchTick).
 * CRITICAL: Uses server_dispatch_tick from dart_bridge_server.h
 * Since dart_bridge.h is NOT included, the old dispatch_tick() literally does not exist here!
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onTick(
    JNIEnv* /* env */, jclass /* cls */, jlong tick) {
    server_dispatch_tick(tick);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onPlayerJoin
 * Signature: (I)V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onPlayerJoin(
    JNIEnv* /* env */, jclass /* cls */, jint playerId) {
    server_dispatch_player_join(static_cast<int32_t>(playerId));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onPlayerLeave
 * Signature: (I)V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onPlayerLeave(
    JNIEnv* /* env */, jclass /* cls */, jint playerId) {
    server_dispatch_player_leave(static_cast<int32_t>(playerId));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onServerStarting
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onServerStarting(
    JNIEnv* /* env */, jclass /* cls */) {
    server_dispatch_server_starting();
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onServerStarted
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onServerStarted(
    JNIEnv* /* env */, jclass /* cls */) {
    server_dispatch_server_started();
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onServerStopping
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onServerStopping(
    JNIEnv* /* env */, jclass /* cls */) {
    server_dispatch_server_stopping();
}

// ==========================================================================
// Proxy Block JNI Entry Points (server-side)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyBlockBreak
 * Signature: (JJIIIJ)Z
 *
 * Called from Java proxy blocks when they are broken.
 * Routes to Dart's BlockRegistry.dispatchBlockBreak().
 * Returns true if break should be allowed, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_onProxyBlockBreak(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handler_id, jlong world_id,
    jint x, jint y, jint z, jlong player_id) {

    return server_dispatch_proxy_block_break(handler_id, world_id, x, y, z, player_id) ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyBlockUse
 * Signature: (JJIIIJI)I
 *
 * Called from Java proxy blocks when they are used (right-clicked).
 * Routes to Dart's BlockRegistry.dispatchBlockUse().
 * Returns ActionResult ordinal.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridge_onProxyBlockUse(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handler_id, jlong world_id,
    jint x, jint y, jint z, jlong player_id, jint hand) {

    return server_dispatch_proxy_block_use(handler_id, world_id, x, y, z, player_id, hand);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyBlockPlaced
 * Signature: (JJIIIJ)V
 *
 * Called from Java proxy blocks when they are placed in the world.
 * Routes to Dart's BlockRegistry.dispatchBlockPlaced().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyBlockPlaced(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handler_id, jlong world_id,
    jint x, jint y, jint z, jlong player_id) {

    server_dispatch_proxy_block_placed(handler_id, world_id, x, y, z, player_id);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyBlockSteppedOn
 * Signature: (JJIIII)V
 *
 * Called when an entity steps on a Dart-defined block.
 * Routes to Dart's BlockRegistry.dispatchBlockSteppedOn().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyBlockSteppedOn(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handler_id, jlong world_id,
    jint x, jint y, jint z, jint entity_id) {

    server_dispatch_proxy_block_stepped_on(
        static_cast<int64_t>(handler_id),
        static_cast<int64_t>(world_id),
        static_cast<int32_t>(x),
        static_cast<int32_t>(y),
        static_cast<int32_t>(z),
        static_cast<int32_t>(entity_id));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyBlockFallenUpon
 * Signature: (JJIIIIF)V
 *
 * Called when an entity falls upon a Dart-defined block.
 * Routes to Dart's BlockRegistry.dispatchBlockFallenUpon().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyBlockFallenUpon(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handler_id, jlong world_id,
    jint x, jint y, jint z, jint entity_id, jfloat fall_distance) {

    server_dispatch_proxy_block_fallen_upon(
        static_cast<int64_t>(handler_id),
        static_cast<int64_t>(world_id),
        static_cast<int32_t>(x),
        static_cast<int32_t>(y),
        static_cast<int32_t>(z),
        static_cast<int32_t>(entity_id),
        static_cast<float>(fall_distance));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyBlockRandomTick
 * Signature: (JJIII)V
 *
 * Called on random tick for a Dart-defined block.
 * Routes to Dart's BlockRegistry.dispatchBlockRandomTick().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyBlockRandomTick(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handler_id, jlong world_id,
    jint x, jint y, jint z) {

    server_dispatch_proxy_block_random_tick(
        static_cast<int64_t>(handler_id),
        static_cast<int64_t>(world_id),
        static_cast<int32_t>(x),
        static_cast<int32_t>(y),
        static_cast<int32_t>(z));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyBlockRemoved
 * Signature: (JJIII)V
 *
 * Called when a Dart-defined block is removed from the world.
 * Routes to Dart's BlockRegistry.dispatchBlockRemoved().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyBlockRemoved(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handler_id, jlong world_id,
    jint x, jint y, jint z) {

    server_dispatch_proxy_block_removed(
        static_cast<int64_t>(handler_id),
        static_cast<int64_t>(world_id),
        static_cast<int32_t>(x),
        static_cast<int32_t>(y),
        static_cast<int32_t>(z));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyBlockNeighborChanged
 * Signature: (JJIIIII)V
 *
 * Called when a neighbor of a Dart-defined block changes.
 * Routes to Dart's BlockRegistry.dispatchBlockNeighborChanged().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyBlockNeighborChanged(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handler_id, jlong world_id,
    jint x, jint y, jint z,
    jint neighbor_x, jint neighbor_y, jint neighbor_z) {

    server_dispatch_proxy_block_neighbor_changed(
        static_cast<int64_t>(handler_id),
        static_cast<int64_t>(world_id),
        static_cast<int32_t>(x),
        static_cast<int32_t>(y),
        static_cast<int32_t>(z),
        static_cast<int32_t>(neighbor_x),
        static_cast<int32_t>(neighbor_y),
        static_cast<int32_t>(neighbor_z));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyBlockEntityInside
 * Signature: (JJIIII)V
 *
 * Called when an entity is inside a Dart-defined block.
 * Routes to Dart's BlockRegistry.dispatchBlockEntityInside().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyBlockEntityInside(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handler_id, jlong world_id,
    jint x, jint y, jint z, jint entity_id) {

    server_dispatch_proxy_block_entity_inside(
        static_cast<int64_t>(handler_id),
        static_cast<int64_t>(world_id),
        static_cast<int32_t>(x),
        static_cast<int32_t>(y),
        static_cast<int32_t>(z),
        static_cast<int32_t>(entity_id));
}

// ==========================================================================
// Player Event JNI Entry Points (server-side)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    onPlayerRespawn
 * Signature: (IZ)V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onPlayerRespawn(
    JNIEnv* /* env */, jclass /* cls */, jint playerId, jboolean endConquered) {
    server_dispatch_player_respawn(static_cast<int32_t>(playerId), endConquered == JNI_TRUE);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onPlayerDeath
 * Signature: (ILjava/lang/String;)Ljava/lang/String;
 *
 * Returns custom death message or null for default.
 */
JNIEXPORT jstring JNICALL Java_com_redstone_DartBridge_onPlayerDeath(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring damageSource) {
    const char* source = env->GetStringUTFChars(damageSource, nullptr);
    char* result = server_dispatch_player_death(static_cast<int32_t>(playerId), source);
    env->ReleaseStringUTFChars(damageSource, source);

    if (result != nullptr) {
        jstring jresult = env->NewStringUTF(result);
        return jresult;
    }
    return nullptr;
}

// ==========================================================================
// Entity Event JNI Entry Points (server-side)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    onEntityDamage
 * Signature: (ILjava/lang/String;D)Z
 *
 * Returns true to allow damage, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_onEntityDamage(
    JNIEnv* env, jclass /* cls */, jint entityId, jstring damageSource, jdouble amount) {
    const char* source = env->GetStringUTFChars(damageSource, nullptr);
    bool result = server_dispatch_entity_damage(static_cast<int32_t>(entityId), source, static_cast<double>(amount));
    env->ReleaseStringUTFChars(damageSource, source);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onEntityDeath
 * Signature: (ILjava/lang/String;)V
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onEntityDeath(
    JNIEnv* env, jclass /* cls */, jint entityId, jstring damageSource) {
    const char* source = env->GetStringUTFChars(damageSource, nullptr);
    server_dispatch_entity_death(static_cast<int32_t>(entityId), source);
    env->ReleaseStringUTFChars(damageSource, source);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onPlayerAttackEntity
 * Signature: (II)Z
 *
 * Returns true to allow attack, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_onPlayerAttackEntity(
    JNIEnv* /* env */, jclass /* cls */, jint playerId, jint targetId) {
    bool result = server_dispatch_player_attack_entity(static_cast<int32_t>(playerId), static_cast<int32_t>(targetId));
    return result ? JNI_TRUE : JNI_FALSE;
}

// ==========================================================================
// Chat/Command Event JNI Entry Points (server-side)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    onPlayerChat
 * Signature: (ILjava/lang/String;)Ljava/lang/String;
 *
 * Returns modified message, original to pass through, or null to cancel.
 */
JNIEXPORT jstring JNICALL Java_com_redstone_DartBridge_onPlayerChat(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring message) {
    const char* msg = env->GetStringUTFChars(message, nullptr);
    char* result = server_dispatch_player_chat(static_cast<int32_t>(playerId), msg);
    env->ReleaseStringUTFChars(message, msg);

    if (result != nullptr) {
        jstring jresult = env->NewStringUTF(result);
        return jresult;
    }
    return nullptr;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onPlayerCommand
 * Signature: (ILjava/lang/String;)Z
 *
 * Returns true to allow command, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_onPlayerCommand(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring command) {
    const char* cmd = env->GetStringUTFChars(command, nullptr);
    bool result = server_dispatch_player_command(static_cast<int32_t>(playerId), cmd);
    env->ReleaseStringUTFChars(command, cmd);
    return result ? JNI_TRUE : JNI_FALSE;
}

// ==========================================================================
// Item Event JNI Entry Points (server-side)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    onItemUse
 * Signature: (ILjava/lang/String;II)Z
 *
 * Returns true to allow use, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_onItemUse(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring itemId, jint count, jint hand) {
    const char* item = env->GetStringUTFChars(itemId, nullptr);
    bool result = server_dispatch_item_use(static_cast<int32_t>(playerId), item,
                                    static_cast<int32_t>(count), static_cast<int32_t>(hand));
    env->ReleaseStringUTFChars(itemId, item);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onItemUseOnBlock
 * Signature: (ILjava/lang/String;IIIIII)I
 *
 * Returns EventResult value.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridge_onItemUseOnBlock(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring itemId, jint count, jint hand,
    jint x, jint y, jint z, jint face) {
    const char* item = env->GetStringUTFChars(itemId, nullptr);
    int32_t result = server_dispatch_item_use_on_block(
        static_cast<int32_t>(playerId), item, static_cast<int32_t>(count), static_cast<int32_t>(hand),
        static_cast<int32_t>(x), static_cast<int32_t>(y), static_cast<int32_t>(z), static_cast<int32_t>(face));
    env->ReleaseStringUTFChars(itemId, item);
    return static_cast<jint>(result);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onItemUseOnEntity
 * Signature: (ILjava/lang/String;III)I
 *
 * Returns EventResult value.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridge_onItemUseOnEntity(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring itemId, jint count, jint hand, jint targetId) {
    const char* item = env->GetStringUTFChars(itemId, nullptr);
    int32_t result = server_dispatch_item_use_on_entity(
        static_cast<int32_t>(playerId), item, static_cast<int32_t>(count), static_cast<int32_t>(hand),
        static_cast<int32_t>(targetId));
    env->ReleaseStringUTFChars(itemId, item);
    return static_cast<jint>(result);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onBlockPlace
 * Signature: (IIIILjava/lang/String;)Z
 *
 * Returns true to allow placement, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_onBlockPlace(
    JNIEnv* env, jclass /* cls */, jint playerId, jint x, jint y, jint z, jstring blockId) {
    const char* block = env->GetStringUTFChars(blockId, nullptr);
    bool result = server_dispatch_block_place(static_cast<int32_t>(playerId),
                                       static_cast<int32_t>(x), static_cast<int32_t>(y), static_cast<int32_t>(z),
                                       block);
    env->ReleaseStringUTFChars(blockId, block);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onPlayerPickupItem
 * Signature: (II)Z
 *
 * Returns true to allow pickup, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_onPlayerPickupItem(
    JNIEnv* /* env */, jclass /* cls */, jint playerId, jint itemEntityId) {
    bool result = server_dispatch_player_pickup_item(static_cast<int32_t>(playerId), static_cast<int32_t>(itemEntityId));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onPlayerDropItem
 * Signature: (ILjava/lang/String;I)Z
 *
 * Returns true to allow drop, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_onPlayerDropItem(
    JNIEnv* env, jclass /* cls */, jint playerId, jstring itemId, jint count) {
    const char* item = env->GetStringUTFChars(itemId, nullptr);
    bool result = server_dispatch_player_drop_item(static_cast<int32_t>(playerId), item, static_cast<int32_t>(count));
    env->ReleaseStringUTFChars(itemId, item);
    return result ? JNI_TRUE : JNI_FALSE;
}

// ==========================================================================
// Entity Proxy JNI Entry Points (server-side)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyEntitySpawn
 * Signature: (JIJ)V
 *
 * Called when a Dart-defined entity is spawned.
 * Routes to Dart's EntityRegistry.dispatchSpawn().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyEntitySpawn(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handlerId, jint entityId, jlong worldId) {
    server_dispatch_proxy_entity_spawn(static_cast<int64_t>(handlerId),
                                 static_cast<int32_t>(entityId),
                                 static_cast<int64_t>(worldId));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyEntityTick
 * Signature: (JI)V
 *
 * Called every tick for a Dart-defined entity.
 * Routes to Dart's EntityRegistry.dispatchTick().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyEntityTick(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handlerId, jint entityId) {
    server_dispatch_proxy_entity_tick(static_cast<int64_t>(handlerId),
                                static_cast<int32_t>(entityId));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyEntityDeath
 * Signature: (JILjava/lang/String;)V
 *
 * Called when a Dart-defined entity dies.
 * Routes to Dart's EntityRegistry.dispatchDeath().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyEntityDeath(
    JNIEnv* env, jclass /* cls */,
    jlong handlerId, jint entityId, jstring damageSource) {
    const char* source = env->GetStringUTFChars(damageSource, nullptr);
    server_dispatch_proxy_entity_death(static_cast<int64_t>(handlerId),
                                 static_cast<int32_t>(entityId),
                                 source);
    env->ReleaseStringUTFChars(damageSource, source);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyEntityDamage
 * Signature: (JILjava/lang/String;F)Z
 *
 * Called when a Dart-defined entity takes damage.
 * Routes to Dart's EntityRegistry.dispatchDamage().
 * Returns true to allow damage, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_onProxyEntityDamage(
    JNIEnv* env, jclass /* cls */,
    jlong handlerId, jint entityId, jstring damageSource, jfloat amount) {
    const char* source = env->GetStringUTFChars(damageSource, nullptr);
    bool result = server_dispatch_proxy_entity_damage(static_cast<int64_t>(handlerId),
                                                static_cast<int32_t>(entityId),
                                                source,
                                                static_cast<double>(amount));
    env->ReleaseStringUTFChars(damageSource, source);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyEntityAttack
 * Signature: (JII)V
 *
 * Called when a Dart-defined entity attacks another entity.
 * Routes to Dart's EntityRegistry.dispatchAttack().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyEntityAttack(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handlerId, jint entityId, jint targetId) {
    server_dispatch_proxy_entity_attack(static_cast<int64_t>(handlerId),
                                  static_cast<int32_t>(entityId),
                                  static_cast<int32_t>(targetId));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyEntityTarget
 * Signature: (JII)V
 *
 * Called when a Dart-defined entity targets another entity.
 * Routes to Dart's EntityRegistry.dispatchTargetAcquired().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyEntityTarget(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handlerId, jint entityId, jint targetId) {
    server_dispatch_proxy_entity_target(static_cast<int64_t>(handlerId),
                                  static_cast<int32_t>(entityId),
                                  static_cast<int32_t>(targetId));
}

// ==========================================================================
// Projectile Proxy JNI Entry Points (server-side)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyProjectileHitEntity
 * Signature: (JII)V
 *
 * Called when a Dart-defined projectile hits an entity.
 * Routes to Dart's EntityRegistry.dispatchProjectileHitEntity().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyProjectileHitEntity(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handlerId, jint projectileId, jint targetId) {
    server_dispatch_proxy_projectile_hit_entity(
        static_cast<int64_t>(handlerId),
        static_cast<int32_t>(projectileId),
        static_cast<int32_t>(targetId));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyProjectileHitBlock
 * Signature: (JIIIILjava/lang/String;)V
 *
 * Called when a Dart-defined projectile hits a block.
 * Routes to Dart's EntityRegistry.dispatchProjectileHitBlock().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyProjectileHitBlock(
    JNIEnv* env, jclass /* cls */,
    jlong handlerId, jint projectileId, jint x, jint y, jint z, jstring side) {
    const char* side_str = env->GetStringUTFChars(side, nullptr);
    server_dispatch_proxy_projectile_hit_block(
        static_cast<int64_t>(handlerId),
        static_cast<int32_t>(projectileId),
        static_cast<int32_t>(x),
        static_cast<int32_t>(y),
        static_cast<int32_t>(z),
        side_str);
    env->ReleaseStringUTFChars(side, side_str);
}

// ==========================================================================
// Animal Proxy JNI Entry Points (server-side)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyAnimalBreed
 * Signature: (JIII)V
 *
 * Called when a Dart-defined animal breeds.
 * Routes to Dart's EntityRegistry.dispatchAnimalBreed().
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onProxyAnimalBreed(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handlerId, jint entityId, jint partnerId, jint babyId) {
    server_dispatch_proxy_animal_breed(
        static_cast<int64_t>(handlerId),
        static_cast<int32_t>(entityId),
        static_cast<int32_t>(partnerId),
        static_cast<int32_t>(babyId));
}

// ==========================================================================
// Item Proxy JNI Entry Points (server-side)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyItemAttackEntity
 * Signature: (JIII)Z
 *
 * Called when a Dart-defined item is used to attack an entity.
 * Routes to Dart's ItemRegistry.dispatchItemAttackEntity().
 * Returns true to allow attack, false to cancel.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_onProxyItemAttackEntity(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handlerId, jint worldId, jint attackerId, jint targetId) {
    bool result = server_dispatch_proxy_item_attack_entity(
        static_cast<int64_t>(handlerId),
        static_cast<int32_t>(worldId),
        static_cast<int32_t>(attackerId),
        static_cast<int32_t>(targetId));
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyItemUse
 * Signature: (JJII)I
 *
 * Called when a Dart-defined item is used (right-click in air).
 * Routes to Dart's ItemRegistry.dispatchItemUse().
 * Returns ItemActionResult ordinal (0=SUCCESS, 1=CONSUME_PARTIAL, 2=CONSUME, 3=FAIL, 4=PASS).
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridge_onProxyItemUse(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handlerId, jlong worldId, jint playerId, jint hand) {
    return static_cast<jint>(server_dispatch_proxy_item_use(
        static_cast<int64_t>(handlerId),
        static_cast<int64_t>(worldId),
        static_cast<int32_t>(playerId),
        static_cast<int32_t>(hand)));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyItemUseOnBlock
 * Signature: (JJIIIII)I
 *
 * Called when a Dart-defined item is used on a block.
 * Routes to Dart's ItemRegistry.dispatchItemUseOnBlock().
 * Returns ItemActionResult ordinal (0=SUCCESS, 1=CONSUME_PARTIAL, 2=CONSUME, 3=FAIL, 4=PASS).
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridge_onProxyItemUseOnBlock(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handlerId, jlong worldId, jint x, jint y, jint z, jint playerId, jint hand) {
    return static_cast<jint>(server_dispatch_proxy_item_use_on_block(
        static_cast<int64_t>(handlerId),
        static_cast<int64_t>(worldId),
        static_cast<int32_t>(x),
        static_cast<int32_t>(y),
        static_cast<int32_t>(z),
        static_cast<int32_t>(playerId),
        static_cast<int32_t>(hand)));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onProxyItemUseOnEntity
 * Signature: (JJIII)I
 *
 * Called when a Dart-defined item is used on an entity.
 * Routes to Dart's ItemRegistry.dispatchItemUseOnEntity().
 * Returns ItemActionResult ordinal (0=SUCCESS, 1=CONSUME_PARTIAL, 2=CONSUME, 3=FAIL, 4=PASS).
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridge_onProxyItemUseOnEntity(
    JNIEnv* /* env */, jclass /* cls */,
    jlong handlerId, jlong worldId, jint entityId, jint playerId, jint hand) {
    return static_cast<jint>(server_dispatch_proxy_item_use_on_entity(
        static_cast<int64_t>(handlerId),
        static_cast<int64_t>(worldId),
        static_cast<int32_t>(entityId),
        static_cast<int32_t>(playerId),
        static_cast<int32_t>(hand)));
}

// ==========================================================================
// Command System JNI
// ==========================================================================

JNIEXPORT jint JNICALL Java_com_redstone_DartBridge_onCommandExecute(
    JNIEnv* env, jclass /* cls */,
    jlong commandId, jint playerId, jstring argsJson) {
    const char* args = argsJson ? env->GetStringUTFChars(argsJson, nullptr) : "";
    jint result = static_cast<jint>(server_dispatch_command_execute(
        static_cast<int64_t>(commandId),
        static_cast<int32_t>(playerId),
        args));
    if (argsJson) {
        env->ReleaseStringUTFChars(argsJson, args);
    }
    return result;
}

// ==========================================================================
// Registry Ready JNI Entry Point
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    signalRegistryReady
 * Signature: ()V
 *
 * Called from Java when Minecraft registries are ready.
 * This signals to Dart that it's safe to register items/blocks.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_signalRegistryReady(
    JNIEnv* /* env */, jclass /* cls */) {
    server_dispatch_registry_ready();
}

// ==========================================================================
// Custom Goal JNI Entry Points
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    nativeOnCustomGoalCanUse
 * Signature: (Ljava/lang/String;I)Z
 *
 * Called from Java DartGoal to check if the goal can start.
 * Returns true if the goal can be used, false otherwise.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_nativeOnCustomGoalCanUse(
    JNIEnv* env, jclass /* cls */, jstring goalId, jint entityId) {
    const char* goal_id = env->GetStringUTFChars(goalId, nullptr);
    bool result = server_dispatch_custom_goal_can_use(goal_id, static_cast<int32_t>(entityId));
    env->ReleaseStringUTFChars(goalId, goal_id);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    nativeOnCustomGoalCanContinueToUse
 * Signature: (Ljava/lang/String;I)Z
 *
 * Called from Java DartGoal to check if the goal should continue running.
 * Returns true if the goal should continue, false to stop.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_nativeOnCustomGoalCanContinueToUse(
    JNIEnv* env, jclass /* cls */, jstring goalId, jint entityId) {
    const char* goal_id = env->GetStringUTFChars(goalId, nullptr);
    bool result = server_dispatch_custom_goal_can_continue_to_use(goal_id, static_cast<int32_t>(entityId));
    env->ReleaseStringUTFChars(goalId, goal_id);
    return result ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    nativeOnCustomGoalStart
 * Signature: (Ljava/lang/String;I)V
 *
 * Called from Java DartGoal when the goal starts running.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_nativeOnCustomGoalStart(
    JNIEnv* env, jclass /* cls */, jstring goalId, jint entityId) {
    const char* goal_id = env->GetStringUTFChars(goalId, nullptr);
    server_dispatch_custom_goal_start(goal_id, static_cast<int32_t>(entityId));
    env->ReleaseStringUTFChars(goalId, goal_id);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    nativeOnCustomGoalTick
 * Signature: (Ljava/lang/String;I)V
 *
 * Called from Java DartGoal every tick while the goal is active.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_nativeOnCustomGoalTick(
    JNIEnv* env, jclass /* cls */, jstring goalId, jint entityId) {
    const char* goal_id = env->GetStringUTFChars(goalId, nullptr);
    server_dispatch_custom_goal_tick(goal_id, static_cast<int32_t>(entityId));
    env->ReleaseStringUTFChars(goalId, goal_id);
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    nativeOnCustomGoalStop
 * Signature: (Ljava/lang/String;I)V
 *
 * Called from Java DartGoal when the goal stops running.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_nativeOnCustomGoalStop(
    JNIEnv* env, jclass /* cls */, jstring goalId, jint entityId) {
    const char* goal_id = env->GetStringUTFChars(goalId, nullptr);
    server_dispatch_custom_goal_stop(goal_id, static_cast<int32_t>(entityId));
    env->ReleaseStringUTFChars(goalId, goal_id);
}

// ==========================================================================
// Registration Queue JNI Methods
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    areRegistrationsQueued
 * Signature: ()Z
 *
 * Check if Dart has finished queueing registrations.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_areRegistrationsQueued(
    JNIEnv* /* env */, jclass /* cls */) {
    // Note: This function needs to check server-side state.
    // The implementation should be in dart_bridge_server.cpp
    // For now, we return false until proper implementation.
    // TODO: Add are_registrations_queued to server header if needed
    return JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    hasPendingBlockRegistrations
 * Signature: ()Z
 *
 * Check if there are pending block registrations in the queue.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_hasPendingBlockRegistrations(
    JNIEnv* /* env */, jclass /* cls */) {
    return server_has_pending_block_registrations() ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    hasPendingItemRegistrations
 * Signature: ()Z
 *
 * Check if there are pending item registrations in the queue.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_hasPendingItemRegistrations(
    JNIEnv* /* env */, jclass /* cls */) {
    return server_has_pending_item_registrations() ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    hasPendingEntityRegistrations
 * Signature: ()Z
 *
 * Check if there are pending entity registrations in the queue.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_hasPendingEntityRegistrations(
    JNIEnv* /* env */, jclass /* cls */) {
    return server_has_pending_entity_registrations() ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    getNextBlockRegistration
 * Signature: ()[Ljava/lang/Object;
 *
 * Get the next block registration from the queue.
 * Returns an Object array: [handlerId(Long), namespace(String), path(String),
 *                           hardness(Float), resistance(Float), requiresTool(Boolean),
 *                           luminance(Integer), slipperiness(Double), velocityMult(Double),
 *                           jumpVelocityMult(Double), ticksRandomly(Boolean),
 *                           collidable(Boolean), replaceable(Boolean), burnable(Boolean)]
 * Returns null if the queue is empty.
 */
JNIEXPORT jobjectArray JNICALL Java_com_redstone_DartBridge_getNextBlockRegistration(
    JNIEnv* env, jclass /* cls */) {

    int64_t handler_id;
    char namespace_buf[256];
    char path_buf[256];
    float hardness, resistance;
    bool requires_tool;
    int32_t luminance;
    double slipperiness, velocity_mult, jump_velocity_mult;
    bool ticks_randomly, collidable, replaceable, burnable;

    if (!server_get_next_block_registration(
            &handler_id,
            namespace_buf, sizeof(namespace_buf),
            path_buf, sizeof(path_buf),
            &hardness,
            &resistance,
            &requires_tool,
            &luminance,
            &slipperiness,
            &velocity_mult,
            &jump_velocity_mult,
            &ticks_randomly,
            &collidable,
            &replaceable,
            &burnable)) {
        return nullptr;
    }

    // Create Object array with 14 elements
    jclass objectClass = env->FindClass("java/lang/Object");
    jobjectArray result = env->NewObjectArray(14, objectClass, nullptr);

    // Use shared boxing helpers from jni_helpers.h
    env->SetObjectArrayElement(result, 0, boxLong(env, static_cast<jlong>(handler_id)));
    env->SetObjectArrayElement(result, 1, env->NewStringUTF(namespace_buf));
    env->SetObjectArrayElement(result, 2, env->NewStringUTF(path_buf));
    env->SetObjectArrayElement(result, 3, boxFloat(env, hardness));
    env->SetObjectArrayElement(result, 4, boxFloat(env, resistance));
    env->SetObjectArrayElement(result, 5, boxBool(env, requires_tool ? JNI_TRUE : JNI_FALSE));
    env->SetObjectArrayElement(result, 6, boxInt(env, luminance));
    env->SetObjectArrayElement(result, 7, boxDouble(env, slipperiness));
    env->SetObjectArrayElement(result, 8, boxDouble(env, velocity_mult));
    env->SetObjectArrayElement(result, 9, boxDouble(env, jump_velocity_mult));
    env->SetObjectArrayElement(result, 10, boxBool(env, ticks_randomly ? JNI_TRUE : JNI_FALSE));
    env->SetObjectArrayElement(result, 11, boxBool(env, collidable ? JNI_TRUE : JNI_FALSE));
    env->SetObjectArrayElement(result, 12, boxBool(env, replaceable ? JNI_TRUE : JNI_FALSE));
    env->SetObjectArrayElement(result, 13, boxBool(env, burnable ? JNI_TRUE : JNI_FALSE));

    return result;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    getNextItemRegistration
 * Signature: ()[Ljava/lang/Object;
 *
 * Get the next item registration from the queue.
 * Returns an Object array: [handlerId(Long), namespace(String), path(String),
 *                           maxStackSize(Integer), maxDamage(Integer), fireResistant(Boolean),
 *                           attackDamage(Double), attackSpeed(Double), attackKnockback(Double)]
 * Returns null if the queue is empty.
 */
JNIEXPORT jobjectArray JNICALL Java_com_redstone_DartBridge_getNextItemRegistration(
    JNIEnv* env, jclass /* cls */) {

    int64_t handler_id;
    char namespace_buf[256];
    char path_buf[256];
    int32_t max_stack_size, max_damage;
    bool fire_resistant;
    double attack_damage, attack_speed, attack_knockback;

    if (!server_get_next_item_registration(
            &handler_id,
            namespace_buf, sizeof(namespace_buf),
            path_buf, sizeof(path_buf),
            &max_stack_size,
            &max_damage,
            &fire_resistant,
            &attack_damage,
            &attack_speed,
            &attack_knockback)) {
        return nullptr;
    }

    // Create Object array with 9 elements
    jclass objectClass = env->FindClass("java/lang/Object");
    jobjectArray result = env->NewObjectArray(9, objectClass, nullptr);

    // Use shared boxing helpers from jni_helpers.h
    env->SetObjectArrayElement(result, 0, boxLong(env, static_cast<jlong>(handler_id)));
    env->SetObjectArrayElement(result, 1, env->NewStringUTF(namespace_buf));
    env->SetObjectArrayElement(result, 2, env->NewStringUTF(path_buf));
    env->SetObjectArrayElement(result, 3, boxInt(env, max_stack_size));
    env->SetObjectArrayElement(result, 4, boxInt(env, max_damage));
    env->SetObjectArrayElement(result, 5, boxBool(env, fire_resistant ? JNI_TRUE : JNI_FALSE));
    env->SetObjectArrayElement(result, 6, boxDouble(env, attack_damage));
    env->SetObjectArrayElement(result, 7, boxDouble(env, attack_speed));
    env->SetObjectArrayElement(result, 8, boxDouble(env, attack_knockback));

    return result;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    getNextEntityRegistration
 * Signature: ()[Ljava/lang/Object;
 *
 * Get the next entity registration from the queue.
 * Returns an Object array: [handlerId(Long), namespace(String), path(String),
 *                           width(Double), height(Double), maxHealth(Double),
 *                           movementSpeed(Double), attackDamage(Double),
 *                           spawnGroup(Integer), baseType(Integer),
 *                           breedingItem(String), modelType(String), texturePath(String),
 *                           modelScale(Double), goalsJson(String), targetGoalsJson(String)]
 * Returns null if the queue is empty.
 */
JNIEXPORT jobjectArray JNICALL Java_com_redstone_DartBridge_getNextEntityRegistration(
    JNIEnv* env, jclass /* cls */) {

    int64_t handler_id;
    char namespace_buf[256];
    char path_buf[256];
    double width, height, max_health, movement_speed, attack_damage;
    int32_t spawn_group, base_type;
    char breeding_item_buf[256];
    char model_type_buf[256];
    char texture_path_buf[512];
    double model_scale;
    char goals_json_buf[4096];
    char target_goals_json_buf[4096];

    if (!server_get_next_entity_registration(
            &handler_id,
            namespace_buf, sizeof(namespace_buf),
            path_buf, sizeof(path_buf),
            &width,
            &height,
            &max_health,
            &movement_speed,
            &attack_damage,
            &spawn_group,
            &base_type,
            breeding_item_buf, sizeof(breeding_item_buf),
            model_type_buf, sizeof(model_type_buf),
            texture_path_buf, sizeof(texture_path_buf),
            &model_scale,
            goals_json_buf, sizeof(goals_json_buf),
            target_goals_json_buf, sizeof(target_goals_json_buf))) {
        return nullptr;
    }

    // Create Object array with 16 elements
    jclass objectClass = env->FindClass("java/lang/Object");
    jobjectArray result = env->NewObjectArray(16, objectClass, nullptr);

    // Use shared boxing helpers from jni_helpers.h
    env->SetObjectArrayElement(result, 0, boxLong(env, static_cast<jlong>(handler_id)));
    env->SetObjectArrayElement(result, 1, env->NewStringUTF(namespace_buf));
    env->SetObjectArrayElement(result, 2, env->NewStringUTF(path_buf));
    env->SetObjectArrayElement(result, 3, boxDouble(env, width));
    env->SetObjectArrayElement(result, 4, boxDouble(env, height));
    env->SetObjectArrayElement(result, 5, boxDouble(env, max_health));
    env->SetObjectArrayElement(result, 6, boxDouble(env, movement_speed));
    env->SetObjectArrayElement(result, 7, boxDouble(env, attack_damage));
    env->SetObjectArrayElement(result, 8, boxInt(env, spawn_group));
    env->SetObjectArrayElement(result, 9, boxInt(env, base_type));
    env->SetObjectArrayElement(result, 10, env->NewStringUTF(breeding_item_buf));
    env->SetObjectArrayElement(result, 11, env->NewStringUTF(model_type_buf));
    env->SetObjectArrayElement(result, 12, env->NewStringUTF(texture_path_buf));
    env->SetObjectArrayElement(result, 13, boxDouble(env, model_scale));
    env->SetObjectArrayElement(result, 14, env->NewStringUTF(goals_json_buf));
    env->SetObjectArrayElement(result, 15, env->NewStringUTF(target_goals_json_buf));

    return result;
}

// ==========================================================================
// Block Entity JNI Entry Points (server-side)
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    onBlockEntityLoad
 * Signature: (IJLjava/lang/String;)V
 *
 * Called when a block entity is loaded from NBT.
 * Routes to Dart's BlockEntityRegistry for state restoration.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onBlockEntityLoad(
    JNIEnv* env, jclass /* cls */,
    jint handler_id, jlong block_pos_hash, jstring nbt_json) {
    const char* nbt_str = nbt_json ? env->GetStringUTFChars(nbt_json, nullptr) : "{}";
    server_dispatch_block_entity_load(
        static_cast<int32_t>(handler_id),
        static_cast<int64_t>(block_pos_hash),
        nbt_str);
    if (nbt_json) {
        env->ReleaseStringUTFChars(nbt_json, nbt_str);
    }
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onBlockEntitySave
 * Signature: (IJ)Ljava/lang/String;
 *
 * Called when a block entity needs to save its state to NBT.
 * Returns JSON string of NBT data to save.
 */
JNIEXPORT jstring JNICALL Java_com_redstone_DartBridge_onBlockEntitySave(
    JNIEnv* env, jclass /* cls */,
    jint handler_id, jlong block_pos_hash) {
    const char* result = server_dispatch_block_entity_save(
        static_cast<int32_t>(handler_id),
        static_cast<int64_t>(block_pos_hash));
    return env->NewStringUTF(result ? result : "{}");
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onBlockEntityTick
 * Signature: (IJ)V
 *
 * Called every tick for a block entity.
 * Routes to Dart's BlockEntityRegistry for tick processing.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onBlockEntityTick(
    JNIEnv* /* env */, jclass /* cls */,
    jint handler_id, jlong block_pos_hash) {
    server_dispatch_block_entity_tick(
        static_cast<int32_t>(handler_id),
        static_cast<int64_t>(block_pos_hash));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    getBlockEntityDataSlot
 * Signature: (IJI)I
 *
 * Gets a data slot value from a block entity (for container data sync).
 * Used for furnace progress bars, etc.
 */
JNIEXPORT jint JNICALL Java_com_redstone_DartBridge_getBlockEntityDataSlot(
    JNIEnv* /* env */, jclass /* cls */,
    jint handler_id, jlong block_pos_hash, jint index) {
    return static_cast<jint>(server_dispatch_block_entity_get_data_slot(
        static_cast<int32_t>(handler_id),
        static_cast<int64_t>(block_pos_hash),
        static_cast<int32_t>(index)));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    setBlockEntityDataSlot
 * Signature: (IJII)V
 *
 * Sets a data slot value on a block entity (for container data sync).
 * Called from client-side when data is synced.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_setBlockEntityDataSlot(
    JNIEnv* /* env */, jclass /* cls */,
    jint handler_id, jlong block_pos_hash, jint index, jint value) {
    server_dispatch_block_entity_set_data_slot(
        static_cast<int32_t>(handler_id),
        static_cast<int64_t>(block_pos_hash),
        static_cast<int32_t>(index),
        static_cast<int32_t>(value));
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    onBlockEntityRemoved
 * Signature: (IJ)V
 *
 * Called when a block entity is removed from the world.
 * Routes to Dart for cleanup.
 */
JNIEXPORT void JNICALL Java_com_redstone_DartBridge_onBlockEntityRemoved(
    JNIEnv* /* env */, jclass /* cls */,
    jint handler_id, jlong block_pos_hash) {
    server_dispatch_block_entity_removed(
        static_cast<int32_t>(handler_id),
        static_cast<int64_t>(block_pos_hash));
}

// ==========================================================================
// Block Entity Registration Queue JNI Methods
// ==========================================================================

/*
 * Class:     com_redstone_DartBridge
 * Method:    hasPendingBlockEntityRegistrations
 * Signature: ()Z
 *
 * Check if there are pending block entity registrations in the queue.
 */
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridge_hasPendingBlockEntityRegistrations(
    JNIEnv* /* env */, jclass /* cls */) {
    return server_has_pending_block_entity_registrations() ? JNI_TRUE : JNI_FALSE;
}

/*
 * Class:     com_redstone_DartBridge
 * Method:    getNextBlockEntityRegistration
 * Signature: ()[Ljava/lang/Object;
 *
 * Get the next block entity registration from the queue.
 * Returns an Object array: [handlerId(Integer), blockId(String),
 *                           inventorySize(Integer), containerTitle(String),
 *                           ticks(Boolean)]
 * Returns null if the queue is empty.
 */
JNIEXPORT jobjectArray JNICALL Java_com_redstone_DartBridge_getNextBlockEntityRegistration(
    JNIEnv* env, jclass /* cls */) {

    int32_t handler_id;
    char block_id_buf[256];
    int32_t inventory_size;
    char container_title_buf[256];
    bool ticks;

    if (!server_get_next_block_entity_registration(
            &handler_id,
            block_id_buf, sizeof(block_id_buf),
            &inventory_size,
            container_title_buf, sizeof(container_title_buf),
            &ticks)) {
        return nullptr;
    }

    // Create Object array with 5 elements
    jclass objectClass = env->FindClass("java/lang/Object");
    jobjectArray result = env->NewObjectArray(5, objectClass, nullptr);

    // Use shared boxing helpers from jni_helpers.h
    env->SetObjectArrayElement(result, 0, boxInt(env, handler_id));
    env->SetObjectArrayElement(result, 1, env->NewStringUTF(block_id_buf));
    env->SetObjectArrayElement(result, 2, boxInt(env, inventory_size));
    env->SetObjectArrayElement(result, 3, env->NewStringUTF(container_title_buf));
    env->SetObjectArrayElement(result, 4, boxBool(env, ticks ? JNI_TRUE : JNI_FALSE));

    return result;
}

} // extern "C"
