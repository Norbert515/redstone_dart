/// Entity goal types for the Redstone behavior system.
library;

/// Flags that indicate what controls a goal uses.
/// Goals with conflicting flags cannot run simultaneously.
enum GoalFlag {
  move, // Uses movement control
  look, // Uses look control
  jump, // Uses jump control
  target, // Is a targeting goal
}

/// Sealed class representing entity goal types.
///
/// Goals define AI behavior and are registered with priority (lower = higher priority).
sealed class EntityGoal {
  /// Priority of this goal (lower numbers = higher priority).
  final int priority;

  const EntityGoal({required this.priority});

  /// Convert to JSON for manifest/serialization.
  Map<String, dynamic> toJson();
}

// =============================================================================
// Combat Goals (goalSelector)
// =============================================================================

/// Stay afloat in water.
final class FloatGoal extends EntityGoal {
  const FloatGoal({required super.priority});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'float',
        'priority': priority,
      };
}

/// Perform melee attacks against the current target.
final class MeleeAttackGoal extends EntityGoal {
  /// Speed multiplier when moving toward target.
  final double speedModifier;

  /// Whether to continue following the target even when out of sight.
  final bool followEvenIfNotSeen;

  const MeleeAttackGoal({
    required super.priority,
    this.speedModifier = 1.0,
    this.followEvenIfNotSeen = true,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'melee_attack',
        'priority': priority,
        'speedModifier': speedModifier,
        'followEvenIfNotSeen': followEvenIfNotSeen,
      };
}

/// Leap at the current target.
final class LeapAtTargetGoal extends EntityGoal {
  /// Vertical velocity when leaping.
  final double yd;

  const LeapAtTargetGoal({
    required super.priority,
    this.yd = 0.4,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'leap_at_target',
        'priority': priority,
        'yd': yd,
      };
}

// =============================================================================
// Passive Goals (goalSelector)
// =============================================================================

/// Randomly wander while avoiding water.
final class WaterAvoidingRandomStrollGoal extends EntityGoal {
  /// Speed multiplier when wandering.
  final double speedModifier;

  const WaterAvoidingRandomStrollGoal({
    required super.priority,
    this.speedModifier = 1.0,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'water_avoiding_random_stroll',
        'priority': priority,
        'speedModifier': speedModifier,
      };
}

/// Look at nearby players.
final class LookAtPlayerGoal extends EntityGoal {
  /// Maximum distance to look at players.
  final double lookDistance;

  const LookAtPlayerGoal({
    required super.priority,
    this.lookDistance = 8.0,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'look_at_player',
        'priority': priority,
        'lookDistance': lookDistance,
      };
}

/// Randomly look around.
final class RandomLookAroundGoal extends EntityGoal {
  const RandomLookAroundGoal({required super.priority});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'random_look_around',
        'priority': priority,
      };
}

/// Panic and run when hurt.
final class PanicGoal extends EntityGoal {
  /// Speed multiplier when panicking.
  final double speedModifier;

  const PanicGoal({
    required super.priority,
    this.speedModifier = 1.5,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'panic',
        'priority': priority,
        'speedModifier': speedModifier,
      };
}

// =============================================================================
// Animal Goals (goalSelector)
// =============================================================================

/// Breed with nearby animals of the same type.
final class BreedGoal extends EntityGoal {
  /// Speed multiplier when seeking a partner.
  final double speedModifier;

  const BreedGoal({
    required super.priority,
    this.speedModifier = 1.0,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'breed',
        'priority': priority,
        'speedModifier': speedModifier,
      };
}

/// Follow players holding a specific item.
final class TemptGoal extends EntityGoal {
  /// The item that tempts this entity.
  final String temptItem;

  /// Speed multiplier when following.
  final double speedModifier;

  const TemptGoal({
    required super.priority,
    required this.temptItem,
    this.speedModifier = 1.0,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'tempt',
        'priority': priority,
        'temptItem': temptItem,
        'speedModifier': speedModifier,
      };
}

/// Baby animals follow their parent.
final class FollowParentGoal extends EntityGoal {
  /// Speed multiplier when following parent.
  final double speedModifier;

  const FollowParentGoal({
    required super.priority,
    this.speedModifier = 1.1,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'follow_parent',
        'priority': priority,
        'speedModifier': speedModifier,
      };
}

// =============================================================================
// Target Goals (targetSelector)
// =============================================================================

/// Find and target the nearest attackable entity of a specific type.
final class NearestAttackableTargetGoal extends EntityGoal {
  /// The entity type to target.
  final String targetType;

  /// Whether the target must be visible.
  final bool mustSee;

  const NearestAttackableTargetGoal({
    required super.priority,
    required this.targetType,
    this.mustSee = true,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'nearest_attackable_target',
        'priority': priority,
        'targetType': targetType,
        'mustSee': mustSee,
      };
}

/// Target entities that hurt this entity.
final class HurtByTargetGoal extends EntityGoal {
  /// Whether to alert nearby entities of the same type when hurt.
  final bool alertOthers;

  const HurtByTargetGoal({
    required super.priority,
    this.alertOthers = true,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'hurt_by_target',
        'priority': priority,
        'alertOthers': alertOthers,
      };
}

/// Reference to a custom goal defined via CustomGoal class.
final class CustomGoalRef extends EntityGoal {
  /// The ID of the custom goal (must match CustomGoal.id)
  final String goalId;

  /// Flags for this goal (optional override)
  final Set<GoalFlag>? flags;

  /// Whether tick() is called every tick
  final bool requiresUpdateEveryTick;

  const CustomGoalRef({
    required super.priority,
    required this.goalId,
    this.flags,
    this.requiresUpdateEveryTick = true,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'custom',
        'priority': priority,
        'goalId': goalId,
        'flags': flags?.map((f) => f.name).toList(),
        'requiresUpdateEveryTick': requiresUpdateEveryTick,
      };
}

/// Base class for custom AI goals defined in Dart.
abstract class CustomGoal {
  /// Unique identifier for this goal type
  final String id;

  /// Priority of this goal (lower = higher priority)
  final int priority;

  /// Flags indicating what controls this goal uses
  final Set<GoalFlag> flags;

  /// Whether this goal needs tick() called every tick.
  final bool requiresUpdateEveryTick;

  const CustomGoal({
    required this.id,
    required this.priority,
    this.flags = const {},
    this.requiresUpdateEveryTick = true,
  });

  /// Called to check if this goal can start.
  bool canUse(int entityId) => false;

  /// Called to check if this goal should continue running.
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
