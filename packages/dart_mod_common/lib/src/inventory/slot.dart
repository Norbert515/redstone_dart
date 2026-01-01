/// Represents a slot in a container for container screens.
library;

/// Types of slots in a container.
enum SlotType {
  /// Container's own slots (chest slots, furnace slots, etc.).
  container,

  /// Player main inventory slots (slots 9-35).
  playerInventory,

  /// Player hotbar slots (slots 0-8).
  playerHotbar,

  /// Armor slots (helmet, chestplate, leggings, boots).
  armor,

  /// Offhand slot.
  offhand,

  /// Crafting result slot.
  craftingResult,

  /// Crafting input slots.
  craftingInput,

  /// Fuel slot (furnace).
  fuel,

  /// Input slot (furnace, brewing stand).
  input,

  /// Output slot (furnace, brewing stand).
  output,
}

/// Represents a slot in a container.
///
/// Slots are UI elements that can hold items in container screens.
/// Each slot has a position, index, and type that determines its behavior.
class Slot {
  /// The slot index within the container.
  final int index;

  /// X position relative to the container's left edge.
  final int x;

  /// Y position relative to the container's top edge.
  final int y;

  /// The type of slot (determines behavior and appearance).
  final SlotType type;

  const Slot({
    required this.index,
    required this.x,
    required this.y,
    this.type = SlotType.container,
  });

  /// Standard slot size in pixels.
  static const int slotSize = 18;

  /// Standard slot inner size (without border).
  static const int slotInnerSize = 16;

  /// Get the center X position of the slot.
  int get centerX => x + slotSize ~/ 2;

  /// Get the center Y position of the slot.
  int get centerY => y + slotSize ~/ 2;

  /// Check if a point is within this slot.
  bool containsPoint(int px, int py) =>
      px >= x && px < x + slotSize && py >= y && py < y + slotSize;

  /// Check if this is a player-related slot.
  bool get isPlayerSlot =>
      type == SlotType.playerInventory ||
      type == SlotType.playerHotbar ||
      type == SlotType.armor ||
      type == SlotType.offhand;

  /// Check if this is a container slot (not player inventory).
  bool get isContainerSlot => !isPlayerSlot;

  @override
  String toString() => 'Slot($index at $x,$y, $type)';

  @override
  bool operator ==(Object other) =>
      other is Slot &&
      index == other.index &&
      x == other.x &&
      y == other.y &&
      type == other.type;

  @override
  int get hashCode => Object.hash(index, x, y, type);
}
