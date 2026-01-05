/// Server-side furnace block entity with smelting logic.
library;

import 'package:dart_mod_server/dart_mod_server.dart';
import 'package:example_mod_common/example_mod_common.dart';

/// Server-side furnace block entity with smelting logic.
///
/// Demonstrates the new Container API with:
/// - [SimpleFurnaceContainer] for synced data (shared with client)
/// - [ContainerBlockEntity] for server-side inventory and ticking
///
/// ## Example
///
/// ```dart
/// // Register the block entity type
/// BlockEntityRegistry.registerType(
///   'example_mod:simple_furnace',
///   SimpleFurnaceEntity.new,
///   inventorySize: 3,
///   containerTitle: 'Simple Furnace',
/// );
/// ```
class SimpleFurnaceEntity
    extends ContainerBlockEntity<SimpleFurnaceContainer> {
  SimpleFurnaceEntity() : super(container: SimpleFurnaceContainer());

  int _tickCount = 0;

  @override
  void serverTick() {
    // Debug: print tick every 100 ticks
    _tickCount++;

    // Check if we can smelt
    final input = getSlot(SimpleFurnaceContainer.inputSlot);
    final fuel = getSlot(SimpleFurnaceContainer.fuelSlot);
    final output = getSlot(SimpleFurnaceContainer.outputSlot);

    if (_tickCount % 100 == 0) {
      print('[SimpleFurnaceEntity] serverTick #$_tickCount');
      print('  litTime=${container.litTime.value}, cookingProgress=${container.cookingProgress.value}');
      print('  input=${input.item.id}:${input.count}, fuel=${fuel.item.id}:${fuel.count}, output=${output.item.id}:${output.count}');
      print('  isLit=${container.isLit}, canSmelt=${input.isNotEmpty && canSmelt(input)}, isFuel=${fuel.isNotEmpty && isFuel(fuel)}');
    }

    final wasLit = container.isLit;
    var changed = false;

    // Burn down fuel
    if (container.litTime.value > 0) {
      container.litTime.value--;
      changed = true;
    }

    // Try to consume fuel if we have input and no lit time
    if (!container.isLit && input.isNotEmpty && canSmelt(input)) {
      if (fuel.isNotEmpty && isFuel(fuel)) {
        // Consume fuel
        container.litDuration.value = getBurnTime(fuel);
        container.litTime.value = container.litDuration.value;
        _consumeItem(SimpleFurnaceContainer.fuelSlot, 1);
        changed = true;
      }
    }

    // Progress cooking if lit and have smeltable input
    if (container.isLit && input.isNotEmpty && canSmelt(input)) {
      container.cookingProgress.value++;
      container.cookingTotalTime.value = 200; // 10 seconds (200 ticks)

      if (container.cookingProgress.value >= container.cookingTotalTime.value) {
        // Smelting complete
        final result = getSmeltResult(input);
        if (result != null && _canAcceptOutput(result, output)) {
          // Add to output
          if (output.isEmpty) {
            setSlot(SimpleFurnaceContainer.outputSlot, result);
          } else {
            // Stack if same item
            _incrementItem(SimpleFurnaceContainer.outputSlot, 1);
          }
          _consumeItem(SimpleFurnaceContainer.inputSlot, 1);
        }
        container.cookingProgress.value = 0;
      }
      changed = true;
    } else if (!container.isLit && container.cookingProgress.value > 0) {
      // Lose progress if no fuel
      container.cookingProgress.value = 0;
      changed = true;
    }

    if (changed || wasLit != container.isLit) {
      _markDirty();
    }
  }

  /// Check if the output slot can accept the result.
  bool _canAcceptOutput(ItemStack result, ItemStack output) {
    if (output.isEmpty) return true;
    if (output.item.id != result.item.id) return false;
    return output.count + result.count <= 64;
  }

  /// Consume items from a slot.
  void _consumeItem(int slot, int count) {
    final current = getSlot(slot);
    if (current.isEmpty) return;

    final newCount = current.count - count;
    if (newCount <= 0) {
      setSlot(slot, ItemStack.empty);
    } else {
      setSlot(slot, current.copyWith(count: newCount));
    }
  }

  /// Increment item count in a slot.
  void _incrementItem(int slot, int count) {
    final current = getSlot(slot);
    if (current.isEmpty) return;

    setSlot(slot, current.copyWith(count: current.count + count));
  }

  /// Mark the block entity as dirty (needs save).
  void _markDirty() {
    // Block entity state changed - framework will handle persistence
  }

  /// Check if an item can be smelted.
  bool canSmelt(ItemStack item) {
    return getSmeltResult(item) != null;
  }

  /// Check if an item is valid fuel.
  bool isFuel(ItemStack item) {
    return getBurnTime(item) > 0;
  }

  /// Get the burn time for a fuel item in ticks.
  int getBurnTime(ItemStack item) {
    final id = item.item.id;
    // Simple fuel values matching vanilla
    if (id.contains('coal_block')) return 16000;
    if (id.contains('coal') || id.contains('charcoal')) return 1600;
    if (id.contains('lava_bucket')) return 20000;
    if (id.contains('blaze_rod')) return 2400;
    if (id.contains('planks') || id.contains('log')) return 300;
    if (id.contains('stick')) return 100;
    return 0;
  }

  /// Get the result of smelting an input item.
  ///
  /// Returns null if the item cannot be smelted.
  ItemStack? getSmeltResult(ItemStack input) {
    final id = input.item.id;
    // Simple recipes for testing
    if (id == 'minecraft:iron_ore' || id == 'minecraft:raw_iron') {
      return ItemStack.of('minecraft:iron_ingot');
    }
    if (id == 'minecraft:gold_ore' || id == 'minecraft:raw_gold') {
      return ItemStack.of('minecraft:gold_ingot');
    }
    if (id == 'minecraft:copper_ore' || id == 'minecraft:raw_copper') {
      return ItemStack.of('minecraft:copper_ingot');
    }
    if (id == 'minecraft:cobblestone') {
      return ItemStack.of('minecraft:stone');
    }
    if (id == 'minecraft:sand') {
      return ItemStack.of('minecraft:glass');
    }
    if (id == 'minecraft:clay_ball') {
      return ItemStack.of('minecraft:brick');
    }
    return null;
  }
}
