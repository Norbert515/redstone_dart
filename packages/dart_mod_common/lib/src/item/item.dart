/// Item API for interacting with Minecraft items.
library;

/// Item type (like Block, represents an item type).
class Item {
  /// The Minecraft item identifier (e.g., "minecraft:stone").
  final String id;

  const Item(this.id);

  // ==========================================================================
  // Common Items
  // ==========================================================================

  static const Item air = Item('minecraft:air');
  static const Item stone = Item('minecraft:stone');
  static const Item dirt = Item('minecraft:dirt');
  static const Item grass = Item('minecraft:grass_block');
  static const Item cobblestone = Item('minecraft:cobblestone');
  static const Item oakLog = Item('minecraft:oak_log');
  static const Item oakPlanks = Item('minecraft:oak_planks');

  // ==========================================================================
  // Tools - Swords
  // ==========================================================================

  static const Item woodenSword = Item('minecraft:wooden_sword');
  static const Item stoneSword = Item('minecraft:stone_sword');
  static const Item ironSword = Item('minecraft:iron_sword');
  static const Item goldenSword = Item('minecraft:golden_sword');
  static const Item diamondSword = Item('minecraft:diamond_sword');
  static const Item netheriteSword = Item('minecraft:netherite_sword');

  // ==========================================================================
  // Tools - Pickaxes
  // ==========================================================================

  static const Item woodenPickaxe = Item('minecraft:wooden_pickaxe');
  static const Item stonePickaxe = Item('minecraft:stone_pickaxe');
  static const Item ironPickaxe = Item('minecraft:iron_pickaxe');
  static const Item goldenPickaxe = Item('minecraft:golden_pickaxe');
  static const Item diamondPickaxe = Item('minecraft:diamond_pickaxe');
  static const Item netheritePickaxe = Item('minecraft:netherite_pickaxe');

  // ==========================================================================
  // Common Materials
  // ==========================================================================

  static const Item stick = Item('minecraft:stick');
  static const Item coal = Item('minecraft:coal');
  static const Item ironIngot = Item('minecraft:iron_ingot');
  static const Item goldIngot = Item('minecraft:gold_ingot');
  static const Item diamond = Item('minecraft:diamond');
  static const Item emerald = Item('minecraft:emerald');
  static const Item netheriteIngot = Item('minecraft:netherite_ingot');

  @override
  bool operator ==(Object other) => other is Item && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Item($id)';
}
