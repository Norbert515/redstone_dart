/// Processing block entity (furnace-like) support.
library;

import '../item/item_stack.dart';
import 'block_entity_settings.dart';
import 'block_entity_with_inventory.dart';
import 'synced_value.dart';

/// A block entity that processes items (furnace-like behavior).
///
/// Provides built-in fuel burning, cooking progress, and client sync via ContainerData.
///
/// ## Example
///
/// ```dart
/// class MyFurnace extends ProcessingBlockEntity {
///   MyFurnace() : super(
///     settings: ProcessingSettings(
///       id: 'mymod:my_furnace',
///       hardness: 3.5,
///       processTime: 200,
///       slots: SlotConfig.furnace(),
///     ),
///   );
///
///   @override
///   ItemStack? process(ItemStack input) {
///     // Define what this furnace smelts
///     if (input.item.id == 'minecraft:iron_ore') {
///       return ItemStack.of('minecraft:iron_ingot');
///     }
///     return null;
///   }
/// }
/// ```
abstract class ProcessingBlockEntity extends BlockEntityWithInventory {
  // Synced state (maps to ContainerData indices)

  /// Current burn time remaining (ticks).
  final SyncedInt litTime = SyncedInt(0);

  /// Total burn time of current fuel (ticks).
  final SyncedInt litDuration = SyncedInt(1);

  /// Current cooking progress (ticks).
  final SyncedInt cookingProgress = SyncedInt(2);

  /// Total cooking time for the current recipe (ticks).
  final SyncedInt cookingTotalTime = SyncedInt(3);

  /// Creates a processing block entity with the given settings.
  ProcessingBlockEntity({required ProcessingSettings settings})
      : super(settings: settings) {
    cookingTotalTime.value = settings.processTime;
  }

  /// Get settings as ProcessingSettings.
  ProcessingSettings get processingSettings => settings as ProcessingSettings;

  /// Get the slot configuration.
  SlotConfig get slots => processingSettings.slots;

  // ============ Slot Accessors ============

  /// The item in the input slot.
  ItemStack get inputSlot => getSlot(slots.inputSlot);
  set inputSlot(ItemStack item) => setSlot(slots.inputSlot, item);

  /// The item in the fuel slot.
  ItemStack get fuelSlot => getSlot(slots.fuelSlot);
  set fuelSlot(ItemStack item) => setSlot(slots.fuelSlot, item);

  /// The item in the output slot.
  ItemStack get outputSlot => getSlot(slots.outputSlot);
  set outputSlot(ItemStack item) => setSlot(slots.outputSlot, item);

  // ============ Processing Logic ============

  /// Override to define what this block entity processes.
  ///
  /// Return the result item for the given input, or null if the input
  /// cannot be processed.
  ItemStack? process(ItemStack input);

  /// Override to check if an item is valid fuel.
  ///
  /// Default implementation accepts coal and charcoal.
  bool isFuel(ItemStack item) {
    final id = item.item.id;
    return id.contains('coal') || id.contains('charcoal');
  }

  /// Override to get the burn time for a fuel item.
  ///
  /// Default returns 1600 ticks (80 seconds) for coal.
  int getBurnTime(ItemStack fuel) {
    final id = fuel.item.id;
    if (id.contains('coal_block')) return 16000;
    if (id.contains('coal') || id.contains('charcoal')) return 1600;
    if (id.contains('lava_bucket')) return 20000;
    if (id.contains('blaze_rod')) return 2400;
    if (id.contains('planks') || id.contains('log')) return 300;
    if (id.contains('stick')) return 100;
    return 200; // Default fallback
  }

  /// Whether the block entity is currently burning fuel.
  bool get isBurning => litTime.value > 0;

  @override
  void serverTick() {
    final wasLit = isBurning;
    var changed = false;

    // Decrement burn time
    if (isBurning) {
      litTime.value--;
    }

    // Check if we can process
    final result = process(inputSlot);

    if (result != null && _canAcceptOutput(result)) {
      // Consume fuel if needed
      if (!isBurning && !fuelSlot.isEmpty && isFuel(fuelSlot)) {
        litDuration.value = getBurnTime(fuelSlot);
        litTime.value = litDuration.value;
        fuelSlot = fuelSlot.copyWith(count: fuelSlot.count - 1);
        changed = true;
      }

      // Process recipe
      if (isBurning) {
        cookingProgress.value++;
        if (cookingProgress.value >= cookingTotalTime.value) {
          cookingProgress.value = 0;
          _produceOutput(result);
          changed = true;
        }
      }
    } else {
      // Can't process - reset progress
      cookingProgress.value = 0;
    }

    if (wasLit != isBurning) {
      changed = true;
      // Could update block state here for lit texture
    }

    // State changed - the framework will handle save/sync
    if (changed) {
      _markDirty();
    }
  }

  bool _canAcceptOutput(ItemStack result) {
    if (outputSlot.isEmpty) return true;
    if (outputSlot.item.id != result.item.id) return false;
    return outputSlot.count + result.count <= 64;
  }

  void _produceOutput(ItemStack result) {
    inputSlot = inputSlot.copyWith(count: inputSlot.count - 1);
    if (outputSlot.isEmpty) {
      outputSlot = result;
    } else {
      outputSlot = outputSlot.copyWith(count: outputSlot.count + result.count);
    }
  }

  /// Called when state changes. Override to perform custom dirty handling.
  void _markDirty() {
    // Block entity state changed - framework will handle persistence
  }

  // ============ Data Slot Access (for Java bridge) ============

  /// Get a ContainerData slot value by index.
  ///
  /// Used by the Java bridge to sync data to clients.
  int getDataSlot(int index) {
    return switch (index) {
      0 => litTime.value,
      1 => litDuration.value,
      2 => cookingProgress.value,
      3 => cookingTotalTime.value,
      _ => 0,
    };
  }

  /// Set a ContainerData slot value by index.
  ///
  /// Used by the Java bridge when receiving data from clients.
  void setDataSlot(int index, int value) {
    switch (index) {
      case 0:
        litTime.value = value;
      case 1:
        litDuration.value = value;
      case 2:
        cookingProgress.value = value;
      case 3:
        cookingTotalTime.value = value;
    }
  }

  // ============ Save/Load ============

  @override
  Map<String, dynamic> onSave() {
    final base = super.onSave();
    base['litTime'] = litTime.value;
    base['litDuration'] = litDuration.value;
    base['cookingProgress'] = cookingProgress.value;
    base['cookingTotalTime'] = cookingTotalTime.value;
    return base;
  }

  @override
  void onLoad(Map<String, dynamic> nbt) {
    super.onLoad(nbt);
    litTime.value = nbt['litTime'] as int? ?? 0;
    litDuration.value = nbt['litDuration'] as int? ?? 0;
    cookingProgress.value = nbt['cookingProgress'] as int? ?? 0;
    cookingTotalTime.value =
        nbt['cookingTotalTime'] as int? ?? processingSettings.processTime;
  }
}
