#ifndef GENERIC_JNI_H
#define GENERIC_JNI_H

#include <jni.h>
#include <cstdint>

extern "C" {

// ============================================================================
// Object Creation
// ============================================================================

/**
 * Create a new Java object.
 * @param class_name Fully qualified class name with slashes (e.g., "java/util/ArrayList")
 * @param ctor_sig Constructor signature (e.g., "()V" or "(I)V")
 * @param args Pointer to array of int64_t encoded arguments (can be null if no args)
 * @param arg_count Number of arguments
 * @return Handle to the new object, or 0 on failure
 */
int64_t jni_create_object(const char* class_name, const char* ctor_sig,
                          int64_t* args, int32_t arg_count);

// ============================================================================
// Instance Method Calls
// ============================================================================

void jni_call_void_method(int64_t obj_handle, const char* class_name,
                          const char* method_name, const char* sig,
                          int64_t* args, int32_t arg_count);

int32_t jni_call_int_method(int64_t obj_handle, const char* class_name,
                            const char* method_name, const char* sig,
                            int64_t* args, int32_t arg_count);

int64_t jni_call_long_method(int64_t obj_handle, const char* class_name,
                             const char* method_name, const char* sig,
                             int64_t* args, int32_t arg_count);

double jni_call_double_method(int64_t obj_handle, const char* class_name,
                              const char* method_name, const char* sig,
                              int64_t* args, int32_t arg_count);

float jni_call_float_method(int64_t obj_handle, const char* class_name,
                            const char* method_name, const char* sig,
                            int64_t* args, int32_t arg_count);

bool jni_call_bool_method(int64_t obj_handle, const char* class_name,
                          const char* method_name, const char* sig,
                          int64_t* args, int32_t arg_count);

/**
 * Call a method that returns an object.
 * @return Handle to the returned object, or 0 if null/failure
 */
int64_t jni_call_object_method(int64_t obj_handle, const char* class_name,
                               const char* method_name, const char* sig,
                               int64_t* args, int32_t arg_count);

/**
 * Call a method that returns a String.
 * @return UTF-8 string that must be freed by caller using jni_free_string(), or nullptr
 */
const char* jni_call_string_method(int64_t obj_handle, const char* class_name,
                                   const char* method_name, const char* sig,
                                   int64_t* args, int32_t arg_count);

// ============================================================================
// Static Method Calls
// ============================================================================

void jni_call_static_void_method(const char* class_name, const char* method_name,
                                 const char* sig, int64_t* args, int32_t arg_count);

int32_t jni_call_static_int_method(const char* class_name, const char* method_name,
                                   const char* sig, int64_t* args, int32_t arg_count);

int64_t jni_call_static_long_method(const char* class_name, const char* method_name,
                                    const char* sig, int64_t* args, int32_t arg_count);

int64_t jni_call_static_object_method(const char* class_name, const char* method_name,
                                      const char* sig, int64_t* args, int32_t arg_count);

const char* jni_call_static_string_method(const char* class_name, const char* method_name,
                                          const char* sig, int64_t* args, int32_t arg_count);

double jni_call_static_double_method(const char* class_name, const char* method_name,
                                     const char* sig, int64_t* args, int32_t arg_count);

bool jni_call_static_bool_method(const char* class_name, const char* method_name,
                                 const char* sig, int64_t* args, int32_t arg_count);

// ============================================================================
// Field Access
// ============================================================================

int64_t jni_get_object_field(int64_t obj_handle, const char* class_name,
                             const char* field_name, const char* sig);

int32_t jni_get_int_field(int64_t obj_handle, const char* class_name,
                          const char* field_name, const char* sig);

int64_t jni_get_long_field(int64_t obj_handle, const char* class_name,
                           const char* field_name, const char* sig);

double jni_get_double_field(int64_t obj_handle, const char* class_name,
                            const char* field_name, const char* sig);

bool jni_get_bool_field(int64_t obj_handle, const char* class_name,
                        const char* field_name, const char* sig);

const char* jni_get_string_field(int64_t obj_handle, const char* class_name,
                                 const char* field_name, const char* sig);

void jni_set_int_field(int64_t obj_handle, const char* class_name,
                       const char* field_name, const char* sig, int32_t value);

void jni_set_long_field(int64_t obj_handle, const char* class_name,
                        const char* field_name, const char* sig, int64_t value);

void jni_set_double_field(int64_t obj_handle, const char* class_name,
                          const char* field_name, const char* sig, double value);

void jni_set_bool_field(int64_t obj_handle, const char* class_name,
                        const char* field_name, const char* sig, bool value);

void jni_set_object_field(int64_t obj_handle, const char* class_name,
                          const char* field_name, const char* sig, int64_t value_handle);

// ============================================================================
// Static Field Access
// ============================================================================

int64_t jni_get_static_object_field(const char* class_name, const char* field_name,
                                    const char* sig);

int32_t jni_get_static_int_field(const char* class_name, const char* field_name,
                                 const char* sig);

// ============================================================================
// Object Lifecycle
// ============================================================================

/**
 * Release an object handle, allowing Java to garbage collect it.
 */
void jni_release_object(int64_t handle);

/**
 * Free a string returned by jni_call_string_method.
 */
void jni_free_string(const char* str);

// ============================================================================
// Initialization
// ============================================================================

/**
 * Initialize the generic JNI system with a JVM reference.
 * Must be called before any other functions.
 */
void generic_jni_init(JavaVM* jvm);

/**
 * Shutdown and cleanup caches.
 */
void generic_jni_shutdown();

} // extern "C"

#endif // GENERIC_JNI_H
