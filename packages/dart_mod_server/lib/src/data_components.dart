/// Data component types for Minecraft 1.20.5+ ItemStack components.
library;

/// Represents a type of data component that can be attached to items.
///
/// Minecraft 1.20.5+ uses a component system for item data. Each component
/// has an ID and optional serialization functions for complex types.
class DataComponentType<T> {
  /// The component ID (e.g., 'max_stack_size', 'damage').
  final String id;

  /// Optional function to deserialize from JSON string.
  final T Function(String json)? fromJson;

  /// Optional function to serialize to JSON string.
  final String Function(T value)? toJson;

  const DataComponentType(this.id, {this.fromJson, this.toJson});

  @override
  String toString() => 'DataComponentType($id)';
}

/// Standard Minecraft data components.
///
/// These correspond to the data component types available in Minecraft 1.20.5+.
class DataComponents {
  /// Maximum stack size for the item (default: 64 for most items).
  static const maxStackSize = DataComponentType<int>('max_stack_size');

  /// Current damage value for damageable items (0 = no damage).
  static const damage = DataComponentType<int>('damage');

  /// Maximum damage (durability) before the item breaks.
  static const maxDamage = DataComponentType<int>('max_damage');

  /// Custom display name for the item.
  static const customName = DataComponentType<String>('custom_name');

  /// Lore text lines displayed on the item tooltip.
  static const lore = DataComponentType<List<String>>('lore');

  /// Enchantments applied to the item (enchantment ID -> level).
  static const enchantments = DataComponentType<Map<String, int>>('enchantments');

  /// Whether the item is unbreakable (ignores damage).
  static const unbreakable = DataComponentType<bool>('unbreakable');

  /// Whether the item resists fire/lava damage.
  static const fireResistant = DataComponentType<bool>('damage_resistant');

  DataComponents._();
}
