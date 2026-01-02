import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/logger.dart';
import 'flutter_sdk.dart';

/// Result of a compilation operation
class CompileResult {
  /// Whether the compilation succeeded
  final bool success;

  /// Standard output from the compiler
  final String output;

  /// Standard error from the compiler (includes errors and warnings)
  final String errors;

  /// Path to the output kernel file (if successful)
  final String? outputPath;

  CompileResult({
    required this.success,
    required this.output,
    required this.errors,
    this.outputPath,
  });

  @override
  String toString() {
    if (success) {
      return 'CompileResult(success: true, outputPath: $outputPath)';
    }
    return 'CompileResult(success: false, errors: $errors)';
  }
}

/// Compiles mod Dart code to Flutter kernel format
///
/// Uses the frontend_server from the Flutter SDK to compile Dart source
/// code into kernel bytecode (.dill files) that can be loaded by the
/// Flutter engine.
class ModCompiler {
  final FlutterSdk flutterSdk;

  ModCompiler({required this.flutterSdk});

  /// Create a ModCompiler by locating the Flutter SDK automatically
  static ModCompiler? create() {
    final sdk = FlutterSdk.locate();
    if (sdk == null) return null;
    return ModCompiler(flutterSdk: sdk);
  }

  /// Compile an entry point to kernel blob
  ///
  /// [entryPoint] - Path to the main Dart file to compile
  /// [outputPath] - Path where the kernel blob should be written
  /// [packagesPath] - Path to .dart_tool/package_config.json
  /// [trackWidgetCreation] - Whether to track widget creation locations (for DevTools)
  /// [aot] - Whether to compile for AOT (release mode)
  /// [debugMode] - Whether to include debug information
  Future<CompileResult> compile({
    required String entryPoint,
    required String outputPath,
    required String packagesPath,
    bool trackWidgetCreation = true,
    bool aot = false,
    bool debugMode = true,
  }) async {
    // Ensure the output directory exists
    final outputDir = Directory(p.dirname(outputPath));
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final frontendServerPath = flutterSdk.bestFrontendServerPath;
    if (!File(frontendServerPath).existsSync()) {
      return CompileResult(
        success: false,
        output: '',
        errors: 'Frontend server not found at: $frontendServerPath\n'
            'Run "flutter precache" to download Flutter artifacts.',
      );
    }

    // Select SDK root based on build mode
    final sdkRoot = aot ? flutterSdk.sdkRootProduct : flutterSdk.sdkRoot;
    if (!Directory(sdkRoot).existsSync()) {
      return CompileResult(
        success: false,
        output: '',
        errors: 'Flutter patched SDK not found at: $sdkRoot\n'
            'Run "flutter precache" to download Flutter artifacts.',
      );
    }

    // Build frontend_server arguments
    final args = <String>[
      frontendServerPath,
      '--sdk-root=$sdkRoot',
      '--target=flutter',
      '--packages=$packagesPath',
      '--output-dill=$outputPath',
    ];

    // Add optional flags
    if (trackWidgetCreation && !aot) {
      args.add('--track-widget-creation');
    }

    if (aot) {
      args.add('--aot');
      args.add('--tfa');
    }

    if (debugMode && !aot) {
      args.add('--enable-asserts');
    }

    // Add the entry point
    args.add(entryPoint);

    // Determine the correct Dart runtime to use
    // AOT snapshots (frontend_server_aot.dart.snapshot) need dartaotruntime
    final isAotSnapshot = frontendServerPath.contains('_aot.');
    final dartRuntime = isAotSnapshot
        ? flutterSdk.dartAotRuntimePath
        : flutterSdk.dartPath;

    Logger.debug('Running frontend_server: $dartRuntime ${args.join(' ')}');

    try {
      final result = await Process.run(
        dartRuntime,
        args,
        workingDirectory: p.dirname(entryPoint),
      );

      final success = result.exitCode == 0;

      if (success) {
        Logger.debug('Compilation successful: $outputPath');
      } else {
        Logger.debug('Compilation failed with exit code: ${result.exitCode}');
      }

      return CompileResult(
        success: success,
        output: result.stdout.toString(),
        errors: result.stderr.toString(),
        outputPath: success ? outputPath : null,
      );
    } catch (e) {
      return CompileResult(
        success: false,
        output: '',
        errors: 'Failed to run frontend_server: $e',
      );
    }
  }

  /// Compile entry point to kernel_blob.bin in the specified assets directory
  ///
  /// This is a convenience method that compiles to the standard Flutter
  /// asset location (flutter_assets/kernel_blob.bin).
  Future<CompileResult> compileToAssets({
    required String entryPoint,
    required String assetsDir,
    required String packagesPath,
    bool trackWidgetCreation = true,
  }) async {
    final outputPath = p.join(assetsDir, 'kernel_blob.bin');
    return compile(
      entryPoint: entryPoint,
      outputPath: outputPath,
      packagesPath: packagesPath,
      trackWidgetCreation: trackWidgetCreation,
    );
  }

  /// Check if the compiler is ready to use
  bool get isReady => flutterSdk.hasRequiredArtifacts;

  /// Get a description of what's missing if not ready
  String? get missingRequirements {
    if (isReady) return null;

    final missing = <String>[];

    if (!File(flutterSdk.bestFrontendServerPath).existsSync()) {
      missing.add('frontend_server');
    }
    if (!Directory(flutterSdk.sdkRoot).existsSync()) {
      missing.add('flutter_patched_sdk');
    }
    if (!File(flutterSdk.icuDataPath).existsSync()) {
      missing.add('icudtl.dat');
    }

    if (missing.isEmpty) return null;
    return 'Missing Flutter artifacts: ${missing.join(', ')}. '
        'Run "flutter precache" to download them.';
  }
}
