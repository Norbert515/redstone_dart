/// Event handler registration for Minecraft events.
///
/// This file provides a high-level API for registering event handlers
/// that will be called when events occur in Minecraft.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bridge.dart';
import 'types.dart';
import '../api/block_registry.dart';
import '../api/player.dart';
import '../api/entity.dart';
import '../api/item.dart';
import '../api/inventory.dart';

/// Default return value for block use events (ActionResult.pass ordinal)
const int _actionResultPassOrdinal = 3;

/// Dart callback types
typedef BlockBreakHandler = EventResult Function(
    int x, int y, int z, int playerId);
typedef BlockInteractHandler = EventResult Function(
    int x, int y, int z, int playerId, int hand);
typedef TickHandler = void Function(int tick);

/// Static storage for callbacks (prevents garbage collection)
BlockBreakHandler? _blockBreakHandler;
BlockInteractHandler? _blockInteractHandler;
TickHandler? _tickHandler;
bool _proxyHandlersRegistered = false;

// New event handlers
void Function(Player player)? _playerJoinHandler;
void Function(Player player)? _playerLeaveHandler;
void Function(Player player, bool endConquered)? _playerRespawnHandler;
String? Function(Player player, String damageSource)? _playerDeathHandler;
bool Function(Entity entity, String damageSource, double amount)? _entityDamageHandler;
void Function(Entity entity, String damageSource)? _entityDeathHandler;
bool Function(Player player, Entity target)? _playerAttackEntityHandler;
String? Function(Player player, String message)? _playerChatHandler;
bool Function(Player player, String command)? _playerCommandHandler;
bool Function(Player player, ItemStack item, Hand hand)? _itemUseHandler;
EventResult Function(Player player, ItemStack item, Hand hand, BlockPos pos, Direction face)? _itemUseOnBlockHandler;
EventResult Function(Player player, ItemStack item, Hand hand, Entity target)? _itemUseOnEntityHandler;
bool Function(Player player, BlockPos pos, String blockId)? _blockPlaceHandler;
bool Function(Player player, ItemEntity item)? _playerPickupItemHandler;
bool Function(Player player, ItemStack item)? _playerDropItemHandler;
void Function()? _serverStartingHandler;
void Function()? _serverStartedHandler;
void Function()? _serverStoppingHandler;

/// Native callback trampolines - these are called from native code
@pragma('vm:entry-point')
int _onBlockBreak(int x, int y, int z, int playerId) {
  if (_blockBreakHandler != null) {
    return _blockBreakHandler!(x, y, z, playerId).value;
  }
  return EventResult.allow.value;
}

@pragma('vm:entry-point')
int _onBlockInteract(int x, int y, int z, int playerId, int hand) {
  if (_blockInteractHandler != null) {
    return _blockInteractHandler!(x, y, z, playerId, hand).value;
  }
  return EventResult.allow.value;
}

@pragma('vm:entry-point')
void _onTick(int tick) {
  _tickHandler?.call(tick);
}

// New event trampolines

@pragma('vm:entry-point')
void _onPlayerJoin(int playerId) {
  _playerJoinHandler?.call(Player(playerId));
}

@pragma('vm:entry-point')
void _onPlayerLeave(int playerId) {
  _playerLeaveHandler?.call(Player(playerId));
}

@pragma('vm:entry-point')
void _onPlayerRespawn(int playerId, bool endConquered) {
  _playerRespawnHandler?.call(Player(playerId), endConquered);
}

@pragma('vm:entry-point')
Pointer<Utf8> _onPlayerDeath(int playerId, Pointer<Utf8> damageSourcePtr) {
  if (_playerDeathHandler == null) return nullptr;
  final damageSource = damageSourcePtr.toDartString();
  final result = _playerDeathHandler!(Player(playerId), damageSource);
  if (result == null) return nullptr;
  return result.toNativeUtf8();
}

