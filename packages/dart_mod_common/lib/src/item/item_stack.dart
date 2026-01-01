/// Item stack data type.
library;

import 'item.dart';

/// An item stack (item + count + optional NBT).
///
/// This is a pure data class. For ItemStack with live Minecraft data access,
/// use the server or client specific implementations.
class ItemStack {
  /// The item type.
  final Item item;

  /// The stack count.
  final int count;

  /// Optional NBT data (not fully implemented yet).
  final Map<String, dynamic>? nbt;

  const ItemStack(this.item, [this.count = 1, this.nbt]);

  /// Empty/air stack.
  static const ItemStack empty = ItemStack(Item.air, 0);

  /// Check if this stack is empty (air or count <= 0).
  bool get isEmpty => item == Item.air || count <= 0;

  /// Check if this stack is not empty.
  bool get isNotEmpty => !isEmpty;

  /// Copy with modifications.
  ItemStack copyWith({int? count, Map<String, dynamic>? nbt}) {
    return ItemStack(item, count ?? this.count, nbt ?? this.nbt);
  }

  /// Create stack from item ID.
  factory ItemStack.of(String itemId, [int count = 1]) {
    return ItemStack(Item(itemId), count);
  }

  /// Parse an ItemStack from a serialized string.
  ///
  /// Supports formats:
  /// - "minecraft:item_name:count" (basic format)
  /// - "minecraft:item_name:count:damage:maxDamage" (with durability)
  /// - Empty or null string returns [ItemStack.empty]
  ///
  /// This is the inverse of the Java `ItemStackSerializer.serialize()` method.
  factory ItemStack.parse(String? data) {
    if (data == null || data.isEmpty) {
      return ItemStack.empty;
    }

    final parts = data.split(':');
    if (parts.length < 3) {
      return ItemStack.empty;
    }

    // Format: "namespace:item_name:count" or "namespace:item_name:count:damage:maxDamage"
    final itemId = '${parts[0]}:${parts[1]}';
    final count = int.tryParse(parts[2]) ?? 1;

    return ItemStack(Item(itemId), count);
  }

  @override
  String toString() => isEmpty ? 'ItemStack.empty' : 'ItemStack(${item.id} x$count)';

  @override
  bool operator ==(Object other) =>
      other is ItemStack && other.item == item && other.count == count;

  @override
  int get hashCode => Object.hash(item, count);
}
