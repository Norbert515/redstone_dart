/// Server-side registries for blocks, items, and entities.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_mod_common/dart_mod_common.dart';

import 'bridge.dart';

// =============================================================================
// Block Registry
// =============================================================================

/// Server-side block registry.
///
/// All blocks must be registered during mod initialization (before Minecraft's
/// registry freezes). Attempting to register blocks after initialization will fail.
class BlockRegistry {
  static final BlockRegistry _instance = BlockRegistry._();
  static BlockRegistry get instance => _instance;

  BlockRegistry._();

  final Map<String, CustomBlock> _blocks = {};
  final Map<int, CustomBlock> _blocksByHandler = {};
  bool _frozen = false;

  // ===========================================================================
  // Static API for backward compatibility
  // ===========================================================================

  /// Register a block (static convenience method).
  static void register(CustomBlock block) => _instance._register(block);

  /// Freeze the registry (static convenience method).
  static void freeze() => _instance._freeze();

  /// Get the number of registered blocks (static convenience getter).
  static int get blockCount => _instance._blocks.length;


  void _register(CustomBlock block) {
    if (_frozen) {
      throw StateError(
        'Cannot register blocks after initialization. Block: ${block.id}',
      );
    }

    if (_blocks.containsKey(block.id)) {
      throw StateError('Block ${block.id} is already registered');
    }

    if (block.isRegistered) {
      throw StateError('Block already registered: ${block.id}');
    }

    // Parse namespace:path
    final parts = block.id.split(':');
    if (parts.length != 2) {
      throw ArgumentError(
        'Invalid block ID: ${block.id}. Must be namespace:path',
      );
    }

    final handlerId = ServerBridge.queueBlockRegistration(
      namespace: parts[0],
      path: parts[1],
      hardness: block.settings.hardness,
      resistance: block.settings.resistance,
      requiresTool: block.settings.requiresTool,
      luminance: block.settings.luminance,
      slipperiness: block.settings.slipperiness,
      velocityMultiplier: block.settings.velocityMultiplier,
      jumpVelocityMultiplier: block.settings.jumpVelocityMultiplier,
      ticksRandomly: block.settings.ticksRandomly,
      collidable: block.settings.collidable,
      replaceable: block.settings.replaceable,
      burnable: block.settings.burnable,
    );

    if (handlerId == 0) {
      throw StateError('Failed to queue block registration for: ${block.id}');
    }

    block.setHandlerId(handlerId);
    _blocks[block.id] = block;
    _blocksByHandler[handlerId] = block;

    // Write manifest after each registration
    _writeManifest();

    print('BlockRegistry: Queued ${block.id} with handler ID $handlerId');
  }

  /// Write the block manifest to `.redstone/manifest.json`.
  ///
  /// This file is read by the CLI to generate Minecraft resource files.
  void _writeManifest() {
    final blocks = <Map<String, dynamic>>[];

    for (final block in _blocks.values) {
      final blockEntry = <String, dynamic>{
        'id': block.id,
      };

      // Only include model if present
      if (block.model != null) {
        blockEntry['model'] = block.model!.toJson();
      }

      // Include drops if specified
      if (block.drops != null) {
        blockEntry['drops'] = block.drops;
      }

      blocks.add(blockEntry);
    }

    // Read existing manifest to preserve items and entities
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

    manifest['blocks'] = blocks;

    // Create .redstone directory if it doesn't exist
    final redstoneDir = Directory('.redstone');
    if (!redstoneDir.existsSync()) {
      redstoneDir.createSync(recursive: true);
    }

    // Write manifest with pretty formatting
    final encoder = JsonEncoder.withIndent('  ');
    manifestFile.writeAsStringSync(encoder.convert(manifest));

    print('BlockRegistry: Wrote manifest with ${blocks.length} blocks');
  }

  CustomBlock? getById(String id) => _blocks[id];

  /// Get a block by its handler ID.
  CustomBlock? getByHandler(int handlerId) => _blocksByHandler[handlerId];

