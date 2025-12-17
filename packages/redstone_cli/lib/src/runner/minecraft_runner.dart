import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../assets/asset_generator.dart';
import '../project/bridge_sync.dart';
import '../project/redstone_project.dart';
import '../util/logger.dart';

/// Manages the Minecraft process lifecycle
class MinecraftRunner {
  final RedstoneProject project;
  final bool testMode;
  Process? _process;
  final _exitCompleter = Completer<int>();

  /// Stream controller for stdout lines (only in test mode)
  StreamController<String>? _stdoutController;

  MinecraftRunner(this.project, {this.testMode = false});

  /// Exit code future - completes when Minecraft exits
  Future<int> get exitCode => _exitCompleter.future;

  /// Stream of stdout lines (only available in test mode).
  /// This is a broadcast stream so multiple listeners can subscribe.
  Stream<String>? get stdoutLines => _stdoutController?.stream;

  /// Start Minecraft with the mod
  Future<void> start() async {
    // First, copy files
    await _prepareFiles();

    // Start Minecraft via Gradle
    final gradlew = Platform.isWindows ? 'gradlew.bat' : './gradlew';

    // Use runServer for test mode (headless server), runClient for normal mode
    final gradleTask = testMode ? 'runServer' : 'runClient';

    Logger.debug('Starting Minecraft from ${project.minecraftDir} with task: $gradleTask');

    if (testMode) {
      // In test mode, capture stdout for parsing JSON events
      _stdoutController = StreamController<String>.broadcast();

      _process = await Process.start(
        gradlew,
        [gradleTask],
        workingDirectory: project.minecraftDir,
        mode: ProcessStartMode.normal,
      );

      // Forward stdout lines to the stream and also to console
      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _stdoutController?.add(line);
      });

