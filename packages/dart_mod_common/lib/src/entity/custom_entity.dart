/// API for defining custom entities in Dart.
library;

import 'entity_goal.dart';
import 'entity_settings.dart';

/// Settings for monster (hostile) entities.
class MonsterSettings extends EntitySettings {
  /// Whether the monster burns when exposed to sunlight.
  final bool burnsInDaylight;

  /// Custom AI goals for the goal selector.
  final List<EntityGoal>? goals;

  /// Custom AI goals for the target selector.
  final List<EntityGoal>? targetGoals;

  const MonsterSettings({
    super.width = 0.6,
    super.height = 1.95,
    super.maxHealth = 20,
    super.movementSpeed = 0.23,
    super.attackDamage = 3,
    this.burnsInDaylight = false,
    this.goals,
    this.targetGoals,
    super.needsTickCallback = false,
    super.model,
  }) : super(spawnGroup: SpawnGroup.monster);

  @override
  EntityBaseType get baseType => EntityBaseType.monster;
}

/// Settings for animal (breedable) entities.
class AnimalSettings extends EntitySettings {
  /// The breeding item identifier.
  final String? breedingItem;

  /// Custom AI goals for the goal selector.
  final List<EntityGoal>? goals;

  /// Custom AI goals for the target selector.
  final List<EntityGoal>? targetGoals;

  const AnimalSettings({
    super.width = 0.9,
    super.height = 1.4,
    super.maxHealth = 10,
    super.movementSpeed = 0.2,
    super.attackDamage = 0,
    this.breedingItem,
    this.goals,
    this.targetGoals,
    super.needsTickCallback = false,
    super.model,
  }) : super(spawnGroup: SpawnGroup.creature);

  @override
  EntityBaseType get baseType => EntityBaseType.animal;
}

/// Settings for projectile entities.
class ProjectileSettings extends EntitySettings {
  /// Gravity applied to the projectile each tick.
  final double gravity;

  /// Whether the projectile ignores block collisions.
  final bool noClip;

  const ProjectileSettings({
    super.width = 0.25,
    super.height = 0.25,
    this.gravity = 0.03,
    this.noClip = false,
    super.needsTickCallback = false,
    super.model,
  }) : super(
          maxHealth: 1,
          movementSpeed: 0,
          attackDamage: 0,
          spawnGroup: SpawnGroup.misc,
        );

  @override
  EntityBaseType get baseType => EntityBaseType.projectile;
}

/// Base class for Dart-defined entities.
abstract class CustomEntity {
  /// The entity identifier in format "namespace:path".
  final String id;

  /// Entity settings (dimensions, health, speed, etc.).
  final EntitySettings settings;

  /// Internal handler ID assigned during registration.
  int? _handlerId;

  CustomEntity({
    required this.id,
    required this.settings,
  });

  /// Get the handler ID (only available after registration).
  int get handlerId {
    if (_handlerId == null) {
      throw StateError('Entity not registered: $id');
    }
    return _handlerId!;
  }

  /// Check if this entity has been registered.
  bool get isRegistered => _handlerId != null;

  // ==========================================================================
  // Lifecycle Hooks
  // ==========================================================================

  /// Called when an instance of this entity type is spawned.
  void onSpawn(int entityId, int worldId) {}

  /// Called every game tick for each living instance.
  void onTick(int entityId) {}

  /// Called when an instance of this entity type dies.
  void onDeath(int entityId, String damageSource) {}

  // ==========================================================================
  // Combat Hooks
  // ==========================================================================

  /// Called when an instance takes damage.
  /// Return true to allow the damage, false to cancel it.
  bool onDamage(int entityId, String damageSource, double amount) {
    return true;
  }

  /// Called when an instance attacks another entity.
  void onAttack(int entityId, int targetId) {}

  // ==========================================================================
  // AI Hooks
  // ==========================================================================

  /// Called when an instance acquires a target.
  void onTargetAcquired(int entityId, int targetId) {}

  // ==========================================================================
  // Internal
  // ==========================================================================

  /// Internal: Set the handler ID after registration.
  void setHandlerId(int id) {
    _handlerId = id;
  }

  @override
  String toString() => 'CustomEntity($id, registered=$isRegistered)';
}

/// Base class for monster (hostile) entities.
abstract class CustomMonster extends CustomEntity {
  CustomMonster({
    required super.id,
    required MonsterSettings settings,
  }) : super(settings: settings);

  @override
  MonsterSettings get settings => super.settings as MonsterSettings;
}

/// Base class for animal (breedable) entities.
abstract class CustomAnimal extends CustomEntity {
  CustomAnimal({
    required super.id,
    required AnimalSettings settings,
  }) : super(settings: settings);

  @override
  AnimalSettings get settings => super.settings as AnimalSettings;

  /// Called when this animal breeds with a partner.
  void onBreed(int entityId, int partnerId, int babyId) {}
}

/// Base class for projectile entities.
abstract class CustomProjectile extends CustomEntity {
  CustomProjectile({
    required super.id,
    required ProjectileSettings settings,
  }) : super(settings: settings);

  @override
  ProjectileSettings get settings => super.settings as ProjectileSettings;

  /// Called when this projectile hits an entity.
  void onHitEntity(int projectileId, int targetId) {}

  /// Called when this projectile hits a block.
  void onHitBlock(int projectileId, int x, int y, int z, String side) {}
}
