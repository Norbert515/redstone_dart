/// API for defining custom AI goals in Dart.
///
/// This library provides the base class and registry for creating custom
/// entity goals that control AI behavior through Dart callbacks.
library;

/// Flags that indicate what controls a goal uses.
/// Goals with conflicting flags cannot run simultaneously.
enum GoalFlag {
  move, // Uses movement control
  look, // Uses look control
  jump, // Uses jump control
  target, // Is a targeting goal
}

/// Base class for custom AI goals defined in Dart.
///
/// Extend this class and override the lifecycle methods to create
/// custom entity behaviors.
///
/// Example:
/// ```dart
/// class FollowPlayerGoal extends CustomGoal {
///   FollowPlayerGoal() : super(
///     id: 'mymod:follow_player',
///     priority: 3,
///     flags: {GoalFlag.move, GoalFlag.look},
///   );
///
///   @override
///   bool canUse(int entityId) => hasNearbyPlayer(entityId);
///
///   @override
///   void tick(int entityId) => moveToNearestPlayer(entityId);
/// }
/// ```
abstract class CustomGoal {
  /// Unique identifier for this goal type (e.g., 'mymod:follow_player')
  final String id;

  /// Priority of this goal (lower = higher priority)
  final int priority;

  /// Flags indicating what controls this goal uses
  final Set<GoalFlag> flags;

  /// Whether this goal needs tick() called every tick.
  /// Set to false if the goal only needs occasional updates.
  final bool requiresUpdateEveryTick;

  const CustomGoal({
    required this.id,
    required this.priority,
    this.flags = const {},
    this.requiresUpdateEveryTick = true,
  });

  /// Called to check if this goal can start.
  /// Return true if the goal should activate.
  bool canUse(int entityId) => false;

  /// Called to check if this goal should continue running.
  /// Default implementation calls canUse().
  bool canContinueToUse(int entityId) => canUse(entityId);

  /// Called when the goal starts.
  void start(int entityId) {}

  /// Called every tick while the goal is active.
  void tick(int entityId) {}

  /// Called when the goal stops.
  void stop(int entityId) {}

  /// Serialize to JSON for passing to Java
  Map<String, dynamic> toJson() => {
        'type': 'custom',
        'goalId': id,
        'priority': priority,
        'flags': flags.map((f) => f.name).toList(),
        'requiresUpdateEveryTick': requiresUpdateEveryTick,
      };
}

/// Registry for custom goals.
/// Goals must be registered before they can be used.
class CustomGoalRegistry {
  static final Map<String, CustomGoal> _goals = {};

  /// Register a custom goal type.
  static void register(CustomGoal goal) {
    if (_goals.containsKey(goal.id)) {
      throw StateError('Goal ${goal.id} is already registered');
    }
    _goals[goal.id] = goal;
    print('CustomGoalRegistry: Registered goal ${goal.id}');
  }

  /// Get a registered goal by ID.
  static CustomGoal? get(String id) => _goals[id];

  /// Check if a goal is registered.
  static bool isRegistered(String id) => _goals.containsKey(id);

  /// Get all registered goal IDs.
  static Iterable<String> get registeredIds => _goals.keys;

  // ===========================================================================
  // Internal: Called by native bridge for goal callbacks
  // These are public to allow access from events.dart
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
