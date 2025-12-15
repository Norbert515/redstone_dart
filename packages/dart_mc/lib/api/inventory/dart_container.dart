/// Base class for defining container behavior in Dart.
///
/// Extend this class to customize slot behavior, item placement rules,
/// and quick-move logic for your containers.
///
/// Example:
/// ```dart
/// class MyChestContainer extends DartContainer {
///   MyChestContainer(super.menuId);
///
///   @override
///   bool mayPlaceInSlot(int slotIndex, ItemStack item) {
///     // Only allow diamonds in slot 0
///     if (slotIndex == 0) return item.itemId == 'minecraft:diamond';
///     return true;
///   }
/// }
/// ```
library;

import '../../src/bridge.dart';
import 'item_stack.dart';
import 'container_callbacks.dart';

/// Base class for defining container behavior in Dart.
///
/// Extend this class to customize slot behavior, item placement rules,
/// and quick-move logic for your containers.
abstract class DartContainer {
  /// The unique menu ID for this container instance.
  final int menuId;

  /// Container instances by menu ID.
  static final Map<int, DartContainer> _containers = {};

  /// Creates a new container for the given menu ID.
  ///
  /// Automatically registers this container instance in the global registry.
  DartContainer(this.menuId) {
    _containers[menuId] = this;
  }

  /// Get a container instance by menu ID.
  ///
  /// Returns null if no container exists for the given menu ID.
  static DartContainer? getContainer(int menuId) => _containers[menuId];

  /// Remove a container from the registry.
  ///
  /// Called when the menu closes.
  static void removeContainer(int menuId) {
    _containers.remove(menuId);
  }

  // ============ Item Access ============

  /// Get the item in a slot.
  ///
  /// Returns [ItemStack.empty] if the slot is empty.
  ItemStack getItem(int slotIndex) {
    final data = Bridge.getContainerItem(menuId, slotIndex);
    return ItemStack.fromString(data);
  }

  /// Set the item in a slot.
  void setItem(int slotIndex, ItemStack item) {
    Bridge.setContainerItem(menuId, slotIndex, item.itemId, item.count);
  }

  /// Clear a slot (set to empty/air).
  void clearSlot(int slotIndex) {
    Bridge.clearContainerSlot(menuId, slotIndex);
  }

  /// Get total number of slots in this container.
  int get slotCount => Bridge.getContainerSlotCount(menuId);

  // ============ Overridable Callbacks ============

  /// Called when a slot is clicked.
  ///
  /// Return values:
  /// - `-1`: Skip default click handling (Dart handled it)
  /// - `0`: Continue with default click handling
  ///
  /// [slotIndex] The clicked slot index (-999 for outside click)
  /// [button] Mouse button (0=left, 1=right, 2=middle)
  /// [clickType] Type of click action
  /// [carriedItem] Item currently held by cursor
  int onSlotClick(
      int slotIndex, int button, ClickType clickType, ItemStack carriedItem) {
    return 0; // Default: continue with normal handling
  }

  /// Called to determine if an item can be placed in a slot.
  ///
  /// Override to restrict what items can go in specific slots.
  ///
  /// [slotIndex] The slot being checked
  /// [item] The item attempting to be placed
  /// Returns true if the item can be placed, false otherwise
  bool mayPlaceInSlot(int slotIndex, ItemStack item) {
    return true; // Default: allow all items
  }

  /// Called to determine if an item can be picked up from a slot.
  ///
  /// Override to prevent removal of items from specific slots.
  ///
  /// [slotIndex] The slot being checked
  /// Returns true if the item can be picked up, false otherwise
  bool mayPickupFromSlot(int slotIndex) {
    return true; // Default: allow pickup
  }

  /// Called when shift-clicking an item.
  ///
  /// Override to customize quick-move behavior.
  ///
  /// [slotIndex] The slot being shift-clicked
  /// Returns the resulting ItemStack, or null to use default behavior
  ItemStack? onQuickMove(int slotIndex) {
    return null; // Default: use Java's default quick-move
  }

  /// Called when the container is opened.
  ///
  /// Override to perform initialization when the container is first opened.
  void onOpen() {}

  /// Called when the container is closed.
  ///
  /// Default implementation removes this container from the registry.
  /// Override to add cleanup logic, but remember to call super.onClose()
  /// or [removeContainer] to clean up properly.
  void onClose() {
    removeContainer(menuId);
  }
}
