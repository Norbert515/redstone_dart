/// Block entity with inventory support.
library;

import 'dart:convert';

import '../item/item.dart';
import '../item/item_stack.dart';
import '../jni/generic_bridge.dart';
import 'block_entity_settings.dart';
import 'ticking_block_entity.dart';

/// Callback type for reading inventory slot from Java via JNI.
typedef JniSlotGetter = ItemStack Function(
    String dimension, int x, int y, int z, int slot);

/// Callback type for writing inventory slot to Java via JNI.
typedef JniSlotSetter = void Function(
    String dimension, int x, int y, int z, int slot, ItemStack item);

/// A ticking block entity with an item inventory.
///
/// Provides slot-based item storage with automatic save/load.
///
/// On the server side, inventory access can be routed through JNI to read/write
/// directly from Java's block entity inventory. Call [enableJniInventoryAccess]
/// once on the server to enable this.
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

  /// Whether JNI inventory access is enabled (server-side only).
  static bool _jniEnabled = false;

  /// The dimension ID for JNI calls (set by server).
  static String _defaultDimension = 'minecraft:overworld';

  /// Enable JNI-based inventory access for block entities.
  ///
  /// Call this once on the server side during initialization.
  /// When enabled, [getSlot] and [setSlot] will read/write directly
  /// from Java's block entity inventory instead of the local Dart cache.
  ///
  /// [dimension] - The default dimension ID for JNI calls.
  static void enableJniInventoryAccess({
    String dimension = 'minecraft:overworld',
  }) {
    _jniEnabled = true;
    _defaultDimension = dimension;
  }

  /// Disable JNI-based inventory access (for testing or client-side).
  static void disableJniInventoryAccess() {
    _jniEnabled = false;
  }

  /// Whether JNI inventory access is currently enabled.
  static bool get isJniEnabled => _jniEnabled;

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
  ///
  /// When JNI inventory access is enabled (server-side), this reads directly
  /// from Java's block entity inventory. Otherwise, returns from local cache.
  ItemStack getSlot(int index) {
    if (index < 0 || index >= _inventory.length) return ItemStack.empty;

    // On server with JNI enabled, read from Java
    if (_jniEnabled) {
      final pos = blockPos;
      if (pos != null) {
        return _jniGetSlot(_defaultDimension, pos.x, pos.y, pos.z, index);
      }
    }

    return _inventory[index];
  }

  /// Set the item in a slot.
  ///
  /// Does nothing if the index is out of bounds.
  ///
  /// When JNI inventory access is enabled (server-side), this writes directly
  /// to Java's block entity inventory. Otherwise, writes to local cache.
  void setSlot(int index, ItemStack item) {
    if (index < 0 || index >= _inventory.length) return;

    // On server with JNI enabled, write to Java
    if (_jniEnabled) {
      final pos = blockPos;
      if (pos != null) {
        _jniSetSlot(_defaultDimension, pos.x, pos.y, pos.z, index, item);
        return;
      }
    }

    _inventory[index] = item;
  }

  /// Internal JNI slot getter.
  static ItemStack _jniGetSlot(
      String dimension, int x, int y, int z, int slot) {
    final json = GenericJniBridge.callStaticStringMethod(
      'com/redstone/DartBridge',
      'getBlockEntitySlot',
      '(Ljava/lang/String;IIII)Ljava/lang/String;',
      [dimension, x, y, z, slot],
    );

    if (json == null || json.isEmpty) return ItemStack.empty;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final id = data['id'] as String?;
      final count = data['count'] as int?;
      if (id == null || id == 'minecraft:air' || count == null || count <= 0) {
        return ItemStack.empty;
      }
      return ItemStack(Item(id), count);
    } catch (e) {
      return ItemStack.empty;
    }
  }

  /// Internal JNI slot setter.
  static void _jniSetSlot(
      String dimension, int x, int y, int z, int slot, ItemStack item) {
    final itemId = item.isEmpty ? 'minecraft:air' : item.item.id;
    final count = item.isEmpty ? 0 : item.count;

    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridge',
      'setBlockEntitySlot',
      '(Ljava/lang/String;IIIILjava/lang/String;I)V',
      [dimension, x, y, z, slot, itemId, count],
    );
  }

  /// Clear all slots in the inventory.
  void clearInventory() {
    for (var i = 0; i < _inventory.length; i++) {
      _inventory[i] = ItemStack.empty;
    }
  }

  @override
  Map<String, dynamic> saveAdditional() {
    final base = super.saveAdditional();
    base['inventory'] = _inventory.map((stack) => _serializeStack(stack)).toList();
    return base;
  }

  @override
  void loadAdditional(Map<String, dynamic> nbt) {
    super.loadAdditional(nbt);
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