@pragma('vm:entry-point')
bool _onEntityDamage(int entityId, Pointer<Utf8> damageSourcePtr, double amount) {
  if (_entityDamageHandler == null) return true; // Allow by default
  final damageSource = damageSourcePtr.toDartString();
  final entity = Entities.getTypedEntity(entityId) ?? Entity(entityId);
  return _entityDamageHandler!(entity, damageSource, amount);
}

@pragma('vm:entry-point')
void _onEntityDeath(int entityId, Pointer<Utf8> damageSourcePtr) {
  if (_entityDeathHandler == null) return;
  final damageSource = damageSourcePtr.toDartString();
  final entity = Entities.getTypedEntity(entityId) ?? Entity(entityId);
  _entityDeathHandler!(entity, damageSource);
}

@pragma('vm:entry-point')
bool _onPlayerAttackEntity(int playerId, int targetId) {
  if (_playerAttackEntityHandler == null) return true; // Allow by default
  final target = Entities.getTypedEntity(targetId) ?? Entity(targetId);
  return _playerAttackEntityHandler!(Player(playerId), target);
}

@pragma('vm:entry-point')
Pointer<Utf8> _onPlayerChat(int playerId, Pointer<Utf8> messagePtr) {
  if (_playerChatHandler == null) return messagePtr; // Pass through
  final message = messagePtr.toDartString();
  final result = _playerChatHandler!(Player(playerId), message);
  if (result == null) return nullptr; // Cancel
  return result.toNativeUtf8();
}

@pragma('vm:entry-point')
bool _onPlayerCommand(int playerId, Pointer<Utf8> commandPtr) {
  if (_playerCommandHandler == null) return true; // Allow by default
  final command = commandPtr.toDartString();
  return _playerCommandHandler!(Player(playerId), command);
}

@pragma('vm:entry-point')
bool _onItemUse(int playerId, Pointer<Utf8> itemIdPtr, int count, int hand) {
  if (_itemUseHandler == null) return true; // Allow by default
  final itemId = itemIdPtr.toDartString();
  final stack = ItemStack(Item(itemId), count);
  return _itemUseHandler!(Player(playerId), stack, Hand.fromValue(hand));
}

@pragma('vm:entry-point')
int _onItemUseOnBlock(int playerId, Pointer<Utf8> itemIdPtr, int count, int hand, int x, int y, int z, int face) {
  if (_itemUseOnBlockHandler == null) return EventResult.allow.value;
  final itemId = itemIdPtr.toDartString();
  final stack = ItemStack(Item(itemId), count);
  final direction = Direction.values.firstWhere((d) => d.id == face, orElse: () => Direction.up);
  return _itemUseOnBlockHandler!(Player(playerId), stack, Hand.fromValue(hand), BlockPos(x, y, z), direction).value;
}

@pragma('vm:entry-point')
int _onItemUseOnEntity(int playerId, Pointer<Utf8> itemIdPtr, int count, int hand, int targetId) {
  if (_itemUseOnEntityHandler == null) return EventResult.allow.value;
  final itemId = itemIdPtr.toDartString();
  final stack = ItemStack(Item(itemId), count);
  final target = Entities.getTypedEntity(targetId) ?? Entity(targetId);
  return _itemUseOnEntityHandler!(Player(playerId), stack, Hand.fromValue(hand), target).value;
}

@pragma('vm:entry-point')
bool _onBlockPlace(int playerId, int x, int y, int z, Pointer<Utf8> blockIdPtr) {
  if (_blockPlaceHandler == null) return true; // Allow by default
  final blockId = blockIdPtr.toDartString();
  return _blockPlaceHandler!(Player(playerId), BlockPos(x, y, z), blockId);
}

@pragma('vm:entry-point')
bool _onPlayerPickupItem(int playerId, int itemEntityId) {
  if (_playerPickupItemHandler == null) return true; // Allow by default
  return _playerPickupItemHandler!(Player(playerId), ItemEntity(itemEntityId));
}

