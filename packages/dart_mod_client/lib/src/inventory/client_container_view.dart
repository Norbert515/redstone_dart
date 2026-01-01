/// Client-side container view implementation.
library;

import 'package:dart_mod_common/dart_mod_common.dart';

/// The Java class name for DartBridgeClient.
const _dartBridgeClient = 'com/redstone/DartBridgeClient';

/// Client-side implementation of ContainerView.
///
/// Queries the current container menu via JNI to the client-side Java bridge.
/// This allows Flutter UI code to access the items in the player's currently
/// open container menu.
///
/// Example usage:
/// ```dart
/// final view = ClientContainerView();
/// if (view.menuId >= 0) {
///   for (var i = 0; i < view.slotCount; i++) {
///     final item = view.getItem(i);
///     if (item.isNotEmpty) {
///       print('Slot $i: ${item.item.id} x${item.count}');
///     }
///   }
/// }
/// ```
class ClientContainerView implements ContainerView {
  /// Create a new client container view.
  ///
  /// This is a lightweight object that queries the container menu on demand.
  const ClientContainerView();

  @override
  int get menuId {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridgeClient,
      'getContainerMenuId',
      '()I',
      [],
    );
  }

  @override
  int get slotCount {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridgeClient,
      'getContainerSlotCount',
      '()I',
      [],
    );
  }

  @override
  ItemStack getItem(int slotIndex) {
    final data = GenericJniBridge.callStaticStringMethod(
      _dartBridgeClient,
      'getContainerSlotItem',
      '(I)Ljava/lang/String;',
      [slotIndex],
    );
    return ItemStack.parse(data);
  }

  /// Check if any container menu is currently open.
  bool get isOpen => menuId >= 0;

  /// Get all items in the container as a list.
  ///
  /// Returns a list of ItemStack objects, with empty stacks for empty slots.
  List<ItemStack> getAllItems() {
    final count = slotCount;
    return List.generate(count, getItem);
  }

  /// Iterate over non-empty slots.
  ///
  /// Returns tuples of (slot index, item stack) for all non-empty slots.
  Iterable<(int slot, ItemStack stack)> get nonEmptySlots sync* {
    final count = slotCount;
    for (var i = 0; i < count; i++) {
      final stack = getItem(i);
      if (stack.isNotEmpty) {
        yield (i, stack);
      }
    }
  }
}
