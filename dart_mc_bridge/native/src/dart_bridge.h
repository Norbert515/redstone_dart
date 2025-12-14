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

    // ==========================================================================
    // New Event Callbacks
    // ==========================================================================

    // Player Events
    typedef void (*PlayerJoinCallback)(int32_t player_id);
    typedef void (*PlayerLeaveCallback)(int32_t player_id);
    typedef void (*PlayerRespawnCallback)(int32_t player_id, bool end_conquered);
    typedef char* (*PlayerDeathCallback)(int32_t player_id, const char* damage_source);  // returns custom message or null

    // Entity Events
    typedef bool (*EntityDamageCallback)(int32_t entity_id, const char* damage_source, double amount);  // returns allow/cancel
    typedef void (*EntityDeathCallback)(int32_t entity_id, const char* damage_source);
    typedef bool (*PlayerAttackEntityCallback)(int32_t player_id, int32_t target_id);  // returns allow/cancel

    // Chat/Command Events
    typedef char* (*PlayerChatCallback)(int32_t player_id, const char* message);  // returns modified message or null
    typedef bool (*PlayerCommandCallback)(int32_t player_id, const char* command);  // returns allow/cancel

    // Item Events
    typedef bool (*ItemUseCallback)(int32_t player_id, const char* item_id, int32_t count, int32_t hand);
    typedef int32_t (*ItemUseOnBlockCallback)(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                               int32_t x, int32_t y, int32_t z, int32_t face);
    typedef int32_t (*ItemUseOnEntityCallback)(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                                int32_t target_id);

    // Block Events
    typedef bool (*BlockPlaceCallback)(int32_t player_id, int32_t x, int32_t y, int32_t z, const char* block_id);

    // Item Pickup/Drop
    typedef bool (*PlayerPickupItemCallback)(int32_t player_id, int32_t item_entity_id);
    typedef bool (*PlayerDropItemCallback)(int32_t player_id, const char* item_id, int32_t count);

    // Server Lifecycle
    typedef void (*ServerStartingCallback)();
    typedef void (*ServerStartedCallback)();
    typedef void (*ServerStoppingCallback)();

    // Registration functions (called from Dart via FFI)
    void register_player_join_handler(PlayerJoinCallback cb);
    void register_player_leave_handler(PlayerLeaveCallback cb);
    void register_player_respawn_handler(PlayerRespawnCallback cb);
    void register_player_death_handler(PlayerDeathCallback cb);
    void register_entity_damage_handler(EntityDamageCallback cb);
    void register_entity_death_handler(EntityDeathCallback cb);
    void register_player_attack_entity_handler(PlayerAttackEntityCallback cb);
    void register_player_chat_handler(PlayerChatCallback cb);
    void register_player_command_handler(PlayerCommandCallback cb);
    void register_item_use_handler(ItemUseCallback cb);
    void register_item_use_on_block_handler(ItemUseOnBlockCallback cb);
    void register_item_use_on_entity_handler(ItemUseOnEntityCallback cb);
    void register_block_place_handler(BlockPlaceCallback cb);
    void register_player_pickup_item_handler(PlayerPickupItemCallback cb);
    void register_player_drop_item_handler(PlayerDropItemCallback cb);
    void register_server_starting_handler(ServerStartingCallback cb);
    void register_server_started_handler(ServerStartedCallback cb);
    void register_server_stopping_handler(ServerStoppingCallback cb);

    // Dispatch functions (called from Java via JNI)
    void dispatch_player_join(int32_t player_id);
    void dispatch_player_leave(int32_t player_id);
    void dispatch_player_respawn(int32_t player_id, bool end_conquered);
    char* dispatch_player_death(int32_t player_id, const char* damage_source);
    bool dispatch_entity_damage(int32_t entity_id, const char* damage_source, double amount);
    void dispatch_entity_death(int32_t entity_id, const char* damage_source);
    bool dispatch_player_attack_entity(int32_t player_id, int32_t target_id);
    char* dispatch_player_chat(int32_t player_id, const char* message);
    bool dispatch_player_command(int32_t player_id, const char* command);
    bool dispatch_item_use(int32_t player_id, const char* item_id, int32_t count, int32_t hand);
    int32_t dispatch_item_use_on_block(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                        int32_t x, int32_t y, int32_t z, int32_t face);
    int32_t dispatch_item_use_on_entity(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                         int32_t target_id);
    bool dispatch_block_place(int32_t player_id, int32_t x, int32_t y, int32_t z, const char* block_id);
    bool dispatch_player_pickup_item(int32_t player_id, int32_t item_entity_id);
    bool dispatch_player_drop_item(int32_t player_id, const char* item_id, int32_t count);
    void dispatch_server_starting();
    void dispatch_server_started();
    void dispatch_server_stopping();
}
