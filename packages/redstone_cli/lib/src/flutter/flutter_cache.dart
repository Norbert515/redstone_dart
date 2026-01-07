import 'dart:io';
import 'package:path/path.dart' as p;
import '../util/logger.dart';

/// Manages the redstone Flutter SDK, embedder, and engine artifacts cache at ~/.redstone/
///
/// ## Why This Cache Exists
///
/// Redstone uses a **custom-built Flutter engine** (FlutterEmbedder) to run Dart/Flutter
/// code inside Minecraft. All Flutter/Dart artifacts must have **matching SDK hashes**
/// to work together. Official Flutter downloads from Google have different SDK hashes
/// than our custom engine build, causing "Invalid kernel binary format version" errors.
///
/// This cache ensures all artifacts come from the same engine build and have matching
/// SDK hashes, preventing version mismatches.
///
/// ## Cache Structure
///
/// ```
/// ~/.redstone/
/// └── versions/
///     └── <version>-<engine-hash>/     # e.g., "3.40.0-1.0.pre-379-362d8f1e"
///         │
///         ├── flutter/                  # Symlink → engine Flutter SDK
///         │   └── (used for `flutter build bundle` command)
///         │
///         ├── embedder/                 # Custom-built Flutter engine
///         │   └── FlutterEmbedder.framework/  (macOS)
///         │       └── Loads and executes Dart kernel in Minecraft
///         │
///         └── engine/                   # Engine build output artifacts
///             ├── flutter_patched_sdk/  # Platform SDK
///             │   └── platform_strong.dill  (SDK hash must match embedder)
///             │
///             ├── dart-sdk/             # Dart compilation tools
///             │   └── bin/
///             │       ├── dartaotruntime           (runs frontend_server)
///             │       └── snapshots/
///             │           └── frontend_server_aot.dart.snapshot
///             │                                    (compiles Dart → kernel)
///             │
///             ├── isolate_snapshot.bin  # Pre-initialized VM state
///             ├── vm_isolate_snapshot.bin
///             └── icudtl.dat            # Unicode/i18n data
/// ```
///
/// ## SDK Hash Matching
///
/// All these components embed an SDK hash that MUST match:
///
/// | Component                    | Purpose                              |
/// |------------------------------|--------------------------------------|
/// | FlutterEmbedder.framework    | Runtime that loads kernel (SOURCE OF TRUTH) |
/// | platform_strong.dill         | Platform libs for compilation        |
/// | frontend_server_aot.dart.snapshot | Compiler that produces kernel   |
/// | dartaotruntime               | Runs the frontend_server             |
/// | isolate_snapshot.bin         | VM startup state                     |
/// | vm_isolate_snapshot.bin      | VM-level snapshot                    |
///
/// ## Version Naming
///
/// Format: `<flutter-version>-<engine-hash>`
/// Example: `3.40.0-1.0.pre-379-362d8f1e`
///
/// This allows multiple redstone versions to coexist with different engine builds.
///
/// ## Artifact Sources
///
/// Artifacts are copied from the engine build output:
/// ```
/// engine_build/monorepo/flutter/engine/src/out/mac_debug_unopt_arm64/
/// ├── flutter_patched_sdk/          → engine/flutter_patched_sdk/
/// ├── dart-sdk/                     → engine/dart-sdk/
/// ├── gen/flutter/lib/snapshot/
/// │   ├── isolate_snapshot.bin      → engine/isolate_snapshot.bin
/// │   └── vm_isolate_snapshot.bin   → engine/vm_isolate_snapshot.bin
/// └── icudtl.dat                    → engine/icudtl.dat
///
/// packages/native_mc_bridge/FlutterEmbedder.framework → embedder/
/// engine_build/monorepo/flutter/                      → flutter/ (symlink)
/// ```
class FlutterCache {
  /// The redstone cache directory
  static String get cacheDir {
    final home = Platform.environment['HOME'] ??
                 Platform.environment['USERPROFILE'] ?? '';
    return p.join(home, '.redstone');
  }

  /// The versions cache directory
  static String get versionsCacheDir => p.join(cacheDir, 'versions');

  /// Required Flutter version for this redstone release
  static const String requiredVersion = '3.40.0-1.0.pre-379';

  /// Required engine hash (short form for directory naming)
  static const String requiredEngineHash = '362d8f1e';

