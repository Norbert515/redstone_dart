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

    for (final block in blocks) {
      await _generateBlockAssets(block as Map<String, dynamic>);
    }

    // Generate item assets
    for (final item in items) {
      await _generateItemAssets(item as Map<String, dynamic>);
    }

    // Generate loot tables for blocks
    await _generateLootTables(blocks);

    await _copyTextures();
    await _generateLangFile(blocks, items);
  }

  Future<Map<String, dynamic>?> _readManifest() async {
    final manifestFile = File(project.manifestPath);
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

  /// Convert 'assets/textures/block/hello.png' to 'mymod:block/hello'
  /// Convert 'assets/textures/item/dart.png' to 'mymod:item/dart'
  String _filePathToTextureRef(String namespace, String filePath) {
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
