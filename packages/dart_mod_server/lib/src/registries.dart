/// Server-side registries for blocks, items, and entities.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_mod_common/dart_mod_common.dart';

import 'bridge.dart';

// =============================================================================
// Abstract Registry Base Class
// =============================================================================

/// Abstract base class for all registries.
///
/// Provides common registration logic, manifest writing, and lookup functionality.
/// Subclasses must implement the type-specific registration queue method and
/// manifest entry conversion.
abstract class Registry<T extends Registrable> {
  final Map<String, T> _byId = {};
  final Map<int, T> _byHandler = {};
  bool _frozen = false;

  /// The key used in the manifest file (e.g., 'blocks', 'items', 'entities').
  String get manifestKey;

  /// The type name for error messages (e.g., 'block', 'item', 'entity').
  String get typeName;

  /// Queue the registration with the native bridge and return the handler ID.
  /// Returns 0 on failure.
  int queueRegistration(T item);

  /// Convert an item to its manifest entry representation.
  Map<String, dynamic> toManifestEntry(T item);

  /// Register an item.
  void registerItem(T item) {
    if (_frozen) {
      throw StateError(
        'Cannot register ${typeName}s after initialization. ${_capitalize(typeName)}: ${item.id}',
      );
    }

    if (_byId.containsKey(item.id)) {
      throw StateError('${_capitalize(typeName)} ${item.id} is already registered');
    }

    if (item.isRegistered) {
      throw StateError('${_capitalize(typeName)} already registered: ${item.id}');
    }

    // Parse namespace:path
    final parts = item.id.split(':');
    if (parts.length != 2) {
      throw ArgumentError(
        'Invalid $typeName ID: ${item.id}. Must be namespace:path',
      );
    }

    final handlerId = queueRegistration(item);

    if (handlerId == 0) {
      throw StateError('Failed to queue $typeName registration for: ${item.id}');
    }

    item.setHandlerId(handlerId);
    _byId[item.id] = item;
    _byHandler[handlerId] = item;

    // Write manifest after each registration
    _writeManifest();

    print('${_capitalize(typeName)}Registry: Queued ${item.id} with handler ID $handlerId');
  }

  /// Write the manifest to `.redstone/manifest.json`.
  void _writeManifest() {
    final entries = <Map<String, dynamic>>[];

    for (final item in _byId.values) {
      entries.add(toManifestEntry(item));
    }

    // Read existing manifest to preserve other registry entries
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

    manifest[manifestKey] = entries;

    // Create .redstone directory if it doesn't exist
    final redstoneDir = Directory('.redstone');
    if (!redstoneDir.existsSync()) {
      redstoneDir.createSync(recursive: true);
    }

    // Write manifest with pretty formatting
    final encoder = JsonEncoder.withIndent('  ');
    manifestFile.writeAsStringSync(encoder.convert(manifest));

    print('${_capitalize(typeName)}Registry: Wrote manifest with ${entries.length} ${typeName}s');
  }

  /// Get an item by its ID.
  T? getById(String id) => _byId[id];

  /// Get an item by its handler ID.
  T? getByHandler(int handlerId) => _byHandler[handlerId];

  /// Check if an item is registered.
  bool isRegistered(String id) => _byId.containsKey(id);

  /// Get all registered IDs.
  Iterable<String> get registeredIds => _byId.keys;

  /// Get all registered items.
  Iterable<T> get all => _byId.values;

  /// Get the count of registered items.
  int get count => _byId.length;

  /// Check if the registry is frozen.
  bool get isFrozen => _frozen;