  /// Full engine hash for verification
  static const String fullEngineHash = '362d8f1e8cf7993f82e20882f5672e682c17f42f';

  /// Version identifier combining version and engine hash
  static String get versionId => '$requiredVersion-$requiredEngineHash';

  /// Get the path to the versioned cache directory
  static String get versionedCachePath => p.join(versionsCacheDir, versionId);

  /// Get the path to the cached Flutter SDK (symlink)
  static String get cachedFlutterPath => p.join(versionedCachePath, 'flutter');

  /// Get the path to the cached embedder directory
  static String get cachedEmbedderPath => p.join(versionedCachePath, 'embedder');

  /// Get the path to the cached engine artifacts directory
  static String get cachedEnginePath => p.join(versionedCachePath, 'engine');

  /// Get the path to the cached FlutterEmbedder.framework (macOS)
  static String get cachedEmbedderFrameworkPath {
    return p.join(cachedEmbedderPath, 'FlutterEmbedder.framework');
  }

  /// Get the path to the cached flutter_patched_sdk
  static String get cachedPatchedSdkPath {
    return p.join(cachedEnginePath, 'flutter_patched_sdk');
  }

  /// Get the path to the cached dart-sdk
  static String get cachedDartSdkPath {
    return p.join(cachedEnginePath, 'dart-sdk');
  }

  /// Check if the required Flutter SDK is cached
  static bool get isFlutterCached {
    final flutterBin = File(p.join(cachedFlutterPath, 'bin', 'flutter'));
    return flutterBin.existsSync();
  }

  /// Check if the required embedder is cached
  static bool get isEmbedderCached {
    if (Platform.isMacOS) {
      final embedder = File(p.join(
        cachedEmbedderFrameworkPath,
        'Versions', 'A', 'FlutterEmbedder'
      ));
      return embedder.existsSync();
    }
    // TODO: Add Linux and Windows checks
    return false;
  }

  /// Check if the required engine artifacts are cached
  static bool get isEngineCached {
    final patchedSdk = Directory(cachedPatchedSdkPath);
    final dartSdk = Directory(cachedDartSdkPath);
    return patchedSdk.existsSync() && dartSdk.existsSync();
  }

  /// Check if all required artifacts are cached
  static bool get isFullyCached {
    return isFlutterCached && isEmbedderCached && isEngineCached;
  }

  /// Ensure all artifacts are available in cache
  ///
  /// This should be called during install/setup, not during runtime.
  /// It caches:
  /// - Flutter SDK (symlink)
  /// - FlutterEmbedder.framework
  /// - Engine artifacts (flutter_patched_sdk, dart-sdk, etc.)
  static Future<bool> ensureFullyCached() async {
    if (isFullyCached) {
      Logger.debug('All redstone artifacts already cached at $versionedCachePath');
      return true;
    }

    Logger.info('Setting up redstone Flutter environment...');

    // 1. Cache Flutter SDK
    final flutterCached = await ensureFlutterCached();
    if (!flutterCached) return false;

    // 2. Cache embedder
    final embedderCached = await ensureEmbedderCached();
    if (!embedderCached) return false;

    // 3. Cache engine artifacts
    final engineCached = await ensureEngineCached();
    if (!engineCached) return false;

    Logger.success('Redstone Flutter environment ready!');
    return true;
  }

  /// Ensure Flutter SDK is available in cache
  static Future<bool> ensureFlutterCached() async {
    if (isFlutterCached) {
      Logger.debug('Flutter SDK already cached');
      return true;
    }

    final engineFlutter = _findEngineFlutter();
    if (engineFlutter == null) {
      Logger.error('Could not find Flutter SDK.');
      Logger.info('Please ensure the redstone framework is properly installed.');
      return false;
    }

    // Create cache directory
    final cacheDirectory = Directory(versionedCachePath);
    if (!cacheDirectory.existsSync()) {
      cacheDirectory.createSync(recursive: true);
    }

    Logger.step('Linking Flutter SDK...');
    try {
      final link = Link(cachedFlutterPath);
      if (link.existsSync()) {
        link.deleteSync();
      }
      link.createSync(engineFlutter);
      Logger.success('Flutter SDK linked');
      return true;
    } catch (e) {
      Logger.error('Failed to link Flutter SDK: $e');
      return false;
    }
  }