@pragma('vm:entry-point')
bool _onPlayerDropItem(int playerId, Pointer<Utf8> itemIdPtr, int count) {
  if (_playerDropItemHandler == null) return true; // Allow by default
  final itemId = itemIdPtr.toDartString();
  final stack = ItemStack(Item(itemId), count);
  return _playerDropItemHandler!(Player(playerId), stack);
}

@pragma('vm:entry-point')
void _onServerStarting() {
  _serverStartingHandler?.call();
}

@pragma('vm:entry-point')
void _onServerStarted() {
  _serverStartedHandler?.call();
}

@pragma('vm:entry-point')
void _onServerStopping() {
  _serverStoppingHandler?.call();
}

/// Proxy block callback trampolines - route to BlockRegistry
/// Returns true to allow break, false to cancel
@pragma('vm:entry-point')
bool _onProxyBlockBreak(int handlerId, int worldId, int x, int y, int z, int playerId) {
  return BlockRegistry.dispatchBlockBreak(handlerId, worldId, x, y, z, playerId);
}

@pragma('vm:entry-point')
int _onProxyBlockUse(int handlerId, int worldId, int x, int y, int z, int playerId, int hand) {
  return BlockRegistry.dispatchBlockUse(handlerId, worldId, x, y, z, playerId, hand);
}

/// Event registration API.
class Events {
  Events._();

  /// Register a handler for block break events.
  ///
  /// The handler receives the block coordinates and player ID.
  /// Return [EventResult.allow] to allow the break, or [EventResult.cancel] to prevent it.
  static void onBlockBreak(BlockBreakHandler handler) {
    _blockBreakHandler = handler;
    final callback =
        Pointer.fromFunction<BlockBreakCallbackNative>(_onBlockBreak, 1);
    Bridge.registerBlockBreakHandler(callback);
  }

  /// Register a handler for block interact events.
  ///
  /// The handler receives the block coordinates, player ID, and which hand was used.
  /// Return [EventResult.allow] to allow the interaction, or [EventResult.cancel] to prevent it.
  static void onBlockInteract(BlockInteractHandler handler) {
    _blockInteractHandler = handler;
    final callback =
        Pointer.fromFunction<BlockInteractCallbackNative>(_onBlockInteract, 1);
    Bridge.registerBlockInteractHandler(callback);
  }

  /// Register a handler for tick events.
  ///
  /// The handler receives the current tick number.
  /// This is called 20 times per second.
  static void onTick(TickHandler handler) {
    _tickHandler = handler;
    final callback = Pointer.fromFunction<TickCallbackNative>(_onTick);
    Bridge.registerTickHandler(callback);
  }

  /// Register proxy block handlers for custom Dart-defined blocks.
  ///
  /// This is called automatically during Bridge initialization.
  /// It routes proxy block events to BlockRegistry which dispatches
  /// to the appropriate CustomBlock instances.
  static void registerProxyBlockHandlers() {
    if (_proxyHandlersRegistered) return;
    _proxyHandlersRegistered = true;

    // Default return value true = allow break
    final breakCallback = Pointer.fromFunction<ProxyBlockBreakCallbackNative>(
        _onProxyBlockBreak, true);
    Bridge.registerProxyBlockBreakHandler(breakCallback);

    // Default: pass (no interaction)
    final useCallback = Pointer.fromFunction<ProxyBlockUseCallbackNative>(
        _onProxyBlockUse, _actionResultPassOrdinal);
    Bridge.registerProxyBlockUseHandler(useCallback);

    print('Events: Proxy block handlers registered');
  }

  // ==========================================================================
  // Player Connection Events
  // ==========================================================================

