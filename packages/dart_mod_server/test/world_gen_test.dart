/// Unit tests for world generation API.
///
/// Tests OreConfig, HeightDistribution, and BiomeSelector.
import 'package:dart_mod_server/src/world_gen.dart';
import 'package:test/test.dart';

void main() {
  group('OreConfig', () {
    test('creates with required parameters', () {
      final config = OreConfig(
        oreBlock: 'mymod:test_ore',
        veinSize: 9,
        minY: -64,
        maxY: 64,
      );

      expect(config.oreBlock, equals('mymod:test_ore'));
      expect(config.veinSize, equals(9));
      expect(config.minY, equals(-64));
      expect(config.maxY, equals(64));
    });

    test('has correct default values', () {
      final config = OreConfig(
        oreBlock: 'mymod:test_ore',
        veinSize: 9,
        minY: -64,
        maxY: 64,
      );

      expect(config.veinsPerChunk, equals(8));
      expect(config.distribution, equals(HeightDistribution.uniform));
      expect(config.replaceableTag, equals('minecraft:stone_ore_replaceables'));
      expect(config.deepslateVariant, isNull);
      expect(config.deepslateTransitionY, equals(0));
    });

    test('creates with all parameters', () {
      final config = OreConfig(
        oreBlock: 'mymod:ruby_ore',
        veinSize: 8,
        veinsPerChunk: 4,
        minY: -64,
        maxY: 16,
        distribution: HeightDistribution.triangle,
        replaceableTag: 'minecraft:deepslate_ore_replaceables',
        deepslateVariant: 'mymod:deepslate_ruby_ore',
        deepslateTransitionY: -8,
      );

      expect(config.oreBlock, equals('mymod:ruby_ore'));
      expect(config.veinSize, equals(8));
      expect(config.veinsPerChunk, equals(4));
      expect(config.minY, equals(-64));
      expect(config.maxY, equals(16));
      expect(config.distribution, equals(HeightDistribution.triangle));
      expect(config.replaceableTag, equals('minecraft:deepslate_ore_replaceables'));
      expect(config.deepslateVariant, equals('mymod:deepslate_ruby_ore'));
      expect(config.deepslateTransitionY, equals(-8));
    });

    test('is const constructible', () {
      const config = OreConfig(
        oreBlock: 'mymod:const_ore',
        veinSize: 5,
        minY: 0,
        maxY: 100,
      );

      expect(config.oreBlock, equals('mymod:const_ore'));
    });

    test('supports negative Y values', () {
      final config = OreConfig(
        oreBlock: 'mymod:deep_ore',
        veinSize: 6,
        minY: -64,
        maxY: -32,
      );

      expect(config.minY, equals(-64));
      expect(config.maxY, equals(-32));
    });

    test('supports large vein sizes', () {
      final config = OreConfig(
        oreBlock: 'mymod:huge_ore',
        veinSize: 64,
        minY: 0,
        maxY: 64,
      );

      expect(config.veinSize, equals(64));
    });
  });

  group('HeightDistribution', () {
    test('has uniform value', () {
      expect(HeightDistribution.uniform, isNotNull);
      expect(HeightDistribution.uniform.name, equals('uniform'));
    });

    test('has triangle value', () {
      expect(HeightDistribution.triangle, isNotNull);
      expect(HeightDistribution.triangle.name, equals('triangle'));
    });

    test('has trapezoid value', () {
      expect(HeightDistribution.trapezoid, isNotNull);
      expect(HeightDistribution.trapezoid.name, equals('trapezoid'));
    });

    test('has exactly 3 values', () {
      expect(HeightDistribution.values.length, equals(3));
    });

    test('values can be used in OreConfig', () {
      for (final dist in HeightDistribution.values) {
        final config = OreConfig(
          oreBlock: 'mymod:test_ore',
          veinSize: 9,
          minY: 0,
          maxY: 64,
          distribution: dist,
        );
        expect(config.distribution, equals(dist));
      }
    });
  });

  group('BiomeSelector', () {
    test('has overworld value', () {
      expect(BiomeSelector.overworld, isNotNull);
      expect(BiomeSelector.overworld.name, equals('overworld'));
    });

    test('has nether value', () {
      expect(BiomeSelector.nether, isNotNull);
      expect(BiomeSelector.nether.name, equals('nether'));
    });

    test('has end value', () {
      expect(BiomeSelector.end, isNotNull);
      expect(BiomeSelector.end.name, equals('end'));
    });

    test('has exactly 3 values', () {
      expect(BiomeSelector.values.length, equals(3));
    });
  });
}