  /// Ensure Flutter embedder is available in cache
  static Future<bool> ensureEmbedderCached() async {
    if (isEmbedderCached) {
      Logger.debug('Flutter embedder already cached');
      return true;
    }

    final embedderSource = _findEmbedderSource();
    if (embedderSource == null) {
      Logger.error('Could not find Flutter embedder.');
      Logger.info('Please ensure the redstone framework is properly installed.');
      return false;
    }

    // Create cache directory
    final embedderDir = Directory(cachedEmbedderPath);
    if (!embedderDir.existsSync()) {
      embedderDir.createSync(recursive: true);
    }

    Logger.step('Caching Flutter embedder...');
    try {
      if (Platform.isMacOS) {
        final sourceFramework = Directory(embedderSource);
        final targetFramework = Directory(cachedEmbedderFrameworkPath);
        if (targetFramework.existsSync()) {
          targetFramework.deleteSync(recursive: true);
        }
        await _copyDirectory(sourceFramework, targetFramework);
        Logger.success('Flutter embedder cached');
      }
      return true;
    } catch (e) {
      Logger.error('Failed to cache Flutter embedder: $e');
      return false;
    }
  }

  /// Ensure engine build artifacts are available in cache
  ///
  /// Copies flutter_patched_sdk, dart-sdk, and other artifacts from the
  /// engine build output directory. These have SDK hashes that match
  /// the FlutterEmbedder.framework.
  static Future<bool> ensureEngineCached() async {
    if (isEngineCached) {
      Logger.debug('Engine artifacts already cached');
      return true;
    }

    final engineBuildOutput = _findEngineBuildOutput();
    if (engineBuildOutput == null) {
      Logger.error('Could not find engine build output.');
      Logger.info('Please ensure the engine has been built.');
      return false;
    }

    // Create cache directory
    final engineDir = Directory(cachedEnginePath);
    if (!engineDir.existsSync()) {
      engineDir.createSync(recursive: true);
    }

    Logger.step('Caching engine artifacts...');
    try {
      // Copy flutter_patched_sdk (has platform_strong.dill with correct SDK hash)
      final patchedSdkSource = Directory(p.join(engineBuildOutput, 'flutter_patched_sdk'));
      if (patchedSdkSource.existsSync()) {
        final patchedSdkTarget = Directory(cachedPatchedSdkPath);
        if (patchedSdkTarget.existsSync()) {
          patchedSdkTarget.deleteSync(recursive: true);
        }
        await _copyDirectory(patchedSdkSource, patchedSdkTarget);
        Logger.debug('Cached flutter_patched_sdk');
      } else {
        Logger.error('flutter_patched_sdk not found in engine build output');
        return false;
      }

      // Copy dart-sdk (has dartaotruntime and frontend_server)
      final dartSdkSource = Directory(p.join(engineBuildOutput, 'dart-sdk'));
      if (dartSdkSource.existsSync()) {
        final dartSdkTarget = Directory(cachedDartSdkPath);
        if (dartSdkTarget.existsSync()) {
          dartSdkTarget.deleteSync(recursive: true);
        }
        await _copyDirectory(dartSdkSource, dartSdkTarget);
        Logger.debug('Cached dart-sdk');
      } else {
        Logger.error('dart-sdk not found in engine build output');
        return false;
      }

      // Copy icudtl.dat
      final icuSource = File(p.join(engineBuildOutput, 'icudtl.dat'));
      if (icuSource.existsSync()) {
        await icuSource.copy(p.join(cachedEnginePath, 'icudtl.dat'));
        Logger.debug('Cached icudtl.dat');
      }

      // Copy snapshot files from gen/flutter/lib/snapshot/
      // These have the correct SDK hash matching our engine build
      final snapshotDir = p.join(engineBuildOutput, 'gen', 'flutter', 'lib', 'snapshot');
      for (final snapshotName in ['isolate_snapshot.bin', 'vm_isolate_snapshot.bin']) {
        final snapshotSource = File(p.join(snapshotDir, snapshotName));
        if (snapshotSource.existsSync()) {
          await snapshotSource.copy(p.join(cachedEnginePath, snapshotName));
          Logger.debug('Cached $snapshotName');
        } else {
          Logger.debug('Snapshot not found: ${snapshotSource.path}');
        }
      }

      Logger.success('Engine artifacts cached');
      return true;
    } catch (e) {
      Logger.error('Failed to cache engine artifacts: $e');
      return false;
    }
  }

