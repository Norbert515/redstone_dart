/// Inventory API for interacting with Minecraft player inventories.
library;

import '../src/jni/generic_bridge.dart';
import '../src/types.dart';
import 'entity.dart';
import 'item.dart';
import 'player.dart';
import 'world.dart';

/// The Java class name for DartBridge.
const _dartBridge = 'com/example/dartbridge/DartBridge';

/// Player inventory access.
///
/// Minecraft slot layout:
/// - 0-8: Hotbar
/// - 9-35: Main inventory
/// - 36-39: Armor (feet, legs, chest, head)
/// - 40: Offhand
class PlayerInventory {
  /// The player this inventory belongs to.
  final Player player;

  PlayerInventory(this.player);

  /// Total inventory size (36 main + 4 armor + 1 offhand = 41).
  int get size => 41;

  /// Main inventory size (hotbar + main slots, 0-35).
  int get mainSize => 36;

  /// Hotbar size (0-8).
  int get hotbarSize => 9;

  /// Currently selected hotbar slot (0-8).
  int get selectedSlot {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getPlayerSelectedSlot',
      '(I)I',
      [player.id],
    );
  }

  /// Set the selected hotbar slot (0-8).
  set selectedSlot(int slot) {
    if (slot < 0 || slot > 8) {
      throw RangeError.range(slot, 0, 8, 'slot', 'Hotbar slot must be 0-8');
    }
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setPlayerSelectedSlot',
      '(II)V',
      [player.id, slot],
    );
  }

  /// Get item in slot.
  ///
  /// Slot indices:
  /// - 0-8: Hotbar
  /// - 9-35: Main inventory
  /// - 36-39: Armor (feet, legs, chest, head)
  /// - 40: Offhand
  ItemStack getSlot(int slot) {
    if (slot < 0 || slot > 40) {
      throw RangeError.range(slot, 0, 40, 'slot');
    }

    final result = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getPlayerInventoryItem',
      '(II)Ljava/lang/String;',
      [player.id, slot],
    );

    if (result == null || result.isEmpty) {
      return ItemStack.empty;
    }

    // Parse "itemId:count" format
    final parts = result.split(':');
    if (parts.length >= 3) {
      // Format: "minecraft:item_name:count"
      final itemId = '${parts[0]}:${parts[1]}';
      final count = int.tryParse(parts[2]) ?? 1;
      return ItemStack.withContext(Item(itemId), count, null, player.id, slot);
    }

    return ItemStack.empty;
  }

  /// Set item in slot.
  void setSlot(int slot, ItemStack stack) {
    if (slot < 0 || slot > 40) {
      throw RangeError.range(slot, 0, 40, 'slot');
    }

    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setPlayerInventoryItem',
      '(IILjava/lang/String;I)V',
      [player.id, slot, stack.item.id, stack.count],
    );
  }

  /// Clear a slot.
  void clearSlot(int slot) => setSlot(slot, ItemStack.empty);

  // ==========================================================================
  // Equipment Shortcuts
  // ==========================================================================

  /// Get the item in the main hand.
  ItemStack get mainHand => getSlot(selectedSlot);

  /// Set the item in the main hand.
  set mainHand(ItemStack stack) => setSlot(selectedSlot, stack);

  /// Get the item in the offhand.
  ItemStack get offHand => getSlot(40);

  /// Set the item in the offhand.
  set offHand(ItemStack stack) => setSlot(40, stack);

  /// Get the helmet.
  ItemStack get helmet => getSlot(39);

  /// Set the helmet.
  set helmet(ItemStack stack) => setSlot(39, stack);

  /// Get the chestplate.
  ItemStack get chestplate => getSlot(38);

  /// Set the chestplate.
  set chestplate(ItemStack stack) => setSlot(38, stack);

  /// Get the leggings.
  ItemStack get leggings => getSlot(37);

  /// Set the leggings.
  set leggings(ItemStack stack) => setSlot(37, stack);

  /// Get the boots.
  ItemStack get boots => getSlot(36);

  /// Set the boots.
  set boots(ItemStack stack) => setSlot(36, stack);

  /// Get equipment by slot type.
  ItemStack getEquipment(EquipmentSlot slot) {
    return getSlot(slot.toSlotIndex(selectedSlot));
  }

  /// Set equipment by slot type.
  void setEquipment(EquipmentSlot slot, ItemStack stack) {
    setSlot(slot.toSlotIndex(selectedSlot), stack);
  }

  // ==========================================================================
  // Inventory Utilities
  // ==========================================================================

  /// Find first slot containing item (or -1 if not found).
  int findItem(Item item) {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'findPlayerInventoryItem',
      '(ILjava/lang/String;)I',
      [player.id, item.id],
    );
  }

  /// Find first empty slot (or -1 if inventory is full).
  int findEmptySlot() {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'findPlayerEmptySlot',
      '(I)I',
      [player.id],
    );
  }

  /// Count total items of type across all slots.
  int countItem(Item item) {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'countPlayerInventoryItem',
      '(ILjava/lang/String;)I',
      [player.id, item.id],
    );
  }

  /// Check if player has at least [minCount] of the specified item.
  bool hasItem(Item item, [int minCount = 1]) {
    return countItem(item) >= minCount;
  }

  /// Give item to player (adds to inventory, drops excess if full).
  ///
  /// Returns true if at least some items were added to inventory.
  bool giveItem(ItemStack stack) {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'givePlayerItem',
      '(ILjava/lang/String;I)Z',
      [player.id, stack.item.id, stack.count],
    );
  }

  /// Remove items from inventory.
  ///
  /// Returns the number of items actually removed.
  int removeItem(Item item, int count) {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'removePlayerItem',
      '(ILjava/lang/String;I)I',
      [player.id, item.id, count],
    );
  }

  /// Clear entire inventory.
  void clear() {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'clearPlayerInventory',
      '(I)V',
      [player.id],
    );
  }

  /// Iterate all slots.
  Iterable<(int slot, ItemStack stack)> get slots sync* {
    for (var i = 0; i <= 40; i++) {
      yield (i, getSlot(i));
    }
  }

  /// Iterate only non-empty slots.
  Iterable<(int slot, ItemStack stack)> get nonEmptySlots sync* {
    for (var i = 0; i <= 40; i++) {
      final stack = getSlot(i);
      if (stack.isNotEmpty) {
        yield (i, stack);
      }
    }
  }

  /// Iterate hotbar slots (0-8).
  Iterable<(int slot, ItemStack stack)> get hotbarSlots sync* {
    for (var i = 0; i < 9; i++) {
      yield (i, getSlot(i));
    }
  }

  /// Iterate main inventory slots (9-35).
  Iterable<(int slot, ItemStack stack)> get mainSlots sync* {
    for (var i = 9; i < 36; i++) {
      yield (i, getSlot(i));
    }
  }

  /// Iterate armor slots (36-39).
  Iterable<(int slot, ItemStack stack)> get armorSlots sync* {
    for (var i = 36; i < 40; i++) {
      yield (i, getSlot(i));
    }
  }
}

