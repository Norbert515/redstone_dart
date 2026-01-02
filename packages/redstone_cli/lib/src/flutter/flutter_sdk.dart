import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/platform.dart';

/// Locates Flutter SDK and its components
class FlutterSdk {
  final String path;

  FlutterSdk(this.path);

  /// Find Flutter SDK from environment or standard locations
  static FlutterSdk? locate() {
    // Check FLUTTER_ROOT environment variable
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null && _isValidFlutterSdk(flutterRoot)) {
      return FlutterSdk(flutterRoot);
    }

    // Check PATH for flutter command
    final flutterFromPath = _findFlutterInPath();
    if (flutterFromPath != null) {
      return FlutterSdk(flutterFromPath);
    }

    // Check standard install locations
    final standardLocations = _getStandardLocations();
    for (final location in standardLocations) {
      if (_isValidFlutterSdk(location)) {
        return FlutterSdk(location);
      }
    }

    return null;
  }

  /// Find Flutter SDK by running `flutter --version` and parsing output
  static String? _findFlutterInPath() {
    try {
      final result = Process.runSync('which', ['flutter']);
      if (result.exitCode == 0) {
        // `which flutter` returns path like /path/to/flutter/bin/flutter
        // We need the parent of bin/
        final flutterBin = result.stdout.toString().trim();
        if (flutterBin.isNotEmpty) {
          final binDir = File(flutterBin).parent.path;
          final sdkDir = Directory(binDir).parent.path;
          if (_isValidFlutterSdk(sdkDir)) {
            return sdkDir;
          }
        }
      }
    } catch (_) {
      // which command may not exist on Windows
      if (Platform.isWindows) {
        try {
          final result = Process.runSync('where', ['flutter']);
          if (result.exitCode == 0) {
            final flutterBin = result.stdout.toString().trim().split('\n').first;
            if (flutterBin.isNotEmpty) {
              final binDir = File(flutterBin).parent.path;
              final sdkDir = Directory(binDir).parent.path;
              if (_isValidFlutterSdk(sdkDir)) {
                return sdkDir;
              }
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// Get standard Flutter installation locations based on platform
  static List<String> _getStandardLocations() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';

    if (Platform.isMacOS) {
      return [
        p.join(home, 'flutter'),
        p.join(home, 'development', 'flutter'),
        '/usr/local/flutter',
        p.join(home, 'fvm', 'default'),
      ];
    } else if (Platform.isLinux) {
      return [
        p.join(home, 'flutter'),
        p.join(home, 'development', 'flutter'),
        '/usr/local/flutter',
        '/opt/flutter',
        p.join(home, 'fvm', 'default'),
      ];
    } else if (Platform.isWindows) {
      return [
        p.join(home, 'flutter'),
        r'C:\flutter',
        r'C:\src\flutter',
        p.join(home, 'fvm', 'default'),
      ];
    }
    return [];
  }

  /// Validate that a path contains a valid Flutter SDK
  static bool _isValidFlutterSdk(String path) {
    // Check for flutter executable in bin/
    final flutterExe = Platform.isWindows ? 'flutter.bat' : 'flutter';
    final flutterBin = File(p.join(path, 'bin', flutterExe));
    if (!flutterBin.existsSync()) {
      return false;
    }

    // Check for engine artifacts directory
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

  /// Path to the Dart AOT runtime within Flutter SDK
  ///
  /// Used for running AOT-compiled snapshots like frontend_server_aot.dart.snapshot
  String get dartAotRuntimePath {
    final exe = Platform.isWindows ? 'dartaotruntime.exe' : 'dartaotruntime';
    return p.join(path, 'bin', 'cache', 'dart-sdk', 'bin', exe);
  }

  /// Path to frontend_server snapshot
  ///
  /// The frontend_server compiles Dart code to kernel format.
  /// Flutter SDK: bin/cache/artifacts/engine/<platform>/frontend_server.dart.snapshot
  String get frontendServerPath {
    return p.join(
      path,
      'bin',
      'cache',
      'artifacts',
      'engine',
      _platformDir,
      'frontend_server.dart.snapshot',
    );
  }

  /// Alternative path to frontend_server (AOT version in dart-sdk)
  /// Flutter SDK: bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot
  String get frontendServerAotPath {
    return p.join(
      path,
      'bin',
      'cache',
      'dart-sdk',
      'bin',
      'snapshots',
      'frontend_server_aot.dart.snapshot',
    );
  }

  /// Get the best available frontend_server path
  String get bestFrontendServerPath {
    // Prefer the engine version as it's more closely matched to Flutter
    if (File(frontendServerPath).existsSync()) {
      return frontendServerPath;
    }
    // Fall back to AOT version
    if (File(frontendServerAotPath).existsSync()) {
      return frontendServerAotPath;
    }
    // Default to engine version (will fail if missing, but with clear error)
    return frontendServerPath;
  }

  /// Path to Flutter's patched SDK
  ///
  /// This is the SDK root that should be passed to frontend_server.
  /// Flutter SDK: bin/cache/artifacts/engine/common/flutter_patched_sdk/
  String get sdkRoot {
    return p.join(
      path,
      'bin',
      'cache',
      'artifacts',
      'engine',
      'common',
      'flutter_patched_sdk',
    );
  }

  /// Path to Flutter's patched SDK for product mode (release builds)
  String get sdkRootProduct {
    return p.join(
      path,
      'bin',
      'cache',
      'artifacts',
      'engine',
      'common',
      'flutter_patched_sdk_product',
    );
  }

  /// Path to ICU data file
  ///
  /// Required for Flutter engine initialization.
  /// Flutter SDK: bin/cache/artifacts/engine/<platform>/icudtl.dat
  String get icuDataPath {
    return p.join(
      path,
      'bin',
      'cache',
      'artifacts',
      'engine',
      _platformDir,
      'icudtl.dat',
    );
  }

  /// Path to engine library directory
  ///
  /// Contains libflutter_engine.dylib/so/dll and other engine artifacts.
  /// Flutter SDK: bin/cache/artifacts/engine/<platform>/
  String get engineLibPath {
    return p.join(
      path,
      'bin',
      'cache',
      'artifacts',
      'engine',
      _platformDir,
    );
  }

  /// Path to Flutter framework on macOS
  ///
  /// macOS: bin/cache/artifacts/engine/<platform>/FlutterMacOS.framework/
  String? get flutterFrameworkPath {
    if (!Platform.isMacOS) return null;
    return p.join(engineLibPath, 'FlutterMacOS.framework');
  }

  /// Path to Dart SDK within Flutter
  String get dartSdkPath {
    return p.join(path, 'bin', 'cache', 'dart-sdk');
  }

  /// Path to platform_dill directory containing core libraries
  ///
  /// Contains platform.dill and other core Dart libraries.
  String get platformDillPath {
    return p.join(
      path,
      'bin',
      'cache',
      'artifacts',
      'engine',
      'common',
      'flutter_patched_sdk',
      'platform_strong.dill',
    );
  }

  /// Get platform-specific directory name
  ///
  /// Returns the directory name used for platform-specific engine artifacts:
  /// - macOS ARM64: darwin-arm64 (falls back to darwin-x64 if not available)
  /// - macOS x64: darwin-x64
  /// - Linux x64: linux-x64
  /// - Windows x64: windows-x64
  String get _platformDir {
    final platform = PlatformInfo.detect();

    if (platform.isMacOS) {
      // Try ARM64 first on Apple Silicon, fall back to x64 (Rosetta)
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

  /// Get Flutter version by running flutter --version
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
  ///
  /// Runs `flutter precache` to download engine artifacts if needed.
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
