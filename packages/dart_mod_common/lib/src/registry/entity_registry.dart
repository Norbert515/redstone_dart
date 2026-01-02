/// Entity registry interface.
library;

import '../entity/custom_entity.dart';
import '../entity/entity_goal.dart';

/// Abstract interface for entity registration.
///
/// The actual implementation is in dart_mod_server which handles
/// the FFI calls to register entities with the Minecraft server.
abstract class EntityRegistryBase {
  /// Register a custom entity type.
  void register(CustomEntity entity);

  /// Get a registered entity by ID.
  CustomEntity? get(String id);

  /// Check if an entity is registered.
  bool isRegistered(String id);

  /// Get all registered entity IDs.
  Iterable<String> get registeredIds;
}

/// Registry for custom goals.
class CustomGoalRegistry {
  static final Map<String, CustomGoal> _goals = {};

  /// Register a custom goal type.
  static void register(CustomGoal goal) {
    if (_goals.containsKey(goal.id)) {
      throw StateError('Goal ${goal.id} is already registered');
    }
    _goals[goal.id] = goal;
  }

  /// Get a registered goal by ID.
  static CustomGoal? get(String id) => _goals[id];

  /// Check if a goal is registered.
  static bool isRegistered(String id) => _goals.containsKey(id);

  /// Get all registered goal IDs.
  static Iterable<String> get registeredIds => _goals.keys;

  // ===========================================================================
  // Internal: Called by native bridge for goal callbacks
  // ===========================================================================

  /// Dispatch canUse callback for a goal.
  static bool dispatchCanUse(String goalId, int entityId) {
    return _goals[goalId]?.canUse(entityId) ?? false;
  }

  /// Dispatch canContinueToUse callback for a goal.
  static bool dispatchCanContinueToUse(String goalId, int entityId) {
    return _goals[goalId]?.canContinueToUse(entityId) ?? false;
  }

  /// Dispatch start callback for a goal.
  static void dispatchStart(String goalId, int entityId) {
    _goals[goalId]?.start(entityId);
  }

  /// Dispatch tick callback for a goal.
  static void dispatchTick(String goalId, int entityId) {
    _goals[goalId]?.tick(entityId);
  }

  /// Dispatch stop callback for a goal.
  static void dispatchStop(String goalId, int entityId) {
    _goals[goalId]?.stop(entityId);
  }
}
