/// Loot Table Modification API for customizing Minecraft loot tables.
///
/// This library provides a fluent API for modifying existing loot tables
/// in Minecraft, allowing modders to add custom drops to vanilla and mod
/// loot tables.
///
/// ## Example
///
/// ```dart
/// import 'package:dart_mc/api/api.dart';
///
/// void onModInit() {
///   // Add diamond drops to zombie loot table
///   LootTables.modify('minecraft:entities/zombie', (builder) {
///     builder.addItem(
///       'minecraft:diamond',
///       chance: 0.1,
///       minCount: 1,
///       maxCount: 2,
///     );
///   });
///
///   // Add custom drops with conditions
///   LootTables.modify('minecraft:blocks/grass', (builder) {
///     builder.addItemWithCondition(
///       'mymod:rare_seed',
///       LootCondition.randomChance(0.01),
///       minCount: 1,
///       maxCount: 1,
///     );
///   });
/// }
/// ```
library;

import 'dart:convert';

import '../src/bridge.dart';
import '../src/jni/generic_bridge.dart';

/// A condition that must be met for a loot entry to be included.
class LootCondition {
  /// The type of condition.
  final String type;

  /// Condition parameters.
  final Map<String, dynamic> parameters;

  LootCondition._(this.type, this.parameters);

  /// Random chance condition.
  /// [chance] is a value between 0.0 and 1.0.
  static LootCondition randomChance(double chance) {
    return LootCondition._('random_chance', {'chance': chance});
  }

  /// Random chance with looting bonus.
  /// [chance] is the base chance, [lootingMultiplier] is added per looting level.
  static LootCondition randomChanceWithLooting(
    double chance, {
    double lootingMultiplier = 0.01,
  }) {
    return LootCondition._('random_chance_with_looting', {
      'chance': chance,
      'looting_multiplier': lootingMultiplier,
    });
  }

  /// Condition that passes when killed by a player.
  static LootCondition killedByPlayer() {
    return LootCondition._('killed_by_player', {});
  }

  /// Condition that passes when a specific tool is used.
  /// [toolId] can be an item ID like 'minecraft:diamond_pickaxe'.
  static LootCondition matchTool(String toolId) {
    return LootCondition._('match_tool', {'tool': toolId});
  }

  /// Condition that passes when the tool has a specific enchantment.
  static LootCondition toolEnchantment(String enchantmentId, {int minLevel = 1}) {
    return LootCondition._('tool_enchantment', {
      'enchantment': enchantmentId,
      'min_level': minLevel,
    });
  }

  /// Condition that passes based on weather.
  static LootCondition weather({bool? raining, bool? thundering}) {
    return LootCondition._('weather_check', {
      if (raining != null) 'raining': raining,
      if (thundering != null) 'thundering': thundering,
    });
  }

  /// Condition based on entity properties.
  static LootCondition entityProperties({
    bool? onFire,
    bool? isBaby,
    String? entity,
  }) {
    return LootCondition._('entity_properties', {
      'entity': entity ?? 'this',
      if (onFire != null) 'on_fire': onFire,
      if (isBaby != null) 'is_baby': isBaby,
    });
  }

  /// Inverts another condition (NOT).
  static LootCondition inverted(LootCondition condition) {
    return LootCondition._('inverted', {'term': condition.toJson()});
  }

  /// All conditions must pass (AND).
  static LootCondition allOf(List<LootCondition> conditions) {
    return LootCondition._('all_of', {
      'terms': conditions.map((c) => c.toJson()).toList(),
    });
  }

  /// Any condition can pass (OR).
  static LootCondition anyOf(List<LootCondition> conditions) {
    return LootCondition._('any_of', {
      'terms': conditions.map((c) => c.toJson()).toList(),
    });
  }

  /// Convert to JSON format.
  Map<String, dynamic> toJson() => {
        'type': type,
        ...parameters,
      };
}

/// A function applied to loot.
class LootFunction {
  /// The type of function.
  final String type;

  /// Function parameters.
  final Map<String, dynamic> parameters;

  LootFunction._(this.type, this.parameters);

  /// Set the count of items.
  static LootFunction setCount(int min, int max) {
    return LootFunction._('set_count', {
      'count': {'min': min, 'max': max, 'type': 'uniform'},
    });
  }

  /// Set a fixed count.
  static LootFunction setCountFixed(int count) {
    return LootFunction._('set_count', {'count': count});
  }

  /// Apply looting enchantment bonus.
  static LootFunction lootingEnchant({int min = 0, int max = 1}) {
    return LootFunction._('looting_enchant', {'count': {'min': min, 'max': max}});
  }

