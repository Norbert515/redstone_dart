/// Registry for Dart-defined custom entities.
library;

import 'dart:convert';
import 'dart:io';

import 'custom_entity.dart';
import 'entity_goal.dart';
import '../src/bridge.dart';

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

  /// Serialize a list of goals to JSON string, or null if empty/null.
  static String? _serializeGoals(List<EntityGoal>? goals) {
    if (goals == null || goals.isEmpty) return null;
    return jsonEncode(goals.map((g) => g.toJson()).toList());
  }

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

    // Extract model info if present
    String modelType = '';
    String texturePath = '';
    double modelScale = 1.0;
    final model = entity.settings.model;
    if (model != null) {
      final modelJson = model.toJson();
      modelType = modelJson['type'] as String;
      texturePath = modelJson['texture'] as String;
      modelScale = (modelJson['scale'] as num?)?.toDouble() ?? 1.0;
    }

    // Extract goal configs for monsters and animals
    String goalsJson = '';
    String targetGoalsJson = '';
    if (entity is CustomMonster) {
      goalsJson = _serializeGoals(entity.settings.goals) ?? '';
      targetGoalsJson = _serializeGoals(entity.settings.targetGoals) ?? '';
    } else if (entity is CustomAnimal) {
      goalsJson = _serializeGoals(entity.settings.goals) ?? '';
      targetGoalsJson = _serializeGoals(entity.settings.targetGoals) ?? '';
    }

    // Get breeding item for animals
    String breedingItem = '';
    if (entity is CustomAnimal) {
      breedingItem = entity.settings.breedingItem ?? '';
    }

    // Queue the entity registration using the thread-safe queue mechanism.
    // This avoids the "Game version not set" error by deferring actual
    // registration to the Java main thread.
    final handlerId = Bridge.queueEntityRegistration(
      namespace: namespace,
      path: path,
      width: entity.settings.width,
      height: entity.settings.height,
      maxHealth: entity.settings.maxHealth,
      movementSpeed: entity.settings.movementSpeed,
      attackDamage: entity.settings.attackDamage,
      spawnGroup: entity.settings.spawnGroup.index,
      baseType: entity.settings.baseType.index,
      breedingItem: breedingItem,
      modelType: modelType,
      texturePath: texturePath,
      modelScale: modelScale,
      goalsJson: goalsJson,
      targetGoalsJson: targetGoalsJson,
    );

    if (handlerId == 0) {
      throw StateError('Failed to queue entity registration for: ${entity.id}');
    }

    // Store the entity and set its handler ID
    entity.setHandlerId(handlerId);
    _entities[handlerId] = entity;

    // Write manifest after each registration
    _writeManifest();

    print('EntityRegistry: Queued ${entity.id} with handler ID $handlerId');
    return handlerId;
  }

  /// Write the entity manifest to `.redstone/manifest.json`.
  ///
  /// This file is read by the CLI to generate Minecraft resource files.
  static void _writeManifest() {
    final entities = <Map<String, dynamic>>[];

    for (final entity in _entities.values) {
      final entityEntry = <String, dynamic>{
        'id': entity.id,
        'baseType': entity.settings.baseType.name,
      };

      // Only include model if present
      if (entity.settings.model != null) {
        entityEntry['model'] = entity.settings.model!.toJson();
      }

      entities.add(entityEntry);
    }

    // Read existing manifest to preserve blocks and items
    Map<String, dynamic> manifest = {};
    final manifestFile = File('.redstone/manifest.json');
    if (manifestFile.existsSync()) {
      try {
        manifest =
            jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parse errors
      }
    }

    manifest['entities'] = entities;

    // Create .redstone directory if it doesn't exist
    final redstoneDir = Directory('.redstone');
    if (!redstoneDir.existsSync()) {
      redstoneDir.createSync(recursive: true);
    }

    // Write manifest with pretty formatting
    final encoder = JsonEncoder.withIndent('  ');
    manifestFile.writeAsStringSync(encoder.convert(manifest));

    print('EntityRegistry: Wrote manifest with ${entities.length} entities');
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
