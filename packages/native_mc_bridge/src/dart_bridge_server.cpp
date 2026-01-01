#include "dart_bridge_server.h"
#include "callback_registry.h"
#include "object_registry.h"
#include "generic_jni.h"

#include <dart_dll.h>
#include <dart_api.h>

#include <iostream>
#include <string>
#include <cstring>
#include <mutex>
#include <thread>
#include <atomic>
#include <queue>

// ==========================================================================
// Server Dart VM State
// ==========================================================================

static Dart_Isolate g_server_isolate = nullptr;
static bool g_server_initialized = false;
static std::recursive_mutex g_server_isolate_mutex;
static std::thread::id g_server_isolate_owner_thread;
static int g_server_isolate_entry_count = 0;

// JVM reference for cleanup operations
static JavaVM* g_server_jvm_ref = nullptr;

// Service URL storage
static std::string g_server_service_url;

// Chat message callback
static SendChatMessageCallback g_server_send_chat_callback = nullptr;

// ==========================================================================
// Safe Isolate Entry/Exit Pattern
// ==========================================================================
// Server-side calls come from multiple threads (Server thread, etc.).
// We need to enter the Dart isolate before calling FFI callbacks and
// exit after. This is a recursive pattern to handle nested calls.

static bool safe_enter_isolate() {
    std::thread::id this_thread = std::this_thread::get_id();

    // Check if we're already in the isolate on this thread (re-entrant call)
    {
        std::lock_guard<std::recursive_mutex> lock(g_server_isolate_mutex);
        if (g_server_isolate_owner_thread == this_thread && g_server_isolate_entry_count > 0) {
            g_server_isolate_entry_count++;
            return false;  // Did not actually enter - already inside
        }
    }

    // Need to acquire the isolate
    g_server_isolate_mutex.lock();
    Dart_EnterIsolate(g_server_isolate);
    g_server_isolate_owner_thread = this_thread;
    g_server_isolate_entry_count = 1;
    return true;  // Actually entered the isolate
}

static void safe_exit_isolate(bool did_enter) {
    if (!did_enter) {
        // This was a re-entrant call, just decrement the count
        std::lock_guard<std::recursive_mutex> lock(g_server_isolate_mutex);
        g_server_isolate_entry_count--;
        return;
    }

    // Actually exit the isolate
    Dart_ExitIsolate();
    g_server_isolate_owner_thread = std::thread::id();
    g_server_isolate_entry_count = 0;
    g_server_isolate_mutex.unlock();
}

// ==========================================================================
// Server Callback Registry (separate from client)
// ==========================================================================
// We use a separate callback registry for server-side events

namespace dart_mc_bridge {

class ServerCallbackRegistry {
public:
    static ServerCallbackRegistry& instance() {
        static ServerCallbackRegistry registry;
        return registry;
    }

    // Block handlers
    void setBlockBreakHandler(BlockBreakCallback cb) { block_break_handler_ = cb; }
    void setBlockInteractHandler(BlockInteractCallback cb) { block_interact_handler_ = cb; }
    void setTickHandler(TickCallback cb) { tick_handler_ = cb; }

    // Proxy block handlers
    void setProxyBlockBreakHandler(ProxyBlockBreakCallback cb) { proxy_block_break_handler_ = cb; }
    void setProxyBlockUseHandler(ProxyBlockUseCallback cb) { proxy_block_use_handler_ = cb; }
    void setProxyBlockSteppedOnHandler(ProxyBlockSteppedOnCallback cb) { proxy_block_stepped_on_handler_ = cb; }
    void setProxyBlockFallenUponHandler(ProxyBlockFallenUponCallback cb) { proxy_block_fallen_upon_handler_ = cb; }
    void setProxyBlockRandomTickHandler(ProxyBlockRandomTickCallback cb) { proxy_block_random_tick_handler_ = cb; }
    void setProxyBlockPlacedHandler(ProxyBlockPlacedCallback cb) { proxy_block_placed_handler_ = cb; }
    void setProxyBlockRemovedHandler(ProxyBlockRemovedCallback cb) { proxy_block_removed_handler_ = cb; }
    void setProxyBlockNeighborChangedHandler(ProxyBlockNeighborChangedCallback cb) { proxy_block_neighbor_changed_handler_ = cb; }
    void setProxyBlockEntityInsideHandler(ProxyBlockEntityInsideCallback cb) { proxy_block_entity_inside_handler_ = cb; }

    // Player handlers
    void setPlayerJoinHandler(PlayerJoinCallback cb) { player_join_handler_ = cb; }
    void setPlayerLeaveHandler(PlayerLeaveCallback cb) { player_leave_handler_ = cb; }
    void setPlayerRespawnHandler(PlayerRespawnCallback cb) { player_respawn_handler_ = cb; }
    void setPlayerDeathHandler(PlayerDeathCallback cb) { player_death_handler_ = cb; }
    void setEntityDamageHandler(EntityDamageCallback cb) { entity_damage_handler_ = cb; }
    void setEntityDeathHandler(EntityDeathCallback cb) { entity_death_handler_ = cb; }
    void setPlayerAttackEntityHandler(PlayerAttackEntityCallback cb) { player_attack_entity_handler_ = cb; }
    void setPlayerChatHandler(PlayerChatCallback cb) { player_chat_handler_ = cb; }
    void setPlayerCommandHandler(PlayerCommandCallback cb) { player_command_handler_ = cb; }
    void setItemUseHandler(ItemUseCallback cb) { item_use_handler_ = cb; }
    void setItemUseOnBlockHandler(ItemUseOnBlockCallback cb) { item_use_on_block_handler_ = cb; }
    void setItemUseOnEntityHandler(ItemUseOnEntityCallback cb) { item_use_on_entity_handler_ = cb; }
    void setBlockPlaceHandler(BlockPlaceCallback cb) { block_place_handler_ = cb; }
    void setPlayerPickupItemHandler(PlayerPickupItemCallback cb) { player_pickup_item_handler_ = cb; }
    void setPlayerDropItemHandler(PlayerDropItemCallback cb) { player_drop_item_handler_ = cb; }
    void setServerStartingHandler(ServerStartingCallback cb) { server_starting_handler_ = cb; }
    void setServerStartedHandler(ServerStartedCallback cb) { server_started_handler_ = cb; }
    void setServerStoppingHandler(ServerStoppingCallback cb) { server_stopping_handler_ = cb; }

    // Entity proxy handlers
    void setProxyEntitySpawnHandler(ProxyEntitySpawnCallback cb) { proxy_entity_spawn_handler_ = cb; }
    void setProxyEntityTickHandler(ProxyEntityTickCallback cb) { proxy_entity_tick_handler_ = cb; }
    void setProxyEntityDeathHandler(ProxyEntityDeathCallback cb) { proxy_entity_death_handler_ = cb; }
    void setProxyEntityDamageHandler(ProxyEntityDamageCallback cb) { proxy_entity_damage_handler_ = cb; }
    void setProxyEntityAttackHandler(ProxyEntityAttackCallback cb) { proxy_entity_attack_handler_ = cb; }
    void setProxyEntityTargetHandler(ProxyEntityTargetCallback cb) { proxy_entity_target_handler_ = cb; }