  /// Set item damage (for damageable items).
  static LootFunction setDamage(double min, double max) {
    return LootFunction._('set_damage', {
      'damage': {'min': min, 'max': max, 'type': 'uniform'},
    });
  }

  /// Smelt the item (as if put in furnace).
  static LootFunction furnaceSmelt() {
    return LootFunction._('furnace_smelt', {});
  }

  /// Enchant randomly with level range.
  static LootFunction enchantRandomly({List<String>? enchantments}) {
    return LootFunction._('enchant_randomly', {
      if (enchantments != null) 'enchantments': enchantments,
    });
  }

  /// Enchant with specific levels.
  static LootFunction enchantWithLevels(int min, int max, {bool treasure = false}) {
    return LootFunction._('enchant_with_levels', {
      'levels': {'min': min, 'max': max, 'type': 'uniform'},
      'treasure': treasure,
    });
  }

  /// Set NBT data on the item.
  static LootFunction setNbt(String nbtTag) {
    return LootFunction._('set_nbt', {'tag': nbtTag});
  }

  /// Copy NBT from entity.
  static LootFunction copyNbt(String source, List<Map<String, String>> operations) {
    return LootFunction._('copy_nbt', {
      'source': source,
      'ops': operations,
    });
  }

  /// Convert to JSON format.
  Map<String, dynamic> toJson() => {
        'function': type,
        ...parameters,
      };
}

/// A loot entry that represents a single item that can drop.
class LootEntry {
  /// The item ID.
  final String itemId;

  /// The weight for random selection.
  final int weight;

  /// The quality bonus per luck level.
  final int quality;

  /// Conditions for this entry.
  final List<LootCondition> conditions;

  /// Functions to apply to the item.
  final List<LootFunction> functions;

  LootEntry._({
    required this.itemId,
    this.weight = 1,
    this.quality = 0,
    this.conditions = const [],
    this.functions = const [],
  });

  Map<String, dynamic> toJson() => {
        'type': 'item',
        'name': itemId,
        'weight': weight,
        if (quality != 0) 'quality': quality,
        if (conditions.isNotEmpty)
          'conditions': conditions.map((c) => c.toJson()).toList(),
        if (functions.isNotEmpty)
          'functions': functions.map((f) => f.toJson()).toList(),
      };
}

/// A loot pool containing multiple entries.
class LootPool {
  /// The entries in this pool.
  final List<LootEntry> entries;

  /// Number of rolls (items selected from pool).
  final int rolls;

  /// Bonus rolls per luck level.
  final int bonusRolls;

  /// Conditions for this entire pool.
  final List<LootCondition> conditions;

  LootPool._({
    required this.entries,
    this.rolls = 1,
    this.bonusRolls = 0,
    this.conditions = const [],
  });

  Map<String, dynamic> toJson() => {
        'rolls': rolls,
        if (bonusRolls != 0) 'bonus_rolls': bonusRolls,
        'entries': entries.map((e) => e.toJson()).toList(),
        if (conditions.isNotEmpty)
          'conditions': conditions.map((c) => c.toJson()).toList(),
      };
}

/// Builder for constructing loot table modifications.
class LootTableBuilder {
  final List<LootPool> _pools = [];

  LootTableBuilder._();

  /// Add a complete loot pool.
  void addPool(LootPool pool) {
    _pools.add(pool);
  }

  /// Add a simple item drop.
  ///
  /// [itemId] is the item to drop (e.g., 'minecraft:diamond').
  /// [chance] is the probability (0.0 to 1.0) - implemented as a condition.
  /// [minCount] and [maxCount] define the quantity range.
  /// [weight] affects selection when multiple items are in the same pool.
  void addItem(
    String itemId, {
    double chance = 1.0,
    int minCount = 1,
    int maxCount = 1,
    int weight = 1,
  }) {
    final conditions = <LootCondition>[];
    if (chance < 1.0) {
      conditions.add(LootCondition.randomChance(chance));
    }

    final functions = <LootFunction>[];
    if (minCount != maxCount) {
      functions.add(LootFunction.setCount(minCount, maxCount));
    } else if (minCount != 1) {
      functions.add(LootFunction.setCountFixed(minCount));
    }

    final entry = LootEntry._(
      itemId: itemId,
      weight: weight,
      conditions: conditions,
      functions: functions,
    );

    _pools.add(LootPool._(entries: [entry]));
  }

