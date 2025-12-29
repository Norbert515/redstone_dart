import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../util/logger.dart';

/// Utilities for synchronizing bridge code between source and project
class BridgeSync {
  /// Compute a content hash of all files in a directory
  ///
  /// Returns a deterministic SHA-256 hash based on file paths and contents.
  /// Files are processed in sorted order to ensure consistent results.
  static String computeDirectoryHash(Directory directory) {
    if (!directory.existsSync()) {
      return '';
    }

    final fileHashes = <String>[];

    // Get all files recursively and sort for determinism
    final files = directory
        .listSync(recursive: true)
        .whereType<File>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      // Get relative path for determinism across machines
      final relativePath = p.relative(file.path, from: directory.path);
      final content = file.readAsBytesSync();
      final contentHash = sha256.convert(content).toString();

      // Include both path and content in the hash input
      fileHashes.add('$relativePath:$contentHash');
    }

    // Compute final hash from all file hashes
    final combinedInput = fileHashes.join('\n');
    return sha256.convert(utf8.encode(combinedInput)).toString();
  }

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

  /// Get the stored bridge content hash from a project's version.json
  ///
  /// Returns null if version.json doesn't exist or doesn't have the hash field.
  static String? getStoredBridgeHash(String projectDir) {
    final info = readVersionInfo(projectDir);
    return info?['bridge_content_hash'] as String?;
  }

  /// Update the bridge content hash in a project's version.json
  ///
  /// Preserves existing fields in version.json.
  static void updateBridgeHash(String projectDir, String hash) {
    final existing = readVersionInfo(projectDir) ?? {};
    existing['bridge_content_hash'] = hash;
    writeVersionInfo(projectDir, existing);
  }

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

  /// Get the source bridge directory path (main source set)
  static String? getSourceBridgeDir() {
    final packagesDir = findPackagesDir();
    if (packagesDir == null) return null;
    return p.join(packagesDir, 'java_mc_bridge', 'src', 'main');
  }

  /// Get the client source bridge directory path (client source set)
  static String? getClientSourceBridgeDir() {
    final packagesDir = findPackagesDir();
    if (packagesDir == null) return null;
    return p.join(packagesDir, 'java_mc_bridge', 'src', 'client');
  }

  /// Get the resources directory path (contains access widener, etc.)
  static String? getResourcesDir() {
    final packagesDir = findPackagesDir();
    if (packagesDir == null) return null;
    return p.join(packagesDir, 'java_mc_bridge', 'src', 'main', 'resources');
  }

  /// Copy bridge code from source to target directory
  static Future<void> copyBridgeCode(
    Directory source,
    Directory target,
  ) async {
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }

    // Clear existing bridge directory contents
    if (target.existsSync()) {
      for (final entity in target.listSync()) {
        if (entity is Directory) {
          entity.deleteSync(recursive: true);
        } else if (entity is File) {
          entity.deleteSync();
        }
      }
    }

    await _copyDirectory(source, target);
  }

  static Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        entity.copySync(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }

  /// Check if bridge code needs to be synced and sync if necessary
  ///
  /// Returns true if sync was performed, false if already up-to-date.
  static Future<bool> syncIfNeeded(String projectDir) async {
    final sourceDirPath = getSourceBridgeDir();
    if (sourceDirPath == null) {
      Logger.warning('Could not find bridge source directory');
      return false;
    }

    final sourceDir = Directory(sourceDirPath);
    if (!sourceDir.existsSync()) {
      Logger.warning('Bridge source not found at $sourceDirPath');
      return false;
    }

    final currentHash = computeSourceBridgeHash();
    final storedHash = getStoredBridgeHash(projectDir);

    if (storedHash == currentHash) {
      return false; // Already up-to-date
    }

    // Need to sync
    Logger.info('Bridge code updated (hash mismatch detected)');

    // Sync main bridge code
    final targetDir = Directory(p.join(projectDir, '.redstone', 'bridge'));
    await copyBridgeCode(sourceDir, targetDir);

    // Sync client bridge code if it exists
    final clientSourceDirPath = getClientSourceBridgeDir();
    if (clientSourceDirPath != null) {
      final clientSourceDir = Directory(clientSourceDirPath);
      if (clientSourceDir.existsSync()) {
        final clientTargetDir = Directory(p.join(projectDir, '.redstone', 'bridge', 'client'));
        await copyBridgeCode(clientSourceDir, clientTargetDir);
      }
    }

    // Sync resources (access widener, etc.)
    final resourcesDirPath = getResourcesDir();
    if (resourcesDirPath != null) {
      final resourcesDir = Directory(resourcesDirPath);
      if (resourcesDir.existsSync()) {
        final resourcesTargetDir = Directory(p.join(projectDir, '.redstone', 'bridge', 'resources'));
        await copyBridgeCode(resourcesDir, resourcesTargetDir);
      }
    }

    updateBridgeHash(projectDir, currentHash);

    return true;
  }

  /// Compute the current source bridge hash
  ///
  /// Includes both main and client source directories.
  /// Returns empty string if source not found.
  static String computeSourceBridgeHash() {
    final mainSourceDirPath = getSourceBridgeDir();
    if (mainSourceDirPath == null) return '';

    final mainSourceDir = Directory(mainSourceDirPath);
    if (!mainSourceDir.existsSync()) return '';

    // Compute hash for main source
    final mainHash = computeDirectoryHash(mainSourceDir);

    // Build combined hash from all source directories
    final hashParts = <String>['main:$mainHash'];

    // Include client source in hash if it exists
    final clientSourceDirPath = getClientSourceBridgeDir();
    if (clientSourceDirPath != null) {
      final clientSourceDir = Directory(clientSourceDirPath);
      if (clientSourceDir.existsSync()) {
        final clientHash = computeDirectoryHash(clientSourceDir);
        hashParts.add('client:$clientHash');
      }
    }

    // Include resources in hash (access widener, etc.)
    final resourcesDirPath = getResourcesDir();
    if (resourcesDirPath != null) {
      final resourcesDir = Directory(resourcesDirPath);
      if (resourcesDir.existsSync()) {
        final resourcesHash = computeDirectoryHash(resourcesDir);
        hashParts.add('resources:$resourcesHash');
      }
    }

    if (hashParts.length == 1) {
      return mainHash;
    }

    final combinedInput = hashParts.join('\n');
    return sha256.convert(utf8.encode(combinedInput)).toString();
  }
}
