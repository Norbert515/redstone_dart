/// Tool material and types for creating custom tools.
library;

/// Material properties for tool items.
///
/// Defines durability, mining speed, damage bonus, enchantability, and repair item
/// for tools. Use the built-in constants for vanilla materials or create custom ones.
class ToolMaterial {
  /// Durability (how many uses before breaking)
  final int durability;

  /// Mining speed multiplier
  final double miningSpeed;

  /// Attack damage bonus (added to base damage)
  final double attackDamageBonus;

  /// Enchantability (higher = better enchantments)
  final int enchantability;

  /// Item used to repair this tool (optional, e.g., 'minecraft:iron_ingot')
  final String? repairItem;

  const ToolMaterial({
    required this.durability,
    required this.miningSpeed,
    required this.attackDamageBonus,
    required this.enchantability,
    this.repairItem,
  });

  // Built-in materials (values from Minecraft's ToolMaterial.java)

  /// Wood tool material: 59 durability, 2.0 speed, +0 damage, 15 enchantability
  static const wood = ToolMaterial(
    durability: 59,
    miningSpeed: 2.0,
    attackDamageBonus: 0.0,
    enchantability: 15,
    repairItem: 'minecraft:oak_planks',
  );

  /// Stone tool material: 131 durability, 4.0 speed, +1 damage, 5 enchantability
  static const stone = ToolMaterial(
    durability: 131,
    miningSpeed: 4.0,
    attackDamageBonus: 1.0,
    enchantability: 5,
    repairItem: 'minecraft:cobblestone',
  );

  /// Copper tool material: 190 durability, 5.0 speed, +1 damage, 13 enchantability
  static const copper = ToolMaterial(
    durability: 190,
    miningSpeed: 5.0,
    attackDamageBonus: 1.0,
    enchantability: 13,
    repairItem: 'minecraft:copper_ingot',
  );

  /// Iron tool material: 250 durability, 6.0 speed, +2 damage, 14 enchantability
  static const iron = ToolMaterial(
    durability: 250,
    miningSpeed: 6.0,
    attackDamageBonus: 2.0,
    enchantability: 14,
    repairItem: 'minecraft:iron_ingot',
  );

  /// Diamond tool material: 1561 durability, 8.0 speed, +3 damage, 10 enchantability
  static const diamond = ToolMaterial(
    durability: 1561,
    miningSpeed: 8.0,
    attackDamageBonus: 3.0,
    enchantability: 10,
    repairItem: 'minecraft:diamond',
  );

  /// Gold tool material: 32 durability, 12.0 speed, +0 damage, 22 enchantability
  static const gold = ToolMaterial(
    durability: 32,
    miningSpeed: 12.0,
    attackDamageBonus: 0.0,
    enchantability: 22,
    repairItem: 'minecraft:gold_ingot',
  );

  /// Netherite tool material: 2031 durability, 9.0 speed, +4 damage, 15 enchantability
  static const netherite = ToolMaterial(
    durability: 2031,
    miningSpeed: 9.0,
    attackDamageBonus: 4.0,
    enchantability: 15,
    repairItem: 'minecraft:netherite_ingot',
  );
}

/// Types of tools.
enum ToolType {
  /// Pickaxe - mines stone and ores efficiently
  pickaxe,

  /// Axe - mines wood efficiently, deals high damage
  axe,

  /// Shovel - mines dirt, sand, gravel efficiently
  shovel,

  /// Hoe - tills farmland
  hoe,

  /// Sword - primary melee weapon
  sword,
}
