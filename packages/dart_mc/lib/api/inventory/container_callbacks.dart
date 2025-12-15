/// Container menu callback handlers for Dart-side slot interaction control.
///
/// This file provides handlers for container menu events like slot clicks,
/// quick-move (shift-click), and placement/pickup validation.
library;

import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../../src/bridge.dart';
import 'item_stack.dart';

// =============================================================================
// Click Type Enumeration
// =============================================================================

/// Represents the type of click action in a container menu.
enum ClickType {
  /// Standard left/right click to pickup or place items.
  pickup,

  /// Shift-click to quick-move items.
  quickMove,

  /// Number key press to swap with hotbar.
  swap,

  /// Creative mode clone (middle-click).
  clone,

  /// Q key to throw items.
  throw_,

  /// Crafting-style quick-craft (drag across slots).
  quickCraft,

  /// Double-click to pickup all matching items.
  pickupAll,
}

// =============================================================================
// Dart Callback Handler Types
// =============================================================================

/// Handler for slot click events.
///
/// Parameters:
/// - [menuId]: The unique ID of the container menu.
/// - [slotIndex]: The index of the slot that was clicked.
/// - [button]: The mouse button (0=left, 1=right, 2=middle).
/// - [clickType]: The type of click action.
/// - [carriedItem]: The item currently being carried by the cursor.
///
/// Returns:
/// - -1 to skip default Minecraft handling (Dart handled it fully).
/// - 0 or greater to allow default handling to continue.
typedef ContainerSlotClickHandler = int Function(
    int menuId, int slotIndex, int button, ClickType clickType, ItemStack carriedItem);

/// Handler for quick-move (shift-click) events.
///
/// Parameters:
/// - [menuId]: The unique ID of the container menu.
/// - [slotIndex]: The index of the slot that was shift-clicked.
///
/// Returns:
/// - An [ItemStack] to use as the result (overrides default behavior).
/// - null to use default quick-move behavior.
typedef ContainerQuickMoveHandler = ItemStack? Function(int menuId, int slotIndex);

/// Handler for may-place validation.
///
/// Called when an item is about to be placed in a slot.
///
/// Parameters:
/// - [menuId]: The unique ID of the container menu.
/// - [slotIndex]: The index of the slot.
/// - [item]: The item being placed.
///
/// Returns:
/// - true to allow placement.
/// - false to deny placement.
typedef ContainerMayPlaceHandler = bool Function(int menuId, int slotIndex, ItemStack item);

/// Handler for may-pickup validation.
///
/// Called when an item is about to be picked up from a slot.
///
/// Parameters:
/// - [menuId]: The unique ID of the container menu.
/// - [slotIndex]: The index of the slot.
///
/// Returns:
/// - true to allow pickup.
/// - false to deny pickup.
typedef ContainerMayPickupHandler = bool Function(int menuId, int slotIndex);

// =============================================================================
// Handler Storage
// =============================================================================

ContainerSlotClickHandler? _slotClickHandler;
ContainerQuickMoveHandler? _quickMoveHandler;
ContainerMayPlaceHandler? _mayPlaceHandler;
ContainerMayPickupHandler? _mayPickupHandler;

// =============================================================================
// Native Callback Implementations
// =============================================================================

/// Native callback for slot click events.
@pragma('vm:entry-point')
int _onSlotClick(
    int menuId, int slotIndex, int button, int clickType, Pointer<Utf8> carriedItemPtr) {
  if (_slotClickHandler == null) return 0; // Continue with default

  final carriedItem = carriedItemPtr != nullptr
      ? ItemStack.fromString(carriedItemPtr.toDartString())
      : ItemStack.empty;

  final clickTypeEnum = clickType >= 0 && clickType < ClickType.values.length
      ? ClickType.values[clickType]
      : ClickType.pickup;

  return _slotClickHandler!(menuId, slotIndex, button, clickTypeEnum, carriedItem);
}

/// Native callback for quick-move (shift-click) events.
@pragma('vm:entry-point')
Pointer<Utf8> _onQuickMove(int menuId, int slotIndex) {
  if (_quickMoveHandler == null) return nullptr;

  final result = _quickMoveHandler!(menuId, slotIndex);
  if (result == null || result.isEmpty) return nullptr;

  // Return serialized ItemStack - NOTE: This memory needs to be managed carefully
  // The native side should not free this as it's Dart-allocated
  return result.toJavaString().toNativeUtf8();
}