      // Forward stderr to console
      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        stderr.writeln(line);
      });
    } else {
      // In normal mode, inherit stdio for interactive use
      _process = await Process.start(
        gradlew,
        [gradleTask],
        workingDirectory: project.minecraftDir,
        mode: ProcessStartMode.inheritStdio,
      );
    }

    // Handle process exit
    _process!.exitCode.then((code) {
      _stdoutController?.close();
      if (!_exitCompleter.isCompleted) {
        _exitCompleter.complete(code);
      }
    });
  }

  /// Stop Minecraft gracefully
  Future<void> stop() async {
    if (_process != null) {
      Logger.debug('Stopping Minecraft...');

      // Try graceful shutdown first
      _process!.kill(ProcessSignal.sigterm);

      // Wait a bit for graceful exit
      final exited = await _process!.exitCode
          .timeout(const Duration(seconds: 5), onTimeout: () => -1);

      if (exited == -1) {
        // Force kill if didn't exit gracefully
        Logger.debug('Force killing Minecraft...');
        _process!.kill(ProcessSignal.sigkill);
      }

      await _stdoutController?.close();

      if (!_exitCompleter.isCompleted) {
        _exitCompleter.complete(0);
      }
    }
  }

  /// Prepare files before running
  Future<void> _prepareFiles() async {
    // Sync bridge code if source has changed
    await BridgeSync.syncIfNeeded(project.rootDir);

    // Generate assets first (blockstates, models, textures)
    await _generateAssets();

    // Copy Dart mod to run/mods/
    await _copyDartMod();

    // Copy native libs to run/natives/
    await _copyNativeLibs();

    // In test mode, ensure EULA is accepted for server
    if (testMode) {
      await _ensureEula();
    }
  }

  /// Ensure EULA is accepted for server mode
  Future<void> _ensureEula() async {
    final eulaFile = File(p.join(project.minecraftDir, 'run', 'eula.txt'));
    if (!eulaFile.parent.existsSync()) {
      eulaFile.parent.createSync(recursive: true);
    }
    eulaFile.writeAsStringSync('eula=true\n');
    Logger.debug('Created EULA file at: ${eulaFile.path}');
  }

  Future<void> _generateAssets() async {
    // Step 1: Run the mod in datagen mode to generate manifest.json
    Logger.info('Running mod in datagen mode...');
    final result = await Process.run(
      'dart',
      ['run', 'lib/main.dart'],
      workingDirectory: project.rootDir,
      environment: {'REDSTONE_DATAGEN': 'true'},
    );

    if (result.exitCode != 0) {
      Logger.error('Datagen failed with exit code ${result.exitCode}');
      if (result.stdout.toString().isNotEmpty) {
        Logger.debug('stdout: ${result.stdout}');
      }
      if (result.stderr.toString().isNotEmpty) {
        Logger.error('stderr: ${result.stderr}');
      }
      throw Exception('Datagen failed');
    }

    // Step 2: Generate all JSON assets from manifest
    Logger.info('Generating Minecraft assets...');
    final generator = AssetGenerator(project);
    await generator.generate();
  }

  Future<void> _copyDartMod() async {
    final sourceDir = Directory(project.libDir);
    // DartModLoader expects the mod at mods/dart_mc/lib/dart_mc.dart
    final targetDir = Directory(
      p.join(project.minecraftDir, 'run', 'mods', 'dart_mc'),
    );

    // Create target directory
    if (targetDir.existsSync()) {
      targetDir.deleteSync(recursive: true);
    }
    targetDir.createSync(recursive: true);

    // Copy lib/ contents
    final targetLibDir = Directory(p.join(targetDir.path, 'lib'));
    await _copyDirectory(sourceDir, targetLibDir);

    if (testMode) {
      // In test mode, use the generated test harness as entry point
      final harnessFile = File(
        p.join(project.rootDir, '.redstone', 'test', 'test_harness.dart'),
      );
      if (!harnessFile.existsSync()) {
        throw StateError('Test harness not found. Run TestHarnessGenerator first.');
      }

      // Copy test harness as dart_mc.dart (entry point)
      final dartMcDart = File(p.join(targetLibDir.path, 'dart_mc.dart'));
      harnessFile.copySync(dartMcDart.path);

      // Delete main.dart if it exists (we don't want it to conflict)
      final mainDart = File(p.join(targetLibDir.path, 'main.dart'));
      if (mainDart.existsSync()) {
        mainDart.deleteSync();
      }

      // Copy test files INSIDE lib/ (as lib/test/) for proper resolution
      // The native Dart VM has issues with ../test/ relative paths
      final testDir = Directory(p.join(project.rootDir, 'test'));
      if (testDir.existsSync()) {
        final targetTestDir = Directory(p.join(targetLibDir.path, 'test'));
        await _copyDirectory(testDir, targetTestDir);
      }
    } else {
      // Normal mode: rename main.dart to dart_mc.dart if it exists
      final mainDart = File(p.join(targetLibDir.path, 'main.dart'));
      final dartMcDart = File(p.join(targetLibDir.path, 'dart_mc.dart'));
      if (mainDart.existsSync() && !dartMcDart.existsSync()) {
        mainDart.renameSync(dartMcDart.path);
      }
    }

    // Copy pubspec.yaml
    final pubspec = File(p.join(project.rootDir, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      pubspec.copySync(p.join(targetDir.path, 'pubspec.yaml'));
    }

    // Run pub get in the target directory
    await Process.run('dart', ['pub', 'get'], workingDirectory: targetDir.path);
  }

  Future<void> _copyNativeLibs() async {
    final nativeDir = Directory(project.nativeDir);
    final targetDir = Directory(p.join(project.minecraftDir, 'run', 'natives'));

    if (!nativeDir.existsSync()) {
      Logger.warning('Native libraries not found at ${nativeDir.path}');
      return;
    }

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    await for (final entity in nativeDir.list()) {
      if (entity is File) {
        final targetPath = p.join(targetDir.path, p.basename(entity.path));
        entity.copySync(targetPath);
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!source.existsSync()) return;

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
}
