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

  /// Custom entry points from redstone.yaml (if specified)
  final String? _serverEntryPoint;
  final String? _clientEntryPoint;
  final String? _datagenEntryPoint;

  /// Custom package directories from redstone.yaml (if specified)
  final String? _serverPackageDir;
  final String? _clientPackageDir;
  final String? _commonPackageDir;

  RedstoneProject._({
    required this.rootDir,
    required this.name,
    required this.description,
    required this.minecraftVersion,
    required this.org,
    required this.author,
    String? serverEntryPoint,
    String? clientEntryPoint,
    String? datagenEntryPoint,
    String? serverPackageDir,
    String? clientPackageDir,
    String? commonPackageDir,
  })  : _serverEntryPoint = serverEntryPoint,
        _clientEntryPoint = clientEntryPoint,
        _datagenEntryPoint = datagenEntryPoint,
        _serverPackageDir = serverPackageDir,
        _clientPackageDir = clientPackageDir,
        _commonPackageDir = commonPackageDir;

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

  /// Directory for Flutter assets (kernel_blob.bin, etc.)
  String get flutterAssetsDir => p.join(redstoneDir, 'flutter_assets');

  /// Path to the main Dart entry point
  String get entryPoint => p.join(rootDir, 'lib', 'main.dart');

  /// Path to the server entry point (dual-runtime mode)
  /// Falls back to lib/server/main.dart if not specified in redstone.yaml
  String get serverEntry =>
      _serverEntryPoint != null
          ? p.join(rootDir, _serverEntryPoint!)
          : p.join(rootDir, 'lib', 'server', 'main.dart');

  /// Path to the client entry point (dual-runtime mode)
  /// Falls back to lib/client/main.dart if not specified in redstone.yaml
  String get clientEntry =>
      _clientEntryPoint != null
          ? p.join(rootDir, _clientEntryPoint!)
          : p.join(rootDir, 'lib', 'client', 'main.dart');

  /// Path to the datagen entry point
  /// Falls back to lib/main.dart if not specified in redstone.yaml
  String get datagenEntry =>
      _datagenEntryPoint != null
          ? p.join(rootDir, _datagenEntryPoint!)
          : entryPoint;

  /// Directory containing server package (dual-runtime mode)
  /// Falls back to lib/server if not specified in redstone.yaml
  String get serverPackageDir =>
      _serverPackageDir != null
          ? p.join(rootDir, _serverPackageDir!)
          : p.join(rootDir, 'lib', 'server');

  /// Directory containing client package (dual-runtime mode)
  /// Falls back to lib/client if not specified in redstone.yaml
  String get clientPackageDir =>
      _clientPackageDir != null
          ? p.join(rootDir, _clientPackageDir!)
          : p.join(rootDir, 'lib', 'client');

  /// Directory containing common package (dual-runtime mode)
  /// Falls back to lib/common if not specified in redstone.yaml
  String get commonPackageDir =>
      _commonPackageDir != null
          ? p.join(rootDir, _commonPackageDir!)
          : p.join(rootDir, 'lib', 'common');

  /// Check if project uses dual-runtime mode (has separate server/client entries)
  bool get hasDualRuntime =>
      _serverEntryPoint != null || _clientEntryPoint != null;

  /// Path to .dart_tool/package_config.json
  String get packagesConfigPath => p.join(rootDir, '.dart_tool', 'package_config.json');

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

  /// Try to load redstone.yaml from the project root.
  /// Returns a map with entry_points and packages configuration.
  static Map<String, dynamic>? _tryLoadRedstoneYaml(String rootDir) {
    try {
      final redstoneYamlFile = File(p.join(rootDir, 'redstone.yaml'));
      if (!redstoneYamlFile.existsSync()) {
        return null;
      }

      final content = redstoneYamlFile.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap;

      final result = <String, dynamic>{};

      // Parse entry_points section
      if (yaml.containsKey('entry_points')) {
        final entryPoints = yaml['entry_points'] as YamlMap;
        result['serverEntry'] = entryPoints['server'] as String?;
        result['clientEntry'] = entryPoints['client'] as String?;
        result['datagenEntry'] = entryPoints['datagen'] as String?;
      }

      // Parse packages section
      if (yaml.containsKey('packages')) {
        final packages = yaml['packages'] as YamlMap;
        result['serverPackage'] = packages['server'] as String?;
        result['clientPackage'] = packages['client'] as String?;
        result['commonPackage'] = packages['common'] as String?;
      }

      return result;
    } catch (_) {
      return null;
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
      final rootDir = pubspecFile.parent.path;

      // Try to load redstone.yaml for custom entry points and packages
      final redstoneYamlConfig = _tryLoadRedstoneYaml(rootDir);

      return RedstoneProject._(
        rootDir: rootDir,
        name: name,
        description: description,
        minecraftVersion: redstone['minecraft_version'] as String? ?? '1.21.11',
        org: redstone['org'] as String? ?? 'com.example',
        author: redstone['author'] as String? ?? 'Unknown',
        serverEntryPoint: redstoneYamlConfig?['serverEntry'] as String?,
        clientEntryPoint: redstoneYamlConfig?['clientEntry'] as String?,
        datagenEntryPoint: redstoneYamlConfig?['datagenEntry'] as String?,
        serverPackageDir: redstoneYamlConfig?['serverPackage'] as String?,
        clientPackageDir: redstoneYamlConfig?['clientPackage'] as String?,
        commonPackageDir: redstoneYamlConfig?['commonPackage'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
