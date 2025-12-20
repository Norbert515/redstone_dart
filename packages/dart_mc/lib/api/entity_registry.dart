/// Registry for Dart-defined custom entities.
library;

import 'custom_entity.dart';
import '../src/jni/generic_bridge.dart';

/// Registry for Dart-defined entities.
///
/// All entities must be registered during mod initialization (before Minecraft's
/// registry freezes). Attempting to register entities after initialization will fail.
///
/// Example:
/// ```dart
/// void onModInit() {
///   EntityRegistry.register(CustomZombie());
///   EntityRegistry.register(CustomCreeper());
///   // ... register all your entities
/// }
/// ```
class EntityRegistry {
  static final Map<int, CustomEntity> _entities = {};
  static bool _frozen = false;

  EntityRegistry._(); // Private constructor - all static

  /// Register a custom entity.
  ///
  /// Must be called during mod initialization, before the registry freezes.
  /// Throws [StateError] if called after initialization.
  ///
  /// Returns the handler ID assigned to this entity.
  static int register(CustomEntity entity) {
    if (_frozen) {
      throw StateError(
        'Cannot register entities after initialization. '
        'Entity: ${entity.id}',
      );
    }

    if (entity.isRegistered) {
      throw StateError('Entity already registered: ${entity.id}');
    }

    // Parse the identifier
    final parts = entity.id.split(':');
    if (parts.length != 2) {
      throw ArgumentError(
        'Invalid entity ID format. Expected "namespace:path", got: ${entity.id}',
      );
    }
    final namespace = parts[0];
    final path = parts[1];

    // Create the proxy entity in Java
    // For animals, we need to pass the breeding item
    final int handlerId;
    if (entity is CustomAnimal) {
      handlerId = GenericJniBridge.callStaticLongMethod(
        'com/redstone/proxy/EntityProxyRegistry',
        'createEntityWithBreedingItem',
        '(FFFFFIILjava/lang/String;)J',
        [
          entity.settings.width,
          entity.settings.height,
          entity.settings.maxHealth,
          entity.settings.movementSpeed,
          entity.settings.attackDamage,
          entity.settings.spawnGroup.index,
          entity.settings.baseType.index,
          entity.settings.breedingItem,
        ],
      );
    } else {
      handlerId = GenericJniBridge.callStaticLongMethod(
        'com/redstone/proxy/EntityProxyRegistry',
        'createEntity',
        '(FFFFFII)J',
        [
          entity.settings.width,
          entity.settings.height,
          entity.settings.maxHealth,
          entity.settings.movementSpeed,
          entity.settings.attackDamage,
          entity.settings.spawnGroup.index,
          entity.settings.baseType.index,
        ],
      );
    }

    if (handlerId == 0) {
      throw StateError('Failed to create proxy entity for: ${entity.id}');
    }

    // Register with Minecraft's registry
    final success = GenericJniBridge.callStaticBoolMethod(
      'com/redstone/proxy/EntityProxyRegistry',
      'registerEntity',
      '(JLjava/lang/String;Ljava/lang/String;)Z',
      [handlerId, namespace, path],
    );

    if (!success) {
      throw StateError('Failed to register entity with Minecraft: ${entity.id}');
    }

    // Store the entity and set its handler ID
    entity.setHandlerId(handlerId);
    _entities[handlerId] = entity;

    print('EntityRegistry: Registered ${entity.id} with handler ID $handlerId');
    return handlerId;
  }

  /// Get an entity by its handler ID.
  ///
  /// Returns null if no entity is registered with that ID.
  static CustomEntity? getEntity(int handlerId) {
    return _entities[handlerId];
  }

  /// Get all registered entities.
  static Iterable<CustomEntity> get allEntities => _entities.values;

  /// Get the number of registered entities.
  static int get entityCount => _entities.length;

  /// Freeze the registry (called internally after mod initialization).
  ///
  /// After this is called, no more entities can be registered.
  static void freeze() {
    _frozen = true;
    print('EntityRegistry: Frozen with ${_entities.length} entities registered');
  }

  /// Check if the registry is frozen.
  static bool get isFrozen => _frozen;

  // ==========================================================================
  // Internal dispatch methods - called from native code via events.dart
  // ==========================================================================

  /// Dispatch an entity spawn event to the appropriate handler.
  static void dispatchSpawn(int handlerId, int entityId, int worldId) {
    final entity = _entities[handlerId];
    if (entity != null) {
      entity.onSpawn(entityId, worldId);
    }
  }

  /// Dispatch an entity tick event to the appropriate handler.
  static void dispatchTick(int handlerId, int entityId) {
    final entity = _entities[handlerId];
    if (entity != null) {
      entity.onTick(entityId);
    }
  }

  /// Dispatch an entity death event to the appropriate handler.
  static void dispatchDeath(int handlerId, int entityId, String damageSource) {
    final entity = _entities[handlerId];
    if (entity != null) {
      entity.onDeath(entityId, damageSource);
    }
  }

  /// Dispatch an entity damage event to the appropriate handler.
  /// Returns true to allow damage, false to cancel.
  static bool dispatchDamage(
    int handlerId,
    int entityId,
    String damageSource,
    double amount,
  ) {
    final entity = _entities[handlerId];
    if (entity != null) {
      return entity.onDamage(entityId, damageSource, amount);
    }
    return true; // Default: allow damage
  }

  /// Dispatch an entity attack event to the appropriate handler.
  static void dispatchAttack(int handlerId, int entityId, int targetId) {
    final entity = _entities[handlerId];
    if (entity != null) {
      entity.onAttack(entityId, targetId);
    }
  }

  /// Dispatch a target acquired event to the appropriate handler.
  static void dispatchTargetAcquired(int handlerId, int entityId, int targetId) {
    final entity = _entities[handlerId];
    if (entity != null) {
      entity.onTargetAcquired(entityId, targetId);
    }
  }

  // ==========================================================================
  // Projectile dispatch methods - called from native code via events.dart
  // ==========================================================================

  /// Dispatch a projectile hit entity event to the appropriate handler.
  static void dispatchProjectileHitEntity(
    int handlerId,
    int projectileId,
    int targetId,
  ) {
    final entity = _entities[handlerId];
    if (entity is CustomProjectile) {
      entity.onHitEntity(projectileId, targetId);
    }
  }

  /// Dispatch a projectile hit block event to the appropriate handler.
  static void dispatchProjectileHitBlock(
    int handlerId,
    int projectileId,
    int x,
    int y,
    int z,
    String side,
  ) {
    final entity = _entities[handlerId];
    if (entity is CustomProjectile) {
      entity.onHitBlock(projectileId, x, y, z, side);
    }
  }

  // ==========================================================================
  // Animal dispatch methods - called from native code via events.dart
  // ==========================================================================

  /// Dispatch an animal breed event to the appropriate handler.
  static void dispatchAnimalBreed(
    int handlerId,
    int entityId,
    int partnerId,
    int babyId,
  ) {
    final entity = _entities[handlerId];
    if (entity is CustomAnimal) {
      entity.onBreed(entityId, partnerId, babyId);
    }
  }
}
