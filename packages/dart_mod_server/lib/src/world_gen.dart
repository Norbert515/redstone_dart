/// World generation configuration for ores.
///
/// Use this to register custom ore generation in your mod.
library;

import 'dart:convert';
import 'dart:io';

import 'bridge.dart';

/// Height distribution type for ore generation.
enum HeightDistribution {
  /// Equal chance at all Y-levels in the range.
  uniform,

  /// Higher concentration at the center, tapering at edges.
  triangle,

  /// Flat top with tapered edges (like vanilla diamond distribution).
  trapezoid,
}

/// Configuration for ore generation.
class OreConfig {
  /// The block ID of the ore (e.g., "mymod:ruby_ore").
  /// This block must be registered before registering the ore feature.
  final String oreBlock;

  /// Maximum number of blocks per vein (e.g., 9 for iron ore).
  final int veinSize;

  /// Average number of veins per chunk.
  final int veinsPerChunk;

  /// Minimum Y level for ore generation.
  final int minY;

  /// Maximum Y level for ore generation.
  final int maxY;

  /// Height distribution type.
  final HeightDistribution distribution;

  /// Tag of blocks the ore can replace (e.g., "minecraft:stone_ore_replaceables").
  final String replaceableTag;

  /// Optional deepslate variant block ID (e.g., "mymod:deepslate_ruby_ore").
  final String? deepslateVariant;

  /// Y level where deepslate variant takes over (default: 0).
  final int deepslateTransitionY;

  const OreConfig({
    required this.oreBlock,
    required this.veinSize,
    this.veinsPerChunk = 8,
    required this.minY,
    required this.maxY,
    this.distribution = HeightDistribution.uniform,
    this.replaceableTag = 'minecraft:stone_ore_replaceables',
    this.deepslateVariant,
    this.deepslateTransitionY = 0,
  });
}

/// Biome selection for ore generation.
enum BiomeSelector {
  /// All Overworld biomes.
  overworld,

  /// All Nether biomes.
  nether,

  /// All End biomes.
  end,
}

/// World generation registration.
class WorldGeneration {
  /// Register an ore feature for world generation.
  ///
  /// The ore block must be registered before calling this method.
  /// This adds the ore to the specified biomes during world generation.
  ///
  /// Example:
  /// ```dart
  /// // First register the ore block
  /// BlockRegistry.register(rubyOre);
  ///
  /// // Then register the ore feature
  /// WorldGeneration.registerOre(
  ///   'mymod:ruby_ore_feature',
  ///   OreConfig(
  ///     oreBlock: 'mymod:ruby_ore',
  ///     veinSize: 8,
  ///     veinsPerChunk: 4,
  ///     minY: -64,
  ///     maxY: 16,
  ///     distribution: HeightDistribution.triangle,
  ///     deepslateVariant: 'mymod:deepslate_ruby_ore',
  ///   ),
  ///   biomes: BiomeSelector.overworld,
  /// );
  /// ```
  static void registerOre(
    String id,
    OreConfig config, {
    BiomeSelector biomes = BiomeSelector.overworld,
  }) {
    _registerOreWithBiomeString(id, config, biomes.name);
  }

  /// Register an ore feature for specific biomes by tag.
  ///
  /// Use this to add ores to specific biome tags.
  ///
  /// Example:
  /// ```dart
  /// WorldGeneration.registerOreForBiomeTag(
  ///   'mymod:desert_gem_ore_feature',
  ///   OreConfig(
  ///     oreBlock: 'mymod:desert_gem_ore',
  ///     veinSize: 5,
  ///     minY: 0,
  ///     maxY: 64,
  ///   ),
  ///   biomeTag: 'minecraft:is_desert',
  /// );
  /// ```
  static void registerOreForBiomeTag(
    String id,
    OreConfig config, {
    required String biomeTag,
  }) {
    // Prefix with # to indicate it's a tag
    _registerOreWithBiomeString(id, config, '#$biomeTag');
  }

  static void _registerOreWithBiomeString(
    String id,
    OreConfig config,
    String biomeSelector,
  ) {
    // Parse namespace:path from id
    final parts = id.split(':');
    if (parts.length != 2) {
      throw ArgumentError(
          'Invalid ore feature ID: $id. Must be namespace:path');
    }

    final namespace = parts[0];
    final path = parts[1];

    // Queue the registration via native bridge
    ServerBridge.queueOreFeatureRegistration(
      namespace: namespace,
      path: path,
      oreBlockId: config.oreBlock,
      veinSize: config.veinSize,
      veinsPerChunk: config.veinsPerChunk,
      minY: config.minY,
      maxY: config.maxY,
      distributionType: config.distribution.name,
      replaceableTag: config.replaceableTag,
      biomeSelector: biomeSelector,
      deepslateVariant: config.deepslateVariant ?? '',
      deepslateTransitionY: config.deepslateTransitionY,
    );

    // Also write to manifest for datagen
    _writeToManifest(id, config, biomeSelector);

    print('WorldGeneration: Queued ore feature $id');
  }

  /// Write ore feature to manifest for CLI datagen.
  static void _writeToManifest(
    String id,
    OreConfig config,
    String biomeSelector,
  ) {
    // Read existing manifest
    Map<String, dynamic> manifest = {};
    final manifestFile = File('.redstone/manifest.json');
    if (manifestFile.existsSync()) {
      try {
        manifest =
            jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parse errors
      }
    }

    // Get or create ore_features list
    final oreFeatures =
        (manifest['ore_features'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    // Add this ore feature
    oreFeatures.add({
      'id': id,
      'oreBlock': config.oreBlock,
      'veinSize': config.veinSize,
      'veinsPerChunk': config.veinsPerChunk,
      'minY': config.minY,
      'maxY': config.maxY,
      'distribution': config.distribution.name,
      'replaceableTag': config.replaceableTag,
      'biomeSelector': biomeSelector,
      'deepslateVariant': config.deepslateVariant,
      'deepslateTransitionY': config.deepslateTransitionY,
    });

    manifest['ore_features'] = oreFeatures;

    // Create .redstone directory if it doesn't exist
    final redstoneDir = Directory('.redstone');
    if (!redstoneDir.existsSync()) {
      redstoneDir.createSync(recursive: true);
    }

    // Write manifest with pretty formatting
    final encoder = JsonEncoder.withIndent('  ');
    manifestFile.writeAsStringSync(encoder.convert(manifest));

    print('WorldGeneration: Wrote ore feature $id to manifest');
  }
}
