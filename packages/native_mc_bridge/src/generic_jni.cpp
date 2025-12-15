#include "generic_jni.h"
#include "object_registry.h"

#include <unordered_map>
#include <string>
#include <mutex>
#include <vector>
#include <cstring>
#include <iostream>

// ============================================================================
// Global State
// ============================================================================

static JavaVM* g_jvm = nullptr;
static std::unordered_map<std::string, jclass> class_cache;
static std::unordered_map<std::string, jmethodID> method_cache;
static std::unordered_map<std::string, jfieldID> field_cache;
static std::mutex cache_mutex;

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Get JNIEnv for current thread, attaching if necessary.
 */
static JNIEnv* get_env() {
    if (g_jvm == nullptr) {
        std::cerr << "generic_jni: JVM not initialized" << std::endl;
        return nullptr;
    }

    JNIEnv* env = nullptr;
    int status = g_jvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_8);

    if (status == JNI_EDETACHED) {
        if (g_jvm->AttachCurrentThread(reinterpret_cast<void**>(&env), nullptr) != JNI_OK) {
            std::cerr << "generic_jni: Failed to attach thread" << std::endl;
            return nullptr;
        }
    } else if (status != JNI_OK) {
        std::cerr << "generic_jni: Failed to get JNIEnv" << std::endl;
        return nullptr;
    }

    return env;
}

/**
 * Get a cached jclass, loading and creating global ref if necessary.
 */
static jclass get_class(JNIEnv* env, const char* name) {
    std::string key(name);

    {
        std::lock_guard<std::mutex> lock(cache_mutex);
        auto it = class_cache.find(key);
        if (it != class_cache.end()) {
            return it->second;
        }
    }

    jclass local = env->FindClass(name);
    if (local == nullptr) {
        env->ExceptionClear();
        std::cerr << "generic_jni: Class not found: " << name << std::endl;
        return nullptr;
    }

    jclass global = static_cast<jclass>(env->NewGlobalRef(local));
    env->DeleteLocalRef(local);

    {
        std::lock_guard<std::mutex> lock(cache_mutex);
        class_cache[key] = global;
    }

    return global;
}

/**
 * Get a cached jmethodID for instance or static method.
 */
static jmethodID get_method(JNIEnv* env, jclass cls, const char* class_name,
                            const char* method_name, const char* sig, bool is_static) {
    std::string key = std::string(class_name) + "." + method_name + sig + (is_static ? "S" : "I");

    {
        std::lock_guard<std::mutex> lock(cache_mutex);
        auto it = method_cache.find(key);
        if (it != method_cache.end()) {
            return it->second;
        }
    }

    jmethodID mid = is_static ?
        env->GetStaticMethodID(cls, method_name, sig) :
        env->GetMethodID(cls, method_name, sig);

    if (mid == nullptr) {
        env->ExceptionClear();
        std::cerr << "generic_jni: Method not found: " << class_name << "." << method_name << sig << std::endl;
        return nullptr;
    }

    {
        std::lock_guard<std::mutex> lock(cache_mutex);
        method_cache[key] = mid;
    }

    return mid;
}

/**
 * Get a cached jfieldID for instance or static field.
 */
static jfieldID get_field(JNIEnv* env, jclass cls, const char* class_name,
                          const char* field_name, const char* sig, bool is_static) {
    std::string key = std::string(class_name) + "." + field_name + sig + (is_static ? "S" : "I");

    {
        std::lock_guard<std::mutex> lock(cache_mutex);
        auto it = field_cache.find(key);
        if (it != field_cache.end()) {
            return it->second;
        }
    }

    jfieldID fid = is_static ?
        env->GetStaticFieldID(cls, field_name, sig) :
        env->GetFieldID(cls, field_name, sig);

    if (fid == nullptr) {
        env->ExceptionClear();
        std::cerr << "generic_jni: Field not found: " << class_name << "." << field_name << std::endl;
        return nullptr;
    }

    {
        std::lock_guard<std::mutex> lock(cache_mutex);
        field_cache[key] = fid;
    }

    return fid;
}

