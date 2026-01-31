/// Test ore blocks for world generation testing.
///
/// These blocks demonstrate the world generation API for custom ores.
import 'package:dart_mod_server/dart_mod_server.dart';

/// A simple test ore block that generates in the overworld.
///
/// Uses diamond_block texture as a placeholder for testing.
class TestOreBlock extends CustomBlock {
  TestOreBlock()
      : super(
          id: 'example_mod:test_ore',
          settings: BlockSettings(
            hardness: 3.0,
            resistance: 3.0,
            requiresTool: true,
          ),
          // Use diamond_block texture from vanilla as placeholder
          model: BlockModel.cubeAll(texture: 'minecraft:block/diamond_ore'),
        );
}

/// Deepslate variant of the test ore block.
///
/// Generates below Y=0 in the deepslate layer.
class DeepslateTestOreBlock extends CustomBlock {
  DeepslateTestOreBlock()
      : super(
          id: 'example_mod:deepslate_test_ore',
          settings: BlockSettings(
            hardness: 4.5, // Slightly harder than regular variant
            resistance: 3.0,
            requiresTool: true,
          ),
          // Use deepslate_diamond_ore texture from vanilla as placeholder
          model: BlockModel.cubeAll(texture: 'minecraft:block/deepslate_diamond_ore'),
        );
}

/// Registers test ore blocks and their world generation features.
void registerTestOres() {
  // Register the ore blocks first
  final testOre = TestOreBlock();
  final deepslateTestOre = DeepslateTestOreBlock();

  BlockRegistry.register(testOre);
  BlockRegistry.register(deepslateTestOre);

  // Register the ore generation feature
  WorldGeneration.registerOre(
    'example_mod:test_ore_feature',
    OreConfig(
      oreBlock: 'example_mod:test_ore',
      veinSize: 9, // Similar to iron ore
      veinsPerChunk: 8,
      minY: -64,
      maxY: 64,
      distribution: HeightDistribution.uniform,
      deepslateVariant: 'example_mod:deepslate_test_ore',
      deepslateTransitionY: 0,
    ),
    biomes: BiomeSelector.overworld,
  );

  print('Registered test ore blocks and world generation feature');
}
