// ==========================================================================
// JNI Helper Functions
// ==========================================================================
// Shared utility functions for JNI boxing operations.
// Used by both jni_interface_server.cpp and jni_interface_client.cpp.
// ==========================================================================

#pragma once

#include <jni.h>

namespace jni_helpers {

/**
 * Box a jlong value into a java.lang.Long object.
 */
inline jobject boxLong(JNIEnv* env, jlong value) {
    jclass cls = env->FindClass("java/lang/Long");
    jmethodID mid = env->GetMethodID(cls, "<init>", "(J)V");
    return env->NewObject(cls, mid, value);
}

/**
 * Box a jint value into a java.lang.Integer object.
 */
inline jobject boxInt(JNIEnv* env, jint value) {
    jclass cls = env->FindClass("java/lang/Integer");
    jmethodID mid = env->GetMethodID(cls, "<init>", "(I)V");
    return env->NewObject(cls, mid, value);
}

/**
 * Box a jdouble value into a java.lang.Double object.
 */
inline jobject boxDouble(JNIEnv* env, jdouble value) {
    jclass cls = env->FindClass("java/lang/Double");
    jmethodID mid = env->GetMethodID(cls, "<init>", "(D)V");
    return env->NewObject(cls, mid, value);
}

/**
 * Box a jfloat value into a java.lang.Float object.
 */
inline jobject boxFloat(JNIEnv* env, jfloat value) {
    jclass cls = env->FindClass("java/lang/Float");
    jmethodID mid = env->GetMethodID(cls, "<init>", "(F)V");
    return env->NewObject(cls, mid, value);
}

/**
 * Box a jboolean value into a java.lang.Boolean object.
 */
inline jobject boxBool(JNIEnv* env, jboolean value) {
    jclass cls = env->FindClass("java/lang/Boolean");
    jmethodID mid = env->GetMethodID(cls, "<init>", "(Z)V");
    return env->NewObject(cls, mid, value);
}

} // namespace jni_helpers
