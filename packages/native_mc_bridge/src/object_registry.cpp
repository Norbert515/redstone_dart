#include "object_registry.h"
#include <iostream>

namespace dart_mc_bridge {

int64_t ObjectRegistry::store(JNIEnv* env, jobject obj) {
    if (obj == nullptr) {
        return 0; // 0 indicates null/invalid handle
    }

    // Create a global reference to prevent garbage collection
    jobject global_ref = env->NewGlobalRef(obj);
    if (global_ref == nullptr) {
        std::cerr << "ObjectRegistry: Failed to create global reference" << std::endl;
        return 0;
    }

    // Get next handle and store the reference
    int64_t handle = next_handle_.fetch_add(1);

    {
        std::lock_guard<std::mutex> lock(mutex_);
        objects_[handle] = global_ref;
    }

    return handle;
}

jobject ObjectRegistry::get(int64_t handle) {
    if (handle == 0) {
        return nullptr;
    }

    std::lock_guard<std::mutex> lock(mutex_);
    auto it = objects_.find(handle);
    if (it != objects_.end()) {
        return it->second;
    }
    return nullptr;
}

void ObjectRegistry::release(JNIEnv* env, int64_t handle) {
    if (handle == 0) {
        return;
    }

    jobject obj = nullptr;

    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = objects_.find(handle);
        if (it != objects_.end()) {
            obj = it->second;
            objects_.erase(it);
        }
    }

    // Delete the global reference outside the lock
    if (obj != nullptr) {
        env->DeleteGlobalRef(obj);
    }
}

void ObjectRegistry::releaseAll(JNIEnv* env) {
    std::lock_guard<std::mutex> lock(mutex_);

    for (auto& pair : objects_) {
        if (pair.second != nullptr) {
            env->DeleteGlobalRef(pair.second);
        }
    }

    objects_.clear();
    std::cout << "ObjectRegistry: Released all object handles" << std::endl;
}

size_t ObjectRegistry::count() {
    std::lock_guard<std::mutex> lock(mutex_);
    return objects_.size();
}

} // namespace dart_mc_bridge