/**
 * Convert int64_t encoded arguments to jvalue array based on method signature.
 *
 * Argument encoding:
 * - Primitives (int, long, bool, etc.): direct cast
 * - Float: 32-bit float bits stored in int64_t
 * - Double: 64-bit double bits stored in int64_t
 * - Objects: handle to lookup in ObjectRegistry
 * - Strings: special case - stored as handle to jstring in registry
 */
static std::vector<jvalue> convert_args(JNIEnv* env, const char* sig,
                                        int64_t* args, int32_t arg_count) {
    std::vector<jvalue> jargs;
    if (arg_count == 0 || args == nullptr) {
        return jargs;
    }

    jargs.reserve(arg_count);

    // Parse signature: "(ILjava/lang/String;D)V"
    // Skip opening paren, parse until closing paren
    const char* p = sig + 1; // Skip '('
    int arg_idx = 0;

    while (*p != ')' && *p != '\0' && arg_idx < arg_count) {
        jvalue jv;
        memset(&jv, 0, sizeof(jvalue));

        switch (*p) {
            case 'Z': // boolean
                jv.z = static_cast<jboolean>(args[arg_idx] != 0);
                p++;
                break;

            case 'B': // byte
                jv.b = static_cast<jbyte>(args[arg_idx]);
                p++;
                break;

            case 'C': // char
                jv.c = static_cast<jchar>(args[arg_idx]);
                p++;
                break;

            case 'S': // short
                jv.s = static_cast<jshort>(args[arg_idx]);
                p++;
                break;

            case 'I': // int
                jv.i = static_cast<jint>(args[arg_idx]);
                p++;
                break;

            case 'J': // long
                jv.j = static_cast<jlong>(args[arg_idx]);
                p++;
                break;

            case 'F': { // float
                // Float bits stored in lower 32 bits of int64_t
                int32_t bits = static_cast<int32_t>(args[arg_idx]);
                jv.f = *reinterpret_cast<float*>(&bits);
                p++;
                break;
            }

            case 'D': { // double
                // Double bits stored in int64_t
                jv.d = *reinterpret_cast<double*>(&args[arg_idx]);
                p++;
                break;
            }

            case 'L': { // Object reference
                // Check if it's a String (Ljava/lang/String;)
                const char* class_start = p + 1;
                // Skip to ';' to find end of class name
                while (*p != ';' && *p != '\0') p++;

                // Check if this is java/lang/String
                bool is_string = (p - class_start == 16) &&
                                 (strncmp(class_start, "java/lang/String", 16) == 0);

                if (*p == ';') p++;

                if (args[arg_idx] == 0) {
                    jv.l = nullptr;
                } else if (is_string) {
                    // For strings, args contains a pointer to a UTF-8 C string
                    const char* str_ptr = reinterpret_cast<const char*>(args[arg_idx]);
                    jv.l = env->NewStringUTF(str_ptr);
                } else {
                    // For other objects, args contains a handle
                    jv.l = dart_mc_bridge::ObjectRegistry::instance().get(args[arg_idx]);
                }
                break;
            }

            case '[': { // Array
                // Skip array type descriptors
                while (*p == '[') p++;
                if (*p == 'L') {
                    while (*p != ';' && *p != '\0') p++;
                    if (*p == ';') p++;
                } else {
                    // Primitive array
                    p++;
                }

                if (args[arg_idx] == 0) {
                    jv.l = nullptr;
                } else {
                    jv.l = dart_mc_bridge::ObjectRegistry::instance().get(args[arg_idx]);
                }
                break;
            }

            default:
                std::cerr << "generic_jni: Unknown type in signature: " << *p << std::endl;
                p++;
                break;
        }

        jargs.push_back(jv);
        arg_idx++;
    }

    return jargs;
}