  /// Register a handler for player join events.
  ///
  /// Called when a player joins the server.
  static void onPlayerJoin(void Function(Player player) handler) {
    _playerJoinHandler = handler;
    final callback = Pointer.fromFunction<PlayerJoinCallbackNative>(_onPlayerJoin);
    Bridge.registerPlayerJoinHandler(callback);
  }

  /// Register a handler for player leave events.
  ///
  /// Called when a player disconnects from the server.
  static void onPlayerLeave(void Function(Player player) handler) {
    _playerLeaveHandler = handler;
    final callback = Pointer.fromFunction<PlayerLeaveCallbackNative>(_onPlayerLeave);
    Bridge.registerPlayerLeaveHandler(callback);
  }

  /// Register a handler for player respawn events.
  ///
  /// Called when a player respawns after dying.
  /// [endConquered] is true if the player defeated the ender dragon.
  static void onPlayerRespawn(void Function(Player player, bool endConquered) handler) {
    _playerRespawnHandler = handler;
    final callback = Pointer.fromFunction<PlayerRespawnCallbackNative>(_onPlayerRespawn);
    Bridge.registerPlayerRespawnHandler(callback);
  }

  // ==========================================================================
  // Player Death/Damage Events
  // ==========================================================================

  /// Set a handler for player death events.
  ///
  /// Return a custom death message, or null for the default message.
  static set onPlayerDeath(String? Function(Player player, String damageSource)? handler) {
    _playerDeathHandler = handler;
    if (handler != null) {
      final callback = Pointer.fromFunction<PlayerDeathCallbackNative>(_onPlayerDeath);
      Bridge.registerPlayerDeathHandler(callback);
    }
  }

  /// Set a handler for entity damage events.
  ///
  /// Return false to cancel the damage, true to allow it.
  static set onEntityDamage(bool Function(Entity entity, String damageSource, double amount)? handler) {
    _entityDamageHandler = handler;
    if (handler != null) {
      final callback = Pointer.fromFunction<EntityDamageCallbackNative>(_onEntityDamage, true);
      Bridge.registerEntityDamageHandler(callback);
    }
  }

  /// Register a handler for entity death events.
  static void onEntityDeath(void Function(Entity entity, String damageSource) handler) {
    _entityDeathHandler = handler;
    final callback = Pointer.fromFunction<EntityDeathCallbackNative>(_onEntityDeath);
    Bridge.registerEntityDeathHandler(callback);
  }

  // ==========================================================================
  // Combat Events
  // ==========================================================================

  /// Set a handler for player attack entity events.
  ///
  /// Return false to cancel the attack, true to allow it.
  static set onPlayerAttackEntity(bool Function(Player player, Entity target)? handler) {
    _playerAttackEntityHandler = handler;
    if (handler != null) {
      final callback = Pointer.fromFunction<PlayerAttackEntityCallbackNative>(_onPlayerAttackEntity, true);
      Bridge.registerPlayerAttackEntityHandler(callback);
    }
  }

  // ==========================================================================
  // Chat & Command Events
  // ==========================================================================

  /// Set a handler for player chat events.
  ///
  /// Return the modified message, the original message to pass through,
  /// or null to cancel the message.
  static set onPlayerChat(String? Function(Player player, String message)? handler) {
    _playerChatHandler = handler;
    if (handler != null) {
      final callback = Pointer.fromFunction<PlayerChatCallbackNative>(_onPlayerChat);
      Bridge.registerPlayerChatHandler(callback);
    }
  }

  /// Set a handler for player command events.
  ///
  /// Return false to cancel the command, true to allow it.
  static set onPlayerCommand(bool Function(Player player, String command)? handler) {
    _playerCommandHandler = handler;
    if (handler != null) {
      final callback = Pointer.fromFunction<PlayerCommandCallbackNative>(_onPlayerCommand, true);
      Bridge.registerPlayerCommandHandler(callback);
    }
  }

  // ==========================================================================
  // Item Use Events
  // ==========================================================================

