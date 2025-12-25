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

    // Additional proxy block callbacks
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

    void register_proxy_block_stepped_on_handler(ProxyBlockSteppedOnCallback cb);
    void register_proxy_block_fallen_upon_handler(ProxyBlockFallenUponCallback cb);
    void register_proxy_block_random_tick_handler(ProxyBlockRandomTickCallback cb);
    void register_proxy_block_placed_handler(ProxyBlockPlacedCallback cb);
    void register_proxy_block_removed_handler(ProxyBlockRemovedCallback cb);
    void register_proxy_block_neighbor_changed_handler(ProxyBlockNeighborChangedCallback cb);
    void register_proxy_block_entity_inside_handler(ProxyBlockEntityInsideCallback cb);

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

    // Additional proxy block dispatch functions
    void dispatch_proxy_block_stepped_on(int64_t handler_id, int64_t world_id,
                                          int32_t x, int32_t y, int32_t z, int32_t entity_id);
    void dispatch_proxy_block_fallen_upon(int64_t handler_id, int64_t world_id,
                                           int32_t x, int32_t y, int32_t z, int32_t entity_id, float fall_distance);
    void dispatch_proxy_block_random_tick(int64_t handler_id, int64_t world_id,
                                           int32_t x, int32_t y, int32_t z);
    void dispatch_proxy_block_placed(int64_t handler_id, int64_t world_id,
                                      int32_t x, int32_t y, int32_t z, int64_t player_id);
    void dispatch_proxy_block_removed(int64_t handler_id, int64_t world_id,
                                       int32_t x, int32_t y, int32_t z);
    void dispatch_proxy_block_neighbor_changed(int64_t handler_id, int64_t world_id,
                                                int32_t x, int32_t y, int32_t z,
                                                int32_t neighbor_x, int32_t neighbor_y, int32_t neighbor_z);
    void dispatch_proxy_block_entity_inside(int64_t handler_id, int64_t world_id,
                                             int32_t x, int32_t y, int32_t z, int32_t entity_id);

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

    // ==========================================================================
    // Screen/GUI Callbacks
    // ==========================================================================

    // Screen callbacks (called from Dart via FFI)
    typedef void (*ScreenInitCallback)(int64_t screen_id, int32_t width, int32_t height);
    typedef void (*ScreenTickCallback)(int64_t screen_id);
    typedef void (*ScreenRenderCallback)(int64_t screen_id, int32_t mouse_x, int32_t mouse_y, float partial_tick);
    typedef void (*ScreenCloseCallback)(int64_t screen_id);
    typedef bool (*ScreenKeyPressedCallback)(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers);
    typedef bool (*ScreenKeyReleasedCallback)(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers);
    typedef bool (*ScreenCharTypedCallback)(int64_t screen_id, int32_t code_point, int32_t modifiers);
    typedef bool (*ScreenMouseClickedCallback)(int64_t screen_id, double mouse_x, double mouse_y, int32_t button);
    typedef bool (*ScreenMouseReleasedCallback)(int64_t screen_id, double mouse_x, double mouse_y, int32_t button);
    typedef bool (*ScreenMouseDraggedCallback)(int64_t screen_id, double mouse_x, double mouse_y, int32_t button, double drag_x, double drag_y);
    typedef bool (*ScreenMouseScrolledCallback)(int64_t screen_id, double mouse_x, double mouse_y, double delta_x, double delta_y);

    // Screen callback registration (called from Dart via FFI)
    void register_screen_init_callback(ScreenInitCallback callback);
    void register_screen_tick_callback(ScreenTickCallback callback);
    void register_screen_render_callback(ScreenRenderCallback callback);
    void register_screen_close_callback(ScreenCloseCallback callback);
    void register_screen_key_pressed_callback(ScreenKeyPressedCallback callback);
    void register_screen_key_released_callback(ScreenKeyReleasedCallback callback);
    void register_screen_char_typed_callback(ScreenCharTypedCallback callback);
    void register_screen_mouse_clicked_callback(ScreenMouseClickedCallback callback);
    void register_screen_mouse_released_callback(ScreenMouseReleasedCallback callback);
    void register_screen_mouse_dragged_callback(ScreenMouseDraggedCallback callback);
    void register_screen_mouse_scrolled_callback(ScreenMouseScrolledCallback callback);

    // Screen dispatch functions (called from Java via JNI)
    void dispatch_screen_init(int64_t screen_id, int32_t width, int32_t height);
    void dispatch_screen_tick(int64_t screen_id);
    void dispatch_screen_render(int64_t screen_id, int32_t mouse_x, int32_t mouse_y, float partial_tick);
    void dispatch_screen_close(int64_t screen_id);
    bool dispatch_screen_key_pressed(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers);
    bool dispatch_screen_key_released(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers);
    bool dispatch_screen_char_typed(int64_t screen_id, int32_t code_point, int32_t modifiers);
    bool dispatch_screen_mouse_clicked(int64_t screen_id, double mouse_x, double mouse_y, int32_t button);
    bool dispatch_screen_mouse_released(int64_t screen_id, double mouse_x, double mouse_y, int32_t button);
    bool dispatch_screen_mouse_dragged(int64_t screen_id, double mouse_x, double mouse_y, int32_t button, double drag_x, double drag_y);
    bool dispatch_screen_mouse_scrolled(int64_t screen_id, double mouse_x, double mouse_y, double delta_x, double delta_y);

    // ==========================================================================
    // Widget Callbacks
    // ==========================================================================

    // Widget callbacks (called from Dart via FFI)
    typedef void (*WidgetPressedCallback)(int64_t screen_id, int64_t widget_id);
    typedef void (*WidgetTextChangedCallback)(int64_t screen_id, int64_t widget_id, const char* text);

    // Widget callback registration (called from Dart via FFI)
    void register_widget_pressed_callback(WidgetPressedCallback callback);
    void register_widget_text_changed_callback(WidgetTextChangedCallback callback);

    // Widget dispatch functions (called from Java via JNI)
    void dispatch_widget_pressed(int64_t screen_id, int64_t widget_id);
    void dispatch_widget_text_changed(int64_t screen_id, int64_t widget_id, const char* text);

    // ==========================================================================
    // Container Screen Callbacks
    // ==========================================================================

    // Container screen callbacks (called from Dart via FFI)
    typedef void (*ContainerScreenInitCallback)(int64_t screen_id, int32_t width, int32_t height,
                                                 int32_t left_pos, int32_t top_pos, int32_t image_width, int32_t image_height);
    typedef void (*ContainerScreenRenderBgCallback)(int64_t screen_id, int32_t mouse_x, int32_t mouse_y,
                                                     float partial_tick, int32_t left_pos, int32_t top_pos);
    typedef void (*ContainerScreenCloseCallback)(int64_t screen_id);

    // Container screen callback registration (called from Dart via FFI)
    void register_container_screen_init_callback(ContainerScreenInitCallback callback);
    void register_container_screen_render_bg_callback(ContainerScreenRenderBgCallback callback);
    void register_container_screen_close_callback(ContainerScreenCloseCallback callback);

    // Container screen dispatch functions (called from Java via JNI)
    void dispatch_container_screen_init(int64_t screen_id, int32_t width, int32_t height,
                                        int32_t left_pos, int32_t top_pos, int32_t image_width, int32_t image_height);
    void dispatch_container_screen_render_bg(int64_t screen_id, int32_t mouse_x, int32_t mouse_y,
                                             float partial_tick, int32_t left_pos, int32_t top_pos);
    void dispatch_container_screen_close(int64_t screen_id);

    // ==========================================================================
    // Container Menu Callbacks (for slot interaction)
    // ==========================================================================

    // Container menu callbacks (called from Dart via FFI)
    // SlotClick: returns -1 to skip default handling, 0+ for custom result
    typedef int32_t (*ContainerSlotClickCallback)(int64_t menu_id, int32_t slot_index,
                                                   int32_t button, int32_t click_type, const char* carried_item);
    // QuickMove: returns serialized ItemStack or nullptr/empty for default
    typedef const char* (*ContainerQuickMoveCallback)(int64_t menu_id, int32_t slot_index);
    // MayPlace: returns true to allow placement, false to deny
    typedef bool (*ContainerMayPlaceCallback)(int64_t menu_id, int32_t slot_index, const char* item_data);
    // MayPickup: returns true to allow pickup, false to deny
    typedef bool (*ContainerMayPickupCallback)(int64_t menu_id, int32_t slot_index);

    // Container menu callback registration (called from Dart via FFI)
    void register_container_slot_click_callback(ContainerSlotClickCallback callback);
    void register_container_quick_move_callback(ContainerQuickMoveCallback callback);
    void register_container_may_place_callback(ContainerMayPlaceCallback callback);
    void register_container_may_pickup_callback(ContainerMayPickupCallback callback);

    // Container menu dispatch functions (called from Java via JNI)
    int32_t dispatch_container_slot_click(int64_t menu_id, int32_t slot_index,
                                           int32_t button, int32_t click_type, const char* carried_item);
    const char* dispatch_container_quick_move(int64_t menu_id, int32_t slot_index);
    bool dispatch_container_may_place(int64_t menu_id, int32_t slot_index, const char* item_data);
    bool dispatch_container_may_pickup(int64_t menu_id, int32_t slot_index);

    // ==========================================================================
    // Container Item Access APIs (Dart -> Java via C++)
    // ==========================================================================

    // Get container item - returns "itemId:count:damage:maxDamage" (Dart must free)
    const char* dart_get_container_item(int64_t menu_id, int32_t slot_index);
    // Set container item
    void dart_set_container_item(int64_t menu_id, int32_t slot_index, const char* item_id, int32_t count);
    // Get container slot count
    int32_t dart_get_container_slot_count(int64_t menu_id);
    // Clear container slot
    void dart_clear_container_slot(int64_t menu_id, int32_t slot_index);
    // Free a string allocated by dart_get_container_item
    void dart_free_string(const char* str);

    // ==========================================================================
    // Container Opening API (Dart -> Java via C++)
    // ==========================================================================

    // Open a container for a player - returns true if successful
    bool dart_open_container_for_player(int32_t player_id, const char* container_id);

    // ==========================================================================
    // Entity Proxy Callbacks (for custom Dart entities)
    // ==========================================================================

    // Entity proxy callbacks (called from Dart via FFI, invoked from Java proxy classes)
    typedef void (*ProxyEntitySpawnCallback)(int64_t handler_id, int32_t entity_id, int64_t world_id);
    typedef void (*ProxyEntityTickCallback)(int64_t handler_id, int32_t entity_id);
    typedef void (*ProxyEntityDeathCallback)(int64_t handler_id, int32_t entity_id, const char* damage_source);
    typedef bool (*ProxyEntityDamageCallback)(int64_t handler_id, int32_t entity_id, const char* damage_source, double amount);
    typedef void (*ProxyEntityAttackCallback)(int64_t handler_id, int32_t entity_id, int32_t target_id);
    typedef void (*ProxyEntityTargetCallback)(int64_t handler_id, int32_t entity_id, int32_t target_id);

    // Item proxy callbacks (called from Dart via FFI, invoked from Java proxy classes)
    // ProxyItemAttackEntityCallback returns true to allow attack, false to cancel
    typedef bool (*ProxyItemAttackEntityCallback)(int64_t handler_id, int32_t world_id, int32_t attacker_id, int32_t target_id);
    // ProxyItemUseCallback returns ItemActionResult ordinal (0=SUCCESS, 1=CONSUME_PARTIAL, 2=CONSUME, 3=FAIL, 4=PASS)
    typedef int32_t (*ProxyItemUseCallback)(int64_t handler_id, int64_t world_id, int32_t player_id, int32_t hand);
    typedef int32_t (*ProxyItemUseOnBlockCallback)(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t player_id, int32_t hand);
    typedef int32_t (*ProxyItemUseOnEntityCallback)(int64_t handler_id, int64_t world_id, int32_t entity_id, int32_t player_id, int32_t hand);

    // Entity proxy callback registration (called from Dart via FFI)
    void register_proxy_entity_spawn_handler(ProxyEntitySpawnCallback cb);
    void register_proxy_entity_tick_handler(ProxyEntityTickCallback cb);
    void register_proxy_entity_death_handler(ProxyEntityDeathCallback cb);
    void register_proxy_entity_damage_handler(ProxyEntityDamageCallback cb);
    void register_proxy_entity_attack_handler(ProxyEntityAttackCallback cb);
    void register_proxy_entity_target_handler(ProxyEntityTargetCallback cb);

    // Item proxy callback registration (called from Dart via FFI)
    void register_proxy_item_attack_entity_handler(ProxyItemAttackEntityCallback cb);
    void register_proxy_item_use_handler(ProxyItemUseCallback cb);
    void register_proxy_item_use_on_block_handler(ProxyItemUseOnBlockCallback cb);
    void register_proxy_item_use_on_entity_handler(ProxyItemUseOnEntityCallback cb);

    // Entity proxy dispatch functions (called from Java via JNI)
    void dispatch_proxy_entity_spawn(int64_t handler_id, int32_t entity_id, int64_t world_id);
    void dispatch_proxy_entity_tick(int64_t handler_id, int32_t entity_id);
    void dispatch_proxy_entity_death(int64_t handler_id, int32_t entity_id, const char* damage_source);
    bool dispatch_proxy_entity_damage(int64_t handler_id, int32_t entity_id, const char* damage_source, double amount);
    void dispatch_proxy_entity_attack(int64_t handler_id, int32_t entity_id, int32_t target_id);
    void dispatch_proxy_entity_target(int64_t handler_id, int32_t entity_id, int32_t target_id);

    // Item proxy dispatch functions (called from Java via JNI)
    // Returns true to allow attack, false to cancel
    bool dispatch_proxy_item_attack_entity(int64_t handler_id, int32_t world_id, int32_t attacker_id, int32_t target_id);
    // Returns ItemActionResult ordinal (0=SUCCESS, 1=CONSUME_PARTIAL, 2=CONSUME, 3=FAIL, 4=PASS)
    int32_t dispatch_proxy_item_use(int64_t handler_id, int64_t world_id, int32_t player_id, int32_t hand);
    int32_t dispatch_proxy_item_use_on_block(int64_t handler_id, int64_t world_id, int32_t x, int32_t y, int32_t z, int32_t player_id, int32_t hand);
    int32_t dispatch_proxy_item_use_on_entity(int64_t handler_id, int64_t world_id, int32_t entity_id, int32_t player_id, int32_t hand);

    // ==========================================================================
    // Command System Callbacks
    // ==========================================================================

    // Command execute callback (called from Dart via FFI)
    // Returns the command result (0 = failure, positive = success)
    typedef int32_t (*CommandExecuteCallback)(int64_t command_id, int32_t player_id, const char* args_json);

    // Command callback registration (called from Dart via FFI)
    void register_command_execute_handler(CommandExecuteCallback cb);

    // Command dispatch function (called from Java via JNI)
    int32_t dispatch_command_execute(int64_t command_id, int32_t player_id, const char* args_json);

    // ==========================================================================
    // Custom Goal Callbacks (for custom Dart entity goals)
    // ==========================================================================

    // Custom goal callbacks (called from Dart via FFI, invoked from Java goal classes)
    // CustomGoalCanUseCallback returns true if the goal can start, false otherwise
    typedef bool (*CustomGoalCanUseCallback)(const char* goal_id, int32_t entity_id);
    // CustomGoalCanContinueToUseCallback returns true if the goal should continue, false to stop
    typedef bool (*CustomGoalCanContinueToUseCallback)(const char* goal_id, int32_t entity_id);
    // CustomGoalStartCallback is called when the goal starts
    typedef void (*CustomGoalStartCallback)(const char* goal_id, int32_t entity_id);
    // CustomGoalTickCallback is called every tick while the goal is active
    typedef void (*CustomGoalTickCallback)(const char* goal_id, int32_t entity_id);
    // CustomGoalStopCallback is called when the goal stops
    typedef void (*CustomGoalStopCallback)(const char* goal_id, int32_t entity_id);

    // Custom goal callback registration (called from Dart via FFI)
    void register_custom_goal_can_use_handler(CustomGoalCanUseCallback cb);
    void register_custom_goal_can_continue_to_use_handler(CustomGoalCanContinueToUseCallback cb);
    void register_custom_goal_start_handler(CustomGoalStartCallback cb);
    void register_custom_goal_tick_handler(CustomGoalTickCallback cb);
    void register_custom_goal_stop_handler(CustomGoalStopCallback cb);

    // Custom goal dispatch functions (called from Java via JNI)
    // Returns true if the goal can start
    bool dispatch_custom_goal_can_use(const char* goal_id, int32_t entity_id);
    // Returns true if the goal should continue
    bool dispatch_custom_goal_can_continue_to_use(const char* goal_id, int32_t entity_id);
    // Called when the goal starts
    void dispatch_custom_goal_start(const char* goal_id, int32_t entity_id);
    // Called every tick while the goal is active
    void dispatch_custom_goal_tick(const char* goal_id, int32_t entity_id);
    // Called when the goal stops
    void dispatch_custom_goal_stop(const char* goal_id, int32_t entity_id);
}