/**
 * Check for and handle JNI exceptions.
 * Returns true if an exception occurred.
 */
static bool check_exception(JNIEnv* env) {
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return true;
    }
    return false;
}

// ============================================================================
// Initialization
// ============================================================================

extern "C" {

void generic_jni_init(JavaVM* jvm) {
    g_jvm = jvm;
    std::cout << "generic_jni: Initialized" << std::endl;
}

void generic_jni_shutdown() {
    JNIEnv* env = get_env();

    // Clear cached classes (delete global refs)
    {
        std::lock_guard<std::mutex> lock(cache_mutex);
        if (env != nullptr) {
            for (auto& pair : class_cache) {
                env->DeleteGlobalRef(pair.second);
            }
        }
        class_cache.clear();
        method_cache.clear();
        field_cache.clear();
    }

    g_jvm = nullptr;
    std::cout << "generic_jni: Shutdown complete" << std::endl;
}

// ============================================================================
// Object Creation
// ============================================================================

int64_t jni_create_object(const char* class_name, const char* ctor_sig,
                          int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jmethodID ctor = get_method(env, cls, class_name, "<init>", ctor_sig, false);
    if (!ctor) return 0;

    auto jargs = convert_args(env, ctor_sig, args, arg_count);

    jobject obj = env->NewObjectA(cls, ctor, jargs.empty() ? nullptr : jargs.data());
    if (check_exception(env) || obj == nullptr) {
        return 0;
    }

    int64_t handle = dart_mc_bridge::ObjectRegistry::instance().store(env, obj);
    env->DeleteLocalRef(obj);

    return handle;
}

// ============================================================================
// Instance Method Calls
// ============================================================================

void jni_call_void_method(int64_t obj_handle, const char* class_name,
                          const char* method_name, const char* sig,
                          int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return;

    jclass cls = get_class(env, class_name);
    if (!cls) return;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, false);
    if (!mid) return;

    auto jargs = convert_args(env, sig, args, arg_count);
    env->CallVoidMethodA(obj, mid, jargs.empty() ? nullptr : jargs.data());
    check_exception(env);
}

int32_t jni_call_int_method(int64_t obj_handle, const char* class_name,
                            const char* method_name, const char* sig,
                            int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, false);
    if (!mid) return 0;

    auto jargs = convert_args(env, sig, args, arg_count);
    jint result = env->CallIntMethodA(obj, mid, jargs.empty() ? nullptr : jargs.data());

    if (check_exception(env)) return 0;
    return result;
}

int64_t jni_call_long_method(int64_t obj_handle, const char* class_name,
                             const char* method_name, const char* sig,
                             int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, false);
    if (!mid) return 0;

    auto jargs = convert_args(env, sig, args, arg_count);
    jlong result = env->CallLongMethodA(obj, mid, jargs.empty() ? nullptr : jargs.data());

    if (check_exception(env)) return 0;
    return result;
}

double jni_call_double_method(int64_t obj_handle, const char* class_name,
                              const char* method_name, const char* sig,
                              int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return 0.0;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return 0.0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0.0;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, false);
    if (!mid) return 0.0;

    auto jargs = convert_args(env, sig, args, arg_count);
    jdouble result = env->CallDoubleMethodA(obj, mid, jargs.empty() ? nullptr : jargs.data());

    if (check_exception(env)) return 0.0;
    return result;
}

float jni_call_float_method(int64_t obj_handle, const char* class_name,
                            const char* method_name, const char* sig,
                            int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return 0.0f;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return 0.0f;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0.0f;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, false);
    if (!mid) return 0.0f;

    auto jargs = convert_args(env, sig, args, arg_count);
    jfloat result = env->CallFloatMethodA(obj, mid, jargs.empty() ? nullptr : jargs.data());

    if (check_exception(env)) return 0.0f;
    return result;
}

