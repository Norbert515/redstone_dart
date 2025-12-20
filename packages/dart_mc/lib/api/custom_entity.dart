/// API for defining custom entities in Dart.
library;

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

  /// Monster - hostile mob (unused for now, reserved for future).
  monster,

  /// Animal - passive mob (unused for now, reserved for future).
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

  /// The base type determines which Java proxy class is used.
  EntityBaseType get baseType => EntityBaseType.pathfinderMob;

  const EntitySettings({
    this.width = 0.6,
    this.height = 1.8,
    this.maxHealth = 20.0,
    this.movementSpeed = 0.25,
    this.attackDamage = 2.0,
    this.spawnGroup = SpawnGroup.creature,
  });
}

/// Settings for monster (hostile) entities.
///
/// Monsters spawn in dark areas and are hostile to players.
/// They can optionally burn in daylight like zombies.
class MonsterSettings extends EntitySettings {
  /// Whether the monster burns when exposed to sunlight.
  final bool burnsInDaylight;

  const MonsterSettings({
    super.width = 0.6,
    super.height = 1.95,
    super.maxHealth = 20,
    super.movementSpeed = 0.23,
    super.attackDamage = 3,
    this.burnsInDaylight = false,
  }) : super(spawnGroup: SpawnGroup.monster);

  @override
  EntityBaseType get baseType => EntityBaseType.monster;
}

/// Settings for animal (breedable) entities.
///
/// Animals are passive mobs that can be bred using a specific item.
/// They use the CREATURE spawn group by default.
class AnimalSettings extends EntitySettings {
  /// The breeding item identifier (e.g., "minecraft:wheat").
  /// If null, the animal cannot be bred.
  final String? breedingItem;

  const AnimalSettings({
    super.width = 0.9,
    super.height = 1.4,
    super.maxHealth = 10,
    super.movementSpeed = 0.2,
    super.attackDamage = 0,
    this.breedingItem,
  }) : super(spawnGroup: SpawnGroup.creature);

  @override
  EntityBaseType get baseType => EntityBaseType.animal;
}

/// Settings for projectile entities.
///
/// Projectiles don't have health, movement speed, or attack damage attributes.
/// They use physics-based movement instead.
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
///
/// Subclass this and override methods to define custom entity behavior.
///
/// Example:
/// ```dart
/// class CustomZombie extends CustomEntity {
///   CustomZombie() : super(
///     id: 'mymod:custom_zombie',
///     settings: EntitySettings(
///       maxHealth: 40.0,
///       attackDamage: 4.0,
///       movementSpeed: 0.3,
///     ),
///   );
///
///   @override
///   void onSpawn(int entityId, int worldId) {
///     print('CustomZombie spawned: $entityId');
///   }
///
///   @override
///   void onTick(int entityId) {
///     // Custom behavior every tick
///   }
///
///   @override
///   bool onDamage(int entityId, String damageSource, double amount) {
///     // Return false to cancel damage
///     return true;
///   }
/// }
/// ```
abstract class CustomEntity {
  /// The entity identifier in format "namespace:path" (e.g., "mymod:custom_entity").
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
  ///
  /// [entityId] is the Minecraft entity ID of the spawned instance.
  /// [worldId] is a hash identifier of the world.
  void onSpawn(int entityId, int worldId) {}

  /// Called every game tick for each living instance.
  ///
  /// This is called 20 times per second. Use sparingly for performance.
  void onTick(int entityId) {}

  /// Called when an instance of this entity type dies.
  ///
  /// [entityId] is the Minecraft entity ID.
  /// [damageSource] describes what killed the entity.
  void onDeath(int entityId, String damageSource) {}

  // ==========================================================================
  // Combat Hooks
  // ==========================================================================

  /// Called when an instance of this entity type takes damage.
  ///
  /// Return true to allow the damage, false to cancel it.
  bool onDamage(int entityId, String damageSource, double amount) {
    return true; // Default: allow damage
  }

  /// Called when an instance of this entity type attacks another entity.
  ///
  /// [entityId] is this entity's ID.
  /// [targetId] is the target entity's ID.
  void onAttack(int entityId, int targetId) {}

  // ==========================================================================
  // AI Hooks
  // ==========================================================================

