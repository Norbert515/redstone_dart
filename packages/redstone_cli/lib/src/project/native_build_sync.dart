import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../util/logger.dart';
import 'bridge_sync.dart';

/// Utilities for automatically rebuilding native libraries when sources change
class NativeBuildSync {
  /// Rebuilds native library if sources changed.
  ///
  /// Returns true if rebuild was performed, false if already up-to-date.
  static Future<bool> rebuildIfNeeded(String projectDir) async {
    final nativeBridgeDir = findNativeBridgeDir();
    if (nativeBridgeDir == null) {
      Logger.debug('Could not find native_mc_bridge directory (development mode)');
      return false;
    }

    final srcDir = Directory(p.join(nativeBridgeDir, 'src'));
    if (!srcDir.existsSync()) {
      Logger.debug('Native source directory not found at ${srcDir.path}');
      return false;
    }

    // Compute current hash of source files
    final currentHash = computeSourceHash(srcDir);
    final storedHash = _getStoredNativeHash(projectDir);

    if (storedHash == currentHash) {
      Logger.debug('Native library up to date');
      return false;
    }

    // Need to rebuild
    Logger.info('Native sources changed, rebuilding...');

    // Run CMake build
    final buildSuccess = await _runCMakeBuild(nativeBridgeDir);
    if (!buildSuccess) {
      return false;
    }

    // Copy output library to .redstone/native/
    final copySuccess = await _copyBuiltLibrary(nativeBridgeDir, projectDir);
    if (!copySuccess) {
      return false;
    }

    // Update stored hash
    _updateNativeHash(projectDir, currentHash);

    return true;
  }

  /// Find the native_mc_bridge package directory
  ///
  /// Returns null if not found.
  static String? findNativeBridgeDir() {
    final packagesDir = BridgeSync.findPackagesDir();
    if (packagesDir == null) return null;

    final nativeBridgeDir = Directory(p.join(packagesDir, 'native_mc_bridge'));
    if (nativeBridgeDir.existsSync()) {
      return nativeBridgeDir.path;
    }

    return null;
  }

  /// Compute hash of native source files (.cpp, .h)
  ///
  /// Returns a deterministic SHA-256 hash based on file paths and contents.
  static String computeSourceHash(Directory srcDir) {
    if (!srcDir.existsSync()) {
      return '';
    }

    final fileHashes = <String>[];

    // Get all .cpp and .h files recursively and sort for determinism
    final files = srcDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) {
          final ext = p.extension(f.path).toLowerCase();
          return ext == '.cpp' || ext == '.h' || ext == '.c' || ext == '.hpp';
        })
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      // Get relative path for determinism across machines
      final relativePath = p.relative(file.path, from: srcDir.path);
      final content = file.readAsBytesSync();
      final contentHash = sha256.convert(content).toString();

      // Include both path and content in the hash input
      fileHashes.add('$relativePath:$contentHash');
    }

    // Compute final hash from all file hashes
    final combinedInput = fileHashes.join('\n');
    return sha256.convert(utf8.encode(combinedInput)).toString();
  }

  /// Get the stored native source hash from version.json
  static String? _getStoredNativeHash(String projectDir) {
    final info = BridgeSync.readVersionInfo(projectDir);
    return info?['native_source_hash'] as String?;
  }

  /// Update the native source hash in version.json
  static void _updateNativeHash(String projectDir, String hash) {
    final existing = BridgeSync.readVersionInfo(projectDir) ?? {};
    existing['native_source_hash'] = hash;
    BridgeSync.writeVersionInfo(projectDir, existing);
  }

  /// Run CMake to build the native library
  ///
  /// Returns true if build succeeded, false otherwise.
  static Future<bool> _runCMakeBuild(String nativeBridgeDir) async {
    final buildDir = Directory(p.join(nativeBridgeDir, 'build'));

    // Check if CMake is available
    try {
      final cmakeCheck = await Process.run('cmake', ['--version']);
      if (cmakeCheck.exitCode != 0) {
        Logger.warning('CMake not found - skipping native library rebuild');
        return false;
      }
    } catch (_) {
      Logger.warning('CMake not available - skipping native library rebuild');
      return false;
    }

    // If build directory doesn't exist, run CMake configure first
    if (!buildDir.existsSync()) {
      Logger.debug('Configuring CMake build...');
      final configResult = await Process.run(
        'cmake',
        ['-B', 'build', '.'],
        workingDirectory: nativeBridgeDir,
      );

      if (configResult.exitCode != 0) {
        Logger.error('CMake configure failed:');
        if (configResult.stderr.toString().isNotEmpty) {
          Logger.error(configResult.stderr.toString());
        }
        throw Exception('CMake configure failed');
      }
    }

    // Run CMake build
    Logger.debug('Building native library...');
    final buildResult = await Process.run(
      'cmake',
      ['--build', 'build'],
      workingDirectory: nativeBridgeDir,
    );

    if (buildResult.exitCode != 0) {
      Logger.error('CMake build failed:');
      if (buildResult.stderr.toString().isNotEmpty) {
        Logger.error(buildResult.stderr.toString());
      }
      if (buildResult.stdout.toString().isNotEmpty) {
        Logger.error(buildResult.stdout.toString());
      }
      throw Exception('CMake build failed');
    }

    Logger.debug('Native library build completed');
    return true;
  }

  /// Copy the built library to the project's .redstone/native/ directory
  ///
  /// Returns true if copy succeeded, false otherwise.
  static Future<bool> _copyBuiltLibrary(
    String nativeBridgeDir,
    String projectDir,
  ) async {
    final libraryName = _getLibraryName();
    final builtLibrary = File(p.join(nativeBridgeDir, 'build', libraryName));

    if (!builtLibrary.existsSync()) {
      Logger.warning('Built library not found at ${builtLibrary.path}');
      return false;
    }

    final targetDir = Directory(p.join(projectDir, '.redstone', 'native'));
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final targetPath = p.join(targetDir.path, libraryName);
    builtLibrary.copySync(targetPath);

    Logger.debug('Copied native library to $targetPath');
    return true;
  }

  /// Get the platform-specific library name
  static String _getLibraryName() {
    if (Platform.isMacOS) {
      return 'dart_mc_bridge.dylib';
    } else if (Platform.isWindows) {
      return 'dart_mc_bridge.dll';
    } else if (Platform.isLinux) {
      return 'dart_mc_bridge.so';
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }
  }
}
