/// Entity goal types for the Redstone behavior system.
///
/// This library provides a sealed class hierarchy for defining entity goals
/// that control AI behavior. Goals are organized into two categories:
/// - Goal Selector: General behavior goals (movement, looking, combat actions)
/// - Target Selector: Target acquisition goals (finding enemies to attack)
library;

import 'custom_goal.dart';

/// Sealed class representing entity goal types.
///
/// Goals define AI behavior and are registered with priority (lower = higher priority).
/// Each entity type can have multiple goals that work together to create complex behavior.
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
///
/// When the entity is in water, it will swim upward to stay at the surface.
final class FloatGoal extends EntityGoal {
  const FloatGoal({required super.priority});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'float',
        'priority': priority,
      };
}

/// Perform melee attacks against the current target.
///
/// The entity will path toward its target and attack when in range.
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
///
/// The entity will jump toward its target when close enough.
final class LeapAtTargetGoal extends EntityGoal {
  /// Vertical velocity when leaping (blocks per tick).
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
///
/// The entity will move to random positions nearby, preferring to stay on land.
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
///
/// The entity will turn to face players within the look distance.
final class LookAtPlayerGoal extends EntityGoal {
  /// Maximum distance to look at players (in blocks).
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
///
/// The entity will occasionally turn its head to look in random directions.
final class RandomLookAroundGoal extends EntityGoal {
  const RandomLookAroundGoal({required super.priority});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'random_look_around',
        'priority': priority,
      };
}

/// Panic and run when hurt.
///
/// The entity will run away at increased speed when it takes damage.
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
///
/// When in love mode, the entity will seek out a partner and breed.
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
///
/// The entity will follow players who are holding the tempt item.
final class TemptGoal extends EntityGoal {
  /// The item that tempts this entity (e.g., "minecraft:wheat").
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
///
/// Young entities will stay close to their parent entity.
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
///
/// Used to make hostile mobs target players or other entities.
final class NearestAttackableTargetGoal extends EntityGoal {
  /// The entity type to target (e.g., "minecraft:player", "minecraft:villager").
  final String targetType;

  /// Whether the target must be visible (not behind blocks).
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
///
/// The entity will remember and target attackers for retaliation.
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
/// The goal must be registered with CustomGoalRegistry before use.
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