/// Extension to add inventory access to Player.
extension PlayerInventoryExtension on Player {
  /// Get the player's inventory.
  PlayerInventory get inventory => PlayerInventory(this);
}

// =============================================================================
// Item Entity
// =============================================================================

/// Item entity (dropped item in world).
class ItemEntity extends Entity {
  const ItemEntity(super.id);

  /// Get the item stack this entity represents.
  ItemStack get stack {
    final result = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getItemEntityStack',
      '(I)Ljava/lang/String;',
      [id],
    );

    if (result == null || result.isEmpty) {
      return ItemStack.empty;
    }

    // Parse "itemId:count" format
    final parts = result.split(':');
    if (parts.length >= 3) {
      // Format: "minecraft:item_name:count"
      final itemId = '${parts[0]}:${parts[1]}';
      final count = int.tryParse(parts[2]) ?? 1;
      return ItemStack(Item(itemId), count);
    }

    return ItemStack.empty;
  }

  /// Set the item stack.
  set stack(ItemStack value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemEntityStack',
      '(ILjava/lang/String;I)V',
      [id, value.item.id, value.count],
    );
  }

  /// Pickup delay in ticks (can't be picked up until 0).
  int get pickupDelay {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getItemEntityPickupDelay',
      '(I)I',
      [id],
    );
  }

  /// Set pickup delay in ticks.
  set pickupDelay(int ticks) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemEntityPickupDelay',
      '(II)V',
      [id, ticks],
    );
  }

  /// Age in ticks (despawns at 6000 = 5 minutes).
  int get age {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getItemEntityAge',
      '(I)I',
      [id],
    );
  }

  /// Set age in ticks.
  set age(int ticks) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemEntityAge',
      '(II)V',
      [id, ticks],
    );
  }

  @override
  String toString() => 'ItemEntity($id, stack: $stack)';
}

/// Drop an item in the world.
///
/// Returns the spawned ItemEntity, or null if failed.
ItemEntity? dropItem(
  World world,
  Vec3 position,
  ItemStack stack, {
  Vec3? velocity,
}) {
  final vel = velocity ?? Vec3.zero;

  final entityId = GenericJniBridge.callStaticIntMethod(
    _dartBridge,
    'dropItem',
    '(Ljava/lang/String;DDDLjava/lang/String;IDDD)I',
    [
      world.dimensionId,
      position.x,
      position.y,
      position.z,
      stack.item.id,
      stack.count,
      vel.x,
      vel.y,
      vel.z,
    ],
  );

  if (entityId < 0) return null;
  return ItemEntity(entityId);
}
