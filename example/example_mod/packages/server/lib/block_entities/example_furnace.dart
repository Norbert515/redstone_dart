import 'package:dart_mod_common/dart_mod_common.dart';

/// Example furnace block entity demonstrating the ProcessingBlockEntity API.
///
/// This furnace can smelt common ores and accepts standard fuels.
/// It uses vanilla furnace screen rendering via ContainerData sync.
class ExampleFurnace extends ProcessingBlockEntity {
  ExampleFurnace()
      : super(
          settings: ProcessingSettings(
            id: 'example_mod:example_furnace',
            hardness: 3.5,
            processTime: 200, // 10 seconds (200 ticks)
            slots: const SlotConfig.furnace(),
          ),
        );

  /// Defines what this furnace can smelt.
  ///
  /// Returns the smelted result for the given input, or null if the
  /// input cannot be processed.
  @override
  ItemStack? process(ItemStack input) {
    // Simple smelting recipes
    final recipes = {
      'minecraft:iron_ore': 'minecraft:iron_ingot',
      'minecraft:deepslate_iron_ore': 'minecraft:iron_ingot',
      'minecraft:gold_ore': 'minecraft:gold_ingot',
      'minecraft:deepslate_gold_ore': 'minecraft:gold_ingot',
      'minecraft:copper_ore': 'minecraft:copper_ingot',
      'minecraft:deepslate_copper_ore': 'minecraft:copper_ingot',
      'minecraft:raw_iron': 'minecraft:iron_ingot',
      'minecraft:raw_gold': 'minecraft:gold_ingot',
      'minecraft:raw_copper': 'minecraft:copper_ingot',
      'minecraft:cobblestone': 'minecraft:stone',
      'minecraft:sand': 'minecraft:glass',
      'minecraft:clay_ball': 'minecraft:brick',
      'minecraft:netherrack': 'minecraft:nether_brick',
      'minecraft:wet_sponge': 'minecraft:sponge',
      // Food
      'minecraft:beef': 'minecraft:cooked_beef',
      'minecraft:porkchop': 'minecraft:cooked_porkchop',
      'minecraft:chicken': 'minecraft:cooked_chicken',
      'minecraft:mutton': 'minecraft:cooked_mutton',
      'minecraft:rabbit': 'minecraft:cooked_rabbit',
      'minecraft:cod': 'minecraft:cooked_cod',
      'minecraft:salmon': 'minecraft:cooked_salmon',
      'minecraft:potato': 'minecraft:baked_potato',
      'minecraft:kelp': 'minecraft:dried_kelp',
    };

    final result = recipes[input.item.id];
    if (result != null) {
      return ItemStack.of(result);
    }
    return null;
  }

  /// Checks if an item is valid fuel for this furnace.
  @override
  bool isFuel(ItemStack item) {
    final id = item.item.id;

    // Standard fuels
    if (id == 'minecraft:coal' ||
        id == 'minecraft:charcoal' ||
        id == 'minecraft:coal_block' ||
        id == 'minecraft:lava_bucket' ||
        id == 'minecraft:blaze_rod' ||
        id == 'minecraft:dried_kelp_block') {
      return true;
    }

    // Wooden items
    if (id.contains('_planks') ||
        id.contains('_log') ||
        id.contains('_wood') ||
        id.contains('_slab') ||
        id.contains('_stairs') ||
        id.contains('_fence') ||
        id == 'minecraft:stick') {
      return true;
    }

    return false;
  }

  /// Gets the burn time in ticks for a fuel item.
  @override
  int getBurnTime(ItemStack fuel) {
    final id = fuel.item.id;

    // High-value fuels
    if (id == 'minecraft:lava_bucket') return 20000;
    if (id == 'minecraft:coal_block') return 16000;
    if (id == 'minecraft:dried_kelp_block') return 4001;
    if (id == 'minecraft:blaze_rod') return 2400;

    // Standard fuels
    if (id == 'minecraft:coal' || id == 'minecraft:charcoal') return 1600;

    // Wooden items
    if (id.contains('_log') || id.contains('_wood')) return 300;
    if (id.contains('_planks')) return 300;
    if (id.contains('_slab')) return 150;
    if (id.contains('_stairs')) return 300;
    if (id.contains('_fence')) return 300;
    if (id == 'minecraft:stick') return 100;

    return 200; // Default fallback
  }
}
