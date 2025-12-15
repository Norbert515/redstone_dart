/// Represents a Minecraft ItemStack in Dart for container screens.
///
/// This is a simplified representation of an ItemStack used for
/// container screen slot contents, parsed from Java string format.
library;

/// Represents a Minecraft ItemStack in Dart.
///
/// This class provides a simple representation of items passed from Java,
/// with support for damage values and custom names.
class ItemStack {
  /// The Minecraft item identifier (e.g., "minecraft:diamond").
  final String itemId;

  /// The number of items in the stack.
  final int count;

  /// Current damage value (0 for undamageable items).
  final int damage;

  /// Maximum damage before the item breaks (0 for undamageable items).
  final int maxDamage;

  /// Optional custom name for the item.
  final String? customName;

  const ItemStack({
    required this.itemId,
    this.count = 1,
    this.damage = 0,
    this.maxDamage = 0,
    this.customName,
  });

  /// Empty/air item.
  static const ItemStack empty = ItemStack(itemId: 'minecraft:air', count: 0);

  /// Check if this stack is empty (air or count <= 0).
  bool get isEmpty => itemId == 'minecraft:air' || count <= 0;

  /// Check if this stack is not empty.
  bool get isNotEmpty => !isEmpty;

  /// Check if this item can be damaged (tools, armor, etc.).
  bool get isDamageable => maxDamage > 0;

  /// Check if this item is broken (damage >= maxDamage).
  bool get isBroken => isDamageable && damage >= maxDamage;

  /// Get durability as a percentage (1.0 = full, 0.0 = broken).
  double get durabilityPercent {
    if (maxDamage <= 0) return 1.0;
    return 1.0 - (damage / maxDamage);
  }

  /// Get the remaining durability (maxDamage - damage).
  int get remainingDurability => isDamageable ? maxDamage - damage : 0;

  /// Parse from Java string format.
  ///
  /// Supports these formats:
  /// - "minecraft:item" - Just item ID (count=1, no damage)
  /// - "minecraft:item:count" - Item ID and count
  /// - "minecraft:item:count:damage:maxDamage" - Full format with damage
  /// - "minecraft:item:count:damage:maxDamage:customName" - Full format with name
  ///
  /// The item ID includes the namespace (e.g., "minecraft:diamond").
  factory ItemStack.fromString(String data) {
    if (data.isEmpty) return ItemStack.empty;

    final parts = data.split(':');

    // Need at least namespace:item_name (2 parts)
    if (parts.length < 2) return ItemStack.empty;

    // Extract namespace and item name
    final namespace = parts[0];
    final itemName = parts[1];
    final itemId = '$namespace:$itemName';

    // Check for air
    if (itemId == 'minecraft:air') return ItemStack.empty;

    // Parse optional fields
    int count = 1;
    int damage = 0;
    int maxDamage = 0;
    String? customName;

    // Parts after item ID: count, damage, maxDamage, customName
    if (parts.length > 2) {
      count = int.tryParse(parts[2]) ?? 1;
    }
    if (parts.length > 3) {
      damage = int.tryParse(parts[3]) ?? 0;
    }
    if (parts.length > 4) {
      maxDamage = int.tryParse(parts[4]) ?? 0;
    }
    if (parts.length > 5) {
      // Custom name might contain colons, so join remaining parts
      customName = parts.sublist(5).join(':');
      if (customName.isEmpty) customName = null;
    }

    if (count <= 0) return ItemStack.empty;

    return ItemStack(
      itemId: itemId,
      count: count,
      damage: damage,
      maxDamage: maxDamage,
      customName: customName,
    );
  }

  /// Convert to simple string format for Java.
  ///
  /// Format: "itemId:count:damage:maxDamage"
  String toJavaString() => '$itemId:$count:$damage:$maxDamage';

  /// Check if this is the same item type (ignoring count/damage).
  bool isSameItem(ItemStack other) => itemId == other.itemId;

  /// Check if items can stack together (same type, not at max stack).
  bool canStackWith(ItemStack other) =>
      isSameItem(other) && customName == other.customName;

  /// Create a copy with different count.
  ItemStack withCount(int newCount) => ItemStack(
        itemId: itemId,
        count: newCount,
        damage: damage,
        maxDamage: maxDamage,
        customName: customName,
      );

  /// Create a copy with different damage.
  ItemStack withDamage(int newDamage) => ItemStack(
        itemId: itemId,
        count: count,
        damage: newDamage,
        maxDamage: maxDamage,
        customName: customName,
      );

  /// Create a copy with a custom name.
  ItemStack withCustomName(String? name) => ItemStack(
        itemId: itemId,
        count: count,
        damage: damage,
        maxDamage: maxDamage,
        customName: name,
      );

  /// Get the display name (custom name or item ID).
  String get displayName => customName ?? itemId.split(':').last;

  @override
  String toString() =>
      isEmpty ? 'ItemStack.empty' : 'ItemStack($itemId x$count)';

  @override
  bool operator ==(Object other) =>
      other is ItemStack &&
      itemId == other.itemId &&
      count == other.count &&
      damage == other.damage;

  @override
  int get hashCode => Object.hash(itemId, count, damage);
}
