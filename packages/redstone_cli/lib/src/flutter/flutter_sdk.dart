import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/platform.dart';
import 'flutter_cache.dart';

/// Locates Flutter SDK and its components
///
/// Redstone manages its own Flutter SDK and engine artifacts to ensure
/// version compatibility. The SDK is cached at:
///   ~/.redstone/versions/<version>-<engine>/
///
/// The engine artifacts (flutter_patched_sdk, dart-sdk) come from the
/// engine build output and have SDK hashes that match the FlutterEmbedder.
class FlutterSdk {
  final String path;

  FlutterSdk(this.path);

  /// Find Flutter SDK from redstone cache
  ///
  /// Returns null if not cached yet - caller should call ensureAvailable() first.
  static FlutterSdk? locate() {
    final cachedFlutter = FlutterCache.cachedFlutterPath;
    if (_isValidFlutterSdk(cachedFlutter)) {
      return FlutterSdk(cachedFlutter);
    }
    return null;
  }

  /// Ensure all Flutter/engine artifacts are available and return SDK
  ///
  /// This caches:
  /// - Flutter SDK (for flutter command)
  /// - Engine artifacts (flutter_patched_sdk, dart-sdk with matching SDK hash)
  /// - FlutterEmbedder.framework
  static Future<FlutterSdk?> ensureAvailable() async {
    final cached = await FlutterCache.ensureFullyCached();
    if (!cached) {
      return null;
    }
    return locate();
  }

  /// Validate that a path contains a valid Flutter SDK
  static bool _isValidFlutterSdk(String path) {
    final flutterExe = Platform.isWindows ? 'flutter.bat' : 'flutter';
    final flutterBin = File(p.join(path, 'bin', flutterExe));
    if (!flutterBin.existsSync()) {
      return false;
    }

    final engineDir = Directory(p.join(path, 'bin', 'cache', 'artifacts', 'engine'));
    if (!engineDir.existsSync()) {
      return false;
    }

    return true;
  }

  /// Path to the Flutter executable
  String get flutterPath {
    final exe = Platform.isWindows ? 'flutter.bat' : 'flutter';
    return p.join(path, 'bin', exe);
  }

  /// Path to the Dart executable within Flutter SDK
  String get dartPath {
    final exe = Platform.isWindows ? 'dart.bat' : 'dart';
    return p.join(path, 'bin', exe);
  }

  /// Path to the Dart AOT runtime
  ///
  /// Uses the cached engine dart-sdk which has matching SDK hash.
  String get dartAotRuntimePath {
    final exe = Platform.isWindows ? 'dartaotruntime.exe' : 'dartaotruntime';

    // Use cached engine dart-sdk (has correct SDK hash)
    final cachedPath = p.join(FlutterCache.cachedDartSdkPath, 'bin', exe);
    if (File(cachedPath).existsSync()) {
      return cachedPath;
    }

    // Fallback to Flutter SDK's dart-sdk
    return p.join(path, 'bin', 'cache', 'dart-sdk', 'bin', exe);
  }

  /// Path to frontend_server snapshot
  ///
  /// Uses the cached engine dart-sdk which has matching SDK hash.
  String get bestFrontendServerPath {
    // Use cached engine dart-sdk's frontend_server (has correct SDK hash)
    final cachedPath = p.join(
      FlutterCache.cachedDartSdkPath,
      'bin',
      'snapshots',
      'frontend_server_aot.dart.snapshot',
    );
    if (File(cachedPath).existsSync()) {
      return cachedPath;
    }

    // Fallback to Flutter SDK paths
    final enginePath = p.join(
      path, 'bin', 'cache', 'artifacts', 'engine',
      _platformDir, 'frontend_server.dart.snapshot',
    );
    if (File(enginePath).existsSync()) {
      return enginePath;
    }

    final aotPath = p.join(
      path, 'bin', 'cache', 'dart-sdk', 'bin', 'snapshots',
      'frontend_server_aot.dart.snapshot',
    );
    if (File(aotPath).existsSync()) {
      return aotPath;
    }

    return enginePath;
  }

  /// Path to Flutter's patched SDK
  ///
  /// Uses the cached engine flutter_patched_sdk which has SDK hash
  /// matching the FlutterEmbedder.framework.
  String get sdkRoot {
    // Use cached engine flutter_patched_sdk (has correct SDK hash)
    final cachedPath = FlutterCache.cachedPatchedSdkPath;
    if (Directory(cachedPath).existsSync()) {
      return cachedPath;
    }

    // Fallback to Flutter SDK's patched sdk
    return p.join(
      path, 'bin', 'cache', 'artifacts', 'engine',
      'common', 'flutter_patched_sdk',
    );
  }

  /// Path to Flutter's patched SDK for product mode (release builds)
  String get sdkRootProduct {
    return p.join(
      path, 'bin', 'cache', 'artifacts', 'engine',
      'common', 'flutter_patched_sdk_product',
    );
  }

  /// Path to ICU data file
  ///
  /// Uses the cached engine icudtl.dat if available.
  String get icuDataPath {
    // Use cached engine icudtl.dat
    final cachedPath = p.join(FlutterCache.cachedEnginePath, 'icudtl.dat');
    if (File(cachedPath).existsSync()) {
      return cachedPath;
    }

    // Fallback to Flutter SDK
    return p.join(
      path, 'bin', 'cache', 'artifacts', 'engine',
      _platformDir, 'icudtl.dat',
    );
  }

  /// Path to engine library directory
  String get engineLibPath {
    return p.join(
      path, 'bin', 'cache', 'artifacts', 'engine', _platformDir,
    );
  }

  /// Path to Flutter framework on macOS
  String? get flutterFrameworkPath {
    if (!Platform.isMacOS) return null;
    return p.join(engineLibPath, 'FlutterMacOS.framework');
  }

  /// Path to Dart SDK within Flutter
  String get dartSdkPath {
    return p.join(path, 'bin', 'cache', 'dart-sdk');
  }

  /// Path to platform_dill
  String get platformDillPath {
    return p.join(sdkRoot, 'platform_strong.dill');
  }

  /// Get platform-specific directory name
  String get _platformDir {
    final platform = PlatformInfo.detect();

    if (platform.isMacOS) {
      if (platform.isArm64) {
        final arm64Dir = p.join(path, 'bin', 'cache', 'artifacts', 'engine', 'darwin-arm64');
        if (Directory(arm64Dir).existsSync()) {
          return 'darwin-arm64';
        }
      }
      return 'darwin-x64';
    } else if (platform.isLinux) {
      return 'linux-x64';
    } else if (platform.isWindows) {
      return 'windows-x64';
    }

    throw UnsupportedError('Unsupported platform: ${platform.identifier}');
  }

  /// Get Flutter version
  Future<String?> getVersion() async {
    try {
      final result = await Process.run(flutterPath, ['--version']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'Flutter (\S+)').firstMatch(output);
        return match?.group(1);
      }
    } catch (_) {}
    return null;
  }

  /// Ensure Flutter artifacts are downloaded
  Future<bool> ensureArtifacts() async {
    try {
      final result = await Process.run(
        flutterPath,
        ['precache', '--flutter_runner'],
        workingDirectory: path,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Check if all required artifacts are present
  bool get hasRequiredArtifacts {
    return File(bestFrontendServerPath).existsSync() &&
        Directory(sdkRoot).existsSync() &&
        File(icuDataPath).existsSync();
  }

  @override
  String toString() => 'FlutterSdk(path: $path)';
}