    // Projectile proxy handlers
    void setProxyProjectileHitEntityHandler(ProxyProjectileHitEntityCallback cb) { proxy_projectile_hit_entity_handler_ = cb; }
    void setProxyProjectileHitBlockHandler(ProxyProjectileHitBlockCallback cb) { proxy_projectile_hit_block_handler_ = cb; }

    // Animal proxy handlers
    void setProxyAnimalBreedHandler(ProxyAnimalBreedCallback cb) { proxy_animal_breed_handler_ = cb; }

    // Item proxy handlers
    void setProxyItemAttackEntityHandler(ProxyItemAttackEntityCallback cb) { proxy_item_attack_entity_handler_ = cb; }
    void setProxyItemUseHandler(ProxyItemUseCallback cb) { proxy_item_use_handler_ = cb; }
    void setProxyItemUseOnBlockHandler(ProxyItemUseOnBlockCallback cb) { proxy_item_use_on_block_handler_ = cb; }
    void setProxyItemUseOnEntityHandler(ProxyItemUseOnEntityCallback cb) { proxy_item_use_on_entity_handler_ = cb; }

    // Command handler
    void setCommandExecuteHandler(CommandExecuteCallback cb) { command_execute_handler_ = cb; }

    // Custom goal handlers
    void setCustomGoalCanUseHandler(CustomGoalCanUseCallback cb) { custom_goal_can_use_handler_ = cb; }
    void setCustomGoalCanContinueToUseHandler(CustomGoalCanContinueToUseCallback cb) { custom_goal_can_continue_to_use_handler_ = cb; }
    void setCustomGoalStartHandler(CustomGoalStartCallback cb) { custom_goal_start_handler_ = cb; }
    void setCustomGoalTickHandler(CustomGoalTickCallback cb) { custom_goal_tick_handler_ = cb; }
    void setCustomGoalStopHandler(CustomGoalStopCallback cb) { custom_goal_stop_handler_ = cb; }

    // Network packet handler
    void setPacketReceivedHandler(PacketReceivedCallback cb) { packet_received_handler_ = cb; }

    // Dispatch methods (call the registered callbacks)
    int32_t dispatchBlockBreak(int32_t x, int32_t y, int32_t z, int64_t player_id) {
        if (block_break_handler_) return block_break_handler_(x, y, z, player_id);
        return 1;
    }

    int32_t dispatchBlockInteract(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand) {
        if (block_interact_handler_) return block_interact_handler_(x, y, z, player_id, hand);
        return 1;
    }

    void dispatchTick(int64_t tick) {
        if (tick_handler_) tick_handler_(tick);
    }

    bool dispatchProxyBlockBreak(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int64_t player_id) {
        if (proxy_block_break_handler_) return proxy_block_break_handler_(handler_id, world_id, x, y, z, player_id);
        return true;
    }

    int32_t dispatchProxyBlockUse(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand) {
        if (proxy_block_use_handler_) return proxy_block_use_handler_(handler_id, world_id, x, y, z, player_id, hand);
        return 3;
    }

    void dispatchProxyBlockSteppedOn(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t entity_id) {
        if (proxy_block_stepped_on_handler_) proxy_block_stepped_on_handler_(handler_id, world_id, x, y, z, entity_id);
    }

    void dispatchProxyBlockFallenUpon(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t entity_id, float fall_distance) {
        if (proxy_block_fallen_upon_handler_) proxy_block_fallen_upon_handler_(handler_id, world_id, x, y, z, entity_id, fall_distance);
    }

    void dispatchProxyBlockRandomTick(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z) {
        if (proxy_block_random_tick_handler_) proxy_block_random_tick_handler_(handler_id, world_id, x, y, z);
    }

    void dispatchProxyBlockPlaced(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int64_t player_id) {
        if (proxy_block_placed_handler_) proxy_block_placed_handler_(handler_id, world_id, x, y, z, player_id);
    }

    void dispatchProxyBlockRemoved(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z) {
        if (proxy_block_removed_handler_) proxy_block_removed_handler_(handler_id, world_id, x, y, z);
    }

    void dispatchProxyBlockNeighborChanged(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t nx, int32_t ny, int32_t nz) {
        if (proxy_block_neighbor_changed_handler_) proxy_block_neighbor_changed_handler_(handler_id, world_id, x, y, z, nx, ny, nz);
    }

    void dispatchProxyBlockEntityInside(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t entity_id) {
        if (proxy_block_entity_inside_handler_) proxy_block_entity_inside_handler_(handler_id, world_id, x, y, z, entity_id);
    }

    void dispatchPlayerJoin(int32_t player_id) { if (player_join_handler_) player_join_handler_(player_id); }
    void dispatchPlayerLeave(int32_t player_id) { if (player_leave_handler_) player_leave_handler_(player_id); }
    void dispatchPlayerRespawn(int32_t player_id, bool end_conquered) { if (player_respawn_handler_) player_respawn_handler_(player_id, end_conquered); }
    char* dispatchPlayerDeath(int32_t player_id, const char* damage_source) { if (player_death_handler_) return player_death_handler_(player_id, damage_source); return nullptr; }
    bool dispatchEntityDamage(int32_t entity_id, const char* damage_source, double amount) { if (entity_damage_handler_) return entity_damage_handler_(entity_id, damage_source, amount); return true; }
    void dispatchEntityDeath(int32_t entity_id, const char* damage_source) { if (entity_death_handler_) entity_death_handler_(entity_id, damage_source); }
    bool dispatchPlayerAttackEntity(int32_t player_id, int32_t target_id) { if (player_attack_entity_handler_) return player_attack_entity_handler_(player_id, target_id); return true; }
    char* dispatchPlayerChat(int32_t player_id, const char* message) { if (player_chat_handler_) return player_chat_handler_(player_id, message); return nullptr; }
    bool dispatchPlayerCommand(int32_t player_id, const char* command) { if (player_command_handler_) return player_command_handler_(player_id, command); return true; }
    bool dispatchItemUse(int32_t player_id, const char* item_id, int32_t count, int32_t hand) { if (item_use_handler_) return item_use_handler_(player_id, item_id, count, hand); return true; }
    int32_t dispatchItemUseOnBlock(int32_t player_id, const char* item_id, int32_t count, int32_t hand, int32_t x, int32_t y, int32_t z, int32_t face) { if (item_use_on_block_handler_) return item_use_on_block_handler_(player_id, item_id, count, hand, x, y, z, face); return 1; }
    int32_t dispatchItemUseOnEntity(int32_t player_id, const char* item_id, int32_t count, int32_t hand, int32_t target_id) { if (item_use_on_entity_handler_) return item_use_on_entity_handler_(player_id, item_id, count, hand, target_id); return 1; }
    bool dispatchBlockPlace(int32_t player_id, int32_t x, int32_t y, int32_t z, const char* block_id) { if (block_place_handler_) return block_place_handler_(player_id, x, y, z, block_id); return true; }
    bool dispatchPlayerPickupItem(int32_t player_id, int32_t item_entity_id) { if (player_pickup_item_handler_) return player_pickup_item_handler_(player_id, item_entity_id); return true; }
    bool dispatchPlayerDropItem(int32_t player_id, const char* item_id, int32_t count) { if (player_drop_item_handler_) return player_drop_item_handler_(player_id, item_id, count); return true; }
    void dispatchServerStarting() { if (server_starting_handler_) server_starting_handler_(); }
    void dispatchServerStarted() { if (server_started_handler_) server_started_handler_(); }
    void dispatchServerStopping() { if (server_stopping_handler_) server_stopping_handler_(); }

