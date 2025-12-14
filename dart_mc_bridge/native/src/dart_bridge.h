#pragma once

#include <cstdint>
#include <jni.h>

extern "C" {
    // Lifecycle
    bool dart_bridge_init(const char* kernel_path);
    void dart_bridge_shutdown();
    void dart_bridge_tick();
    void dart_bridge_set_jvm(JavaVM* jvm);

    // Callback registration (called from Dart via FFI)
    typedef int32_t (*BlockBreakCallback)(int32_t x, int32_t y, int32_t z, int64_t player_id);
    typedef int32_t (*BlockInteractCallback)(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand);
    typedef void (*TickCallback)(int64_t tick);

    void register_block_break_handler(BlockBreakCallback cb);
    void register_block_interact_handler(BlockInteractCallback cb);
    void register_tick_handler(TickCallback cb);

    // Proxy block callbacks (called from Dart via FFI, invoked from Java proxy classes)
    // ProxyBlockBreakCallback returns true to allow break, false to cancel
    typedef bool (*ProxyBlockBreakCallback)(int64_t handler_id, int64_t world_id,
                                             int32_t x, int32_t y, int32_t z, int64_t player_id);
    typedef int32_t (*ProxyBlockUseCallback)(int64_t handler_id, int64_t world_id,
                                              int32_t x, int32_t y, int32_t z,
                                              int64_t player_id, int32_t hand);

    void register_proxy_block_break_handler(ProxyBlockBreakCallback cb);
    void register_proxy_block_use_handler(ProxyBlockUseCallback cb);

    // Event dispatch (called from Java via JNI)
    int32_t dispatch_block_break(int32_t x, int32_t y, int32_t z, int64_t player_id);
    int32_t dispatch_block_interact(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand);
    void dispatch_tick(int64_t tick);

    // Proxy block dispatch (called from Java proxy classes via JNI)
    // Returns true if break should be allowed, false to cancel
    bool dispatch_proxy_block_break(int64_t handler_id, int64_t world_id,
                                     int32_t x, int32_t y, int32_t z, int64_t player_id);
    int32_t dispatch_proxy_block_use(int64_t handler_id, int64_t world_id,
                                      int32_t x, int32_t y, int32_t z,
                                      int64_t player_id, int32_t hand);

    // Dart -> Java communication (called from Dart, implemented via JNI callback)
    typedef void (*SendChatMessageCallback)(int64_t player_id, const char* message);
    void set_send_chat_message_callback(SendChatMessageCallback cb);
    void send_chat_message(int64_t player_id, const char* message);

    // Get the Dart VM service URL for hot reload/debugging
    // Returns the URL string (e.g., "http://127.0.0.1:5858/")
    const char* get_dart_service_url();
}
