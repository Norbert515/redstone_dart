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

  const EntitySettings({
    this.width = 0.6,
    this.height = 1.8,
    this.maxHealth = 20.0,
    this.movementSpeed = 0.25,
    this.attackDamage = 2.0,
    this.spawnGroup = SpawnGroup.creature,
  });
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
