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

    void setProxyBlockSteppedOnHandler(ProxyBlockSteppedOnCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_block_stepped_on_handler_ = cb;
    }

    void setProxyBlockFallenUponHandler(ProxyBlockFallenUponCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_block_fallen_upon_handler_ = cb;
    }

    void setProxyBlockRandomTickHandler(ProxyBlockRandomTickCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_block_random_tick_handler_ = cb;
    }

    void setProxyBlockPlacedHandler(ProxyBlockPlacedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_block_placed_handler_ = cb;
    }

    void setProxyBlockRemovedHandler(ProxyBlockRemovedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_block_removed_handler_ = cb;
    }

    void setProxyBlockNeighborChangedHandler(ProxyBlockNeighborChangedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_block_neighbor_changed_handler_ = cb;
    }

    void setProxyBlockEntityInsideHandler(ProxyBlockEntityInsideCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_block_entity_inside_handler_ = cb;
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

    // Screen callback setters
    void setScreenInitHandler(ScreenInitCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        screen_init_handler_ = cb;
    }

    void setScreenTickHandler(ScreenTickCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        screen_tick_handler_ = cb;
    }

    void setScreenRenderHandler(ScreenRenderCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        screen_render_handler_ = cb;
    }

    void setScreenCloseHandler(ScreenCloseCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        screen_close_handler_ = cb;
    }

    void setScreenKeyPressedHandler(ScreenKeyPressedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        screen_key_pressed_handler_ = cb;
    }

    void setScreenKeyReleasedHandler(ScreenKeyReleasedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        screen_key_released_handler_ = cb;
    }

    void setScreenCharTypedHandler(ScreenCharTypedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        screen_char_typed_handler_ = cb;
    }

    void setScreenMouseClickedHandler(ScreenMouseClickedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        screen_mouse_clicked_handler_ = cb;
    }

    void setScreenMouseReleasedHandler(ScreenMouseReleasedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        screen_mouse_released_handler_ = cb;
    }

    void setScreenMouseDraggedHandler(ScreenMouseDraggedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        screen_mouse_dragged_handler_ = cb;
    }

    void setScreenMouseScrolledHandler(ScreenMouseScrolledCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        screen_mouse_scrolled_handler_ = cb;
    }

    // Widget callback setters
    void setWidgetPressedHandler(WidgetPressedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        widget_pressed_handler_ = cb;
    }

    void setWidgetTextChangedHandler(WidgetTextChangedCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        widget_text_changed_handler_ = cb;
    }

    // Entity proxy callback setters
    void setProxyEntitySpawnHandler(ProxyEntitySpawnCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_entity_spawn_handler_ = cb;
    }

    void setProxyEntityTickHandler(ProxyEntityTickCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_entity_tick_handler_ = cb;
    }

    void setProxyEntityDeathHandler(ProxyEntityDeathCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_entity_death_handler_ = cb;
    }

    void setProxyEntityDamageHandler(ProxyEntityDamageCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_entity_damage_handler_ = cb;
    }

    void setProxyEntityAttackHandler(ProxyEntityAttackCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_entity_attack_handler_ = cb;
    }

    void setProxyEntityTargetHandler(ProxyEntityTargetCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        proxy_entity_target_handler_ = cb;
    }

    // Command callback setters
    void setCommandExecuteHandler(CommandExecuteCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        command_execute_handler_ = cb;
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

    void dispatchProxyBlockSteppedOn(int64_t handler_id, int64_t world_id,
                                      int32_t x, int32_t y, int32_t z, int32_t entity_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_block_stepped_on_handler_) {
            proxy_block_stepped_on_handler_(handler_id, world_id, x, y, z, entity_id);
        }
    }

    void dispatchProxyBlockFallenUpon(int64_t handler_id, int64_t world_id,
                                       int32_t x, int32_t y, int32_t z, int32_t entity_id, float fall_distance) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_block_fallen_upon_handler_) {
            proxy_block_fallen_upon_handler_(handler_id, world_id, x, y, z, entity_id, fall_distance);
        }
    }

    void dispatchProxyBlockRandomTick(int64_t handler_id, int64_t world_id,
                                       int32_t x, int32_t y, int32_t z) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_block_random_tick_handler_) {
            proxy_block_random_tick_handler_(handler_id, world_id, x, y, z);
        }
    }

    void dispatchProxyBlockPlaced(int64_t handler_id, int64_t world_id,
                                   int32_t x, int32_t y, int32_t z, int32_t player_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_block_placed_handler_) {
            proxy_block_placed_handler_(handler_id, world_id, x, y, z, player_id);
        }
    }

    void dispatchProxyBlockRemoved(int64_t handler_id, int64_t world_id,
                                    int32_t x, int32_t y, int32_t z) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_block_removed_handler_) {
            proxy_block_removed_handler_(handler_id, world_id, x, y, z);
        }
    }

    void dispatchProxyBlockNeighborChanged(int64_t handler_id, int64_t world_id,
                                            int32_t x, int32_t y, int32_t z,
                                            int32_t neighbor_x, int32_t neighbor_y, int32_t neighbor_z) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_block_neighbor_changed_handler_) {
            proxy_block_neighbor_changed_handler_(handler_id, world_id, x, y, z, neighbor_x, neighbor_y, neighbor_z);
        }
    }

    void dispatchProxyBlockEntityInside(int64_t handler_id, int64_t world_id,
                                         int32_t x, int32_t y, int32_t z, int32_t entity_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_block_entity_inside_handler_) {
            proxy_block_entity_inside_handler_(handler_id, world_id, x, y, z, entity_id);
        }
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
        ServerStartedCallback handler = nullptr;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            handler = server_started_handler_;
        }
        // Call outside the lock to avoid deadlock when callback registers handlers
        if (handler) {
            handler();
        }
    }

    void dispatchServerStopping() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (server_stopping_handler_) {
            server_stopping_handler_();
        }
    }

    // Screen event dispatch methods
    void dispatchScreenInit(int64_t screen_id, int32_t width, int32_t height) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (screen_init_handler_) {
            screen_init_handler_(screen_id, width, height);
        }
    }

    void dispatchScreenTick(int64_t screen_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (screen_tick_handler_) {
            screen_tick_handler_(screen_id);
        }
    }

    void dispatchScreenRender(int64_t screen_id, int32_t mouse_x, int32_t mouse_y, float partial_tick) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (screen_render_handler_) {
            screen_render_handler_(screen_id, mouse_x, mouse_y, partial_tick);
        }
    }

    void dispatchScreenClose(int64_t screen_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (screen_close_handler_) {
            screen_close_handler_(screen_id);
        }
    }

    bool dispatchScreenKeyPressed(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (screen_key_pressed_handler_) {
            return screen_key_pressed_handler_(screen_id, key_code, scan_code, modifiers);
        }
        return false; // Default: not handled
    }

    bool dispatchScreenKeyReleased(int64_t screen_id, int32_t key_code, int32_t scan_code, int32_t modifiers) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (screen_key_released_handler_) {
            return screen_key_released_handler_(screen_id, key_code, scan_code, modifiers);
        }
        return false; // Default: not handled
    }

    bool dispatchScreenCharTyped(int64_t screen_id, int32_t code_point, int32_t modifiers) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (screen_char_typed_handler_) {
            return screen_char_typed_handler_(screen_id, code_point, modifiers);
        }
        return false; // Default: not handled
    }

    bool dispatchScreenMouseClicked(int64_t screen_id, double mouse_x, double mouse_y, int32_t button) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (screen_mouse_clicked_handler_) {
            return screen_mouse_clicked_handler_(screen_id, mouse_x, mouse_y, button);
        }
        return false; // Default: not handled
    }

    bool dispatchScreenMouseReleased(int64_t screen_id, double mouse_x, double mouse_y, int32_t button) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (screen_mouse_released_handler_) {
            return screen_mouse_released_handler_(screen_id, mouse_x, mouse_y, button);
        }
        return false; // Default: not handled
    }

    bool dispatchScreenMouseDragged(int64_t screen_id, double mouse_x, double mouse_y, int32_t button, double drag_x, double drag_y) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (screen_mouse_dragged_handler_) {
            return screen_mouse_dragged_handler_(screen_id, mouse_x, mouse_y, button, drag_x, drag_y);
        }
        return false; // Default: not handled
    }

    bool dispatchScreenMouseScrolled(int64_t screen_id, double mouse_x, double mouse_y, double delta_x, double delta_y) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (screen_mouse_scrolled_handler_) {
            return screen_mouse_scrolled_handler_(screen_id, mouse_x, mouse_y, delta_x, delta_y);
        }
        return false; // Default: not handled
    }

    // Widget event dispatch methods
    void dispatchWidgetPressed(int64_t screen_id, int64_t widget_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (widget_pressed_handler_) {
            widget_pressed_handler_(screen_id, widget_id);
        }
    }

    void dispatchWidgetTextChanged(int64_t screen_id, int64_t widget_id, const char* text) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (widget_text_changed_handler_) {
            widget_text_changed_handler_(screen_id, widget_id, text);
        }
    }

    // Container screen callback setters
    void setContainerScreenInitHandler(ContainerScreenInitCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        container_screen_init_handler_ = cb;
    }

    void setContainerScreenRenderBgHandler(ContainerScreenRenderBgCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        container_screen_render_bg_handler_ = cb;
    }

    void setContainerScreenCloseHandler(ContainerScreenCloseCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        container_screen_close_handler_ = cb;
    }

    // Container screen event dispatch methods
    void dispatchContainerScreenInit(int64_t screen_id, int32_t width, int32_t height,
                                     int32_t left_pos, int32_t top_pos, int32_t image_width, int32_t image_height) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (container_screen_init_handler_) {
            container_screen_init_handler_(screen_id, width, height, left_pos, top_pos, image_width, image_height);
        }
    }

    void dispatchContainerScreenRenderBg(int64_t screen_id, int32_t mouse_x, int32_t mouse_y,
                                         float partial_tick, int32_t left_pos, int32_t top_pos) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (container_screen_render_bg_handler_) {
            container_screen_render_bg_handler_(screen_id, mouse_x, mouse_y, partial_tick, left_pos, top_pos);
        }
    }

    void dispatchContainerScreenClose(int64_t screen_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (container_screen_close_handler_) {
            container_screen_close_handler_(screen_id);
        }
    }

    // Container menu callback setters
    void setContainerSlotClickHandler(ContainerSlotClickCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        container_slot_click_handler_ = cb;
    }

    void setContainerQuickMoveHandler(ContainerQuickMoveCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        container_quick_move_handler_ = cb;
    }

    void setContainerMayPlaceHandler(ContainerMayPlaceCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        container_may_place_handler_ = cb;
    }

    void setContainerMayPickupHandler(ContainerMayPickupCallback cb) {
        std::lock_guard<std::mutex> lock(mutex_);
        container_may_pickup_handler_ = cb;
    }

    // Container menu event dispatch methods
    int32_t dispatchContainerSlotClick(int64_t menu_id, int32_t slot_index,
                                        int32_t button, int32_t click_type, const char* carried_item) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (container_slot_click_handler_) {
            return container_slot_click_handler_(menu_id, slot_index, button, click_type, carried_item);
        }
        return 0; // Default: continue with default handling
    }

    const char* dispatchContainerQuickMove(int64_t menu_id, int32_t slot_index) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (container_quick_move_handler_) {
            return container_quick_move_handler_(menu_id, slot_index);
        }
        return nullptr; // Default: use default behavior
    }

    bool dispatchContainerMayPlace(int64_t menu_id, int32_t slot_index, const char* item_data) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (container_may_place_handler_) {
            return container_may_place_handler_(menu_id, slot_index, item_data);
        }
        return true; // Default: allow placement
    }

    bool dispatchContainerMayPickup(int64_t menu_id, int32_t slot_index) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (container_may_pickup_handler_) {
            return container_may_pickup_handler_(menu_id, slot_index);
        }
        return true; // Default: allow pickup
    }

    // Entity proxy dispatch methods
    void dispatchProxyEntitySpawn(int64_t handler_id, int32_t entity_id, int64_t world_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_entity_spawn_handler_) {
            proxy_entity_spawn_handler_(handler_id, entity_id, world_id);
        }
    }

    void dispatchProxyEntityTick(int64_t handler_id, int32_t entity_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_entity_tick_handler_) {
            proxy_entity_tick_handler_(handler_id, entity_id);
        }
    }

    void dispatchProxyEntityDeath(int64_t handler_id, int32_t entity_id, const char* damage_source) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_entity_death_handler_) {
            proxy_entity_death_handler_(handler_id, entity_id, damage_source);
        }
    }

    // Returns true to allow damage, false to cancel
    bool dispatchProxyEntityDamage(int64_t handler_id, int32_t entity_id, const char* damage_source, double amount) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_entity_damage_handler_) {
            return proxy_entity_damage_handler_(handler_id, entity_id, damage_source, amount);
        }
        return true; // Default: allow damage
    }

    void dispatchProxyEntityAttack(int64_t handler_id, int32_t entity_id, int32_t target_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_entity_attack_handler_) {
            proxy_entity_attack_handler_(handler_id, entity_id, target_id);
        }
    }

    void dispatchProxyEntityTarget(int64_t handler_id, int32_t entity_id, int32_t target_id) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (proxy_entity_target_handler_) {
            proxy_entity_target_handler_(handler_id, entity_id, target_id);
        }
    }

    // Command dispatch
    int32_t dispatchCommandExecute(int64_t command_id, int32_t player_id, const char* args_json) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (command_execute_handler_) {
            return command_execute_handler_(command_id, player_id, args_json);
        }
        return 0; // Default: failure
    }

    // Clear all handlers
    void clear() {
        std::lock_guard<std::mutex> lock(mutex_);
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
        // Screen handlers
        screen_init_handler_ = nullptr;
        screen_tick_handler_ = nullptr;
        screen_render_handler_ = nullptr;
        screen_close_handler_ = nullptr;
        screen_key_pressed_handler_ = nullptr;
        screen_key_released_handler_ = nullptr;
        screen_char_typed_handler_ = nullptr;
        screen_mouse_clicked_handler_ = nullptr;
        screen_mouse_released_handler_ = nullptr;
        screen_mouse_dragged_handler_ = nullptr;
        screen_mouse_scrolled_handler_ = nullptr;
        // Widget handlers
        widget_pressed_handler_ = nullptr;
        widget_text_changed_handler_ = nullptr;
        // Container screen handlers
        container_screen_init_handler_ = nullptr;
        container_screen_render_bg_handler_ = nullptr;
        container_screen_close_handler_ = nullptr;
        // Container menu handlers
        container_slot_click_handler_ = nullptr;
        container_quick_move_handler_ = nullptr;
        container_may_place_handler_ = nullptr;
        container_may_pickup_handler_ = nullptr;
        // Entity proxy handlers
        proxy_entity_spawn_handler_ = nullptr;
        proxy_entity_tick_handler_ = nullptr;
        proxy_entity_death_handler_ = nullptr;
        proxy_entity_damage_handler_ = nullptr;
        proxy_entity_attack_handler_ = nullptr;
        proxy_entity_target_handler_ = nullptr;
        // Command handlers
        command_execute_handler_ = nullptr;
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
    ProxyBlockSteppedOnCallback proxy_block_stepped_on_handler_ = nullptr;
    ProxyBlockFallenUponCallback proxy_block_fallen_upon_handler_ = nullptr;
    ProxyBlockRandomTickCallback proxy_block_random_tick_handler_ = nullptr;
    ProxyBlockPlacedCallback proxy_block_placed_handler_ = nullptr;
    ProxyBlockRemovedCallback proxy_block_removed_handler_ = nullptr;
    ProxyBlockNeighborChangedCallback proxy_block_neighbor_changed_handler_ = nullptr;
    ProxyBlockEntityInsideCallback proxy_block_entity_inside_handler_ = nullptr;

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

    // Screen handlers
    ScreenInitCallback screen_init_handler_ = nullptr;
    ScreenTickCallback screen_tick_handler_ = nullptr;
    ScreenRenderCallback screen_render_handler_ = nullptr;
    ScreenCloseCallback screen_close_handler_ = nullptr;
    ScreenKeyPressedCallback screen_key_pressed_handler_ = nullptr;
    ScreenKeyReleasedCallback screen_key_released_handler_ = nullptr;
    ScreenCharTypedCallback screen_char_typed_handler_ = nullptr;
    ScreenMouseClickedCallback screen_mouse_clicked_handler_ = nullptr;
    ScreenMouseReleasedCallback screen_mouse_released_handler_ = nullptr;
    ScreenMouseDraggedCallback screen_mouse_dragged_handler_ = nullptr;
    ScreenMouseScrolledCallback screen_mouse_scrolled_handler_ = nullptr;

    // Widget handlers
    WidgetPressedCallback widget_pressed_handler_ = nullptr;
    WidgetTextChangedCallback widget_text_changed_handler_ = nullptr;

    // Container screen handlers
    ContainerScreenInitCallback container_screen_init_handler_ = nullptr;
    ContainerScreenRenderBgCallback container_screen_render_bg_handler_ = nullptr;
    ContainerScreenCloseCallback container_screen_close_handler_ = nullptr;

    // Container menu handlers
    ContainerSlotClickCallback container_slot_click_handler_ = nullptr;
    ContainerQuickMoveCallback container_quick_move_handler_ = nullptr;
    ContainerMayPlaceCallback container_may_place_handler_ = nullptr;
    ContainerMayPickupCallback container_may_pickup_handler_ = nullptr;

    // Entity proxy handlers
    ProxyEntitySpawnCallback proxy_entity_spawn_handler_ = nullptr;
    ProxyEntityTickCallback proxy_entity_tick_handler_ = nullptr;
    ProxyEntityDeathCallback proxy_entity_death_handler_ = nullptr;
    ProxyEntityDamageCallback proxy_entity_damage_handler_ = nullptr;
    ProxyEntityAttackCallback proxy_entity_attack_handler_ = nullptr;
    ProxyEntityTargetCallback proxy_entity_target_handler_ = nullptr;

    // Command handlers
    CommandExecuteCallback command_execute_handler_ = nullptr;
};

} // namespace dart_mc_bridge
