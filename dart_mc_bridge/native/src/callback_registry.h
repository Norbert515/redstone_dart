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

    // New event handler setters
    void setPlayerJoinHandler(PlayerJoinCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        player_join_handler_ = cb;
    }

    void setPlayerLeaveHandler(PlayerLeaveCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        player_leave_handler_ = cb;
    }

    void setPlayerRespawnHandler(PlayerRespawnCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        player_respawn_handler_ = cb;
    }

    void setPlayerDeathHandler(PlayerDeathCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        player_death_handler_ = cb;
    }

    void setEntityDamageHandler(EntityDamageCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        entity_damage_handler_ = cb;
    }

    void setEntityDeathHandler(EntityDeathCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        entity_death_handler_ = cb;
    }

    void setPlayerAttackEntityHandler(PlayerAttackEntityCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        player_attack_entity_handler_ = cb;
    }

    void setPlayerChatHandler(PlayerChatCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        player_chat_handler_ = cb;
    }

    void setPlayerCommandHandler(PlayerCommandCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        player_command_handler_ = cb;
    }

    void setItemUseHandler(ItemUseCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        item_use_handler_ = cb;
    }

    void setItemUseOnBlockHandler(ItemUseOnBlockCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        item_use_on_block_handler_ = cb;
    }

    void setItemUseOnEntityHandler(ItemUseOnEntityCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        item_use_on_entity_handler_ = cb;
    }

    void setBlockPlaceHandler(BlockPlaceCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        block_place_handler_ = cb;
    }

    void setPlayerPickupItemHandler(PlayerPickupItemCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        player_pickup_item_handler_ = cb;
    }

    void setPlayerDropItemHandler(PlayerDropItemCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        player_drop_item_handler_ = cb;
    }

    void setServerStartingHandler(ServerStartingCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        server_starting_handler_ = cb;
    }

    void setServerStartedHandler(ServerStartedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        server_started_handler_ = cb;
    }

    void setServerStoppingHandler(ServerStoppingCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        server_stopping_handler_ = cb;
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

    // New event dispatch methods
    void dispatchPlayerJoin(int32_t player_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (player_join_handler_) {
            player_join_handler_(player_id);
        }
    }

    void dispatchPlayerLeave(int32_t player_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (player_leave_handler_) {
            player_leave_handler_(player_id);
        }
    }

    void dispatchPlayerRespawn(int32_t player_id, bool end_conquered) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (player_respawn_handler_) {
            player_respawn_handler_(player_id, end_conquered);
        }
    }

    char* dispatchPlayerDeath(int32_t player_id, const char* damage_source) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (player_death_handler_) {
            return player_death_handler_(player_id, damage_source);
        }
        return nullptr; // Default: use default death message
    }

    bool dispatchEntityDamage(int32_t entity_id, const char* damage_source, double amount) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (entity_damage_handler_) {
            return entity_damage_handler_(entity_id, damage_source, amount);
        }
        return true; // Default: allow damage
    }

    void dispatchEntityDeath(int32_t entity_id, const char* damage_source) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (entity_death_handler_) {
            entity_death_handler_(entity_id, damage_source);
        }
    }

    bool dispatchPlayerAttackEntity(int32_t player_id, int32_t target_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (player_attack_entity_handler_) {
            return player_attack_entity_handler_(player_id, target_id);
        }
        return true; // Default: allow attack
    }

    char* dispatchPlayerChat(int32_t player_id, const char* message) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (player_chat_handler_) {
            return player_chat_handler_(player_id, message);
        }
        return nullptr; // Default: pass through message unchanged
    }

    bool dispatchPlayerCommand(int32_t player_id, const char* command) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (player_command_handler_) {
            return player_command_handler_(player_id, command);
        }
        return true; // Default: allow command
    }

    bool dispatchItemUse(int32_t player_id, const char* item_id, int32_t count, int32_t hand) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (item_use_handler_) {
            return item_use_handler_(player_id, item_id, count, hand);
        }
        return true; // Default: allow use
    }

    int32_t dispatchItemUseOnBlock(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                    int32_t x, int32_t y, int32_t z, int32_t face) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (item_use_on_block_handler_) {
            return item_use_on_block_handler_(player_id, item_id, count, hand, x, y, z, face);
        }
        return 1; // Default: allow
    }

    int32_t dispatchItemUseOnEntity(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                     int32_t target_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (item_use_on_entity_handler_) {
            return item_use_on_entity_handler_(player_id, item_id, count, hand, target_id);
        }
        return 1; // Default: allow
    }

    bool dispatchBlockPlace(int32_t player_id, int32_t x, int32_t y, int32_t z, const char* block_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (block_place_handler_) {
            return block_place_handler_(player_id, x, y, z, block_id);
        }
        return true; // Default: allow placement
    }

    bool dispatchPlayerPickupItem(int32_t player_id, int32_t item_entity_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (player_pickup_item_handler_) {
            return player_pickup_item_handler_(player_id, item_entity_id);
        }
        return true; // Default: allow pickup
    }

    bool dispatchPlayerDropItem(int32_t player_id, const char* item_id, int32_t count) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (player_drop_item_handler_) {
            return player_drop_item_handler_(player_id, item_id, count);
        }
        return true; // Default: allow drop
    }

    void dispatchServerStarting() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (server_starting_handler_) {
            server_starting_handler_();
        }
    }

    void dispatchServerStarted() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (server_started_handler_) {
            server_started_handler_();
        }
    }

    void dispatchServerStopping() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (server_stopping_handler_) {
            server_stopping_handler_();
        }
    }

    // Clear all handlers
    void clear() {
        std::lock_guard<std::mutex> lock(mutex_);
        block_break_handler_ = nullptr;
        block_interact_handler_ = nullptr;
        tick_handler_ = nullptr;
        proxy_block_break_handler_ = nullptr;
        proxy_block_use_handler_ = nullptr;
        // New event handlers
        player_join_handler_ = nullptr;
        player_leave_handler_ = nullptr;
        player_respawn_handler_ = nullptr;
        player_death_handler_ = nullptr;
        entity_damage_handler_ = nullptr;
        entity_death_handler_ = nullptr;
        player_attack_entity_handler_ = nullptr;
        player_chat_handler_ = nullptr;
        player_command_handler_ = nullptr;
        item_use_handler_ = nullptr;
        item_use_on_block_handler_ = nullptr;
        item_use_on_entity_handler_ = nullptr;
        block_place_handler_ = nullptr;
        player_pickup_item_handler_ = nullptr;
        player_drop_item_handler_ = nullptr;
        server_starting_handler_ = nullptr;
        server_started_handler_ = nullptr;
        server_stopping_handler_ = nullptr;
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

    // New event handlers
    PlayerJoinCallback player_join_handler_ = nullptr;
    PlayerLeaveCallback player_leave_handler_ = nullptr;
    PlayerRespawnCallback player_respawn_handler_ = nullptr;
    PlayerDeathCallback player_death_handler_ = nullptr;
    EntityDamageCallback entity_damage_handler_ = nullptr;
    EntityDeathCallback entity_death_handler_ = nullptr;
    PlayerAttackEntityCallback player_attack_entity_handler_ = nullptr;
    PlayerChatCallback player_chat_handler_ = nullptr;
    PlayerCommandCallback player_command_handler_ = nullptr;
    ItemUseCallback item_use_handler_ = nullptr;
    ItemUseOnBlockCallback item_use_on_block_handler_ = nullptr;
    ItemUseOnEntityCallback item_use_on_entity_handler_ = nullptr;
    BlockPlaceCallback block_place_handler_ = nullptr;
    PlayerPickupItemCallback player_pickup_item_handler_ = nullptr;
    PlayerDropItemCallback player_drop_item_handler_ = nullptr;
    ServerStartingCallback server_starting_handler_ = nullptr;
    ServerStartedCallback server_started_handler_ = nullptr;
    ServerStoppingCallback server_stopping_handler_ = nullptr;
};

} // namespace dart_mc_bridge
