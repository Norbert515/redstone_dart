/// Custom Goal Registry API for server-side goal dispatch.
///
/// This library provides the registry for custom AI goals that
/// dispatches callbacks from the native bridge to Dart goal implementations.
///
/// The [CustomGoal] base class is defined in dart_mod_common.
/// This file provides the server-side [CustomGoalRegistry] that handles
/// the dispatch of goal callbacks.
library;

import 'dart:ffi';

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:ffi/ffi.dart';

import 'bridge.dart';

/// Registry for custom goals.
/// Goals must be registered before they can be used.
class CustomGoalRegistry {
  static final Map<String, CustomGoal> _goals = {};
  static bool _handlersRegistered = false;

  /// Register a custom goal type.
  static void register(CustomGoal goal) {
    if (_goals.containsKey(goal.id)) {
      throw StateError('Goal ${goal.id} is already registered');
    }

    _ensureHandlersRegistered();

    _goals[goal.id] = goal;
    print('CustomGoalRegistry: Registered goal ${goal.id}');
  }

  /// Get a registered goal by ID.
  static CustomGoal? get(String id) => _goals[id];

  /// Check if a goal is registered.
  static bool isRegistered(String id) => _goals.containsKey(id);

  /// Get all registered goal IDs.
  static Iterable<String> get registeredIds => _goals.keys;

  /// Ensure native handlers are registered for goal callbacks.
  static void _ensureHandlersRegistered() {
    if (_handlersRegistered) return;
    if (ServerBridge.isDatagenMode) {
      _handlersRegistered = true;
      return;
    }

    ServerBridge.registerCustomGoalCanUseHandler(
      Pointer.fromFunction<_CustomGoalBoolCallbackNative>(
        _onCanUse,
        false,
      ),
    );

    ServerBridge.registerCustomGoalCanContinueToUseHandler(
      Pointer.fromFunction<_CustomGoalBoolCallbackNative>(
        _onCanContinueToUse,
        false,
      ),
    );

    ServerBridge.registerCustomGoalStartHandler(
      Pointer.fromFunction<_CustomGoalVoidCallbackNative>(
        _onStart,
      ),
    );

    ServerBridge.registerCustomGoalTickHandler(
      Pointer.fromFunction<_CustomGoalVoidCallbackNative>(
        _onTick,
      ),
    );

    ServerBridge.registerCustomGoalStopHandler(
      Pointer.fromFunction<_CustomGoalVoidCallbackNative>(
        _onStop,
      ),
    );

    _handlersRegistered = true;
  }

  // ===========================================================================
  // Internal: Called by native bridge for goal callbacks
  // ===========================================================================

  /// Dispatch canUse callback for a goal.
  @pragma('vm:entry-point')
  static bool _onCanUse(Pointer<Utf8> goalIdPtr, int entityId) {
    final goalId = goalIdPtr.toDartString();
    return dispatchCanUse(goalId, entityId);
  }

  /// Dispatch canContinueToUse callback for a goal.
  @pragma('vm:entry-point')
  static bool _onCanContinueToUse(Pointer<Utf8> goalIdPtr, int entityId) {
    final goalId = goalIdPtr.toDartString();
    return dispatchCanContinueToUse(goalId, entityId);
  }

  /// Dispatch start callback for a goal.
  @pragma('vm:entry-point')
  static void _onStart(Pointer<Utf8> goalIdPtr, int entityId) {
    final goalId = goalIdPtr.toDartString();
    dispatchStart(goalId, entityId);
  }

  /// Dispatch tick callback for a goal.
  @pragma('vm:entry-point')
  static void _onTick(Pointer<Utf8> goalIdPtr, int entityId) {
    final goalId = goalIdPtr.toDartString();
    dispatchTick(goalId, entityId);
  }

  /// Dispatch stop callback for a goal.
  @pragma('vm:entry-point')
  static void _onStop(Pointer<Utf8> goalIdPtr, int entityId) {
    final goalId = goalIdPtr.toDartString();
    dispatchStop(goalId, entityId);
  }

  // ===========================================================================
  // Public dispatch methods (can also be called directly if needed)
  // ===========================================================================

  /// Dispatch canUse callback for a goal.
  /// Called by native bridge to check if a goal can start.
  static bool dispatchCanUse(String goalId, int entityId) {
    return _goals[goalId]?.canUse(entityId) ?? false;
  }

  /// Dispatch canContinueToUse callback for a goal.
  /// Called by native bridge to check if a goal should continue.
  static bool dispatchCanContinueToUse(String goalId, int entityId) {
    return _goals[goalId]?.canContinueToUse(entityId) ?? false;
  }

  /// Dispatch start callback for a goal.
  /// Called by native bridge when a goal starts.
  static void dispatchStart(String goalId, int entityId) {
    _goals[goalId]?.start(entityId);
  }

  /// Dispatch tick callback for a goal.
  /// Called by native bridge every tick while a goal is active.
  static void dispatchTick(String goalId, int entityId) {
    _goals[goalId]?.tick(entityId);
  }

  /// Dispatch stop callback for a goal.
  /// Called by native bridge when a goal stops.
  static void dispatchStop(String goalId, int entityId) {
    _goals[goalId]?.stop(entityId);
  }
}

// =============================================================================
// FFI Callback Type Definitions
// =============================================================================

/// Native callback type for bool-returning goal methods.
typedef _CustomGoalBoolCallbackNative = Bool Function(
  Pointer<Utf8> goalId,
  Int32 entityId,
);

/// Native callback type for void goal methods.
typedef _CustomGoalVoidCallbackNative = Void Function(
  Pointer<Utf8> goalId,
  Int32 entityId,
);
