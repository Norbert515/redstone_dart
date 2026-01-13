/// JNI access to block entity data from Java.
///
/// Provides methods to read and write block entity inventory slots
/// directly from Java, bypassing the Dart-side inventory cache.
library;

import 'dart:convert';

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:dart_mod_common/src/jni/jni_internal.dart';

/// The Java class name for DartBridge.
const _dartBridge = 'com/redstone/DartBridge';

/// JNI access to block entity data from Java.
///
/// This class provides methods to read and write block entity inventory slots
/// directly from Java's block entity storage.
class BlockEntityJni {
  BlockEntityJni._(); // Private constructor - all static

  /// Get an item from a block entity's inventory at the given world position.
  ///
  /// [dimension] - The dimension ID (e.g., "minecraft:overworld")
  /// [pos] - The block position
  /// [slot] - The slot index
  ///
  /// Returns the ItemStack at the slot, or [ItemStack.empty] if empty or error.
  static ItemStack getSlot(String dimension, BlockPos pos, int slot) {
    final json = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getBlockEntitySlot',
      '(Ljava/lang/String;IIII)Ljava/lang/String;',
      [dimension, pos.x, pos.y, pos.z, slot],
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

  /// Set an item in a block entity's inventory at the given world position.
  ///
  /// [dimension] - The dimension ID (e.g., "minecraft:overworld")
  /// [pos] - The block position
  /// [slot] - The slot index
  /// [item] - The ItemStack to set (use [ItemStack.empty] to clear)
  static void setSlot(String dimension, BlockPos pos, int slot, ItemStack item) {
    final itemId = item.isEmpty ? 'minecraft:air' : item.item.id;
    final count = item.isEmpty ? 0 : item.count;

    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setBlockEntitySlot',
      '(Ljava/lang/String;IIIILjava/lang/String;I)V',
      [dimension, pos.x, pos.y, pos.z, slot, itemId, count],
    );
  }
}