  /// Called when an instance of this entity type acquires a target.
  ///
  /// [entityId] is this entity's ID.
  /// [targetId] is the target entity's ID.
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

/// Base class for Dart-defined monster (hostile) entities.
///
/// Subclass this and override methods to define custom monster behavior.
/// Monsters automatically use hostile spawn group and Monster base class.
///
/// Example:
/// ```dart
/// class CustomZombie extends CustomMonster {
///   CustomZombie() : super(
///     id: 'mymod:custom_zombie',
///     settings: MonsterSettings(
///       maxHealth: 40.0,
///       attackDamage: 5.0,
///       movementSpeed: 0.25,
///       burnsInDaylight: true,
///     ),
///   );
///
///   @override
///   void onTick(int entityId) {
///     // Custom monster behavior every tick
///   }
///
///   @override
///   void onAttack(int entityId, int targetId) {
///     // Called when the monster attacks
///   }
/// }
/// ```
abstract class CustomMonster extends CustomEntity {
  CustomMonster({
    required super.id,
    required MonsterSettings settings,
  }) : super(settings: settings);

  /// Get the monster-specific settings.
  @override
  MonsterSettings get settings => super.settings as MonsterSettings;
}

/// Base class for Dart-defined animal (breedable) entities.
///
/// Subclass this and override methods to define custom animal behavior.
/// Animals automatically use creature spawn group and Animal base class.
///
/// Example:
/// ```dart
/// class CustomCow extends CustomAnimal {
///   CustomCow() : super(
///     id: 'mymod:custom_cow',
///     settings: AnimalSettings(
///       maxHealth: 10.0,
///       movementSpeed: 0.2,
///       breedingItem: 'minecraft:wheat',
///     ),
///   );
///
///   @override
///   void onBreed(int entityId, int partnerId, int babyId) {
///     print('Custom cow bred! Baby: $babyId');
///   }
/// }
/// ```
abstract class CustomAnimal extends CustomEntity {
  CustomAnimal({
    required super.id,
    required AnimalSettings settings,
  }) : super(settings: settings);

  /// Get the animal-specific settings.
  @override
  AnimalSettings get settings => super.settings as AnimalSettings;

  // ==========================================================================
  // Animal Hooks
  // ==========================================================================

  /// Called when this animal breeds with a partner.
  ///
  /// [entityId] is this animal's Minecraft entity ID.
  /// [partnerId] is the partner animal's Minecraft entity ID.
  /// [babyId] is the baby animal's Minecraft entity ID.
  void onBreed(int entityId, int partnerId, int babyId) {}
}

/// Base class for Dart-defined projectile entities.
///
/// Subclass this and override methods to define custom projectile behavior.
///
/// Example:
/// ```dart
/// class Fireball extends CustomProjectile {
///   Fireball() : super(
///     id: 'mymod:fireball',
///     settings: ProjectileSettings(
///       width: 0.5,
///       height: 0.5,
///       gravity: 0.01,
///     ),
///   );
///
///   @override
///   void onHitEntity(int projectileId, int targetId) {
///     // Deal damage to the target
///   }
///
///   @override
///   void onHitBlock(int projectileId, int x, int y, int z, String side) {
///     // Explode or remove the projectile
///   }
/// }
/// ```
abstract class CustomProjectile extends CustomEntity {
  CustomProjectile({
    required super.id,
    required ProjectileSettings settings,
  }) : super(settings: settings);

  /// Get the projectile-specific settings.
  @override
  ProjectileSettings get settings => super.settings as ProjectileSettings;

  // ==========================================================================
  // Projectile Hooks
  // ==========================================================================

  /// Called when this projectile hits an entity.
  ///
  /// [projectileId] is this projectile's entity ID.
  /// [targetId] is the entity ID of the hit target.
  void onHitEntity(int projectileId, int targetId) {}

  /// Called when this projectile hits a block.
  ///
  /// [projectileId] is this projectile's entity ID.
  /// [x], [y], [z] are the block coordinates.
  /// [side] is the direction the projectile hit from (e.g., "up", "down", "north").
  void onHitBlock(int projectileId, int x, int y, int z, String side) {}
}
