import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/logger.dart';

/// Utilities for synchronizing bridge code between source and project via symlinks
class BridgeSync {
  // ===========================================================================
  // Version file utilities (used by multiple sync systems)
  // ===========================================================================

  /// Read version.json from a project's .redstone directory
  ///
  /// Returns null if the file doesn't exist or can't be parsed.
  static Map<String, dynamic>? readVersionInfo(String projectDir) {
    final versionFile = File(p.join(projectDir, '.redstone', 'version.json'));
    if (!versionFile.existsSync()) {
      return null;
    }

    try {
      return jsonDecode(versionFile.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Write version.json to a project's .redstone directory
  static void writeVersionInfo(String projectDir, Map<String, dynamic> info) {
    final versionFile = File(p.join(projectDir, '.redstone', 'version.json'));
    versionFile.parent.createSync(recursive: true);
    versionFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(info),
    );
  }

  /// Returns an identifier for the bridge source (path-based, not content hash)
  ///
  /// With symlinks, we don't need content hashing. This returns a stable identifier
  /// based on the bridge source location for backward compatibility with version.json.
  static String computeSourceBridgeHash() {
    final bridgeSrcDir = getBridgeSrcDir();
    if (bridgeSrcDir == null) return 'symlink';
    return 'symlink:$bridgeSrcDir';
  }

  // ===========================================================================
  // Package directory utilities
  // ===========================================================================

  /// Find the packages directory containing the source bridge code
  ///
  /// Returns null if not found.
  static String? findPackagesDir() {
    // Try to find the packages/ directory that contains redstone_cli, java_mc_bridge, etc.
    var dir = Directory(Platform.script.toFilePath()).parent;

    // Walk up looking for pubspec.yaml with name: redstone_cli
    for (var i = 0; i < 5; i++) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (content.contains('name: redstone_cli')) {
          // packages/redstone_cli -> packages/
          return dir.parent.path;
        }
      }
      dir = dir.parent;
    }

    // Fallback: look for packages directory relative to script
    final scriptDir = Platform.script.toFilePath();
    if (scriptDir.contains('packages/')) {
      final idx = scriptDir.indexOf('packages/');
      return scriptDir.substring(0, idx + 'packages'.length);
    }

    return null;
  }

  /// Get the java_mc_bridge src directory path
  static String? getBridgeSrcDir() {
    final packagesDir = findPackagesDir();
    if (packagesDir == null) return null;
    return p.join(packagesDir, 'java_mc_bridge', 'src');
  }

  /// Create a symlink, removing any existing file/directory/symlink at target
  static void _createSymlink(String targetPath, String linkPath) {
    final link = Link(linkPath);

    // Remove existing entity at link path
    if (link.existsSync()) {
      link.deleteSync();
    } else if (FileSystemEntity.isDirectorySync(linkPath)) {
      Directory(linkPath).deleteSync(recursive: true);
    } else if (FileSystemEntity.isFileSync(linkPath)) {
      File(linkPath).deleteSync();
    }

    // Create the symlink
    link.createSync(targetPath);
  }

  /// Ensure bridge symlinks exist and point to the correct source
  ///
  /// Creates symlinks:
  /// - .redstone/bridge/java -> {java_mc_bridge}/src/main/java
  /// - .redstone/bridge/client -> {java_mc_bridge}/src/client
  /// - .redstone/bridge/resources -> {java_mc_bridge}/src/main/resources
  ///
  /// Returns true if symlinks were created/updated, false if already correct.
  static Future<bool> syncIfNeeded(String projectDir) async {
    final bridgeSrcDir = getBridgeSrcDir();
    if (bridgeSrcDir == null) {
      Logger.warning('Could not find java_mc_bridge source directory');
      return false;
    }

    if (!Directory(bridgeSrcDir).existsSync()) {
      Logger.warning('Bridge source not found at $bridgeSrcDir');
      return false;
    }

    final bridgeDir = p.join(projectDir, '.redstone', 'bridge');

    // Ensure bridge directory exists
    Directory(bridgeDir).createSync(recursive: true);

    var updated = false;

    // Define symlink mappings: link name -> source subdirectory
    final symlinks = {
      'java': p.join(bridgeSrcDir, 'main', 'java'),
      'client': p.join(bridgeSrcDir, 'client'),
      'resources': p.join(bridgeSrcDir, 'main', 'resources'),
    };

    for (final entry in symlinks.entries) {
      final linkPath = p.join(bridgeDir, entry.key);
      final targetPath = entry.value;

      // Check if source exists
      if (!Directory(targetPath).existsSync()) {
        Logger.warning('Bridge source ${entry.key} not found at $targetPath');
        continue;
      }

      // Check if symlink already exists and points to correct target
      final link = Link(linkPath);
      if (link.existsSync()) {
        try {
          final currentTarget = link.targetSync();
          if (currentTarget == targetPath) {
            continue; // Already correct
          }
        } catch (_) {
          // Link exists but can't read target, recreate it
        }
      }

      // Create/update symlink
      Logger.info('Creating symlink: ${entry.key} -> $targetPath');
      _createSymlink(targetPath, linkPath);
      updated = true;
    }

    return updated;
  }

  /// Check if bridge symlinks are properly set up
  static bool isSymlinked(String projectDir) {
    final bridgeDir = p.join(projectDir, '.redstone', 'bridge');

    for (final name in ['java', 'client', 'resources']) {
      final linkPath = p.join(bridgeDir, name);
      if (!Link(linkPath).existsSync()) {
        return false;
      }
    }

    return true;
  }

  /// Get the target path of a bridge symlink
  static String? getSymlinkTarget(String projectDir, String name) {
    final linkPath = p.join(projectDir, '.redstone', 'bridge', name);
    final link = Link(linkPath);

    if (!link.existsSync()) {
      return null;
    }

    try {
      return link.targetSync();
    } catch (_) {
      return null;
    }
  }
}
