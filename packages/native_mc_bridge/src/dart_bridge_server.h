#pragma once

#include <cstdint>
#include <jni.h>

// ==========================================================================
// Server-side Dart Bridge using dart_dll (standalone Dart VM)
// ==========================================================================
// This bridge runs on the Server thread and uses dart_dll for script loading.
// Server functions are called from multiple threads, so we need mutex +
// Dart_EnterIsolate/Dart_ExitIsolate for thread safety.

extern "C" {

// ==========================================================================
// Lifecycle
// ==========================================================================

// Initialize the Dart VM and load the server-side script
// script_path: Path to the Dart script to run
// package_config: Path to package_config.json (can be null)
// service_port: Port for Dart VM service (hot reload/debugging)
bool dart_server_init(const char* script_path, const char* package_config, int service_port);

// Shutdown the Dart VM
void dart_server_shutdown();

// Tick the Dart VM (drain microtask queue)
void dart_server_tick();

// Set JVM reference for JNI callbacks
void dart_server_set_jvm(JavaVM* jvm);

// Get the Dart VM service URL for hot reload/debugging
const char* dart_server_get_service_url();

// ==========================================================================
// Callback Types (same as dart_bridge.h for server-side events)
// ==========================================================================

// Block/World events
typedef int32_t (*BlockBreakCallback)(int32_t x, int32_t y, int32_t z, int64_t player_id);
typedef int32_t (*BlockInteractCallback)(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand);
typedef void (*TickCallback)(int64_t tick);

// Proxy block callbacks
typedef bool (*ProxyBlockBreakCallback)(int64_t handler_id, int64_t world_id,
                                         int32_t x, int32_t y, int32_t z, int64_t player_id);
typedef int32_t (*ProxyBlockUseCallback)(int64_t handler_id, int64_t world_id,
                                          int32_t x, int32_t y, int32_t z,
                                          int64_t player_id, int32_t hand);
typedef void (*ProxyBlockSteppedOnCallback)(int64_t handler_id, int64_t world_id,
                                             int32_t x, int32_t y, int32_t z, int32_t entity_id);
typedef void (*ProxyBlockFallenUponCallback)(int64_t handler_id, int64_t world_id,
                                              int32_t x, int32_t y, int32_t z, int32_t entity_id, float fall_distance);
typedef void (*ProxyBlockRandomTickCallback)(int64_t handler_id, int64_t world_id,
                                              int32_t x, int32_t y, int32_t z);
typedef void (*ProxyBlockPlacedCallback)(int64_t handler_id, int64_t world_id,
                                          int32_t x, int32_t y, int32_t z, int64_t player_id);
typedef void (*ProxyBlockRemovedCallback)(int64_t handler_id, int64_t world_id,
                                           int32_t x, int32_t y, int32_t z);
typedef void (*ProxyBlockNeighborChangedCallback)(int64_t handler_id, int64_t world_id,
                                                   int32_t x, int32_t y, int32_t z,
                                                   int32_t neighbor_x, int32_t neighbor_y, int32_t neighbor_z);
typedef void (*ProxyBlockEntityInsideCallback)(int64_t handler_id, int64_t world_id,
                                                int32_t x, int32_t y, int32_t z, int32_t entity_id);

// Block entity callbacks
typedef void (*BlockEntityLoadCallback)(int32_t handler_id, int64_t block_pos_hash, const char* nbt_json);
typedef const char* (*BlockEntitySaveCallback)(int32_t handler_id, int64_t block_pos_hash);
typedef void (*BlockEntityTickCallback)(int32_t handler_id, int64_t block_pos_hash);
typedef int32_t (*BlockEntityGetDataSlotCallback)(int32_t handler_id, int64_t block_pos_hash, int32_t index);
typedef void (*BlockEntitySetDataSlotCallback)(int32_t handler_id, int64_t block_pos_hash, int32_t index, int32_t value);
typedef void (*BlockEntityRemovedCallback)(int32_t handler_id, int64_t block_pos_hash);

// Player events
typedef void (*PlayerJoinCallback)(int32_t player_id);
typedef void (*PlayerLeaveCallback)(int32_t player_id);
typedef void (*PlayerRespawnCallback)(int32_t player_id, bool end_conquered);
typedef char* (*PlayerDeathCallback)(int32_t player_id, const char* damage_source);

// Entity events
typedef bool (*EntityDamageCallback)(int32_t entity_id, const char* damage_source, double amount);
typedef void (*EntityDeathCallback)(int32_t entity_id, const char* damage_source);
typedef bool (*PlayerAttackEntityCallback)(int32_t player_id, int32_t target_id);

// Chat/Command events
typedef char* (*PlayerChatCallback)(int32_t player_id, const char* message);
typedef bool (*PlayerCommandCallback)(int32_t player_id, const char* command);

// Item events
typedef bool (*ItemUseCallback)(int32_t player_id, const char* item_id, int32_t count, int32_t hand);
typedef int32_t (*ItemUseOnBlockCallback)(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                           int32_t x, int32_t y, int32_t z, int32_t face);
typedef int32_t (*ItemUseOnEntityCallback)(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                            int32_t target_id);

// Block events
typedef bool (*BlockPlaceCallback)(int32_t player_id, int32_t x, int32_t y, int32_t z, const char* block_id);

// Item Pickup/Drop
typedef bool (*PlayerPickupItemCallback)(int32_t player_id, int32_t item_entity_id);
typedef bool (*PlayerDropItemCallback)(int32_t player_id, const char* item_id, int32_t count);

// Server lifecycle
typedef void (*ServerStartingCallback)();
typedef void (*ServerStartedCallback)();
typedef void (*ServerStoppingCallback)();

// Registry ready callback (called when Java signals it's safe to register items/blocks)
typedef void (*RegistryReadyCallback)();

// Entity proxy callbacks
typedef void (*ProxyEntitySpawnCallback)(int64_t handler_id, int32_t entity_id, int64_t world_id);
typedef void (*ProxyEntityTickCallback)(int64_t handler_id, int32_t entity_id);
typedef void (*ProxyEntityDeathCallback)(int64_t handler_id, int32_t entity_id, const char* damage_source);
typedef bool (*ProxyEntityDamageCallback)(int64_t handler_id, int32_t entity_id, const char* damage_source, double amount);
typedef void (*ProxyEntityAttackCallback)(int64_t handler_id, int32_t entity_id, int32_t target_id);
typedef void (*ProxyEntityTargetCallback)(int64_t handler_id, int32_t entity_id, int32_t target_id);

// Projectile proxy callbacks
typedef void (*ProxyProjectileHitEntityCallback)(int64_t handler_id, int32_t projectile_id, int32_t target_id);
typedef void (*ProxyProjectileHitBlockCallback)(int64_t handler_id, int32_t projectile_id, int32_t x, int32_t y, int32_t z, const char* side);

// Animal proxy callbacks
typedef void (*ProxyAnimalBreedCallback)(int64_t handler_id, int32_t entity_id, int32_t partner_id, int32_t baby_id);

// Item proxy callbacks
typedef bool (*ProxyItemAttackEntityCallback)(int64_t handler_id, int32_t world_id, int32_t attacker_id, int32_t target_id);
typedef int32_t (*ProxyItemUseCallback)(int64_t handler_id, int64_t world_id, int32_t player_id, int32_t hand);
typedef int32_t (*ProxyItemUseOnBlockCallback)(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t player_id, int32_t hand);
typedef int32_t (*ProxyItemUseOnEntityCallback)(int64_t handler_id, int64_t world_id, int32_t entity_id, int32_t player_id, int32_t hand);

// Command callback
typedef int32_t (*CommandExecuteCallback)(int64_t command_id, int32_t player_id, const char* args_json);

// Custom goal callbacks
typedef bool (*CustomGoalCanUseCallback)(const char* goal_id, int32_t entity_id);
typedef bool (*CustomGoalCanContinueToUseCallback)(const char* goal_id, int32_t entity_id);
typedef void (*CustomGoalStartCallback)(const char* goal_id, int32_t entity_id);
typedef void (*CustomGoalTickCallback)(const char* goal_id, int32_t entity_id);
typedef void (*CustomGoalStopCallback)(const char* goal_id, int32_t entity_id);

// Dart -> Java communication
typedef void (*SendChatMessageCallback)(int64_t player_id, const char* message);

// ==========================================================================
// Callback Registration (called from Dart via FFI)
// ==========================================================================

void server_register_block_break_handler(BlockBreakCallback cb);
void server_register_block_interact_handler(BlockInteractCallback cb);
void server_register_tick_handler(TickCallback cb);

void server_register_proxy_block_break_handler(ProxyBlockBreakCallback cb);
void server_register_proxy_block_use_handler(ProxyBlockUseCallback cb);
void server_register_proxy_block_stepped_on_handler(ProxyBlockSteppedOnCallback cb);
void server_register_proxy_block_fallen_upon_handler(ProxyBlockFallenUponCallback cb);
void server_register_proxy_block_random_tick_handler(ProxyBlockRandomTickCallback cb);
void server_register_proxy_block_placed_handler(ProxyBlockPlacedCallback cb);
void server_register_proxy_block_removed_handler(ProxyBlockRemovedCallback cb);
void server_register_proxy_block_neighbor_changed_handler(ProxyBlockNeighborChangedCallback cb);
void server_register_proxy_block_entity_inside_handler(ProxyBlockEntityInsideCallback cb);

// Block entity callback registration
void server_register_block_entity_load_handler(BlockEntityLoadCallback cb);
void server_register_block_entity_save_handler(BlockEntitySaveCallback cb);
void server_register_block_entity_tick_handler(BlockEntityTickCallback cb);
void server_register_block_entity_get_data_slot_handler(BlockEntityGetDataSlotCallback cb);
void server_register_block_entity_set_data_slot_handler(BlockEntitySetDataSlotCallback cb);
void server_register_block_entity_removed_handler(BlockEntityRemovedCallback cb);

void server_register_player_join_handler(PlayerJoinCallback cb);
void server_register_player_leave_handler(PlayerLeaveCallback cb);
void server_register_player_respawn_handler(PlayerRespawnCallback cb);
void server_register_player_death_handler(PlayerDeathCallback cb);
void server_register_entity_damage_handler(EntityDamageCallback cb);
void server_register_entity_death_handler(EntityDeathCallback cb);
void server_register_player_attack_entity_handler(PlayerAttackEntityCallback cb);
void server_register_player_chat_handler(PlayerChatCallback cb);
void server_register_player_command_handler(PlayerCommandCallback cb);
void server_register_item_use_handler(ItemUseCallback cb);
void server_register_item_use_on_block_handler(ItemUseOnBlockCallback cb);
void server_register_item_use_on_entity_handler(ItemUseOnEntityCallback cb);
void server_register_block_place_handler(BlockPlaceCallback cb);
void server_register_player_pickup_item_handler(PlayerPickupItemCallback cb);
void server_register_player_drop_item_handler(PlayerDropItemCallback cb);
void server_register_server_starting_handler(ServerStartingCallback cb);
void server_register_server_started_handler(ServerStartedCallback cb);
void server_register_server_stopping_handler(ServerStoppingCallback cb);

void server_register_proxy_entity_spawn_handler(ProxyEntitySpawnCallback cb);
void server_register_proxy_entity_tick_handler(ProxyEntityTickCallback cb);
void server_register_proxy_entity_death_handler(ProxyEntityDeathCallback cb);
void server_register_proxy_entity_damage_handler(ProxyEntityDamageCallback cb);
void server_register_proxy_entity_attack_handler(ProxyEntityAttackCallback cb);
void server_register_proxy_entity_target_handler(ProxyEntityTargetCallback cb);

void server_register_proxy_item_attack_entity_handler(ProxyItemAttackEntityCallback cb);
void server_register_proxy_item_use_handler(ProxyItemUseCallback cb);
void server_register_proxy_item_use_on_block_handler(ProxyItemUseOnBlockCallback cb);
void server_register_proxy_item_use_on_entity_handler(ProxyItemUseOnEntityCallback cb);

void server_register_command_execute_handler(CommandExecuteCallback cb);

void server_register_custom_goal_can_use_handler(CustomGoalCanUseCallback cb);
void server_register_custom_goal_can_continue_to_use_handler(CustomGoalCanContinueToUseCallback cb);
void server_register_custom_goal_start_handler(CustomGoalStartCallback cb);
void server_register_custom_goal_tick_handler(CustomGoalTickCallback cb);
void server_register_custom_goal_stop_handler(CustomGoalStopCallback cb);

void server_set_send_chat_message_callback(SendChatMessageCallback cb);

// Registry ready callback registration
void server_register_registry_ready_handler(RegistryReadyCallback cb);

// ==========================================================================
// Event Dispatch (called from Java via JNI)
// These functions use safe_enter_isolate/safe_exit_isolate pattern
// ==========================================================================

int32_t server_dispatch_block_break(int32_t x, int32_t y, int32_t z, int64_t player_id);
int32_t server_dispatch_block_interact(int32_t x, int32_t y, int32_t z, int64_t player_id, int32_t hand);
void server_dispatch_tick(int64_t tick);

bool server_dispatch_proxy_block_break(int64_t handler_id, int64_t world_id,
                                        int32_t x, int32_t y, int32_t z, int64_t player_id);
int32_t server_dispatch_proxy_block_use(int64_t handler_id, int64_t world_id,
                                         int32_t x, int32_t y, int32_t z,
                                         int64_t player_id, int32_t hand);
void server_dispatch_proxy_block_stepped_on(int64_t handler_id, int64_t world_id,
                                             int32_t x, int32_t y, int32_t z, int32_t entity_id);
void server_dispatch_proxy_block_fallen_upon(int64_t handler_id, int64_t world_id,
                                              int32_t x, int32_t y, int32_t z, int32_t entity_id, float fall_distance);
void server_dispatch_proxy_block_random_tick(int64_t handler_id, int64_t world_id,
                                              int32_t x, int32_t y, int32_t z);
void server_dispatch_proxy_block_placed(int64_t handler_id, int64_t world_id,
                                         int32_t x, int32_t y, int32_t z, int64_t player_id);
void server_dispatch_proxy_block_removed(int64_t handler_id, int64_t world_id,
                                          int32_t x, int32_t y, int32_t z);
void server_dispatch_proxy_block_neighbor_changed(int64_t handler_id, int64_t world_id,
                                                   int32_t x, int32_t y, int32_t z,
                                                   int32_t neighbor_x, int32_t neighbor_y, int32_t neighbor_z);
void server_dispatch_proxy_block_entity_inside(int64_t handler_id, int64_t world_id,
                                                int32_t x, int32_t y, int32_t z, int32_t entity_id);

// Block entity dispatch functions
void server_dispatch_block_entity_load(int32_t handler_id, int64_t block_pos_hash, const char* nbt_json);
const char* server_dispatch_block_entity_save(int32_t handler_id, int64_t block_pos_hash);
void server_dispatch_block_entity_tick(int32_t handler_id, int64_t block_pos_hash);
int32_t server_dispatch_block_entity_get_data_slot(int32_t handler_id, int64_t block_pos_hash, int32_t index);
void server_dispatch_block_entity_set_data_slot(int32_t handler_id, int64_t block_pos_hash, int32_t index, int32_t value);
void server_dispatch_block_entity_removed(int32_t handler_id, int64_t block_pos_hash);

void server_dispatch_player_join(int32_t player_id);
void server_dispatch_player_leave(int32_t player_id);
void server_dispatch_player_respawn(int32_t player_id, bool end_conquered);
char* server_dispatch_player_death(int32_t player_id, const char* damage_source);
bool server_dispatch_entity_damage(int32_t entity_id, const char* damage_source, double amount);
void server_dispatch_entity_death(int32_t entity_id, const char* damage_source);
bool server_dispatch_player_attack_entity(int32_t player_id, int32_t target_id);
char* server_dispatch_player_chat(int32_t player_id, const char* message);
bool server_dispatch_player_command(int32_t player_id, const char* command);
bool server_dispatch_item_use(int32_t player_id, const char* item_id, int32_t count, int32_t hand);
int32_t server_dispatch_item_use_on_block(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                           int32_t x, int32_t y, int32_t z, int32_t face);
int32_t server_dispatch_item_use_on_entity(int32_t player_id, const char* item_id, int32_t count, int32_t hand,
                                            int32_t target_id);
bool server_dispatch_block_place(int32_t player_id, int32_t x, int32_t y, int32_t z, const char* block_id);
bool server_dispatch_player_pickup_item(int32_t player_id, int32_t item_entity_id);
bool server_dispatch_player_drop_item(int32_t player_id, const char* item_id, int32_t count);
void server_dispatch_server_starting();
void server_dispatch_server_started();
void server_dispatch_server_stopping();

// Dispatch registry ready signal (called from Java when registries are ready)
void server_dispatch_registry_ready();

void server_dispatch_proxy_entity_spawn(int64_t handler_id, int32_t entity_id, int64_t world_id);
void server_dispatch_proxy_entity_tick(int64_t handler_id, int32_t entity_id);
void server_dispatch_proxy_entity_death(int64_t handler_id, int32_t entity_id, const char* damage_source);
bool server_dispatch_proxy_entity_damage(int64_t handler_id, int32_t entity_id, const char* damage_source, double amount);
void server_dispatch_proxy_entity_attack(int64_t handler_id, int32_t entity_id, int32_t target_id);
void server_dispatch_proxy_entity_target(int64_t handler_id, int32_t entity_id, int32_t target_id);

// Projectile proxy dispatch
void server_dispatch_proxy_projectile_hit_entity(int64_t handler_id, int32_t projectile_id, int32_t target_id);
void server_dispatch_proxy_projectile_hit_block(int64_t handler_id, int32_t projectile_id, int32_t x, int32_t y, int32_t z, const char* side);

// Animal proxy dispatch
void server_dispatch_proxy_animal_breed(int64_t handler_id, int32_t entity_id, int32_t partner_id, int32_t baby_id);

bool server_dispatch_proxy_item_attack_entity(int64_t handler_id, int32_t world_id, int32_t attacker_id, int32_t target_id);
int32_t server_dispatch_proxy_item_use(int64_t handler_id, int64_t world_id, int32_t player_id, int32_t hand);
int32_t server_dispatch_proxy_item_use_on_block(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t player_id, int32_t hand);
int32_t server_dispatch_proxy_item_use_on_entity(int64_t handler_id, int64_t world_id, int32_t entity_id, int32_t player_id, int32_t hand);

int32_t server_dispatch_command_execute(int64_t command_id, int32_t player_id, const char* args_json);

bool server_dispatch_custom_goal_can_use(const char* goal_id, int32_t entity_id);
bool server_dispatch_custom_goal_can_continue_to_use(const char* goal_id, int32_t entity_id);
void server_dispatch_custom_goal_start(const char* goal_id, int32_t entity_id);
void server_dispatch_custom_goal_tick(const char* goal_id, int32_t entity_id);
void server_dispatch_custom_goal_stop(const char* goal_id, int32_t entity_id);

void server_send_chat_message(int64_t player_id, const char* message);

// ==========================================================================
// Network Packet Functions
// ==========================================================================

// Callback type for packet received from client (C2S)
typedef void (*PacketReceivedCallback)(int32_t player_id, int32_t packet_type, const uint8_t* data, int32_t data_length);

// Callback type for sending packets to client (S2C) - called by Dart
typedef void (*SendPacketToClientCallback)(int32_t player_id, int32_t packet_type, const uint8_t* data, int32_t data_length);

// Register the callback for receiving packets from clients (called from Dart via FFI)
void server_register_packet_received_handler(PacketReceivedCallback cb);

// Set the callback for sending packets to clients (called from Dart via FFI)
void server_set_send_packet_to_client_callback(SendPacketToClientCallback cb);

// Dispatch a packet from client to server Dart VM (called from Java via JNI)
void server_dispatch_client_packet(int32_t player_id, int32_t packet_type, const uint8_t* data, int32_t data_length);

// Send a packet from server to client - invokes the Java callback (called from Dart via FFI)
void server_send_packet_to_client(int32_t player_id, int32_t packet_type, const uint8_t* data, int32_t data_length);

// ==========================================================================
// Registration Queue Functions (thread-safe registration from Dart)
// ==========================================================================

int64_t server_queue_block_registration(
    const char* namespace_id, const char* path,
    float hardness, float resistance, bool requires_tool, int32_t luminance,
    double slipperiness, double velocity_multiplier, double jump_velocity_multiplier,
    bool ticks_randomly, bool collidable, bool replaceable, bool burnable);

int64_t server_queue_item_registration(
    const char* namespace_id, const char* path,
    int32_t max_stack_size, int32_t max_damage, bool fire_resistant,
    double attack_damage, double attack_speed, double attack_knockback);

int64_t server_queue_entity_registration(
    const char* namespace_id, const char* path,
    double width, double height, double max_health, double movement_speed, double attack_damage,
    int32_t spawn_group, int32_t base_type, const char* breeding_item,
    const char* model_type, const char* texture_path, double model_scale,
    const char* goals_json, const char* target_goals_json);

void server_signal_registrations_queued();

// ==========================================================================
// Registration Queue Access Functions (called from JNI)
// ==========================================================================

bool server_has_pending_block_registrations();
bool server_has_pending_item_registrations();
bool server_has_pending_entity_registrations();

bool server_get_next_block_registration(
    int64_t* out_handler_id,
    char* out_namespace, size_t namespace_len,
    char* out_path, size_t path_len,
    float* out_hardness, float* out_resistance, bool* out_requires_tool,
    int32_t* out_luminance, double* out_slipperiness,
    double* out_velocity_mult, double* out_jump_velocity_mult,
    bool* out_ticks_randomly, bool* out_collidable,
    bool* out_replaceable, bool* out_burnable);

bool server_get_next_item_registration(
    int64_t* out_handler_id,
    char* out_namespace, size_t namespace_len,
    char* out_path, size_t path_len,
    int32_t* out_max_stack_size, int32_t* out_max_damage, bool* out_fire_resistant,
    double* out_attack_damage, double* out_attack_speed, double* out_attack_knockback);

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
    char* out_target_goals_json, size_t target_goals_json_len);

// ==========================================================================
// Block Entity Registration Queue Functions
// ==========================================================================

/**
 * Queue a block entity registration from Dart.
 *
 * @param block_id The block ID this block entity is associated with (e.g., "mymod:furnace")
 * @param inventory_size Number of inventory slots (0 for no inventory)
 * @param container_title Display title for the container UI
 * @param ticks Whether this block entity should tick
 * @return Handler ID assigned to this block entity type
 */
int32_t server_queue_block_entity_registration(
    const char* block_id,
    int32_t inventory_size,
    const char* container_title,
    bool ticks);

/**
 * Check if there are pending block entity registrations.
 */
bool server_has_pending_block_entity_registrations();

/**
 * Get the next block entity registration from the queue.
 * Returns true if a registration was retrieved, false if queue is empty.
 */
bool server_get_next_block_entity_registration(
    int32_t* out_handler_id,
    char* out_block_id, size_t block_id_len,
    int32_t* out_inventory_size,
    char* out_container_title, size_t container_title_len,
    bool* out_ticks);

} // extern "C"
