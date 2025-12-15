#ifndef OBJECT_REGISTRY_H
#define OBJECT_REGISTRY_H

#include <jni.h>
#include <cstdint>
#include <unordered_map>
#include <mutex>
#include <atomic>

namespace dart_mc_bridge {

/**
 * Thread-safe registry mapping int64_t handles to jobject global refs.
 * Prevents Java objects from being garbage collected while Dart holds references.
 */
class ObjectRegistry {
public:
    static ObjectRegistry& instance() {
        static ObjectRegistry registry;
        return registry;
    }

    // Store a jobject, creating a GlobalRef. Returns a unique handle.
    int64_t store(JNIEnv* env, jobject obj);

    // Get the jobject for a handle. Returns nullptr if not found.
    jobject get(int64_t handle);

    // Release a handle, deleting the GlobalRef.
    // Requires JNIEnv* to delete the global ref.
    void release(JNIEnv* env, int64_t handle);

    // Release all handles (call during shutdown).
    void releaseAll(JNIEnv* env);

    // Get count of stored objects (for debugging)
    size_t count();

private:
    ObjectRegistry() = default;
    ~ObjectRegistry() = default;
    ObjectRegistry(const ObjectRegistry&) = delete;
    ObjectRegistry& operator=(const ObjectRegistry&) = delete;

    std::unordered_map<int64_t, jobject> objects_;
    std::atomic<int64_t> next_handle_{1};
    std::mutex mutex_;
};

} // namespace dart_mc_bridge

#endif // OBJECT_REGISTRY_H