    void dispatchProxyEntitySpawn(int64_t handler_id, int32_t entity_id, int64_t world_id) { if (proxy_entity_spawn_handler_) proxy_entity_spawn_handler_(handler_id, entity_id, world_id); }
    void dispatchProxyEntityTick(int64_t handler_id, int32_t entity_id) { if (proxy_entity_tick_handler_) proxy_entity_tick_handler_(handler_id, entity_id); }
    void dispatchProxyEntityDeath(int64_t handler_id, int32_t entity_id, const char* damage_source) { if (proxy_entity_death_handler_) proxy_entity_death_handler_(handler_id, entity_id, damage_source); }
    bool dispatchProxyEntityDamage(int64_t handler_id, int32_t entity_id, const char* damage_source, double amount) { if (proxy_entity_damage_handler_) return proxy_entity_damage_handler_(handler_id, entity_id, damage_source, amount); return true; }
    void dispatchProxyEntityAttack(int64_t handler_id, int32_t entity_id, int32_t target_id) { if (proxy_entity_attack_handler_) proxy_entity_attack_handler_(handler_id, entity_id, target_id); }
    void dispatchProxyEntityTarget(int64_t handler_id, int32_t entity_id, int32_t target_id) { if (proxy_entity_target_handler_) proxy_entity_target_handler_(handler_id, entity_id, target_id); }

    void dispatchProxyProjectileHitEntity(int64_t handler_id, int32_t projectile_id, int32_t target_id) { if (proxy_projectile_hit_entity_handler_) proxy_projectile_hit_entity_handler_(handler_id, projectile_id, target_id); }
    void dispatchProxyProjectileHitBlock(int64_t handler_id, int32_t projectile_id, int32_t x, int32_t y, int32_t z, const char* side) { if (proxy_projectile_hit_block_handler_) proxy_projectile_hit_block_handler_(handler_id, projectile_id, x, y, z, side); }

    void dispatchProxyAnimalBreed(int64_t handler_id, int32_t entity_id, int32_t partner_id, int32_t baby_id) { if (proxy_animal_breed_handler_) proxy_animal_breed_handler_(handler_id, entity_id, partner_id, baby_id); }

    bool dispatchProxyItemAttackEntity(int64_t handler_id, int32_t world_id, int32_t attacker_id, int32_t target_id) { if (proxy_item_attack_entity_handler_) return proxy_item_attack_entity_handler_(handler_id, world_id, attacker_id, target_id); return true; }
    int32_t dispatchProxyItemUse(int64_t handler_id, int64_t world_id, int32_t player_id, int32_t hand) { if (proxy_item_use_handler_) return proxy_item_use_handler_(handler_id, world_id, player_id, hand); return 4; }
    int32_t dispatchProxyItemUseOnBlock(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t player_id, int32_t hand) { if (proxy_item_use_on_block_handler_) return proxy_item_use_on_block_handler_(handler_id, world_id, x, y, z, player_id, hand); return 4; }
    int32_t dispatchProxyItemUseOnEntity(int64_t handler_id, int64_t world_id, int32_t entity_id, int32_t player_id, int32_t hand) { if (proxy_item_use_on_entity_handler_) return proxy_item_use_on_entity_handler_(handler_id, world_id, entity_id, player_id, hand); return 4; }

    int32_t dispatchCommandExecute(int64_t command_id, int32_t player_id, const char* args_json) { if (command_execute_handler_) return command_execute_handler_(command_id, player_id, args_json); return 0; }

    bool dispatchCustomGoalCanUse(const char* goal_id, int32_t entity_id) { if (custom_goal_can_use_handler_) return custom_goal_can_use_handler_(goal_id, entity_id); return false; }
    bool dispatchCustomGoalCanContinueToUse(const char* goal_id, int32_t entity_id) { if (custom_goal_can_continue_to_use_handler_) return custom_goal_can_continue_to_use_handler_(goal_id, entity_id); return false; }
    void dispatchCustomGoalStart(const char* goal_id, int32_t entity_id) { if (custom_goal_start_handler_) custom_goal_start_handler_(goal_id, entity_id); }
    void dispatchCustomGoalTick(const char* goal_id, int32_t entity_id) { if (custom_goal_tick_handler_) custom_goal_tick_handler_(goal_id, entity_id); }
    void dispatchCustomGoalStop(const char* goal_id, int32_t entity_id) { if (custom_goal_stop_handler_) custom_goal_stop_handler_(goal_id, entity_id); }

    // Network packet dispatch
    void dispatchPacketReceived(int32_t player_id, int32_t packet_type, const uint8_t* data, int32_t data_length) {
        if (packet_received_handler_) packet_received_handler_(player_id, packet_type, data, data_length);
    }

    void clear() {
        block_break_handler_ = nullptr;
        block_interact_handler_ = nullptr;
        tick_handler_ = nullptr;
        proxy_block_break_handler_ = nullptr;
        proxy_block_use_handler_ = nullptr;
        proxy_block_stepped_on_handler_ = nullptr;
        proxy_block_fallen_upon_handler_ = nullptr;
        proxy_block_random_tick_handler_ = nullptr;
        proxy_block_placed_handler_ = nullptr;
        proxy_block_removed_handler_ = nullptr;
        proxy_block_neighbor_changed_handler_ = nullptr;
        proxy_block_entity_inside_handler_ = nullptr;
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
        proxy_entity_spawn_handler_ = nullptr;
        proxy_entity_tick_handler_ = nullptr;
        proxy_entity_death_handler_ = nullptr;
        proxy_entity_damage_handler_ = nullptr;
        proxy_entity_attack_handler_ = nullptr;
        proxy_entity_target_handler_ = nullptr;
        proxy_projectile_hit_entity_handler_ = nullptr;
        proxy_projectile_hit_block_handler_ = nullptr;
        proxy_animal_breed_handler_ = nullptr;
        proxy_item_attack_entity_handler_ = nullptr;
        proxy_item_use_handler_ = nullptr;
        proxy_item_use_on_block_handler_ = nullptr;
        proxy_item_use_on_entity_handler_ = nullptr;
        command_execute_handler_ = nullptr;
        custom_goal_can_use_handler_ = nullptr;
        custom_goal_can_continue_to_use_handler_ = nullptr;
        custom_goal_start_handler_ = nullptr;
        custom_goal_tick_handler_ = nullptr;
        custom_goal_stop_handler_ = nullptr;
        packet_received_handler_ = nullptr;
    }

private:
    ServerCallbackRegistry() = default;
    ~ServerCallbackRegistry() = default;