bool jni_call_bool_method(int64_t obj_handle, const char* class_name,
                          const char* method_name, const char* sig,
                          int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return false;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return false;

    jclass cls = get_class(env, class_name);
    if (!cls) return false;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, false);
    if (!mid) return false;

    auto jargs = convert_args(env, sig, args, arg_count);
    jboolean result = env->CallBooleanMethodA(obj, mid, jargs.empty() ? nullptr : jargs.data());

    if (check_exception(env)) return false;
    return result != JNI_FALSE;
}

int64_t jni_call_object_method(int64_t obj_handle, const char* class_name,
                               const char* method_name, const char* sig,
                               int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, false);
    if (!mid) return 0;

    auto jargs = convert_args(env, sig, args, arg_count);
    jobject result = env->CallObjectMethodA(obj, mid, jargs.empty() ? nullptr : jargs.data());

    if (check_exception(env) || result == nullptr) {
        return 0;
    }

    int64_t handle = dart_mc_bridge::ObjectRegistry::instance().store(env, result);
    env->DeleteLocalRef(result);

    return handle;
}

const char* jni_call_string_method(int64_t obj_handle, const char* class_name,
                                   const char* method_name, const char* sig,
                                   int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return nullptr;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return nullptr;

    jclass cls = get_class(env, class_name);
    if (!cls) return nullptr;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, false);
    if (!mid) return nullptr;

    auto jargs = convert_args(env, sig, args, arg_count);
    jstring jstr = static_cast<jstring>(env->CallObjectMethodA(obj, mid,
                                        jargs.empty() ? nullptr : jargs.data()));

    if (check_exception(env) || jstr == nullptr) {
        return nullptr;
    }

    const char* utf = env->GetStringUTFChars(jstr, nullptr);
    char* result = strdup(utf); // Caller must free with jni_free_string
    env->ReleaseStringUTFChars(jstr, utf);
    env->DeleteLocalRef(jstr);

    return result;
}

// ============================================================================
// Static Method Calls
// ============================================================================

void jni_call_static_void_method(const char* class_name, const char* method_name,
                                 const char* sig, int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return;

    jclass cls = get_class(env, class_name);
    if (!cls) return;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, true);
    if (!mid) return;

    auto jargs = convert_args(env, sig, args, arg_count);
    env->CallStaticVoidMethodA(cls, mid, jargs.empty() ? nullptr : jargs.data());
    check_exception(env);
}

int32_t jni_call_static_int_method(const char* class_name, const char* method_name,
                                   const char* sig, int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, true);
    if (!mid) return 0;

    auto jargs = convert_args(env, sig, args, arg_count);
    jint result = env->CallStaticIntMethodA(cls, mid, jargs.empty() ? nullptr : jargs.data());

    if (check_exception(env)) return 0;
    return result;
}

int64_t jni_call_static_long_method(const char* class_name, const char* method_name,
                                    const char* sig, int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, true);
    if (!mid) return 0;

    auto jargs = convert_args(env, sig, args, arg_count);
    jlong result = env->CallStaticLongMethodA(cls, mid, jargs.empty() ? nullptr : jargs.data());

    if (check_exception(env)) return 0;
    return result;
}

int64_t jni_call_static_object_method(const char* class_name, const char* method_name,
                                      const char* sig, int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, true);
    if (!mid) return 0;

    auto jargs = convert_args(env, sig, args, arg_count);
    jobject result = env->CallStaticObjectMethodA(cls, mid, jargs.empty() ? nullptr : jargs.data());

    if (check_exception(env) || result == nullptr) {
        return 0;
    }

    int64_t handle = dart_mc_bridge::ObjectRegistry::instance().store(env, result);
    env->DeleteLocalRef(result);

    return handle;
}

