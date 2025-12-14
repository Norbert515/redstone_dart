/// Event handler registration for Minecraft events.
///
/// This file provides a high-level API for registering event handlers
/// that will be called when events occur in Minecraft.
library;

import 'dart:ffi';

import 'bridge.dart';
import 'types.dart';

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
}
