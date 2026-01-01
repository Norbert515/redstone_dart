/// Block entity with inventory support.
library;

import '../item/item_stack.dart';
import 'block_entity_settings.dart';
import 'ticking_block_entity.dart';

/// A ticking block entity with an item inventory.
///
/// Provides slot-based item storage with automatic save/load.
///
/// ## Example
///
/// ```dart
/// class MyChestEntity extends BlockEntityWithInventory {
///   MyChestEntity() : super(
///     settings: BlockEntitySettings(id: 'mymod:chest'),
///     slotCount: 27, // 3 rows of 9
///   );
/// }
/// ```
abstract class BlockEntityWithInventory extends TickingBlockEntity {
  late final List<ItemStack> _inventory;

  /// Creates a block entity with the specified number of inventory slots.
  ///
  /// If [slotCount] is not provided, it will be derived from [ProcessingSettings.slots.totalSlots]
  /// if the settings is a [ProcessingSettings], otherwise defaults to 0.
  BlockEntityWithInventory({
    required super.settings,
    int? slotCount,
  }) {
    final count = slotCount ?? _deriveSlotCount();
    _inventory = List.filled(count, ItemStack.empty);
  }

  int _deriveSlotCount() {
    if (settings is ProcessingSettings) {
      return (settings as ProcessingSettings).slots.totalSlots;
    }
    return 0;
  }

  /// The number of slots in this inventory.
  int get slotCount => _inventory.length;

  /// Get the item in a slot.
  ///
  /// Returns [ItemStack.empty] if the slot is empty or index is out of bounds.
  ItemStack getSlot(int index) {
    if (index < 0 || index >= _inventory.length) return ItemStack.empty;
    return _inventory[index];
  }

  /// Set the item in a slot.
  ///
  /// Does nothing if the index is out of bounds.
  void setSlot(int index, ItemStack item) {
    if (index < 0 || index >= _inventory.length) return;
    _inventory[index] = item;
  }

  /// Clear all slots in the inventory.
  void clearInventory() {
    for (var i = 0; i < _inventory.length; i++) {
      _inventory[i] = ItemStack.empty;
    }
  }

  @override
  Map<String, dynamic> onSave() {
    final base = super.onSave();
    base['inventory'] = _inventory.map((stack) => _serializeStack(stack)).toList();
    return base;
  }

  @override
  void onLoad(Map<String, dynamic> nbt) {
    super.onLoad(nbt);
    final inv = nbt['inventory'] as List?;
    if (inv != null) {
      for (var i = 0; i < inv.length && i < _inventory.length; i++) {
        _inventory[i] = _deserializeStack(inv[i]);
      }
    }
  }

  /// Serialize an ItemStack to a map for NBT storage.
  Map<String, dynamic> _serializeStack(ItemStack stack) {
    if (stack.isEmpty) {
      return {'id': 'minecraft:air', 'count': 0};
    }
    return {
      'id': stack.item.id,
      'count': stack.count,
    };
  }

  /// Deserialize an ItemStack from a map.
  ItemStack _deserializeStack(dynamic data) {
    if (data is! Map<String, dynamic>) return ItemStack.empty;
    final id = data['id'] as String?;
    final count = data['count'] as int?;
    if (id == null || id == 'minecraft:air' || count == null || count <= 0) {
      return ItemStack.empty;
    }
    return ItemStack.of(id, count);
  }
}