  bool isBlockRegistered(String id) => _blocks.containsKey(id);

  Iterable<String> get registeredBlockIds => _blocks.keys;

  /// Get all registered blocks.
  Iterable<CustomBlock> get allBlocks => _blocks.values;

  /// Internal freeze implementation.
  void _freeze() {
    _frozen = true;
    print('BlockRegistry: Frozen with ${_blocks.length} blocks registered');

    // In datagen mode, exit cleanly after registration is complete
    if (ServerBridge.isDatagenMode) {
      print('BlockRegistry: Datagen mode complete, exiting...');
      exit(0);
    }
  }

  /// Check if the registry is frozen.
  bool get isFrozen => _frozen;

  // ===========================================================================
  // Internal dispatch methods - called from native code
  // ===========================================================================

  /// Dispatch a block break event to the appropriate handler.
  /// Called from native code via callback.
  /// Returns true to allow break, false to cancel.
  @pragma('vm:entry-point')
  static bool dispatchBlockBreak(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
  ) {
    final block = _instance._blocksByHandler[handlerId];
    if (block != null) {
      return block.onBreak(worldId, x, y, z, playerId);
    }
    return true; // Default: allow break
  }

  /// Dispatch a block use event to the appropriate handler.
  /// Called from native code via callback.
  /// Returns the ActionResult ordinal.
  @pragma('vm:entry-point')
  static int dispatchBlockUse(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
    int hand,
  ) {
    final block = _instance._blocksByHandler[handlerId];
    if (block != null) {
      final result = block.onUse(worldId, x, y, z, playerId, hand);
      return result.index;
    }
    return ActionResult.pass.index;
  }

  /// Dispatch a stepped on event to the appropriate handler.
  /// Called from native code via callback.
  @pragma('vm:entry-point')
  static void dispatchSteppedOn(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int entityId,
  ) {
    final block = _instance._blocksByHandler[handlerId];
    block?.onSteppedOn(worldId, x, y, z, entityId);
  }

  /// Dispatch a fallen upon event to the appropriate handler.
  /// Called from native code via callback.
  @pragma('vm:entry-point')
  static void dispatchFallenUpon(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int entityId,
    double fallDistance,
  ) {
    final block = _instance._blocksByHandler[handlerId];
    block?.onFallenUpon(worldId, x, y, z, entityId, fallDistance);
  }

  /// Dispatch a random tick event to the appropriate handler.
  /// Called from native code via callback.
  @pragma('vm:entry-point')
  static void dispatchRandomTick(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
  ) {
    final block = _instance._blocksByHandler[handlerId];
    block?.randomTick(worldId, x, y, z);
  }

  /// Dispatch a block placed event to the appropriate handler.
  /// Called from native code via callback.
  @pragma('vm:entry-point')
  static void dispatchPlaced(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
  ) {
    final block = _instance._blocksByHandler[handlerId];
    block?.onPlaced(worldId, x, y, z, playerId);
  }

  /// Dispatch a block removed event to the appropriate handler.
  /// Called from native code via callback.
  @pragma('vm:entry-point')
  static void dispatchRemoved(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
  ) {
    final block = _instance._blocksByHandler[handlerId];
    block?.onRemoved(worldId, x, y, z);
  }

  /// Dispatch a neighbor changed event to the appropriate handler.
  /// Called from native code via callback.
  @pragma('vm:entry-point')
  static void dispatchNeighborChanged(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int neighborX,
    int neighborY,
    int neighborZ,
  ) {
    final block = _instance._blocksByHandler[handlerId];
    block?.neighborChanged(worldId, x, y, z, neighborX, neighborY, neighborZ);
  }

  /// Dispatch an entity inside event to the appropriate handler.
  /// Called from native code via callback.
  @pragma('vm:entry-point')
  static void dispatchEntityInside(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int entityId,
  ) {
    final block = _instance._blocksByHandler[handlerId];
    block?.entityInside(worldId, x, y, z, entityId);
  }
}

// =============================================================================
// Item Registry
// =============================================================================