    BlockBreakCallback block_break_handler_ = nullptr;
    BlockInteractCallback block_interact_handler_ = nullptr;
    TickCallback tick_handler_ = nullptr;
    ProxyBlockBreakCallback proxy_block_break_handler_ = nullptr;
    ProxyBlockUseCallback proxy_block_use_handler_ = nullptr;
    ProxyBlockSteppedOnCallback proxy_block_stepped_on_handler_ = nullptr;
    ProxyBlockFallenUponCallback proxy_block_fallen_upon_handler_ = nullptr;
    ProxyBlockRandomTickCallback proxy_block_random_tick_handler_ = nullptr;
    ProxyBlockPlacedCallback proxy_block_placed_handler_ = nullptr;
    ProxyBlockRemovedCallback proxy_block_removed_handler_ = nullptr;
    ProxyBlockNeighborChangedCallback proxy_block_neighbor_changed_handler_ = nullptr;
    ProxyBlockEntityInsideCallback proxy_block_entity_inside_handler_ = nullptr;
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
    ProxyEntitySpawnCallback proxy_entity_spawn_handler_ = nullptr;
    ProxyEntityTickCallback proxy_entity_tick_handler_ = nullptr;
    ProxyEntityDeathCallback proxy_entity_death_handler_ = nullptr;
    ProxyEntityDamageCallback proxy_entity_damage_handler_ = nullptr;
    ProxyEntityAttackCallback proxy_entity_attack_handler_ = nullptr;
    ProxyEntityTargetCallback proxy_entity_target_handler_ = nullptr;
    ProxyProjectileHitEntityCallback proxy_projectile_hit_entity_handler_ = nullptr;
    ProxyProjectileHitBlockCallback proxy_projectile_hit_block_handler_ = nullptr;
    ProxyAnimalBreedCallback proxy_animal_breed_handler_ = nullptr;
    ProxyItemAttackEntityCallback proxy_item_attack_entity_handler_ = nullptr;
    ProxyItemUseCallback proxy_item_use_handler_ = nullptr;
    ProxyItemUseOnBlockCallback proxy_item_use_on_block_handler_ = nullptr;
    ProxyItemUseOnEntityCallback proxy_item_use_on_entity_handler_ = nullptr;
    CommandExecuteCallback command_execute_handler_ = nullptr;
    CustomGoalCanUseCallback custom_goal_can_use_handler_ = nullptr;
    CustomGoalCanContinueToUseCallback custom_goal_can_continue_to_use_handler_ = nullptr;
    CustomGoalStartCallback custom_goal_start_handler_ = nullptr;
    CustomGoalTickCallback custom_goal_tick_handler_ = nullptr;
    CustomGoalStopCallback custom_goal_stop_handler_ = nullptr;

    // Network packet handler
    PacketReceivedCallback packet_received_handler_ = nullptr;
};

} // namespace dart_mc_bridge

// Global callback for sending packets to Java/clients
static SendPacketToClientCallback g_server_send_packet_callback = nullptr;

// Registry ready callback (called when Java signals registries are ready)
static RegistryReadyCallback g_server_registry_ready_callback = nullptr;

// ==========================================================================
// Registration Queue System (for thread-safe registration from Dart)
// ==========================================================================

struct ServerBlockRegistration {
    int64_t handler_id;
    std::string namespace_id;
    std::string path;
    float hardness, resistance;
    bool requires_tool;
    int32_t luminance;
    double slipperiness, velocity_multiplier, jump_velocity_multiplier;
    bool ticks_randomly, collidable, replaceable, burnable;
};

struct ServerItemRegistration {
    int64_t handler_id;
    std::string namespace_id;
    std::string path;
    int32_t max_stack_size, max_damage;
    bool fire_resistant;
    double attack_damage, attack_speed, attack_knockback;
};

struct ServerEntityRegistration {
    int64_t handler_id;
    std::string namespace_id;
    std::string path;
    double width, height, max_health, movement_speed, attack_damage;
    int32_t spawn_group, base_type;
    std::string breeding_item, model_type, texture_path;
    double model_scale;
    std::string goals_json, target_goals_json;
};

static std::queue<ServerBlockRegistration> g_server_block_queue;
static std::queue<ServerItemRegistration> g_server_item_queue;
static std::queue<ServerEntityRegistration> g_server_entity_queue;
static std::mutex g_server_registration_mutex;
static std::atomic<bool> g_server_registrations_complete{false};
static std::atomic<int64_t> g_server_next_block_id{1};
static std::atomic<int64_t> g_server_next_item_id{1};
static std::atomic<int64_t> g_server_next_entity_id{1};

// ==========================================================================
// Lifecycle Functions
// ==========================================================================