  /// Freeze the registry (internal implementation).
  void _freeze() {
    _frozen = true;
    print('${_capitalize(typeName)}Registry: Frozen with ${_byId.length} ${typeName}s registered');
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// =============================================================================
// Block Registry
// =============================================================================

/// Server-side block registry.
///
/// All blocks must be registered during mod initialization (before Minecraft's
/// registry freezes). Attempting to register blocks after initialization will fail.
class BlockRegistry extends Registry<CustomBlock> {
  static final BlockRegistry _instance = BlockRegistry._();
  static BlockRegistry get instance => _instance;

  BlockRegistry._();

  @override
  String get manifestKey => 'blocks';

  @override
  String get typeName => 'block';

  // ===========================================================================
  // Static API for backward compatibility
  // ===========================================================================

  /// Register a block (static convenience method).
  static void register(CustomBlock block) => _instance.registerItem(block);

  /// Freeze the registry (static convenience method).
  static void freeze() => _instance._freezeWithDatagenCheck();

  /// Get the number of registered blocks (static convenience getter).
  static int get blockCount => _instance.count;

  @override
  int queueRegistration(CustomBlock block) {
    final parts = block.id.split(':');
    return ServerBridge.queueBlockRegistration(
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
  }

  @override
  Map<String, dynamic> toManifestEntry(CustomBlock block) {
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

    return blockEntry;
  }

  /// Get all registered blocks.
  Iterable<CustomBlock> get allBlocks => all;

  /// Check if a block is registered.
  bool isBlockRegistered(String id) => isRegistered(id);

  /// Get all registered block IDs.
  Iterable<String> get registeredBlockIds => registeredIds;

  /// Internal freeze implementation with datagen mode check.
  void _freezeWithDatagenCheck() {
    _freeze();

    // In datagen mode, exit cleanly after registration is complete
    if (ServerBridge.isDatagenMode) {
      print('BlockRegistry: Datagen mode complete, exiting...');
      exit(0);
    }
  }

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
    final block = _instance.getByHandler(handlerId);
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
    final block = _instance.getByHandler(handlerId);
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
    final block = _instance.getByHandler(handlerId);
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
    final block = _instance.getByHandler(handlerId);
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
    final block = _instance.getByHandler(handlerId);
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
    final block = _instance.getByHandler(handlerId);
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
    final block = _instance.getByHandler(handlerId);
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
    final block = _instance.getByHandler(handlerId);
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
    final block = _instance.getByHandler(handlerId);
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
class ItemRegistry extends Registry<CustomItem> {
  static final ItemRegistry _instance = ItemRegistry._();
  static ItemRegistry get instance => _instance;

  ItemRegistry._();

  @override
  String get manifestKey => 'items';

  @override
  String get typeName => 'item';

  // ===========================================================================
  // Static API for backward compatibility
  // ===========================================================================

  /// Register an item (static convenience method).
  static void register(CustomItem item) => _instance.registerItem(item);

  /// Freeze the registry (static convenience method).
  static void freeze() => _instance._freeze();

  /// Get the number of registered items.
  static int get itemCount => _instance.count;

  @override
  int queueRegistration(CustomItem item) {
    final parts = item.id.split(':');

    // Extract combat values (use NaN for "not set")
    final combat = item.combat;
    final attackDamage = combat?.attackDamage ?? double.nan;
    final attackSpeed = combat?.attackSpeed ?? double.nan;
    final attackKnockback = combat?.attackKnockback ?? double.nan;

    return ServerBridge.queueItemRegistration(
      namespace: parts[0],
      path: parts[1],
      maxStackSize: item.settings.maxStackSize,
      maxDamage: item.settings.maxDamage,
      fireResistant: item.settings.fireResistant,
      attackDamage: attackDamage,
      attackSpeed: attackSpeed,
      attackKnockback: attackKnockback,
    );
  }

  @override
  Map<String, dynamic> toManifestEntry(CustomItem item) {
    return <String, dynamic>{
      'id': item.id,
      'model': item.model.toJson(),
    };
  }

  /// Get all registered items.
  Iterable<CustomItem> get allItems => all;

  /// Check if an item is registered.
  bool isItemRegistered(String id) => isRegistered(id);

  /// Get all registered item IDs.
  Iterable<String> get registeredItemIds => registeredIds;

  // ===========================================================================
  // Internal dispatch methods - called from native code
  // ===========================================================================

  /// Dispatch an item use event.
  @pragma('vm:entry-point')
  static int dispatchItemUse(int handlerId, int worldId, int playerId, int hand) {
    final item = _instance.getByHandler(handlerId);
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
    final item = _instance.getByHandler(handlerId);
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
    final item = _instance.getByHandler(handlerId);
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
    final item = _instance.getByHandler(handlerId);
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
class EntityRegistry extends Registry<CustomEntity> {
  static final EntityRegistry _instance = EntityRegistry._();
  static EntityRegistry get instance => _instance;

  EntityRegistry._();

  @override
  String get manifestKey => 'entities';

  @override
  String get typeName => 'entity';

  /// Serialize a list of goals to JSON string, or null if empty/null.
  static String? _serializeGoals(List<EntityGoal>? goals) {
    if (goals == null || goals.isEmpty) return null;
    return jsonEncode(goals.map((g) => g.toJson()).toList());
  }

  // ===========================================================================
  // Static API for backward compatibility
  // ===========================================================================

  /// Register an entity (static convenience method).
  static void register(CustomEntity entity) => _instance.registerItem(entity);

  /// Freeze the registry (static convenience method).
  static void freeze() => _instance._freeze();

  /// Get the number of registered entities (static convenience getter).
  static int get entityCount => _instance.count;

  @override
  int queueRegistration(CustomEntity entity) {
    final parts = entity.id.split(':');

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

    return ServerBridge.queueEntityRegistration(
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
  }

  @override
  Map<String, dynamic> toManifestEntry(CustomEntity entity) {
    final entityEntry = <String, dynamic>{
      'id': entity.id,
      'baseType': entity.settings.baseType.name,
    };

    // Only include model if present
    if (entity.settings.model != null) {
      entityEntry['model'] = entity.settings.model!.toJson();
    }

    return entityEntry;
  }

  /// Get all registered entities.
  Iterable<CustomEntity> get allEntities => all;

  /// Check if an entity is registered.
  bool isEntityRegistered(String id) => isRegistered(id);

  /// Get all registered entity IDs.
  Iterable<String> get registeredEntityIds => registeredIds;

  // ===========================================================================
  // Internal dispatch methods - called from native code via events.dart
  // ===========================================================================

  /// Dispatch an entity spawn event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchSpawn(int handlerId, int entityId, int worldId) {
    final entity = _instance.getByHandler(handlerId);
    if (entity != null) {
      entity.onSpawn(entityId, worldId);
    }
  }

  /// Dispatch an entity tick event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchTick(int handlerId, int entityId) {
    final entity = _instance.getByHandler(handlerId);
    if (entity != null) {
      entity.onTick(entityId);
    }
  }

  /// Dispatch an entity death event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchDeath(int handlerId, int entityId, String damageSource) {
    final entity = _instance.getByHandler(handlerId);
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
    final entity = _instance.getByHandler(handlerId);
    if (entity != null) {
      return entity.onDamage(entityId, damageSource, amount);
    }
    return true; // Default: allow damage
  }

  /// Dispatch an entity attack event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchAttack(int handlerId, int entityId, int targetId) {
    final entity = _instance.getByHandler(handlerId);
    if (entity != null) {
      entity.onAttack(entityId, targetId);
    }
  }

  /// Dispatch a target acquired event to the appropriate handler.
  @pragma('vm:entry-point')
  static void dispatchTargetAcquired(int handlerId, int entityId, int targetId) {
    final entity = _instance.getByHandler(handlerId);
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
    final entity = _instance.getByHandler(handlerId);
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
    final entity = _instance.getByHandler(handlerId);
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
    final entity = _instance.getByHandler(handlerId);
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
