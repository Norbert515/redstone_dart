/// Container menu callback handlers for Dart-side slot interaction control.
///
/// This file provides handlers for container menu events like slot clicks,
/// quick-move (shift-click), and placement/pickup validation.
library;

import 'package:dart_mod_common/dart_mod_common.dart';

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
// Native Callback Entry Points (called from native code via JNI)
// =============================================================================

/// Native callback for slot click events.
/// Called from native code when a container slot is clicked.
@pragma('vm:entry-point')
int onContainerSlotClick(
    int menuId, int slotIndex, int button, int clickType, String carriedItemData) {
  if (_slotClickHandler == null) return 0; // Continue with default

  final carriedItem = parseItemStack(carriedItemData);

  final clickTypeEnum = clickType >= 0 && clickType < ClickType.values.length
      ? ClickType.values[clickType]
      : ClickType.pickup;

  return _slotClickHandler!(menuId, slotIndex, button, clickTypeEnum, carriedItem);
}

/// Native callback for quick-move (shift-click) events.
/// Called from native code when a slot is shift-clicked.
@pragma('vm:entry-point')
String? onContainerQuickMove(int menuId, int slotIndex) {
  if (_quickMoveHandler == null) return null;

  final result = _quickMoveHandler!(menuId, slotIndex);
  if (result == null || result.isEmpty) return null;

  return serializeItemStack(result);
}

/// Native callback for may-place validation.
/// Called from native code before placing an item in a slot.
@pragma('vm:entry-point')
bool onContainerMayPlace(int menuId, int slotIndex, String itemData) {
  if (_mayPlaceHandler == null) return true; // Allow by default

  final item = parseItemStack(itemData);
  return _mayPlaceHandler!(menuId, slotIndex, item);
}

/// Native callback for may-pickup validation.
/// Called from native code before picking up from a slot.
@pragma('vm:entry-point')
bool onContainerMayPickup(int menuId, int slotIndex) {
  if (_mayPickupHandler == null) return true; // Allow by default
  return _mayPickupHandler!(menuId, slotIndex);
}

// =============================================================================
// ItemStack Serialization Helpers
// =============================================================================

/// Parse an ItemStack from a string format.
///
/// Format: "namespace:item:count:damage:maxDamage"
ItemStack parseItemStack(String data) {
  if (data.isEmpty) return ItemStack.empty;

  final parts = data.split(':');
  if (parts.length < 2) return ItemStack.empty;

  final namespace = parts[0];
  final itemName = parts[1];
  final itemId = '$namespace:$itemName';

  if (itemId == 'minecraft:air') return ItemStack.empty;

  int count = 1;
  if (parts.length > 2) {
    count = int.tryParse(parts[2]) ?? 1;
  }

  if (count <= 0) return ItemStack.empty;

  return ItemStack.of(itemId, count);
}

/// Serialize an ItemStack to string format for Java.
String serializeItemStack(ItemStack stack) {
  return '${stack.item.id}:${stack.count}:0:0';
}

// =============================================================================
// Public API
// =============================================================================

/// Initialize container menu callbacks.
///
/// Call this once during mod initialization to set up container callback routing.
void initContainerMenuCallbacks() {
  // Entry points are registered via @pragma('vm:entry-point') annotations.
  // Native code calls these entry points directly via JNI.
  print('ContainerCallbacks: Initialized');
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
///     return item.item.id == 'minecraft:diamond';
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
  final data = GenericJniBridge.callStaticStringMethod(
    'com/redstone/DartBridge',
    'getContainerItem',
    '(II)Ljava/lang/String;',
    [menuId, slotIndex],
  );
  if (data == null) return ItemStack.empty;
  return parseItemStack(data);
}

/// Set the item in a container slot.
///
/// Pass [ItemStack.empty] or an item with count <= 0 to clear the slot.
void setContainerItem(int menuId, int slotIndex, ItemStack item) {
  if (item.isEmpty) {
    clearContainerSlot(menuId, slotIndex);
  } else {
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridge',
      'setContainerItem',
      '(IILjava/lang/String;I)V',
      [menuId, slotIndex, item.item.id, item.count],
    );
  }
}

/// Get the total number of slots in a container menu.
int getContainerSlotCount(int menuId) {
  return GenericJniBridge.callStaticIntMethod(
    'com/redstone/DartBridge',
    'getContainerSlotCount',
    '(I)I',
    [menuId],
  );
}

/// Clear a container slot (set to empty/air).
void clearContainerSlot(int menuId, int slotIndex) {
  GenericJniBridge.callStaticVoidMethod(
    'com/redstone/DartBridge',
    'clearContainerSlot',
    '(II)V',
    [menuId, slotIndex],
  );
}
