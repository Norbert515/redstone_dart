/// Server-side registries for blocks, items, and entities.
library;

import 'dart:convert';

import 'package:dart_mod_common/dart_mod_common.dart';

import 'bridge.dart';

/// Server-side block registry.
class BlockRegistry implements BlockRegistryBase {
  static final BlockRegistry _instance = BlockRegistry._();
  static BlockRegistry get instance => _instance;

  BlockRegistry._();

  final Map<String, CustomBlock> _blocks = {};
  final Map<int, CustomBlock> _blocksByHandler = {};

  @override
  void register(CustomBlock block) {
    if (_blocks.containsKey(block.id)) {
      throw StateError('Block ${block.id} is already registered');
    }

    // Parse namespace:path
    final parts = block.id.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid block ID: ${block.id}. Must be namespace:path');
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

    block.setHandlerId(handlerId);
    _blocks[block.id] = block;
    _blocksByHandler[handlerId] = block;
  }

  @override
  CustomBlock? get(String id) => _blocks[id];

  /// Get a block by its handler ID.
  CustomBlock? getByHandler(int handlerId) => _blocksByHandler[handlerId];

  @override
  bool isRegistered(String id) => _blocks.containsKey(id);

  @override
  Iterable<String> get registeredIds => _blocks.keys;
}

/// Server-side item registry.
class ItemRegistry implements ItemRegistryBase {
  static final ItemRegistry _instance = ItemRegistry._();
  static ItemRegistry get instance => _instance;

  ItemRegistry._();

  final Map<String, CustomItem> _items = {};
  final Map<int, CustomItem> _itemsByHandler = {};

  @override
  void register(CustomItem item) {
    if (_items.containsKey(item.id)) {
      throw StateError('Item ${item.id} is already registered');
    }

    final parts = item.id.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid item ID: ${item.id}. Must be namespace:path');
    }

    final handlerId = ServerBridge.queueItemRegistration(
      namespace: parts[0],
      path: parts[1],
      maxStackSize: item.settings.maxStackSize,
      maxDamage: item.settings.maxDamage,
      fireResistant: item.settings.fireResistant,
      attackDamage: item.combat?.attackDamage ?? 0.0,
      attackSpeed: item.combat?.attackSpeed ?? 0.0,
      attackKnockback: item.combat?.attackKnockback ?? 0.0,
    );

    item.setHandlerId(handlerId);
    _items[item.id] = item;
    _itemsByHandler[handlerId] = item;
  }

  @override
  CustomItem? get(String id) => _items[id];

  /// Get an item by its handler ID.
  CustomItem? getByHandler(int handlerId) => _itemsByHandler[handlerId];

  @override
  bool isRegistered(String id) => _items.containsKey(id);

  @override
  Iterable<String> get registeredIds => _items.keys;
}

/// Server-side entity registry.
class EntityRegistry implements EntityRegistryBase {
  static final EntityRegistry _instance = EntityRegistry._();
  static EntityRegistry get instance => _instance;

  EntityRegistry._();

  final Map<String, CustomEntity> _entities = {};
  final Map<int, CustomEntity> _entitiesByHandler = {};

  @override
  void register(CustomEntity entity) {
    if (_entities.containsKey(entity.id)) {
      throw StateError('Entity ${entity.id} is already registered');
    }

    final parts = entity.id.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid entity ID: ${entity.id}. Must be namespace:path');
    }

    // Serialize entity model
    String? modelType;
    String? texturePath;
    double modelScale = 1.0;

    final model = entity.settings.model;
    if (model != null) {
      final json = model.toJson();
      modelType = json['type'] as String?;
      texturePath = json['texture'] as String?;
      modelScale = (json['scale'] as num?)?.toDouble() ?? 1.0;
    }

    // Serialize goals
    String? goalsJson;
    String? targetGoalsJson;

    if (entity is CustomMonster) {
      if (entity.settings.goals != null) {
        goalsJson = jsonEncode(entity.settings.goals!.map((g) => g.toJson()).toList());
      }
      if (entity.settings.targetGoals != null) {
        targetGoalsJson = jsonEncode(entity.settings.targetGoals!.map((g) => g.toJson()).toList());
      }
    } else if (entity is CustomAnimal) {
      if (entity.settings.goals != null) {
        goalsJson = jsonEncode(entity.settings.goals!.map((g) => g.toJson()).toList());
      }
      if (entity.settings.targetGoals != null) {
        targetGoalsJson = jsonEncode(entity.settings.targetGoals!.map((g) => g.toJson()).toList());
      }
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
      breedingItem: entity is CustomAnimal ? entity.settings.breedingItem : null,
      modelType: modelType,
      texturePath: texturePath,
      modelScale: modelScale,
      goalsJson: goalsJson,
      targetGoalsJson: targetGoalsJson,
    );

    entity.setHandlerId(handlerId);
    _entities[entity.id] = entity;
    _entitiesByHandler[handlerId] = entity;
  }

  @override
  CustomEntity? get(String id) => _entities[id];

  /// Get an entity by its handler ID.
  CustomEntity? getByHandler(int handlerId) => _entitiesByHandler[handlerId];

  @override
  bool isRegistered(String id) => _entities.containsKey(id);

  @override
  Iterable<String> get registeredIds => _entities.keys;
}

/// Signal that all registrations are complete.
void signalRegistrationsQueued() {
  ServerBridge.signalRegistrationsQueued();
}