/// Server-side item registry.
///
/// All items must be registered during mod initialization (before Minecraft's
/// registry freezes). Attempting to register items after initialization will fail.
class ItemRegistry {
  static final ItemRegistry _instance = ItemRegistry._();
  static ItemRegistry get instance => _instance;

  ItemRegistry._();

  final Map<String, CustomItem> _items = {};
  final Map<int, CustomItem> _itemsByHandler = {};
  bool _frozen = false;

  // ===========================================================================
  // Static API for backward compatibility
  // ===========================================================================

  /// Register an item (static convenience method).
  static void register(CustomItem item) => _instance._register(item);

  /// Freeze the registry (static convenience method).
  static void freeze() => _instance._freeze();

  /// Get the number of registered items.
  static int get itemCount => _instance._items.length;

  void _register(CustomItem item) {
    if (_frozen) {
      throw StateError(
        'Cannot register items after initialization. Item: ${item.id}',
      );
    }

    if (_items.containsKey(item.id)) {
      throw StateError('Item ${item.id} is already registered');
    }

    if (item.isRegistered) {
      throw StateError('Item already registered: ${item.id}');
    }

    final parts = item.id.split(':');
    if (parts.length != 2) {
      throw ArgumentError(
        'Invalid item ID: ${item.id}. Must be namespace:path',
      );
    }

    // Extract combat values (use NaN for "not set")
    final combat = item.combat;
    final attackDamage = combat?.attackDamage ?? double.nan;
    final attackSpeed = combat?.attackSpeed ?? double.nan;
    final attackKnockback = combat?.attackKnockback ?? double.nan;

    final handlerId = ServerBridge.queueItemRegistration(
      namespace: parts[0],
      path: parts[1],
      maxStackSize: item.settings.maxStackSize,
      maxDamage: item.settings.maxDamage,
      fireResistant: item.settings.fireResistant,
      attackDamage: attackDamage,
      attackSpeed: attackSpeed,
      attackKnockback: attackKnockback,
    );

    if (handlerId == 0) {
      throw StateError('Failed to queue item registration for: ${item.id}');
    }

    item.setHandlerId(handlerId);
    _items[item.id] = item;
    _itemsByHandler[handlerId] = item;

    // Write manifest after each registration
    _writeManifest();

    print('ItemRegistry: Queued ${item.id} with handler ID $handlerId');
  }

  /// Write the item manifest to `.redstone/manifest.json`.
  ///
  /// This updates the existing manifest (which may contain blocks).
  void _writeManifest() {
    // Read existing manifest or create new
    Map<String, dynamic> manifest = {};
    final manifestFile = File('.redstone/manifest.json');
    if (manifestFile.existsSync()) {
      try {
        manifest =
            jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parse errors, start fresh
      }
    }

    // Build items list
    final items = <Map<String, dynamic>>[];
    for (final item in _items.values) {
      final itemEntry = <String, dynamic>{
        'id': item.id,
        'model': item.model.toJson(),
      };
      items.add(itemEntry);
    }

    manifest['items'] = items;

    // Create .redstone directory if it doesn't exist
    final redstoneDir = Directory('.redstone');
    if (!redstoneDir.existsSync()) {
      redstoneDir.createSync(recursive: true);
    }

    // Write manifest with pretty formatting
    final encoder = JsonEncoder.withIndent('  ');
    manifestFile.writeAsStringSync(encoder.convert(manifest));

    print('ItemRegistry: Wrote manifest with ${items.length} items');
  }

  CustomItem? getById(String id) => _items[id];

  /// Get an item by its handler ID.
  CustomItem? getByHandler(int handlerId) => _itemsByHandler[handlerId];

  bool isItemRegistered(String id) => _items.containsKey(id);

  Iterable<String> get registeredItemIds => _items.keys;

  /// Get all registered items.
  Iterable<CustomItem> get allItems => _items.values;

  /// Freeze the registry (instance method, called internally).
  void _freeze() {
    _frozen = true;
    print('ItemRegistry: Frozen with ${_items.length} items registered');
  }

