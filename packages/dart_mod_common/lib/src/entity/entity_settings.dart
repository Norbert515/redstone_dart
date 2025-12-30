/// Entity settings for creating custom entities.
library;

import 'entity_model.dart';

/// Spawn groups for entity category.
enum SpawnGroup {
  monster,
  creature,
  ambient,
  waterCreature,
  misc,
}

/// Base type for entities - determines which Java proxy class is used.
enum EntityBaseType {
  /// PathfinderMob - basic mob with pathfinding AI.
  pathfinderMob,

  /// Monster - hostile mob.
  monster,

  /// Animal - passive mob.
  animal,

  /// Projectile - throwable/shootable entity.
  projectile,
}

/// Settings for creating a custom entity.
class EntitySettings {
  /// The entity's collision box width.
  final double width;

  /// The entity's collision box height.
  final double height;

  /// The entity's maximum health.
  final double maxHealth;

  /// The entity's movement speed.
  final double movementSpeed;

  /// The entity's attack damage.
  final double attackDamage;

  /// The spawn group (determines despawning behavior and spawn caps).
  final SpawnGroup spawnGroup;

  /// Whether the entity needs tick callbacks.
  final bool needsTickCallback;

  /// The entity model for rendering.
  final EntityModel? model;

  /// The base type determines which Java proxy class is used.
  EntityBaseType get baseType => EntityBaseType.pathfinderMob;

  const EntitySettings({
    this.width = 0.6,
    this.height = 1.8,
    this.maxHealth = 20.0,
    this.movementSpeed = 0.25,
    this.attackDamage = 2.0,
    this.spawnGroup = SpawnGroup.creature,
    this.needsTickCallback = false,
    this.model,
  });
}
