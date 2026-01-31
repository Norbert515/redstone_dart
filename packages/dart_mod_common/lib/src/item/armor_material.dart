/// Material properties for armor items.
library;

import 'armor_type.dart';

/// Material properties for armor items.
///
/// Defines the durability, protection, enchantability, toughness, and
/// knockback resistance for armor made of this material.
///
/// Example of creating a custom material:
/// ```dart
/// final myMaterial = ArmorMaterial(
///   durability: 20,
///   protection: ArmorMaterial.makeProtection(2, 5, 6, 2),
///   enchantability: 12,
///   toughness: 1.0,
///   repairItem: 'mymod:custom_ingot',
/// );
/// ```
class ArmorMaterial {
  /// Base durability multiplier.
  ///
  /// Total durability is calculated as: baseDurability * slotMultiplier.
  final int durability;

  /// Protection values per armor slot.
  ///
  /// Use [makeProtection] to easily create this map.
  final Map<ArmorType, int> protection;

  /// Enchantability value (higher = better enchantments).
  final int enchantability;

  /// Armor toughness (reduces high damage attacks).
  ///
  /// Diamond has 2.0, netherite has 3.0, most others have 0.0.
  final double toughness;

  /// Knockback resistance (0.0-1.0).
  ///
  /// Netherite has 0.1, most others have 0.0.
  final double knockbackResistance;

  /// Item used to repair this armor in an anvil (optional).
  ///
  /// Use a Minecraft item ID like 'minecraft:diamond' or
  /// a custom item like 'mymod:custom_ingot'.
  final String? repairItem;

  const ArmorMaterial({
    required this.durability,
    required this.protection,
    required this.enchantability,
    this.toughness = 0.0,
    this.knockbackResistance = 0.0,
    this.repairItem,
  });

  /// Helper to create a protection map.
  ///
  /// Order: boots, leggings, chestplate, helmet (matching Minecraft's order).
  static Map<ArmorType, int> makeProtection(
    int boots,
    int leggings,
    int chestplate,
    int helmet, [
    int body = 0,
  ]) {
    return {
      ArmorType.boots: boots,
      ArmorType.leggings: leggings,
      ArmorType.chestplate: chestplate,
      ArmorType.helmet: helmet,
      ArmorType.body: body,
    };
  }

  // ==========================================================================
  // Built-in materials (matching Minecraft 1.21+ ArmorMaterials.java values)
  // ==========================================================================

  /// Leather armor material.
  static final leather = ArmorMaterial(
    durability: 5,
    protection: makeProtection(1, 2, 3, 1, 3),
    enchantability: 15,
    repairItem: 'minecraft:leather',
  );

  /// Chainmail armor material.
  static final chainmail = ArmorMaterial(
    durability: 15,
    protection: makeProtection(1, 4, 5, 2, 4),
    enchantability: 12,
  );

  /// Iron armor material.
  static final iron = ArmorMaterial(
    durability: 15,
    protection: makeProtection(2, 5, 6, 2, 5),
    enchantability: 9,
    repairItem: 'minecraft:iron_ingot',
  );

  /// Gold armor material.
  static final gold = ArmorMaterial(
    durability: 7,
    protection: makeProtection(1, 3, 5, 2, 7),
    enchantability: 25,
    repairItem: 'minecraft:gold_ingot',
  );

  /// Diamond armor material.
  static final diamond = ArmorMaterial(
    durability: 33,
    protection: makeProtection(3, 6, 8, 3, 11),
    enchantability: 10,
    toughness: 2.0,
    repairItem: 'minecraft:diamond',
  );

  /// Netherite armor material.
  static final netherite = ArmorMaterial(
    durability: 37,
    protection: makeProtection(3, 6, 8, 3, 19),
    enchantability: 15,
    toughness: 3.0,
    knockbackResistance: 0.1,
    repairItem: 'minecraft:netherite_ingot',
  );

  /// Turtle scute armor material (for turtle helmet).
  static final turtleScute = ArmorMaterial(
    durability: 25,
    protection: makeProtection(2, 5, 6, 2, 5),
    enchantability: 9,
  );

  /// Copper armor material.
  static final copper = ArmorMaterial(
    durability: 11,
    protection: makeProtection(1, 3, 4, 2, 4),
    enchantability: 8,
    repairItem: 'minecraft:copper_ingot',
  );

  /// Armadillo scute armor material (for wolf armor).
  static final armadilloScute = ArmorMaterial(
    durability: 4,
    protection: makeProtection(3, 6, 8, 3, 11),
    enchantability: 10,
    repairItem: 'minecraft:armadillo_scute',
  );

  /// Get protection value for a specific armor slot.
  int getProtection(ArmorType type) => protection[type] ?? 0;

  /// Get total durability for a specific armor slot.
  int getDurability(ArmorType type) => type.getDurability(durability);
}