  /// Check if the registry is frozen.
  bool get isFrozen => _frozen;

  // ===========================================================================
  // Internal dispatch methods - called from native code
  // ===========================================================================

  /// Dispatch an item use event.
  @pragma('vm:entry-point')
  static int dispatchItemUse(int handlerId, int worldId, int playerId, int hand) {
    final item = _instance._itemsByHandler[handlerId];
    if (item != null) {
      final result = item.onUse(worldId, playerId, hand);
      return result.index;
    }
    return ItemActionResult.pass.index;
  }

  /// Dispatch an item use on block event.
  @pragma('vm:entry-point')
  static int dispatchItemUseOnBlock(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
    int hand,
  ) {
    final item = _instance._itemsByHandler[handlerId];
    if (item != null) {
      final result = item.onUseOnBlock(worldId, x, y, z, playerId, hand);
      return result.index;
    }
    return ItemActionResult.pass.index;
  }

  /// Dispatch an item use on entity event.
  @pragma('vm:entry-point')
  static int dispatchItemUseOnEntity(
    int handlerId,
    int worldId,
    int entityId,
    int playerId,
    int hand,
  ) {
    final item = _instance._itemsByHandler[handlerId];
    if (item != null) {
      final result = item.onUseOnEntity(worldId, entityId, playerId, hand);
      return result.index;
    }
    return ItemActionResult.pass.index;
  }

  /// Dispatches an attack entity event to the appropriate item.
  /// Called from native code when a player attacks an entity with a custom item.
  @pragma('vm:entry-point')
  static bool dispatchItemAttackEntity(
    int handlerId,
    int worldId,
    int attackerId,
    int targetId,
  ) {
    final item = _instance._itemsByHandler[handlerId];
    if (item != null) {
      return item.onAttackEntity(worldId, attackerId, targetId);
    }
    return false;
  }
}

// =============================================================================
// Entity Registry
// =============================================================================

/// Server-side entity registry.
///
/// All entities must be registered during mod initialization (before Minecraft's
/// registry freezes). Attempting to register entities after initialization will fail.
class EntityRegistry {
  static final EntityRegistry _instance = EntityRegistry._();
  static EntityRegistry get instance => _instance;

  EntityRegistry._();

  final Map<String, CustomEntity> _entities = {};
  final Map<int, CustomEntity> _entitiesByHandler = {};
  bool _frozen = false;

  /// Serialize a list of goals to JSON string, or null if empty/null.
  static String? _serializeGoals(List<EntityGoal>? goals) {
    if (goals == null || goals.isEmpty) return null;
    return jsonEncode(goals.map((g) => g.toJson()).toList());
  }

  // ===========================================================================
  // Static API for backward compatibility
  // ===========================================================================

  /// Register an entity (static convenience method).
  static void register(CustomEntity entity) => _instance._register(entity);

  /// Freeze the registry (static convenience method).
  static void freeze() => _instance._freeze();

  /// Get the number of registered entities (static convenience getter).
  static int get entityCount => _instance._entities.length;

