import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../project/redstone_project.dart';

/// Generates Minecraft resource files from a manifest produced by the Dart mod.
class AssetGenerator {
  final RedstoneProject project;

  AssetGenerator(this.project);

  /// Generate all assets from the manifest.
  Future<void> generate() async {
    final manifest = await _readManifest();
    if (manifest == null) return; // No manifest = no custom blocks with models

    final blocks = manifest['blocks'] as List<dynamic>? ?? [];
    final items = manifest['items'] as List<dynamic>? ?? [];
    final entities = manifest['entities'] as List<dynamic>? ?? [];
    final oreFeatures = manifest['ore_features'] as List<dynamic>? ?? [];

    for (final block in blocks) {
      await _generateBlockAssets(block as Map<String, dynamic>);
    }

    // Generate item assets
    for (final item in items) {
      await _generateItemAssets(item as Map<String, dynamic>);
    }

    // Generate loot tables for blocks
    await _generateLootTables(blocks);

    // Generate worldgen assets for ore features
    for (final oreFeature in oreFeatures) {
      await _generateOreFeatureAssets(oreFeature as Map<String, dynamic>);
    }

    await _copyTextures();
    await _copyEntityTextures(entities);
    await _generateLangFile(blocks, items);
  }

  Future<Map<String, dynamic>?> _readManifest() async {
    // In datagen mode (CLI context), manifest is written to project root
    // at .redstone/manifest.json
    final manifestPath = p.join(project.rootDir, '.redstone', 'manifest.json');
    final manifestFile = File(manifestPath);
    if (!manifestFile.existsSync()) return null;
    final content = await manifestFile.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<void> _generateBlockAssets(Map<String, dynamic> block) async {
    final id = block['id'] as String; // e.g., 'mymod:hello_block'
    final model = block['model'] as Map<String, dynamic>?;
    if (model == null) return;

    final namespace = id.split(':')[0];
    final blockName = id.split(':')[1];

    await _generateBlockstate(namespace, blockName, model);
    await _generateBlockModel(namespace, blockName, model);
    await _generateBlockItemModel(namespace, blockName);
    // 1.21.4+: Generate item model definition in items/ folder
    await _generateItemModelDefinition(namespace, blockName, '$namespace:block/$blockName');
  }

  Future<void> _generateBlockstate(
    String namespace,
    String blockName,
    Map<String, dynamic> model,
  ) async {
    // Generate blockstates/{blockName}.json
    final type = model['type'] as String;

    Map<String, dynamic> blockstate;
    if (type == 'orientable_cube_column') {
      // Rotatable blocks need axis variants
      blockstate = {
        'variants': {
          'axis=x': {'model': '$namespace:block/$blockName', 'x': 90, 'y': 90},
          'axis=y': {'model': '$namespace:block/$blockName'},
          'axis=z': {'model': '$namespace:block/$blockName', 'x': 90},
        }
      };
    } else {
      blockstate = {
        'variants': {
          '': {'model': '$namespace:block/$blockName'}
        }
      };
    }

    final path = p.join(
      project.minecraftAssetsDir(namespace),
      'blockstates',
      '$blockName.json',
    );
    await _writeJson(path, blockstate);
  }

  Future<void> _generateBlockModel(
    String namespace,
    String blockName,
    Map<String, dynamic> model,
  ) async {
    final type = model['type'] as String;

    // Handle elements-based models separately
    if (type == 'elements') {
      await _generateElementsBlockModel(namespace, blockName, model);
      return;
    }

    final textures = model['textures'] as Map<String, dynamic>;

    // Map type to Minecraft parent model
    final parent = switch (type) {
      'cube_all' => 'minecraft:block/cube_all',
      'cube_column' => 'minecraft:block/cube_column',
      'cube_bottom_top' => 'minecraft:block/cube_bottom_top',
      'orientable_cube_column' => 'minecraft:block/cube_column',
      'custom' => model['modelPath'] as String,
      _ => 'minecraft:block/cube_all',
    };

    // Convert file paths to Minecraft texture references
    final mcTextures = <String, String>{};
    for (final entry in textures.entries) {
      mcTextures[entry.key] =
          _filePathToTextureRef(namespace, entry.value as String);
    }

    final blockModel = {
      'parent': parent,
      'textures': mcTextures,
    };

    final path = p.join(
      project.minecraftAssetsDir(namespace),
      'models',
      'block',
      '$blockName.json',
    );
    await _writeJson(path, blockModel);
  }

  /// Generate a block model using custom elements
  ///
  /// For animated blocks with per-element animation, this generates two models:
  /// - `{blockName}.json` - contains ONLY static elements (animated: false)
  /// - `{blockName}_animated.json` - contains ONLY animated elements (animated: true, default)
  ///
  /// The renderer will load the static model and render it without transforms,
  /// then load the animated model and render it with animation transforms.
  Future<void> _generateElementsBlockModel(
    String namespace,
    String blockName,
    Map<String, dynamic> model,
  ) async {
    final textures = model['textures'] as Map<String, dynamic>;
    final elements = model['elements'] as List<dynamic>;
    final parent = model['parent'] as String?;
    final ambientOcclusion = model['ambientOcclusion'] as bool?;

    // Convert file paths to Minecraft texture references
    final mcTextures = <String, String>{};
    for (final entry in textures.entries) {
      mcTextures[entry.key] =
          _filePathToTextureRef(namespace, entry.value as String);
    }

    // Check if any elements have __animated: false (per-element animation)
    final staticElements = <dynamic>[];
    final animatedElements = <dynamic>[];

    for (final element in elements) {
      final elementMap = element as Map<String, dynamic>;
      // __animated is our internal marker; default is true
      final isAnimated = elementMap['__animated'] ?? true;

      // Create a clean copy without our internal markers
      final cleanElement = Map<String, dynamic>.from(elementMap);
      cleanElement.remove('__animated');
      cleanElement.remove('__name');

      if (isAnimated) {
        animatedElements.add(cleanElement);
      } else {
        staticElements.add(cleanElement);
      }
    }

    // Determine if we need to split the model
    final hasStaticElements = staticElements.isNotEmpty;
    final hasAnimatedElements = animatedElements.isNotEmpty;
    final needsSplit = hasStaticElements && hasAnimatedElements;

    if (needsSplit) {
      // Generate static model (body, etc.)
      final staticModel = <String, dynamic>{
        'textures': mcTextures,
        'elements': staticElements,
      };
      if (parent != null) staticModel['parent'] = parent;
      if (ambientOcclusion != null) {
        staticModel['ambientocclusion'] = ambientOcclusion;
      }

      final staticPath = p.join(
        project.minecraftAssetsDir(namespace),
        'models',
        'block',
        '$blockName.json',
      );
      await _writeJson(staticPath, staticModel);

      // Generate animated model (lid, latch, etc.)
      final animatedModel = <String, dynamic>{
        'textures': mcTextures,
        'elements': animatedElements,
      };
      if (parent != null) animatedModel['parent'] = parent;
      if (ambientOcclusion != null) {
        animatedModel['ambientocclusion'] = ambientOcclusion;
      }

      final animatedPath = p.join(
        project.minecraftAssetsDir(namespace),
        'models',
        'block',
        '${blockName}_animated.json',
      );
      await _writeJson(animatedPath, animatedModel);

      print(
          'Generated split models for $namespace:$blockName (${staticElements.length} static, ${animatedElements.length} animated elements)');
    } else {
      // No split needed - generate single model with all elements
      // Clean the elements of internal markers
      final cleanElements = elements.map((e) {
        final elementMap = e as Map<String, dynamic>;
        final clean = Map<String, dynamic>.from(elementMap);
        clean.remove('__animated');
        clean.remove('__name');
        return clean;
      }).toList();

      final blockModel = <String, dynamic>{
        'textures': mcTextures,
        'elements': cleanElements,
      };

      if (parent != null) {
        blockModel['parent'] = parent;
      }
      if (ambientOcclusion != null) {
        blockModel['ambientocclusion'] = ambientOcclusion;
      }

      final path = p.join(
        project.minecraftAssetsDir(namespace),
        'models',
        'block',
        '$blockName.json',
      );
      await _writeJson(path, blockModel);
    }
  }

  /// Generate item model for a block (references the block model as parent)
  Future<void> _generateBlockItemModel(
    String namespace,
    String blockName,
  ) async {
    final itemModel = {
      'parent': '$namespace:block/$blockName',
    };

    final path = p.join(
      project.minecraftAssetsDir(namespace),
      'models',
      'item',
      '$blockName.json',
    );
    await _writeJson(path, itemModel);
  }

  Future<void> _generateItemAssets(Map<String, dynamic> item) async {
    final id = item['id'] as String; // e.g., 'mymod:dart_item'
    final model = item['model'] as Map<String, dynamic>?;
    if (model == null) return;

    final namespace = id.split(':')[0];
    final itemName = id.split(':')[1];

    await _generateItemModel(namespace, itemName, model);
    // 1.21.4+: Generate item model definition in items/ folder
    await _generateItemModelDefinition(namespace, itemName, '$namespace:item/$itemName');
  }

  Future<void> _generateItemModel(
    String namespace,
    String itemName,
    Map<String, dynamic> model,
  ) async {
    final type = model['type'] as String;
    final texture = model['texture'] as String;

    // Map type to Minecraft parent model
    final parent = switch (type) {
      'generated' => 'minecraft:item/generated',
      'handheld' => 'minecraft:item/handheld',
      _ => 'minecraft:item/generated',
    };

    final itemModel = {
      'parent': parent,
      'textures': {
        'layer0': _filePathToTextureRef(namespace, texture),
      },
    };

    final path = p.join(
      project.minecraftAssetsDir(namespace),
      'models',
      'item',
      '$itemName.json',
    );
    await _writeJson(path, itemModel);
  }

  /// Generate item model definition for 1.21.4+
  /// These go in assets/<namespace>/items/<name>.json
  /// and point to the actual model in models/block/ or models/item/
  Future<void> _generateItemModelDefinition(
    String namespace,
    String itemName,
    String modelRef,
  ) async {
    final itemDef = {
      'model': {
        'type': 'minecraft:model',
        'model': modelRef,
      }
    };

    final path = p.join(
      project.minecraftAssetsDir(namespace),
      'items',
      '$itemName.json',
    );
    await _writeJson(path, itemDef);
  }

  /// Convert 'assets/textures/block/hello.png' to 'mymod:block/hello'
  /// Convert 'assets/textures/item/dart.png' to 'mymod:item/dart'
  /// Already namespaced refs like 'minecraft:block/diamond_ore' are passed through unchanged
  String _filePathToTextureRef(String namespace, String filePath) {
    // If already namespaced (e.g., 'minecraft:block/diamond_ore'), pass through
    if (filePath.contains(':')) {
      return filePath;
    }

    // Remove 'assets/textures/' prefix and '.png' suffix
    var ref = filePath;
    if (ref.startsWith('assets/textures/')) {
      ref = ref.substring('assets/textures/'.length);
    }
    if (ref.endsWith('.png')) {
      ref = ref.substring(0, ref.length - 4);
    }
    return '$namespace:$ref';
  }

  Future<void> _generateLootTables(List<dynamic> blocks) async {
    for (final block in blocks) {
      final blockMap = block as Map<String, dynamic>;
      final id = blockMap['id'] as String;
      final drops = blockMap['drops'] as String?;

      final namespace = id.split(':')[0];
      final blockName = id.split(':')[1];

      // Determine what the block drops
      final dropItem = drops ?? id; // Default: drop itself (BlockItem)

      final lootTable = {
        'type': 'minecraft:block',
        'pools': [
          {
            'rolls': 1.0,
            'bonus_rolls': 0.0,
            'entries': [
              {
                'type': 'minecraft:item',
                'name': dropItem,
              }
            ],
            'conditions': [
              {'condition': 'minecraft:survives_explosion'}
            ]
          }
        ]
      };

      // Loot tables go in data/{namespace}/loot_table/blocks/{block}.json
      final path = p.join(
        project.minecraftDir,
        'src',
        'main',
        'resources',
        'data',
        namespace,
        'loot_table',
        'blocks',
        '$blockName.json',
      );
      await _writeJson(path, lootTable);
    }
  }

  /// Generate worldgen JSON files for ore features.
  ///
  /// Creates:
  /// - data/<namespace>/worldgen/configured_feature/<name>.json
  /// - data/<namespace>/worldgen/placed_feature/<name>.json
  Future<void> _generateOreFeatureAssets(Map<String, dynamic> oreFeature) async {
    final id = oreFeature['id'] as String; // e.g., 'mymod:ruby_ore_feature'
    final namespace = id.split(':')[0];
    final featureName = id.split(':')[1];

    final oreBlock = oreFeature['oreBlock'] as String;
    final veinSize = oreFeature['veinSize'] as int;
    final veinsPerChunk = oreFeature['veinsPerChunk'] as int;
    final minY = oreFeature['minY'] as int;
    final maxY = oreFeature['maxY'] as int;
    final distribution = oreFeature['distribution'] as String;
    final replaceableTag = oreFeature['replaceableTag'] as String;
    final deepslateVariant = oreFeature['deepslateVariant'] as String?;

    // Generate ConfiguredFeature JSON
    await _generateConfiguredFeature(
      namespace,
      featureName,
      oreBlock,
      veinSize,
      replaceableTag,
      deepslateVariant,
    );

    // Generate PlacedFeature JSON
    await _generatePlacedFeature(
      namespace,
      featureName,
      veinsPerChunk,
      minY,
      maxY,
      distribution,
    );

    print('Generated worldgen assets for $id');
  }

  Future<void> _generateConfiguredFeature(
    String namespace,
    String featureName,
    String oreBlock,
    int veinSize,
    String replaceableTag,
    String? deepslateVariant,
  ) async {
    final targets = <Map<String, dynamic>>[
      {
        'state': {'Name': oreBlock},
        'target': {
          'predicate_type': 'minecraft:tag_match',
          'tag': replaceableTag,
        },
      },
    ];

    // Add deepslate variant if specified
    if (deepslateVariant != null && deepslateVariant.isNotEmpty) {
      targets.add({
        'state': {'Name': deepslateVariant},
        'target': {
          'predicate_type': 'minecraft:tag_match',
          'tag': 'minecraft:deepslate_ore_replaceables',
        },
      });
    }

    final configuredFeature = {
      'type': 'minecraft:ore',
      'config': {
        'discard_chance_on_air_exposure': 0.0,
        'size': veinSize,
        'targets': targets,
      },
    };

    final path = p.join(
      project.minecraftDir,
      'src',
      'main',
      'resources',
      'data',
      namespace,
      'worldgen',
      'configured_feature',
      '$featureName.json',
    );
    await _writeJson(path, configuredFeature);
  }

  Future<void> _generatePlacedFeature(
    String namespace,
    String featureName,
    int veinsPerChunk,
    int minY,
    int maxY,
    String distribution,
  ) async {
    // Map distribution type to Minecraft height provider
    final heightType = switch (distribution.toLowerCase()) {
      'triangle' => 'minecraft:trapezoid',
      'trapezoid' => 'minecraft:trapezoid',
      _ => 'minecraft:uniform',
    };

    final placedFeature = {
      'feature': '$namespace:$featureName',
      'placement': [
        {'type': 'minecraft:count', 'count': veinsPerChunk},
        {'type': 'minecraft:in_square'},
        {
          'type': 'minecraft:height_range',
          'height': {
            'type': heightType,
            'min_inclusive': {'absolute': minY},
            'max_inclusive': {'absolute': maxY},
          },
        },
        {'type': 'minecraft:biome'},
      ],
    };

    final path = p.join(
      project.minecraftDir,
      'src',
      'main',
      'resources',
      'data',
      namespace,
      'worldgen',
      'placed_feature',
      '$featureName.json',
    );
    await _writeJson(path, placedFeature);
  }

  Future<void> _copyTextures() async {
    final sourceDir = Directory(p.join(project.assetsDir, 'textures'));
    if (!sourceDir.existsSync()) return;

    // Get namespace from project name
    final namespace = project.name;
    final targetDir = Directory(
      p.join(
        project.minecraftAssetsDir(namespace),
        'textures',
      ),
    );

    await _copyDirectory(sourceDir, targetDir);
  }

  /// Copy entity textures from manifest entries to the minecraft assets folder.
  Future<void> _copyEntityTextures(List<dynamic> entities) async {
    for (final entity in entities) {
      final entityMap = entity as Map<String, dynamic>;
      final id = entityMap['id'] as String;
      final model = entityMap['model'] as Map<String, dynamic>?;
      if (model == null) continue;

      final texture = model['texture'] as String?;
      if (texture == null) continue;

      final namespace = id.split(':')[0];

      // Source: project assets directory + texture path (e.g., assets/textures/entity/custom_zombie.png)
      final sourceFile = File(p.join(project.rootDir, texture));
      if (!sourceFile.existsSync()) continue;

      // Target: minecraft assets directory (e.g., assets/<namespace>/textures/entity/<filename>)
      final filename = p.basename(texture);
      final targetPath = p.join(
        project.minecraftAssetsDir(namespace),
        'textures',
        'entity',
        filename,
      );

      final targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);
      await sourceFile.copy(targetPath);
    }
  }