const char* jni_call_static_string_method(const char* class_name, const char* method_name,
                                          const char* sig, int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return nullptr;

    jclass cls = get_class(env, class_name);
    if (!cls) return nullptr;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, true);
    if (!mid) return nullptr;

    auto jargs = convert_args(env, sig, args, arg_count);
    jstring jstr = static_cast<jstring>(env->CallStaticObjectMethodA(cls, mid,
                                        jargs.empty() ? nullptr : jargs.data()));

    if (check_exception(env) || jstr == nullptr) {
        return nullptr;
    }

    const char* utf = env->GetStringUTFChars(jstr, nullptr);
    char* result = strdup(utf);
    env->ReleaseStringUTFChars(jstr, utf);
    env->DeleteLocalRef(jstr);

    return result;
}

double jni_call_static_double_method(const char* class_name, const char* method_name,
                                     const char* sig, int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return 0.0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0.0;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, true);
    if (!mid) return 0.0;

    auto jargs = convert_args(env, sig, args, arg_count);
    jdouble result = env->CallStaticDoubleMethodA(cls, mid, jargs.empty() ? nullptr : jargs.data());

    if (check_exception(env)) return 0.0;
    return result;
}

bool jni_call_static_bool_method(const char* class_name, const char* method_name,
                                 const char* sig, int64_t* args, int32_t arg_count) {
    JNIEnv* env = get_env();
    if (!env) return false;

    jclass cls = get_class(env, class_name);
    if (!cls) return false;

    jmethodID mid = get_method(env, cls, class_name, method_name, sig, true);
    if (!mid) return false;

    auto jargs = convert_args(env, sig, args, arg_count);
    jboolean result = env->CallStaticBooleanMethodA(cls, mid, jargs.empty() ? nullptr : jargs.data());

    if (check_exception(env)) return false;
    return result != JNI_FALSE;
}

// ============================================================================
// Field Access (Instance)
// ============================================================================

int64_t jni_get_object_field(int64_t obj_handle, const char* class_name,
                             const char* field_name, const char* sig) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, false);
    if (!fid) return 0;

    jobject result = env->GetObjectField(obj, fid);
    if (check_exception(env) || result == nullptr) {
        return 0;
    }

    int64_t handle = dart_mc_bridge::ObjectRegistry::instance().store(env, result);
    env->DeleteLocalRef(result);

    return handle;
}

int32_t jni_get_int_field(int64_t obj_handle, const char* class_name,
                          const char* field_name, const char* sig) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, false);
    if (!fid) return 0;

    jint result = env->GetIntField(obj, fid);
    if (check_exception(env)) return 0;

    return result;
}

int64_t jni_get_long_field(int64_t obj_handle, const char* class_name,
                           const char* field_name, const char* sig) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, false);
    if (!fid) return 0;

    jlong result = env->GetLongField(obj, fid);
    if (check_exception(env)) return 0;

    return result;
}

double jni_get_double_field(int64_t obj_handle, const char* class_name,
                            const char* field_name, const char* sig) {
    JNIEnv* env = get_env();
    if (!env) return 0.0;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return 0.0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0.0;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, false);
    if (!fid) return 0.0;

    jdouble result = env->GetDoubleField(obj, fid);
    if (check_exception(env)) return 0.0;

    return result;
}

bool jni_get_bool_field(int64_t obj_handle, const char* class_name,
                        const char* field_name, const char* sig) {
    JNIEnv* env = get_env();
    if (!env) return false;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return false;

    jclass cls = get_class(env, class_name);
    if (!cls) return false;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, false);
    if (!fid) return false;

    jboolean result = env->GetBooleanField(obj, fid);
    if (check_exception(env)) return false;

    return result != JNI_FALSE;
}

const char* jni_get_string_field(int64_t obj_handle, const char* class_name,
                                 const char* field_name, const char* sig) {
    JNIEnv* env = get_env();
    if (!env) return nullptr;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return nullptr;

    jclass cls = get_class(env, class_name);
    if (!cls) return nullptr;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, false);
    if (!fid) return nullptr;

    jstring jstr = static_cast<jstring>(env->GetObjectField(obj, fid));
    if (check_exception(env) || jstr == nullptr) {
        return nullptr;
    }

    const char* utf = env->GetStringUTFChars(jstr, nullptr);
    char* result = strdup(utf);
    env->ReleaseStringUTFChars(jstr, utf);
    env->DeleteLocalRef(jstr);

    return result;
}

