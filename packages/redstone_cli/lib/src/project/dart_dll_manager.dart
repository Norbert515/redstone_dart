import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../util/logger.dart';
import '../util/platform.dart';
import 'bridge_sync.dart';

/// Manages the dart_dll dependency for the native bridge.
///
/// dart_dll is the embedded Dart VM library from dart_shared_library.
/// This class handles checking if it exists and downloading if needed.
class DartDllManager {
  /// The version of dart_dll to download
  static const String dartDllVersion = '0.2.0';

  /// GitHub release URL pattern
  static const String _releaseUrlPattern =
      'https://github.com/fuzzybinary/dart_shared_library/releases/download/{version}/lib-{platform}.zip';

  /// Check if dart_dll is available and download if needed.
  ///
  /// Returns true if dart_dll is available (either already existed or was downloaded).
  /// Returns false if download failed or platform is unsupported.
  static Future<bool> ensureAvailable() async {
    final dllPath = _getDartDllPath();
    if (dllPath == null) {
      Logger.debug('Could not determine dart_dll path (development mode only)');
      return false;
    }

    if (_isDartDllPresent(dllPath)) {
      Logger.debug('dart_dll already available at $dllPath');
      return true;
    }

    Logger.info('dart_dll not found, downloading...');
    return await _download(dllPath);
  }

  /// Check if dart_dll needs to be downloaded.
  ///
  /// Returns true if dart_dll is missing and should be downloaded.
  static bool needsDownload() {
    final dllPath = _getDartDllPath();
    if (dllPath == null) return false;
    return !_isDartDllPresent(dllPath);
  }

  /// Get the path to the dart_dll directory.
  ///
  /// Returns null if not in development mode (packages dir not found).
  static String? _getDartDllPath() {
    final packagesDir = BridgeSync.findPackagesDir();
    if (packagesDir == null) return null;
    return p.join(packagesDir, 'native_mc_bridge', 'deps', 'dart_dll');
  }

  /// Check if dart_dll library file exists.
  static bool _isDartDllPresent(String dllPath) {
    final platform = PlatformInfo.detect();
    final libName = _getLibraryName(platform);
    final libFile = File(p.join(dllPath, 'lib', libName));
    return libFile.existsSync();
  }

  /// Get the platform-specific library name for dart_dll.
  static String _getLibraryName(PlatformInfo platform) {
    if (platform.isMacOS) {
      return 'libdart_dll.dylib';
    } else if (platform.isWindows) {
      return 'dart_dll.dll';
    } else {
      return 'libdart_dll.so';
    }
  }

  /// Get the download URL for the current platform.
  static String? _getDownloadUrl() {
    final platform = PlatformInfo.detect();

    // ARM64 macOS requires building from source
    if (platform.isMacOS && platform.isArm64) {
      Logger.warning(
        'dart_dll for macOS ARM64 (M1/M2/M3) must be built from source.',
      );
      Logger.step('See: https://github.com/fuzzybinary/dart_shared_library');
      return null;
    }

    String platformName;
    if (platform.isMacOS) {
      platformName = 'macos';
    } else if (platform.isWindows) {
      platformName = 'win';
    } else if (platform.isLinux) {
      platformName = 'linux';
    } else {
      Logger.error('Unsupported platform: ${platform.identifier}');
      return null;
    }

    return _releaseUrlPattern
        .replaceAll('{version}', dartDllVersion)
        .replaceAll('{platform}', platformName);
  }

  /// Download and extract dart_dll.
  static Future<bool> _download(String dllPath) async {
    final url = _getDownloadUrl();
    if (url == null) return false;

    final libDir = Directory(p.join(dllPath, 'lib'));

    try {
      // Create lib directory if it doesn't exist
      if (!libDir.existsSync()) {
        libDir.createSync(recursive: true);
      }

      // Download the zip file
      Logger.progress('Downloading dart_dll v$dartDllVersion');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        Logger.progressFailed();
        Logger.error('Download failed with status ${response.statusCode}');
        return false;
      }
      Logger.progressDone();

      // Save to temp file
      final tempDir = await Directory.systemTemp.createTemp('dart_dll_');
      final zipFile = File(p.join(tempDir.path, 'dart_dll.zip'));
      await zipFile.writeAsBytes(response.bodyBytes);

      // Extract the zip
      Logger.progress('Extracting');
      final extractResult = await _extractZip(zipFile.path, dllPath);

      // Clean up temp files
      await tempDir.delete(recursive: true);

      if (!extractResult) {
        Logger.progressFailed();
        return false;
      }

      // The zip extracts to bin/, but CMake expects lib/
      // Move the library to the expected location
      await _moveLibraryToLib(dllPath);

      Logger.progressDone();

      // Verify the library exists
      if (_isDartDllPresent(dllPath)) {
        Logger.success('dart_dll v$dartDllVersion installed successfully');
        return true;
      } else {
        Logger.error('dart_dll library not found after extraction');
        return false;
      }
    } catch (e) {
      Logger.error('Failed to download dart_dll: $e');
      return false;
    }
  }

  /// Extract a zip file to the target directory.
  static Future<bool> _extractZip(String zipPath, String targetDir) async {
    try {
      ProcessResult result;

      if (Platform.isWindows) {
        // Use PowerShell on Windows
        result = await Process.run(
          'powershell',
          [
            '-Command',
            'Expand-Archive',
            '-Path',
            zipPath,
            '-DestinationPath',
            targetDir,
            '-Force',
          ],
        );
      } else {
        // Use unzip on macOS/Linux
        result = await Process.run(
          'unzip',
          ['-o', zipPath, '-d', targetDir],
        );
      }

      if (result.exitCode != 0) {
        Logger.debug('Extraction failed: ${result.stderr}');
        return false;
      }

      return true;
    } catch (e) {
      Logger.debug('Extraction error: $e');
      return false;
    }
  }

  /// Move the library from bin/ to lib/ after extraction.
  ///
  /// The dart_shared_library zip extracts to bin/, but CMake expects lib/.
  static Future<void> _moveLibraryToLib(String dllPath) async {
    final platform = PlatformInfo.detect();
    final libName = _getLibraryName(platform);

    final binDir = Directory(p.join(dllPath, 'bin'));
    final libDir = Directory(p.join(dllPath, 'lib'));

    // Check if bin/ exists and lib/ doesn't have the file
    final binFile = File(p.join(binDir.path, libName));
    final libFile = File(p.join(libDir.path, libName));

    if (binFile.existsSync() && !libFile.existsSync()) {
      // Create lib/ if it doesn't exist
      if (!libDir.existsSync()) {
        libDir.createSync(recursive: true);
      }

      // Move the library
      binFile.copySync(libFile.path);
      binFile.deleteSync();
      Logger.debug('Moved $libName from bin/ to lib/');
    }
  }
}