extern "C" {

bool dart_server_init(const char* script_path, const char* package_config, int service_port) {
    if (g_server_initialized) {
        std::cerr << "Server Dart bridge already initialized" << std::endl;
        return false;
    }

    std::cout << "Initializing Server Dart VM..." << std::endl;
    std::cout << "  Script path: " << (script_path ? script_path : "null") << std::endl;
    std::cout << "  Package config: " << (package_config ? package_config : "null") << std::endl;
    std::cout << "  Service port: " << service_port << " (0 = disabled)" << std::endl;

    // Configure dart_dll
    DartDllConfig config;
    // Service port: 0 = disabled, >0 = enable on specific port
    config.start_service_isolate = (service_port > 0);
    config.service_port = (service_port > 0) ? service_port : 5858;

    // Initialize Dart VM
    if (!DartDll_Initialize(config)) {
        std::cerr << "Failed to initialize Dart VM" << std::endl;
        return false;
    }

    // Load the script
    g_server_isolate = DartDll_LoadScript(script_path, package_config, nullptr);
    if (g_server_isolate == nullptr) {
        std::cerr << "Failed to load Dart script: " << script_path << std::endl;
        DartDll_Shutdown();
        return false;
    }

    // Enter the isolate to run main
    Dart_EnterIsolate(g_server_isolate);
    Dart_EnterScope();

    // Get root library and run main
    Dart_Handle root_library = Dart_RootLibrary();
    if (Dart_IsError(root_library)) {
        std::cerr << "Failed to get root library: " << Dart_GetError(root_library) << std::endl;
        Dart_ExitScope();
        Dart_ExitIsolate();
        DartDll_Shutdown();
        return false;
    }

    Dart_Handle result = DartDll_RunMain(root_library);
    if (Dart_IsError(result)) {
        std::cerr << "Failed to run main: " << Dart_GetError(result) << std::endl;
        Dart_ExitScope();
        Dart_ExitIsolate();
        DartDll_Shutdown();
        return false;
    }

    // Drain microtask queue to complete async initialization
    DartDll_DrainMicrotaskQueue();

    Dart_ExitScope();
    Dart_ExitIsolate();

    g_server_initialized = true;

    // Build and print service URL in the format expected by the CLI for hot reload detection
    if (service_port > 0) {
        g_server_service_url = "http://127.0.0.1:" + std::to_string(service_port) + "/";
        // Print in the exact format the CLI expects for VM service detection
        std::cout << "The Dart VM service is listening on " << g_server_service_url << std::endl;
    }

    std::cout << "Server Dart VM initialized successfully" << std::endl;

    return true;
}

void dart_server_shutdown() {
    if (!g_server_initialized) return;

    std::cout << "Shutting down Server Dart VM..." << std::endl;

    // Clear callbacks first to prevent any new callbacks from running
    std::cout << "  Clearing callbacks..." << std::endl;
    dart_mc_bridge::ServerCallbackRegistry::instance().clear();

    // Try to shutdown the isolate properly before full VM shutdown
    std::cout << "  Shutting down isolate..." << std::endl;
    if (g_server_isolate != nullptr) {
        // Enter the isolate to shut it down
        Dart_Isolate current = Dart_CurrentIsolate();
        if (current != g_server_isolate) {
            Dart_EnterIsolate(g_server_isolate);
        }
        // Shutdown the isolate - this should stop any pending async work
        Dart_ShutdownIsolate();
        g_server_isolate = nullptr;
    }

    // Now shutdown the VM
    // Note: DartDll_Shutdown can hang if there are pending isolates/threads
    // Since we already shut down our isolate, this should be quick
    std::cout << "  Shutting down Dart VM..." << std::endl;
    DartDll_Shutdown();

    g_server_initialized = false;
    g_server_jvm_ref = nullptr;

    std::cout << "Server Dart VM shutdown complete" << std::endl;
}

void dart_server_tick() {
    if (!g_server_initialized || g_server_isolate == nullptr) return;

    // Enter isolate and drain microtask queue
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();

    DartDll_DrainMicrotaskQueue();

    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void dart_server_set_jvm(JavaVM* jvm) {
    g_server_jvm_ref = jvm;
    // Initialize generic_jni module so Dart can call back into Java
    generic_jni_init(jvm);
}

const char* dart_server_get_service_url() {
    if (g_server_initialized) {
        return g_server_service_url.c_str();
    }
    return nullptr;
}

// ==========================================================================
// Callback Registration (called from Dart via FFI)
// ==========================================================================

void server_register_block_break_handler(BlockBreakCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setBlockBreakHandler(cb); }
void server_register_block_interact_handler(BlockInteractCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setBlockInteractHandler(cb); }
void server_register_tick_handler(TickCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setTickHandler(cb); }

void server_register_proxy_block_break_handler(ProxyBlockBreakCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyBlockBreakHandler(cb); }
void server_register_proxy_block_use_handler(ProxyBlockUseCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyBlockUseHandler(cb); }
void server_register_proxy_block_stepped_on_handler(ProxyBlockSteppedOnCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyBlockSteppedOnHandler(cb); }
void server_register_proxy_block_fallen_upon_handler(ProxyBlockFallenUponCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyBlockFallenUponHandler(cb); }
void server_register_proxy_block_random_tick_handler(ProxyBlockRandomTickCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyBlockRandomTickHandler(cb); }
void server_register_proxy_block_placed_handler(ProxyBlockPlacedCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyBlockPlacedHandler(cb); }
void server_register_proxy_block_removed_handler(ProxyBlockRemovedCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyBlockRemovedHandler(cb); }
void server_register_proxy_block_neighbor_changed_handler(ProxyBlockNeighborChangedCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyBlockNeighborChangedHandler(cb); }
void server_register_proxy_block_entity_inside_handler(ProxyBlockEntityInsideCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyBlockEntityInsideHandler(cb); }

void server_register_player_join_handler(PlayerJoinCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setPlayerJoinHandler(cb); }
void server_register_player_leave_handler(PlayerLeaveCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setPlayerLeaveHandler(cb); }
void server_register_player_respawn_handler(PlayerRespawnCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setPlayerRespawnHandler(cb); }
void server_register_player_death_handler(PlayerDeathCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setPlayerDeathHandler(cb); }
void server_register_entity_damage_handler(EntityDamageCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setEntityDamageHandler(cb); }
void server_register_entity_death_handler(EntityDeathCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setEntityDeathHandler(cb); }
void server_register_player_attack_entity_handler(PlayerAttackEntityCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setPlayerAttackEntityHandler(cb); }
void server_register_player_chat_handler(PlayerChatCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setPlayerChatHandler(cb); }
void server_register_player_command_handler(PlayerCommandCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setPlayerCommandHandler(cb); }
void server_register_item_use_handler(ItemUseCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setItemUseHandler(cb); }
void server_register_item_use_on_block_handler(ItemUseOnBlockCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setItemUseOnBlockHandler(cb); }
void server_register_item_use_on_entity_handler(ItemUseOnEntityCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setItemUseOnEntityHandler(cb); }
void server_register_block_place_handler(BlockPlaceCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setBlockPlaceHandler(cb); }
void server_register_player_pickup_item_handler(PlayerPickupItemCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setPlayerPickupItemHandler(cb); }
void server_register_player_drop_item_handler(PlayerDropItemCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setPlayerDropItemHandler(cb); }
void server_register_server_starting_handler(ServerStartingCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setServerStartingHandler(cb); }
void server_register_server_started_handler(ServerStartedCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setServerStartedHandler(cb); }
void server_register_server_stopping_handler(ServerStoppingCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setServerStoppingHandler(cb); }

void server_register_proxy_entity_spawn_handler(ProxyEntitySpawnCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyEntitySpawnHandler(cb); }
void server_register_proxy_entity_tick_handler(ProxyEntityTickCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyEntityTickHandler(cb); }
void server_register_proxy_entity_death_handler(ProxyEntityDeathCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyEntityDeathHandler(cb); }
void server_register_proxy_entity_damage_handler(ProxyEntityDamageCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyEntityDamageHandler(cb); }
void server_register_proxy_entity_attack_handler(ProxyEntityAttackCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyEntityAttackHandler(cb); }
void server_register_proxy_entity_target_handler(ProxyEntityTargetCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyEntityTargetHandler(cb); }

void server_register_proxy_item_attack_entity_handler(ProxyItemAttackEntityCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyItemAttackEntityHandler(cb); }
void server_register_proxy_item_use_handler(ProxyItemUseCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyItemUseHandler(cb); }
void server_register_proxy_item_use_on_block_handler(ProxyItemUseOnBlockCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyItemUseOnBlockHandler(cb); }
void server_register_proxy_item_use_on_entity_handler(ProxyItemUseOnEntityCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setProxyItemUseOnEntityHandler(cb); }

void server_register_command_execute_handler(CommandExecuteCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setCommandExecuteHandler(cb); }

void server_register_custom_goal_can_use_handler(CustomGoalCanUseCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setCustomGoalCanUseHandler(cb); }
void server_register_custom_goal_can_continue_to_use_handler(CustomGoalCanContinueToUseCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setCustomGoalCanContinueToUseHandler(cb); }
void server_register_custom_goal_start_handler(CustomGoalStartCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setCustomGoalStartHandler(cb); }
void server_register_custom_goal_tick_handler(CustomGoalTickCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setCustomGoalTickHandler(cb); }
void server_register_custom_goal_stop_handler(CustomGoalStopCallback cb) { dart_mc_bridge::ServerCallbackRegistry::instance().setCustomGoalStopHandler(cb); }

void server_set_send_chat_message_callback(SendChatMessageCallback cb) {
    g_server_send_chat_callback = cb;
}

// ==========================================================================
// Event Dispatch (called from Java via JNI)
// All dispatch functions use safe_enter_isolate/safe_exit_isolate pattern
// ==========================================================================

#define SERVER_DISPATCH_BEGIN() \
    if (!g_server_initialized || g_server_isolate == nullptr) return
#define SERVER_DISPATCH_BEGIN_RET(default_ret) \
    if (!g_server_initialized || g_server_isolate == nullptr) return default_ret

int32_t server_dispatch_block_break(int32_t x, int32_t y, int32_t z, int64_t player_id) {
    SERVER_DISPATCH_BEGIN_RET(1);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchBlockBreak(x, y, z, player_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t server_dispatch_block_interact(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand) {
    SERVER_DISPATCH_BEGIN_RET(1);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchBlockInteract(x, y, z, player_id, hand);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

void server_dispatch_tick(int64_t tick) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchTick(tick);
    DartDll_DrainMicrotaskQueue();  // Also drain after tick
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

bool server_dispatch_proxy_block_break(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int64_t player_id) {
    SERVER_DISPATCH_BEGIN_RET(true);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyBlockBreak(handler_id, world_id, x, y, z, player_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t server_dispatch_proxy_block_use(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand) {
    SERVER_DISPATCH_BEGIN_RET(3);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyBlockUse(handler_id, world_id, x, y, z, player_id, hand);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

void server_dispatch_proxy_block_stepped_on(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t entity_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyBlockSteppedOn(handler_id, world_id, x, y, z, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_block_fallen_upon(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t entity_id, float fall_distance) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyBlockFallenUpon(handler_id, world_id, x, y, z, entity_id, fall_distance);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_block_random_tick(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyBlockRandomTick(handler_id, world_id, x, y, z);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_block_placed(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int64_t player_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyBlockPlaced(handler_id, world_id, x, y, z, player_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_block_removed(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyBlockRemoved(handler_id, world_id, x, y, z);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_block_neighbor_changed(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t nx, int32_t ny, int32_t nz) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyBlockNeighborChanged(handler_id, world_id, x, y, z, nx, ny, nz);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_block_entity_inside(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t entity_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyBlockEntityInside(handler_id, world_id, x, y, z, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_player_join(int32_t player_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchPlayerJoin(player_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_player_leave(int32_t player_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchPlayerLeave(player_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_player_respawn(int32_t player_id, bool end_conquered) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchPlayerRespawn(player_id, end_conquered);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

char* server_dispatch_player_death(int32_t player_id, const char* damage_source) {
    SERVER_DISPATCH_BEGIN_RET(nullptr);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    char* result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchPlayerDeath(player_id, damage_source);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool server_dispatch_entity_damage(int32_t entity_id, const char* damage_source, double amount) {
    SERVER_DISPATCH_BEGIN_RET(true);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchEntityDamage(entity_id, damage_source, amount);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

void server_dispatch_entity_death(int32_t entity_id, const char* damage_source) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchEntityDeath(entity_id, damage_source);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

bool server_dispatch_player_attack_entity(int32_t player_id, int32_t target_id) {
    SERVER_DISPATCH_BEGIN_RET(true);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchPlayerAttackEntity(player_id, target_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

char* server_dispatch_player_chat(int32_t player_id, const char* message) {
    SERVER_DISPATCH_BEGIN_RET(nullptr);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    char* result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchPlayerChat(player_id, message);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool server_dispatch_player_command(int32_t player_id, const char* command) {
    SERVER_DISPATCH_BEGIN_RET(true);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchPlayerCommand(player_id, command);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool server_dispatch_item_use(int32_t player_id, const char* item_id, int32_t count, int32_t hand) {
    SERVER_DISPATCH_BEGIN_RET(true);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchItemUse(player_id, item_id, count, hand);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t server_dispatch_item_use_on_block(int32_t player_id, const char* item_id, int32_t count, int32_t hand, int32_t x, int32_t y, int32_t z, int32_t face) {
    SERVER_DISPATCH_BEGIN_RET(1);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchItemUseOnBlock(player_id, item_id, count, hand, x, y, z, face);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t server_dispatch_item_use_on_entity(int32_t player_id, const char* item_id, int32_t count, int32_t hand, int32_t target_id) {
    SERVER_DISPATCH_BEGIN_RET(1);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchItemUseOnEntity(player_id, item_id, count, hand, target_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool server_dispatch_block_place(int32_t player_id, int32_t x, int32_t y, int32_t z, const char* block_id) {
    SERVER_DISPATCH_BEGIN_RET(true);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchBlockPlace(player_id, x, y, z, block_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool server_dispatch_player_pickup_item(int32_t player_id, int32_t item_entity_id) {
    SERVER_DISPATCH_BEGIN_RET(true);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchPlayerPickupItem(player_id, item_entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool server_dispatch_player_drop_item(int32_t player_id, const char* item_id, int32_t count) {
    SERVER_DISPATCH_BEGIN_RET(true);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchPlayerDropItem(player_id, item_id, count);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

void server_dispatch_server_starting() {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchServerStarting();
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_server_started() {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchServerStarted();
    DartDll_DrainMicrotaskQueue();
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_server_stopping() {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchServerStopping();
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_register_registry_ready_handler(RegistryReadyCallback cb) {
    g_server_registry_ready_callback = cb;
    std::cout << "Server registry ready callback registered" << std::endl;
}

void server_dispatch_registry_ready() {
    SERVER_DISPATCH_BEGIN();
    std::cout << "Server registry ready signal received" << std::endl;
    if (g_server_registry_ready_callback) {
        bool did_enter = safe_enter_isolate();
        Dart_EnterScope();
        g_server_registry_ready_callback();
        Dart_ExitScope();
        safe_exit_isolate(did_enter);
    }
}

void server_dispatch_proxy_entity_spawn(int64_t handler_id, int32_t entity_id, int64_t world_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyEntitySpawn(handler_id, entity_id, world_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_entity_tick(int64_t handler_id, int32_t entity_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyEntityTick(handler_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_entity_death(int64_t handler_id, int32_t entity_id, const char* damage_source) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyEntityDeath(handler_id, entity_id, damage_source);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

bool server_dispatch_proxy_entity_damage(int64_t handler_id, int32_t entity_id, const char* damage_source, double amount) {
    SERVER_DISPATCH_BEGIN_RET(true);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyEntityDamage(handler_id, entity_id, damage_source, amount);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

void server_dispatch_proxy_entity_attack(int64_t handler_id, int32_t entity_id, int32_t target_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyEntityAttack(handler_id, entity_id, target_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_entity_target(int64_t handler_id, int32_t entity_id, int32_t target_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyEntityTarget(handler_id, entity_id, target_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_projectile_hit_entity(int64_t handler_id, int32_t projectile_id, int32_t target_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyProjectileHitEntity(handler_id, projectile_id, target_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_projectile_hit_block(int64_t handler_id, int32_t projectile_id, int32_t x, int32_t y, int32_t z, const char* side) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyProjectileHitBlock(handler_id, projectile_id, x, y, z, side);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_proxy_animal_breed(int64_t handler_id, int32_t entity_id, int32_t partner_id, int32_t baby_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyAnimalBreed(handler_id, entity_id, partner_id, baby_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

bool server_dispatch_proxy_item_attack_entity(int64_t handler_id, int32_t world_id, int32_t attacker_id, int32_t target_id) {
    SERVER_DISPATCH_BEGIN_RET(true);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyItemAttackEntity(handler_id, world_id, attacker_id, target_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t server_dispatch_proxy_item_use(int64_t handler_id, int64_t world_id, int32_t player_id, int32_t hand) {
    SERVER_DISPATCH_BEGIN_RET(4);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyItemUse(handler_id, world_id, player_id, hand);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t server_dispatch_proxy_item_use_on_block(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t player_id, int32_t hand) {
    SERVER_DISPATCH_BEGIN_RET(4);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyItemUseOnBlock(handler_id, world_id, x, y, z, player_id, hand);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t server_dispatch_proxy_item_use_on_entity(int64_t handler_id, int64_t world_id, int32_t entity_id, int32_t player_id, int32_t hand) {
    SERVER_DISPATCH_BEGIN_RET(4);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchProxyItemUseOnEntity(handler_id, world_id, entity_id, player_id, hand);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

int32_t server_dispatch_command_execute(int64_t command_id, int32_t player_id, const char* args_json) {
    SERVER_DISPATCH_BEGIN_RET(0);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    int32_t result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchCommandExecute(command_id, player_id, args_json);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool server_dispatch_custom_goal_can_use(const char* goal_id, int32_t entity_id) {
    SERVER_DISPATCH_BEGIN_RET(false);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchCustomGoalCanUse(goal_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

bool server_dispatch_custom_goal_can_continue_to_use(const char* goal_id, int32_t entity_id) {
    SERVER_DISPATCH_BEGIN_RET(false);
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    bool result = dart_mc_bridge::ServerCallbackRegistry::instance().dispatchCustomGoalCanContinueToUse(goal_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
    return result;
}

void server_dispatch_custom_goal_start(const char* goal_id, int32_t entity_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchCustomGoalStart(goal_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_custom_goal_tick(const char* goal_id, int32_t entity_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchCustomGoalTick(goal_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_dispatch_custom_goal_stop(const char* goal_id, int32_t entity_id) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchCustomGoalStop(goal_id, entity_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_send_chat_message(int64_t player_id, const char* message) {
    if (g_server_send_chat_callback) {
        g_server_send_chat_callback(player_id, message);
    }
}

// ==========================================================================
// Registration Queue Functions (thread-safe)
// ==========================================================================

int64_t server_queue_block_registration(
    const char* namespace_id, const char* path,
    float hardness, float resistance, bool requires_tool, int32_t luminance,
    double slipperiness, double velocity_multiplier, double jump_velocity_multiplier,
    bool ticks_randomly, bool collidable, bool replaceable, bool burnable) {

    std::lock_guard<std::mutex> lock(g_server_registration_mutex);
    int64_t handler_id = g_server_next_block_id.fetch_add(1);

    ServerBlockRegistration reg;
    reg.handler_id = handler_id;
    reg.namespace_id = namespace_id ? namespace_id : "";
    reg.path = path ? path : "";
    reg.hardness = hardness;
    reg.resistance = resistance;
    reg.requires_tool = requires_tool;
    reg.luminance = luminance;
    reg.slipperiness = slipperiness;
    reg.velocity_multiplier = velocity_multiplier;
    reg.jump_velocity_multiplier = jump_velocity_multiplier;
    reg.ticks_randomly = ticks_randomly;
    reg.collidable = collidable;
    reg.replaceable = replaceable;
    reg.burnable = burnable;

    g_server_block_queue.push(reg);
    return handler_id;
}

int64_t server_queue_item_registration(
    const char* namespace_id, const char* path,
    int32_t max_stack_size, int32_t max_damage, bool fire_resistant,
    double attack_damage, double attack_speed, double attack_knockback) {

    std::lock_guard<std::mutex> lock(g_server_registration_mutex);
    int64_t handler_id = g_server_next_item_id.fetch_add(1);

    ServerItemRegistration reg;
    reg.handler_id = handler_id;
    reg.namespace_id = namespace_id ? namespace_id : "";
    reg.path = path ? path : "";
    reg.max_stack_size = max_stack_size;
    reg.max_damage = max_damage;
    reg.fire_resistant = fire_resistant;
    reg.attack_damage = attack_damage;
    reg.attack_speed = attack_speed;
    reg.attack_knockback = attack_knockback;

    g_server_item_queue.push(reg);
    return handler_id;
}

int64_t server_queue_entity_registration(
    const char* namespace_id, const char* path,
    double width, double height, double max_health, double movement_speed, double attack_damage,
    int32_t spawn_group, int32_t base_type, const char* breeding_item,
    const char* model_type, const char* texture_path, double model_scale,
    const char* goals_json, const char* target_goals_json) {

    std::lock_guard<std::mutex> lock(g_server_registration_mutex);
    int64_t handler_id = g_server_next_entity_id.fetch_add(1);

    ServerEntityRegistration reg;
    reg.handler_id = handler_id;
    reg.namespace_id = namespace_id ? namespace_id : "";
    reg.path = path ? path : "";
    reg.width = width;
    reg.height = height;
    reg.max_health = max_health;
    reg.movement_speed = movement_speed;
    reg.attack_damage = attack_damage;
    reg.spawn_group = spawn_group;
    reg.base_type = base_type;
    reg.breeding_item = breeding_item ? breeding_item : "";
    reg.model_type = model_type ? model_type : "";
    reg.texture_path = texture_path ? texture_path : "";
    reg.model_scale = model_scale;
    reg.goals_json = goals_json ? goals_json : "";
    reg.target_goals_json = target_goals_json ? target_goals_json : "";

    g_server_entity_queue.push(reg);
    return handler_id;
}

void server_signal_registrations_queued() {
    g_server_registrations_complete.store(true);
}

// ==========================================================================
// Network Packet Functions
// ==========================================================================

void server_register_packet_received_handler(PacketReceivedCallback cb) {
    dart_mc_bridge::ServerCallbackRegistry::instance().setPacketReceivedHandler(cb);
}

void server_set_send_packet_to_client_callback(SendPacketToClientCallback cb) {
    g_server_send_packet_callback = cb;
}

void server_dispatch_client_packet(int32_t player_id, int32_t packet_type, const uint8_t* data, int32_t data_length) {
    SERVER_DISPATCH_BEGIN();
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::ServerCallbackRegistry::instance().dispatchPacketReceived(player_id, packet_type, data, data_length);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}

void server_send_packet_to_client(int32_t player_id, int32_t packet_type, const uint8_t* data, int32_t data_length) {
    if (g_server_send_packet_callback) {
        g_server_send_packet_callback(player_id, packet_type, data, data_length);
    }
}

// ==========================================================================
// Server-side Queue Access Functions (called from JNI)
// ==========================================================================

bool server_has_pending_block_registrations() {
    std::lock_guard<std::mutex> lock(g_server_registration_mutex);
    return !g_server_block_queue.empty();
}

bool server_has_pending_item_registrations() {
    std::lock_guard<std::mutex> lock(g_server_registration_mutex);
    return !g_server_item_queue.empty();
}

bool server_has_pending_entity_registrations() {
    std::lock_guard<std::mutex> lock(g_server_registration_mutex);
    return !g_server_entity_queue.empty();
}

bool server_get_next_block_registration(
    int64_t* out_handler_id,
    char* out_namespace, size_t namespace_len,
    char* out_path, size_t path_len,
    float* out_hardness, float* out_resistance, bool* out_requires_tool,
    int32_t* out_luminance, double* out_slipperiness,
    double* out_velocity_mult, double* out_jump_velocity_mult,
    bool* out_ticks_randomly, bool* out_collidable,
    bool* out_replaceable, bool* out_burnable
) {
    std::lock_guard<std::mutex> lock(g_server_registration_mutex);

    if (g_server_block_queue.empty()) return false;

    const auto& reg = g_server_block_queue.front();

    *out_handler_id = reg.handler_id;
    strncpy(out_namespace, reg.namespace_id.c_str(), namespace_len - 1);
    out_namespace[namespace_len - 1] = '\0';
    strncpy(out_path, reg.path.c_str(), path_len - 1);
    out_path[path_len - 1] = '\0';
    *out_hardness = reg.hardness;
    *out_resistance = reg.resistance;
    *out_requires_tool = reg.requires_tool;
    *out_luminance = reg.luminance;
    *out_slipperiness = reg.slipperiness;
    *out_velocity_mult = reg.velocity_multiplier;
    *out_jump_velocity_mult = reg.jump_velocity_multiplier;
    *out_ticks_randomly = reg.ticks_randomly;
    *out_collidable = reg.collidable;
    *out_replaceable = reg.replaceable;
    *out_burnable = reg.burnable;

    g_server_block_queue.pop();
    return true;
}

bool server_get_next_item_registration(
    int64_t* out_handler_id,
    char* out_namespace, size_t namespace_len,
    char* out_path, size_t path_len,
    int32_t* out_max_stack_size, int32_t* out_max_damage, bool* out_fire_resistant,
    double* out_attack_damage, double* out_attack_speed, double* out_attack_knockback
) {
    std::lock_guard<std::mutex> lock(g_server_registration_mutex);

    if (g_server_item_queue.empty()) return false;

    const auto& reg = g_server_item_queue.front();

    *out_handler_id = reg.handler_id;
    strncpy(out_namespace, reg.namespace_id.c_str(), namespace_len - 1);
    out_namespace[namespace_len - 1] = '\0';
    strncpy(out_path, reg.path.c_str(), path_len - 1);
    out_path[path_len - 1] = '\0';
    *out_max_stack_size = reg.max_stack_size;
    *out_max_damage = reg.max_damage;
    *out_fire_resistant = reg.fire_resistant;
    *out_attack_damage = reg.attack_damage;
    *out_attack_speed = reg.attack_speed;
    *out_attack_knockback = reg.attack_knockback;

    g_server_item_queue.pop();
    return true;
}

bool server_get_next_entity_registration(
    int64_t* out_handler_id,
    char* out_namespace, size_t namespace_len,
    char* out_path, size_t path_len,
    double* out_width, double* out_height, double* out_max_health,
    double* out_movement_speed, double* out_attack_damage,
    int32_t* out_spawn_group, int32_t* out_base_type,
    char* out_breeding_item, size_t breeding_item_len,
    char* out_model_type, size_t model_type_len,
    char* out_texture_path, size_t texture_path_len,
    double* out_model_scale,
    char* out_goals_json, size_t goals_json_len,
    char* out_target_goals_json, size_t target_goals_json_len
) {
    std::lock_guard<std::mutex> lock(g_server_registration_mutex);

    if (g_server_entity_queue.empty()) return false;

    const auto& reg = g_server_entity_queue.front();

    *out_handler_id = reg.handler_id;
    strncpy(out_namespace, reg.namespace_id.c_str(), namespace_len - 1);
    out_namespace[namespace_len - 1] = '\0';
    strncpy(out_path, reg.path.c_str(), path_len - 1);
    out_path[path_len - 1] = '\0';
    *out_width = reg.width;
    *out_height = reg.height;
    *out_max_health = reg.max_health;
    *out_movement_speed = reg.movement_speed;
    *out_attack_damage = reg.attack_damage;
    *out_spawn_group = reg.spawn_group;
    *out_base_type = reg.base_type;

    strncpy(out_breeding_item, reg.breeding_item.c_str(), breeding_item_len - 1);
    out_breeding_item[breeding_item_len - 1] = '\0';
    strncpy(out_model_type, reg.model_type.c_str(), model_type_len - 1);
    out_model_type[model_type_len - 1] = '\0';
    strncpy(out_texture_path, reg.texture_path.c_str(), texture_path_len - 1);
    out_texture_path[texture_path_len - 1] = '\0';
    *out_model_scale = reg.model_scale;
    strncpy(out_goals_json, reg.goals_json.c_str(), goals_json_len - 1);
    out_goals_json[goals_json_len - 1] = '\0';
    strncpy(out_target_goals_json, reg.target_goals_json.c_str(), target_goals_json_len - 1);
    out_target_goals_json[target_goals_json_len - 1] = '\0';

    g_server_entity_queue.pop();
    return true;
}

} // extern "C"
