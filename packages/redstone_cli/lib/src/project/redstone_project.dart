import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Represents a Redstone project
class RedstoneProject {
  final String rootDir;
  final String name;
  final String description;
  final String minecraftVersion;
  final String org;
  final String author;

  RedstoneProject._({
    required this.rootDir,
    required this.name,
    required this.description,
    required this.minecraftVersion,
    required this.org,
    required this.author,
  });

  /// Directory containing user's Dart code
  String get libDir => p.join(rootDir, 'lib');

  /// Directory containing the Minecraft/Fabric mod
  String get minecraftDir => p.join(rootDir, 'minecraft');

  /// Directory containing Redstone-managed files
  String get redstoneDir => p.join(rootDir, '.redstone');

  /// Directory for native libraries
  String get nativeDir => p.join(redstoneDir, 'native');

  /// Directory for bridge code
  String get bridgeDir => p.join(redstoneDir, 'bridge');

  /// Directory containing user assets (textures, etc.)
  String get assetsDir => p.join(rootDir, 'assets');

  /// Path to generated asset manifest (written by Dart mod at runtime)
  String get manifestPath => p.join(minecraftDir, 'run', '.redstone', 'manifest.json');

  /// Get Minecraft assets directory for a namespace
  String minecraftAssetsDir(String namespace) =>
      p.join(minecraftDir, 'src', 'main', 'resources', 'assets', namespace);

  /// Find a Redstone project by searching up from current directory
  static RedstoneProject? find([String? startDir]) {
    var dir = Directory(startDir ?? Directory.current.path);

    while (true) {
      final pubspecFile = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        final project = _tryLoadProject(pubspecFile);
        if (project != null) {
          return project;
        }
      }

      final parent = dir.parent;
      if (parent.path == dir.path) {
        // Reached root
        return null;
      }
      dir = parent;
    }
  }

  static RedstoneProject? _tryLoadProject(File pubspecFile) {
    try {
      final content = pubspecFile.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap;

      // Check if this has a redstone: section
      if (!yaml.containsKey('redstone')) {
        return null;
      }

      final name = yaml['name'] as String;
      final description = yaml['description'] as String? ?? '';
      final redstone = yaml['redstone'] as YamlMap;

      return RedstoneProject._(
        rootDir: pubspecFile.parent.path,
        name: name,
        description: description,
        minecraftVersion: redstone['minecraft_version'] as String? ?? '1.21.11',
        org: redstone['org'] as String? ?? 'com.example',
        author: redstone['author'] as String? ?? 'Unknown',
      );
    } catch (_) {
      return null;
    }
  }
}
