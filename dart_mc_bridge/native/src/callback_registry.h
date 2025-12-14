#pragma once

#include "dart_bridge.h"
#include <mutex>

namespace dart_mc_bridge {

/**
 * Thread-safe registry for Dart callbacks.
 *
 * Callbacks are registered from Dart via FFI and invoked from Java via JNI.
 * All callback invocations are protected by a mutex to ensure thread safety
 * when Minecraft's game loop and Dart's isolate interact.
 */
class CallbackRegistry {
public:
    static CallbackRegistry& instance() {
        static CallbackRegistry registry;
        return registry;
    }

    // Registration (called from Dart)
    void setBlockBreakHandler(BlockBreakCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        block_break_handler_ = cb;
    }

    void setBlockInteractHandler(BlockInteractCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        block_interact_handler_ = cb;
    }

    void setTickHandler(TickCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        tick_handler_ = cb;
    }

    void setProxyBlockBreakHandler(ProxyBlockBreakCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_block_break_handler_ = cb;
    }

    void setProxyBlockUseHandler(ProxyBlockUseCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_block_use_handler_ = cb;
    }

    // Dispatch (called from Java via JNI)
    int32_t dispatchBlockBreak(int32_t x, int32_t y, int32_t z, int64_t player_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (block_break_handler_) {
            return block_break_handler_(x, y, z, player_id);
        }
        return 1; // Default: allow
    }

    int32_t dispatchBlockInteract(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (block_interact_handler_) {
            return block_interact_handler_(x, y, z, player_id, hand);
        }
        return 1; // Default: allow
    }

    void dispatchTick(int64_t tick) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (tick_handler_) {
            tick_handler_(tick);
        }
    }

    // Returns true to allow break, false to cancel
    bool dispatchProxyBlockBreak(int64_t handler_id, int64_t world_id,
                                  int32_t x, int32_t y, int32_t z, int64_t player_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_block_break_handler_) {
            return proxy_block_break_handler_(handler_id, world_id, x, y, z, player_id);
        }
        return true; // Default: allow break
    }

    int32_t dispatchProxyBlockUse(int64_t handler_id, int64_t world_id,
                                   int32_t x, int32_t y, int32_t z,
                                   int64_t player_id, int32_t hand) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_block_use_handler_) {
            return proxy_block_use_handler_(handler_id, world_id, x, y, z, player_id, hand);
        }
        return 3; // Default: ActionResult.pass
    }

    // Clear all handlers
    void clear() {
        std::lock_guard<std::mutex> lock(mutex_);
        block_break_handler_ = nullptr;
        block_interact_handler_ = nullptr;
        tick_handler_ = nullptr;
        proxy_block_break_handler_ = nullptr;
        proxy_block_use_handler_ = nullptr;
    }

private:
    CallbackRegistry() = default;
    ~CallbackRegistry() = default;

    CallbackRegistry(const CallbackRegistry&) = delete;
    CallbackRegistry& operator=(const CallbackRegistry&) = delete;

    std::mutex mutex_;
    BlockBreakCallback block_break_handler_ = nullptr;
    BlockInteractCallback block_interact_handler_ = nullptr;
    TickCallback tick_handler_ = nullptr;
    ProxyBlockBreakCallback proxy_block_break_handler_ = nullptr;
    ProxyBlockUseCallback proxy_block_use_handler_ = nullptr;
};

} // namespace dart_mc_bridge
