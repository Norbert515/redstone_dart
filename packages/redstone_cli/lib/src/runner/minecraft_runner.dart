import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../assets/asset_generator.dart';
import '../project/bridge_sync.dart';
import '../project/native_build_sync.dart';
import '../project/redstone_project.dart';
import '../util/logger.dart';

/// Manages the Minecraft process lifecycle
class MinecraftRunner {
  final RedstoneProject project;
  final bool testMode;
  final bool clientTestMode;
  Process? _process;
  final _exitCompleter = Completer<int>();
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;

  /// Stream controller for stdout lines (only in test mode)
  StreamController<String>? _stdoutController;

  MinecraftRunner(this.project, {this.testMode = false, this.clientTestMode = false});

  /// Exit code future - completes when Minecraft exits
  Future<int> get exitCode => _exitCompleter.future;

  /// Stream of stdout lines (only available in test mode).
  /// This is a broadcast stream so multiple listeners can subscribe.
  Stream<String>? get stdoutLines => _stdoutController?.stream;

  /// Start Minecraft with the mod
  Future<void> start() async {
    // First, prepare files (assets, native libs, etc.)
    await _prepareFiles();

    // Start Minecraft via Gradle
    final gradlew = Platform.isWindows ? 'gradlew.bat' : './gradlew';

    // Determine which Gradle task to use:
    // - clientTestMode: runClient (client tests with visual testing)
    // - testMode: runServer (headless server tests)
    // - normal: runClient (interactive development)
    final gradleTask = testMode && !clientTestMode ? 'runServer' : 'runClient';

    Logger.debug('Starting Minecraft from ${project.minecraftDir} with task: $gradleTask');

    // Determine the script path for Dart VM
    final scriptPath = _getDartScriptPath();
    Logger.debug('Dart script path: $scriptPath');

    // Pass the script path via Gradle project property
    // This is more reliable than environment variables because Gradle daemon
    // uses its own environment that was set when it started
    final gradleArgs = [
      gradleTask,
      '-PdartScriptPath=$scriptPath',
    ];
    Logger.debug('Gradle args: $gradleArgs');

    if (testMode || clientTestMode) {
      // In test mode (server or client), capture stdout for parsing JSON events
      _stdoutController = StreamController<String>.broadcast();

      _process = await Process.start(
        gradlew,
        gradleArgs,
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
      // In normal mode, use normal mode and manually pipe stdout/stderr
      // This allows the parent process to keep stdin for hot reload input
      _process = await Process.start(
        gradlew,
        gradleArgs,
        workingDirectory: project.minecraftDir,
        mode: ProcessStartMode.normal,
      );

      // Forward stdout and stderr to the terminal
      // Note: We intentionally do NOT pipe stdin to allow hot reload input
      _stdoutSubscription = _process!.stdout.listen(stdout.add);
      _stderrSubscription = _process!.stderr.listen(stderr.add);
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
      // Try graceful shutdown first
      _process!.kill(ProcessSignal.sigterm);

      // Wait a bit for graceful exit
      final exited = await _process!.exitCode
          .timeout(const Duration(seconds: 5), onTimeout: () => -1);

      if (exited == -1) {
        // Force kill if didn't exit gracefully
        _process!.kill(ProcessSignal.sigkill);
      }

      await _stdoutSubscription?.cancel();
      await _stderrSubscription?.cancel();
      await _stdoutController?.close();

      if (!_exitCompleter.isCompleted) {
        _exitCompleter.complete(0);
      }
    }
  }

  /// Get the path to the Dart script that the Dart VM should load.
  ///
  /// In test mode (server or client), this is the generated test harness.
  /// In normal mode, this is the project's lib/main.dart (renamed to dart_mc.dart).
  String _getDartScriptPath() {
    if (testMode || clientTestMode) {
      // Use the test harness as entry point
      // Client tests use a different harness file
      final harnessName = clientTestMode ? 'client_test_harness.dart' : 'test_harness.dart';
      return p.join(project.rootDir, '.redstone', 'test', harnessName);
    } else {
      // Use the project's main.dart as entry point
      return p.join(project.rootDir, 'lib', 'main.dart');
    }
  }

  /// Prepare files before running
  Future<void> _prepareFiles() async {
    // Sync bridge code if source has changed
    final bridgeSynced = await BridgeSync.syncIfNeeded(project.rootDir);
    if (bridgeSynced) {
      Logger.info('Bridge code updated');
    }

    // Rebuild native library if sources changed
    final nativeRebuilt = await NativeBuildSync.rebuildIfNeeded(project.rootDir);
    if (nativeRebuilt) {
      Logger.info('Native library rebuilt');
    }

    // Generate assets first (blockstates, models, textures)
    await _generateAssets();

    // Copy native libs to run/natives/
    await _copyNativeLibs();

    // In server test mode, ensure EULA is accepted for server
    if (testMode && !clientTestMode) {
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

}