  /// Find the engine build output directory
  ///
  /// This is where the freshly built engine artifacts live:
  /// engine_build/monorepo/flutter/engine/src/out/mac_debug_unopt_arm64/
  static String? _findEngineBuildOutput() {
    try {
      final scriptPath = Platform.script.toFilePath();
      var dir = Directory(scriptPath).parent;

      for (var i = 0; i < 15; i++) {
        // Check if we're in packages/redstone_cli
        if (p.basename(dir.path) == 'redstone_cli') {
          final packagesDir = dir.parent;
          if (p.basename(packagesDir.path) == 'packages') {
            final redstoneDartRoot = packagesDir.parent;
            final engineOutput = p.join(
              redstoneDartRoot.path,
              'engine_build', 'monorepo', 'flutter', 'engine', 'src', 'out',
              _getEngineBuildDir(),
            );
            if (Directory(engineOutput).existsSync()) {
              return engineOutput;
            }
          }
        }

        // Also check directly
        final engineOutput = p.join(
          dir.path,
          'engine_build', 'monorepo', 'flutter', 'engine', 'src', 'out',
          _getEngineBuildDir(),
        );
        if (Directory(engineOutput).existsSync()) {
          return engineOutput;
        }

        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}
    return null;
  }

  /// Get the engine build directory name for the current platform
  static String _getEngineBuildDir() {
    if (Platform.isMacOS) {
      // Check for ARM64 first
      return 'mac_debug_unopt_arm64';
    } else if (Platform.isLinux) {
      return 'linux_debug_unopt';
    } else if (Platform.isWindows) {
      return 'windows_debug_unopt';
    }
    return 'host_debug_unopt';
  }

  /// Find the embedder source (FlutterEmbedder.framework on macOS)
  static String? _findEmbedderSource() {
    final nativeBridgeDir = _findNativeBridgeDir();
    if (nativeBridgeDir != null) {
      if (Platform.isMacOS) {
        final embedderPath = p.join(nativeBridgeDir, 'FlutterEmbedder.framework');
        if (Directory(embedderPath).existsSync()) {
          return embedderPath;
        }
      }
    }
    return null;
  }

  /// Find the native_mc_bridge package directory
  static String? _findNativeBridgeDir() {
    try {
      final scriptPath = Platform.script.toFilePath();
      var dir = Directory(scriptPath).parent;

      for (var i = 0; i < 15; i++) {
        if (p.basename(dir.path) == 'redstone_cli') {
          final packagesDir = dir.parent;
          if (p.basename(packagesDir.path) == 'packages') {
            final nativeBridgePath = p.join(packagesDir.path, 'native_mc_bridge');
            if (Directory(nativeBridgePath).existsSync()) {
              return nativeBridgePath;
            }
          }
        }

        final nativeBridgePath = p.join(dir.path, 'packages', 'native_mc_bridge');
        if (Directory(nativeBridgePath).existsSync()) {
          return nativeBridgePath;
        }

        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}
    return null;
  }

  /// Find engine Flutter relative to this CLI package
  static String? _findEngineFlutter() {
    try {
      final scriptPath = Platform.script.toFilePath();
      var dir = Directory(scriptPath).parent;

      for (var i = 0; i < 15; i++) {
        final engineFlutter = p.join(dir.path, 'engine_build', 'monorepo', 'flutter');
        final flutterBin = File(p.join(engineFlutter, 'bin', 'flutter'));
        if (flutterBin.existsSync()) {
          return engineFlutter;
        }

        if (p.basename(dir.path) == 'redstone_cli') {
          final packagesDir = dir.parent;
          if (p.basename(packagesDir.path) == 'packages') {
            final redstoneDartRoot = packagesDir.parent;
            final engineFlutterPath = p.join(redstoneDartRoot.path, 'engine_build', 'monorepo', 'flutter');
            final bin = File(p.join(engineFlutterPath, 'bin', 'flutter'));
            if (bin.existsSync()) {
              return engineFlutterPath;
            }
          }
        }

        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}
    return null;
  }

  /// Recursively copy a directory
  static Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is Link) {
        final linkTarget = entity.targetSync();
        Link(targetPath).createSync(linkTarget);
      }
    }
  }
}