  /// Add an item with specific conditions.
  void addItemWithCondition(
    String itemId,
    LootCondition condition, {
    int minCount = 1,
    int maxCount = 1,
    int weight = 1,
  }) {
    final functions = <LootFunction>[];
    if (minCount != maxCount) {
      functions.add(LootFunction.setCount(minCount, maxCount));
    } else if (minCount != 1) {
      functions.add(LootFunction.setCountFixed(minCount));
    }

    final entry = LootEntry._(
      itemId: itemId,
      weight: weight,
      conditions: [condition],
      functions: functions,
    );

    _pools.add(LootPool._(entries: [entry]));
  }

  /// Add an item with multiple conditions (all must pass).
  void addItemWithConditions(
    String itemId,
    List<LootCondition> conditions, {
    int minCount = 1,
    int maxCount = 1,
    int weight = 1,
  }) {
    final functions = <LootFunction>[];
    if (minCount != maxCount) {
      functions.add(LootFunction.setCount(minCount, maxCount));
    } else if (minCount != 1) {
      functions.add(LootFunction.setCountFixed(minCount));
    }

    final entry = LootEntry._(
      itemId: itemId,
      weight: weight,
      conditions: conditions,
      functions: functions,
    );

    _pools.add(LootPool._(entries: [entry]));
  }

  /// Add an item with functions applied.
  void addItemWithFunctions(
    String itemId,
    List<LootFunction> functions, {
    double chance = 1.0,
    int weight = 1,
    int quality = 0,
  }) {
    final conditions = <LootCondition>[];
    if (chance < 1.0) {
      conditions.add(LootCondition.randomChance(chance));
    }

    final entry = LootEntry._(
      itemId: itemId,
      weight: weight,
      quality: quality,
      conditions: conditions,
      functions: functions,
    );

    _pools.add(LootPool._(entries: [entry]));
  }

  /// Add a pool with multiple weighted items (one is selected per roll).
  void addWeightedPool(
    Map<String, int> itemsWithWeights, {
    int rolls = 1,
    int bonusRolls = 0,
    double chance = 1.0,
  }) {
    final conditions = <LootCondition>[];
    if (chance < 1.0) {
      conditions.add(LootCondition.randomChance(chance));
    }

    final entries = itemsWithWeights.entries
        .map((e) => LootEntry._(itemId: e.key, weight: e.value))
        .toList();

    _pools.add(LootPool._(
      entries: entries,
      rolls: rolls,
      bonusRolls: bonusRolls,
      conditions: conditions,
    ));
  }

  /// Get the JSON representation of all modifications.
  List<Map<String, dynamic>> toJson() =>
      _pools.map((p) => p.toJson()).toList();
}

/// Loot table modification registry.
///
/// Use this class to modify existing Minecraft loot tables.
class LootTables {
  static final Map<String, List<Map<String, dynamic>>> _modifications = {};
  static bool _registered = false;

  LootTables._();

  /// Modify an existing loot table.
  ///
  /// [tableId] is the loot table identifier (e.g., 'minecraft:entities/zombie').
  /// [modifier] is a callback that receives a builder to add modifications.
  static void modify(
    String tableId,
    void Function(LootTableBuilder builder) modifier,
  ) {
    final builder = LootTableBuilder._();
    modifier(builder);

    final pools = builder.toJson();
    if (pools.isEmpty) return;

    _modifications.putIfAbsent(tableId, () => []).addAll(pools);

    // Register with Java if not in datagen mode
    if (!Bridge.isDatagenMode) {
      _ensureRegistered();
      _registerModification(tableId, pools);
    }

    print('LootTables: Added ${pools.length} pool(s) to $tableId');
  }

  /// Ensure the loot table modification system is registered with Java.
  static void _ensureRegistered() {
    if (_registered) return;

    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/proxy/LootTableRegistry',
      'initialize',
      '()V',
    );

    _registered = true;
  }

  /// Register a modification with the Java side.
  static void _registerModification(
    String tableId,
    List<Map<String, dynamic>> pools,
  ) {
    final poolsJson = jsonEncode(pools);

    GenericJniBridge.callStaticBoolMethod(
      'com/redstone/proxy/LootTableRegistry',
      'addModification',
      '(Ljava/lang/String;Ljava/lang/String;)Z',
      [tableId, poolsJson],
    );
  }

  /// Get all modifications for a loot table.
  static List<Map<String, dynamic>>? getModifications(String tableId) =>
      _modifications[tableId];

  /// Get all modified loot table IDs.
  static Iterable<String> get modifiedTables => _modifications.keys;
}
