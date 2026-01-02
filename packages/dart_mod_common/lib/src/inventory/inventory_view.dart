/// Read-only inventory view interfaces.
///
/// These interfaces define read-only access to inventories and container menus.
/// They are shared between client and server implementations.
library;

import '../item/item_stack.dart';

/// Read-only view of an inventory.
///
/// This interface provides read-only access to inventory contents.
/// Implementations exist for both server-side (PlayerInventory) and
/// client-side (ClientContainerView) use cases.
abstract interface class InventoryView {
  /// Number of slots in this inventory.
  int get size;

  /// Get the item in a specific slot.
  ///
  /// Returns [ItemStack.empty] if the slot is empty or out of bounds.
  ItemStack getSlot(int slot);

  /// Check if a slot is empty.
  bool isEmpty(int slot);

  /// Check if entire inventory is empty.
  bool get isAllEmpty;

  /// Iterate over non-empty slots.
  ///
  /// Returns tuples of (slot index, item stack) for all non-empty slots.
  Iterable<(int slot, ItemStack stack)> get nonEmptySlots;
}

/// Read-only view of a container menu.
///
/// This interface provides read-only access to the currently open container
/// menu. On the client side, this queries the player's current container menu.
/// On the server side, this can be used to query any container.
abstract interface class ContainerView {
  /// The menu/container ID.
  ///
  /// This is the Minecraft container ID assigned when the container was opened.
  /// Returns -1 if no container is open.
  int get menuId;

  /// Total number of slots in this container.
  ///
  /// This includes both the container's own slots and player inventory slots.
  int get slotCount;

  /// Get item at slot index.
  ///
  /// Slot indices follow Minecraft's container slot numbering:
  /// - Container slots come first (0 to container size - 1)
  /// - Player inventory slots follow (typically 27 slots for main inventory)
  /// - Hotbar slots come last (9 slots)
  ///
  /// Returns [ItemStack.empty] if the slot is empty or index is out of bounds.
  ItemStack getItem(int slotIndex);
}