/// Native callback for may-place validation.
@pragma('vm:entry-point')
bool _onMayPlace(int menuId, int slotIndex, Pointer<Utf8> itemDataPtr) {
  if (_mayPlaceHandler == null) return true; // Allow by default

  final item = itemDataPtr != nullptr
      ? ItemStack.fromString(itemDataPtr.toDartString())
      : ItemStack.empty;

  return _mayPlaceHandler!(menuId, slotIndex, item);
}

/// Native callback for may-pickup validation.
@pragma('vm:entry-point')
bool _onMayPickup(int menuId, int slotIndex) {
  if (_mayPickupHandler == null) return true; // Allow by default
  return _mayPickupHandler!(menuId, slotIndex);
}

// =============================================================================
// Public API
// =============================================================================

/// Initialize container menu callbacks.
///
/// This registers all native callbacks with the C++ bridge.
/// Call this once during mod initialization.
void initContainerMenuCallbacks() {
  Bridge.registerContainerSlotClickHandler(
      Pointer.fromFunction<ContainerSlotClickCallbackNative>(_onSlotClick, 0));
  Bridge.registerContainerQuickMoveHandler(
      Pointer.fromFunction<ContainerQuickMoveCallbackNative>(_onQuickMove));
  Bridge.registerContainerMayPlaceHandler(
      Pointer.fromFunction<ContainerMayPlaceCallbackNative>(_onMayPlace, true));
  Bridge.registerContainerMayPickupHandler(
      Pointer.fromFunction<ContainerMayPickupCallbackNative>(_onMayPickup, true));
}

/// Set a handler for slot click events.
///
/// Example:
/// ```dart
/// setSlotClickHandler((menuId, slotIndex, button, clickType, carriedItem) {
///   print('Clicked slot $slotIndex with $clickType');
///   return 0; // Continue with default handling
/// });
/// ```
void setSlotClickHandler(ContainerSlotClickHandler? handler) {
  _slotClickHandler = handler;
}

/// Set a handler for quick-move (shift-click) events.
///
/// Example:
/// ```dart
/// setQuickMoveHandler((menuId, slotIndex) {
///   // Custom shift-click behavior
///   return null; // Use default behavior
/// });
/// ```
void setQuickMoveHandler(ContainerQuickMoveHandler? handler) {
  _quickMoveHandler = handler;
}

/// Set a handler for may-place validation.
///
/// Example:
/// ```dart
/// setMayPlaceHandler((menuId, slotIndex, item) {
///   // Only allow diamonds in slot 0
///   if (slotIndex == 0) {
///     return item.itemId == 'minecraft:diamond';
///   }
///   return true;
/// });
/// ```
void setMayPlaceHandler(ContainerMayPlaceHandler? handler) {
  _mayPlaceHandler = handler;
}

/// Set a handler for may-pickup validation.
///
/// Example:
/// ```dart
/// setMayPickupHandler((menuId, slotIndex) {
///   // Prevent picking up from output slot
///   return slotIndex != 5;
/// });
/// ```
void setMayPickupHandler(ContainerMayPickupHandler? handler) {
  _mayPickupHandler = handler;
}

// =============================================================================
// Container Item Access Utilities
// =============================================================================

/// Get the item in a container slot.
///
/// Returns [ItemStack.empty] if the slot is empty or if the menu doesn't exist.
ItemStack getContainerItem(int menuId, int slotIndex) {
  final data = Bridge.getContainerItem(menuId, slotIndex);
  return ItemStack.fromString(data);
}

/// Set the item in a container slot.
///
/// Pass [ItemStack.empty] or an item with count <= 0 to clear the slot.
void setContainerItem(int menuId, int slotIndex, ItemStack item) {
  if (item.isEmpty) {
    Bridge.clearContainerSlot(menuId, slotIndex);
  } else {
    Bridge.setContainerItem(menuId, slotIndex, item.itemId, item.count);
  }
}

/// Get the total number of slots in a container menu.
int getContainerSlotCount(int menuId) {
  return Bridge.getContainerSlotCount(menuId);
}

/// Clear a container slot (set to empty/air).
void clearContainerSlot(int menuId, int slotIndex) {
  Bridge.clearContainerSlot(menuId, slotIndex);
}