  /// Set a handler for item use events (right-click with item).
  ///
  /// Return false to cancel the use, true to allow it.
  static set onItemUse(bool Function(Player player, ItemStack item, Hand hand)? handler) {
    _itemUseHandler = handler;
    if (handler != null) {
      final callback = Pointer.fromFunction<ItemUseCallbackNative>(_onItemUse, true);
      Bridge.registerItemUseHandler(callback);
    }
  }

  /// Set a handler for item use on block events.
  ///
  /// Return EventResult to control the interaction.
  static set onItemUseOnBlock(EventResult Function(Player player, ItemStack item, Hand hand, BlockPos pos, Direction face)? handler) {
    _itemUseOnBlockHandler = handler;
    if (handler != null) {
      final callback = Pointer.fromFunction<ItemUseOnBlockCallbackNative>(_onItemUseOnBlock, 1);
      Bridge.registerItemUseOnBlockHandler(callback);
    }
  }

  /// Set a handler for item use on entity events.
  ///
  /// Return EventResult to control the interaction.
  static set onItemUseOnEntity(EventResult Function(Player player, ItemStack item, Hand hand, Entity target)? handler) {
    _itemUseOnEntityHandler = handler;
    if (handler != null) {
      final callback = Pointer.fromFunction<ItemUseOnEntityCallbackNative>(_onItemUseOnEntity, 1);
      Bridge.registerItemUseOnEntityHandler(callback);
    }
  }

  // ==========================================================================
  // Block Place Event
  // ==========================================================================

  /// Set a handler for block place events.
  ///
  /// Return false to cancel the placement, true to allow it.
  static set onBlockPlace(bool Function(Player player, BlockPos pos, String blockId)? handler) {
    _blockPlaceHandler = handler;
    if (handler != null) {
      final callback = Pointer.fromFunction<BlockPlaceCallbackNative>(_onBlockPlace, true);
      Bridge.registerBlockPlaceHandler(callback);
    }
  }

  // ==========================================================================
  // Item Pickup/Drop Events
  // ==========================================================================

  /// Set a handler for player pickup item events.
  ///
  /// Return false to cancel the pickup, true to allow it.
  static set onPlayerPickupItem(bool Function(Player player, ItemEntity item)? handler) {
    _playerPickupItemHandler = handler;
    if (handler != null) {
      final callback = Pointer.fromFunction<PlayerPickupItemCallbackNative>(_onPlayerPickupItem, true);
      Bridge.registerPlayerPickupItemHandler(callback);
    }
  }

  /// Set a handler for player drop item events.
  ///
  /// Return false to cancel the drop, true to allow it.
  static set onPlayerDropItem(bool Function(Player player, ItemStack item)? handler) {
    _playerDropItemHandler = handler;
    if (handler != null) {
      final callback = Pointer.fromFunction<PlayerDropItemCallbackNative>(_onPlayerDropItem, true);
      Bridge.registerPlayerDropItemHandler(callback);
    }
  }

  // ==========================================================================
  // Server Lifecycle Events
  // ==========================================================================

  /// Register a handler for server starting event.
  static void onServerStarting(void Function() handler) {
    _serverStartingHandler = handler;
    final callback = Pointer.fromFunction<ServerLifecycleCallbackNative>(_onServerStarting);
    Bridge.registerServerStartingHandler(callback);
  }

  /// Register a handler for server started event.
  static void onServerStarted(void Function() handler) {
    _serverStartedHandler = handler;
    final callback = Pointer.fromFunction<ServerLifecycleCallbackNative>(_onServerStarted);
    Bridge.registerServerStartedHandler(callback);
  }

  /// Register a handler for server stopping event.
  static void onServerStopping(void Function() handler) {
    _serverStoppingHandler = handler;
    final callback = Pointer.fromFunction<ServerLifecycleCallbackNative>(_onServerStopping);
    Bridge.registerServerStoppingHandler(callback);
  }
}