  Future<void> _generateLangFile(List<dynamic> blocks, List<dynamic> items) async {
    if (blocks.isEmpty && items.isEmpty) return;

    // Get namespace from first block or item
    String namespace;
    if (blocks.isNotEmpty) {
      namespace = (blocks.first['id'] as String).split(':')[0];
    } else {
      namespace = (items.first['id'] as String).split(':')[0];
    }

    final translations = <String, String>{};

    // Block translations
    for (final block in blocks) {
      final id = block['id'] as String;
      final blockName = id.split(':')[1];
      final displayName = _toDisplayName(blockName);
      translations['block.$namespace.$blockName'] = displayName;
    }

    // Item translations
    for (final item in items) {
      final id = item['id'] as String;
      final itemName = id.split(':')[1];
      final displayName = _toDisplayName(itemName);
      translations['item.$namespace.$itemName'] = displayName;
    }

    final path = p.join(
      project.minecraftAssetsDir(namespace),
      'lang',
      'en_us.json',
    );
    await _writeJson(path, translations);
  }

  /// Convert snake_case to Title Case
  String _toDisplayName(String snakeCase) {
    return snakeCase
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Future<void> _writeJson(String path, Map<String, dynamic> content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(content),
    );
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!source.existsSync()) return;
    if (!target.existsSync()) {
      await target.create(recursive: true);
    }
    await for (final entity in source.list(recursive: false)) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }
}