void jni_set_int_field(int64_t obj_handle, const char* class_name,
                       const char* field_name, const char* sig, int32_t value) {
    JNIEnv* env = get_env();
    if (!env) return;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return;

    jclass cls = get_class(env, class_name);
    if (!cls) return;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, false);
    if (!fid) return;

    env->SetIntField(obj, fid, value);
    check_exception(env);
}

void jni_set_long_field(int64_t obj_handle, const char* class_name,
                        const char* field_name, const char* sig, int64_t value) {
    JNIEnv* env = get_env();
    if (!env) return;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return;

    jclass cls = get_class(env, class_name);
    if (!cls) return;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, false);
    if (!fid) return;

    env->SetLongField(obj, fid, value);
    check_exception(env);
}

void jni_set_double_field(int64_t obj_handle, const char* class_name,
                          const char* field_name, const char* sig, double value) {
    JNIEnv* env = get_env();
    if (!env) return;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return;

    jclass cls = get_class(env, class_name);
    if (!cls) return;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, false);
    if (!fid) return;

    env->SetDoubleField(obj, fid, value);
    check_exception(env);
}

void jni_set_bool_field(int64_t obj_handle, const char* class_name,
                        const char* field_name, const char* sig, bool value) {
    JNIEnv* env = get_env();
    if (!env) return;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return;

    jclass cls = get_class(env, class_name);
    if (!cls) return;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, false);
    if (!fid) return;

    env->SetBooleanField(obj, fid, value ? JNI_TRUE : JNI_FALSE);
    check_exception(env);
}

void jni_set_object_field(int64_t obj_handle, const char* class_name,
                          const char* field_name, const char* sig, int64_t value_handle) {
    JNIEnv* env = get_env();
    if (!env) return;

    jobject obj = dart_mc_bridge::ObjectRegistry::instance().get(obj_handle);
    if (!obj) return;

    jclass cls = get_class(env, class_name);
    if (!cls) return;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, false);
    if (!fid) return;

    jobject value = nullptr;
    if (value_handle != 0) {
        value = dart_mc_bridge::ObjectRegistry::instance().get(value_handle);
    }

    env->SetObjectField(obj, fid, value);
    check_exception(env);
}

// ============================================================================
// Static Field Access
// ============================================================================

int64_t jni_get_static_object_field(const char* class_name, const char* field_name,
                                    const char* sig) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, true);
    if (!fid) return 0;

    jobject result = env->GetStaticObjectField(cls, fid);
    if (check_exception(env) || result == nullptr) {
        return 0;
    }

    int64_t handle = dart_mc_bridge::ObjectRegistry::instance().store(env, result);
    env->DeleteLocalRef(result);

    return handle;
}

int32_t jni_get_static_int_field(const char* class_name, const char* field_name,
                                 const char* sig) {
    JNIEnv* env = get_env();
    if (!env) return 0;

    jclass cls = get_class(env, class_name);
    if (!cls) return 0;

    jfieldID fid = get_field(env, cls, class_name, field_name, sig, true);
    if (!fid) return 0;

    jint result = env->GetStaticIntField(cls, fid);
    if (check_exception(env)) return 0;

    return result;
}

// ============================================================================
// Object Lifecycle
// ============================================================================

void jni_release_object(int64_t handle) {
    if (handle == 0) return;

    JNIEnv* env = get_env();
    if (!env) return;

    dart_mc_bridge::ObjectRegistry::instance().release(env, handle);
}

void jni_free_string(const char* str) {
    free(const_cast<char*>(str));
}

} // extern "C"
