#pragma once

#include <cstdint>

extern "C" {
    // Lifecycle
    bool dart_bridge_init(const char* kernel_path);
    void dart_bridge_shutdown();
    void dart_bridge_tick();

    // Callback registration (called from Dart via FFI)
    typedef int32_t (*BlockBreakCallback)(int32_t x, int32_t y, int32_t z, int64_t player_id);
    typedef int32_t (*BlockInteractCallback)(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand);
    typedef void (*TickCallback)(int64_t tick);

    void register_block_break_handler(BlockBreakCallback cb);
    void register_block_interact_handler(BlockInteractCallback cb);
    void register_tick_handler(TickCallback cb);

    // Event dispatch (called from Java via JNI)
    int32_t dispatch_block_break(int32_t x, int32_t y, int32_t z, int64_t player_id);
    int32_t dispatch_block_interact(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand);
    void dispatch_tick(int64_t tick);

    // Dart -> Java communication (called from Dart, implemented via JNI callback)
    typedef void (*SendChatMessageCallback)(int64_t player_id, const char* message);
    void set_send_chat_message_callback(SendChatMessageCallback cb);
    void send_chat_message(int64_t player_id, const char* message);
}