  void _register(CustomEntity entity) {
    if (_frozen) {
      throw StateError(
        'Cannot register entities after initialization. Entity: ${entity.id}',
      );
    }

    if (_entities.containsKey(entity.id)) {
      throw StateError('Entity ${entity.id} is already registered');
    }

    if (entity.isRegistered) {
      throw StateError('Entity already registered: ${entity.id}');
    }

    final parts = entity.id.split(':');
    if (parts.length != 2) {
      throw ArgumentError(
        'Invalid entity ID: ${entity.id}. Must be namespace:path',
      );
    }

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

    final handlerId = ServerBridge.queueEntityRegistration(
      namespace: parts[0],
      path: parts[1],
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

    entity.setHandlerId(handlerId);
    _entities[entity.id] = entity;
    _entitiesByHandler[handlerId] = entity;

    // Write manifest after each registration
    _writeManifest();

    print('EntityRegistry: Queued ${entity.id} with handler ID $handlerId');
  }

  /// Write the entity manifest to `.redstone/manifest.json`.
  ///
  /// This file is read by the CLI to generate Minecraft resource files.
  void _writeManifest() {
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

  CustomEntity? getById(String id) => _entities[id];

  /// Get an entity by its handler ID.
  CustomEntity? getByHandler(int handlerId) => _entitiesByHandler[handlerId];

  bool isEntityRegistered(String id) => _entities.containsKey(id);

  Iterable<String> get registeredEntityIds => _entities.keys;

  /// Get all registered entities.
  Iterable<CustomEntity> get allEntities => _entities.values;

  /// Freeze the registry (instance method, called internally).
  ///
  /// After this is called, no more entities can be registered.
  void _freeze() {
    _frozen = true;
    print('EntityRegistry: Frozen with ${_entities.length} entities registered');
  }

  /// Check if the registry is frozen.
  bool get isFrozen => _frozen;

  // ===========================================================================
  // Internal dispatch methods - called from native code via events.dart
  // ===========================================================================

  /// Dispatch an entity spawn event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchSpawn(int handlerId, int entityId, int worldId) {
    final entity = _instance._entitiesByHandler[handlerId];
    if (entity != null) {
      entity.onSpawn(entityId, worldId);
    }
  }

  /// Dispatch an entity tick event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchTick(int handlerId, int entityId) {
    final entity = _instance._entitiesByHandler[handlerId];
    if (entity != null) {
      entity.onTick(entityId);
    }
  }

  /// Dispatch an entity death event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchDeath(int handlerId, int entityId, String damageSource) {
    final entity = _instance._entitiesByHandler[handlerId];
    if (entity != null) {
      entity.onDeath(entityId, damageSource);
    }
  }

  /// Dispatch an entity damage event to the appropriate handler.
  /// Returns true to allow damage, false to cancel.
  @pragma('vm:entry-point')
  static bool dispatchDamage(
    int handlerId,
    int entityId,
    String damageSource,
    double amount,
  ) {
    final entity = _instance._entitiesByHandler[handlerId];
    if (entity != null) {
      return entity.onDamage(entityId, damageSource, amount);
    }
    return true; // Default: allow damage
  }

  /// Dispatch an entity attack event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchAttack(int handlerId, int entityId, int targetId) {
    final entity = _instance._entitiesByHandler[handlerId];
    if (entity != null) {
      entity.onAttack(entityId, targetId);
    }
  }

  /// Dispatch a target acquired event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchTargetAcquired(int handlerId, int entityId, int targetId) {
    final entity = _instance._entitiesByHandler[handlerId];
    if (entity != null) {
      entity.onTargetAcquired(entityId, targetId);
    }
  }

  // ===========================================================================
  // Projectile dispatch methods - called from native code via events.dart
  // ===========================================================================

  /// Dispatch a projectile hit entity event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchProjectileHitEntity(
    int handlerId,
    int projectileId,
    int targetId,
  ) {
    final entity = _instance._entitiesByHandler[handlerId];
    if (entity is CustomProjectile) {
      entity.onHitEntity(projectileId, targetId);
    }
  }

  /// Dispatch a projectile hit block event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchProjectileHitBlock(
    int handlerId,
    int projectileId,
    int x,
    int y,
    int z,
    String side,
  ) {
    final entity = _instance._entitiesByHandler[handlerId];
    if (entity is CustomProjectile) {
      entity.onHitBlock(projectileId, x, y, z, side);
    }
  }

  // ===========================================================================
  // Animal dispatch methods - called from native code via events.dart
  // ===========================================================================

  /// Dispatch an animal breed event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchAnimalBreed(
    int handlerId,
    int entityId,
    int partnerId,
    int babyId,
  ) {
    final entity = _instance._entitiesByHandler[handlerId];
    if (entity is CustomAnimal) {
      entity.onBreed(entityId, partnerId, babyId);
    }
  }
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Signal that all registrations are complete.
void signalRegistrationsQueued() {
  ServerBridge.signalRegistrationsQueued();
}
