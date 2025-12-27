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
  Completer<int> _exitCompleter = Completer<int>();
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  /// Stream controller for stdout lines (only in test mode)
  StreamController<String>? _stdoutController;

  /// Stream controller for monitoring output (used for waitForOutput)
  StreamController<String>? _outputMonitor;

  /// Detected world name from Minecraft output (for quick play on restart)
  String? _currentWorldName;

  MinecraftRunner(this.project, {this.testMode = false, this.clientTestMode = false});

  /// Get the currently detected world name
  String? get worldName => _currentWorldName;

  /// Exit code future - completes when Minecraft exits
  Future<int> get exitCode => _exitCompleter.future;

  /// Stream of stdout lines (only available in test mode).
  /// This is a broadcast stream so multiple listeners can subscribe.
  Stream<String>? get stdoutLines => _stdoutController?.stream;

  /// Start Minecraft with the mod
  /// If [quickPlayWorld] is provided, Minecraft will auto-join that world on startup.
  Future<void> start({String? quickPlayWorld}) async {
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

    // Add quick play world if provided (for auto-rejoin after restart)
    if (quickPlayWorld != null) {
      gradleArgs.add('-PquickPlayWorld=$quickPlayWorld');
      Logger.debug('Quick play world: $quickPlayWorld');
    }

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
      // In normal mode, manually pipe stdout/stderr
      _process = await Process.start(
        gradlew,
        gradleArgs,
        workingDirectory: project.minecraftDir,
        mode: ProcessStartMode.normal,
      );

      // Create output monitor for waitForOutput functionality
      _outputMonitor = StreamController<String>.broadcast();

      // Forward stdout and stderr to the terminal
      // Note: We intentionally do NOT pipe stdin to allow hot reload input
      _stdoutSubscription = _process!.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        stdout.writeln(line);
        _outputMonitor?.add(line);
        // Detect world name from Minecraft output for quick play on restart
        _detectWorldName(line);
      });
      _stderrSubscription = _process!.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        stderr.writeln(line);
        _outputMonitor?.add(line);
      });
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
      await _outputMonitor?.close();

      _process = null;

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

  /// Send a command to the Minecraft server via stdin
  void sendCommand(String command) {
    if (_process == null) {
      Logger.warning('Cannot send command - no process running');
      return;
    }
    // Write the command followed by newline
    _process!.stdin.writeln(command);
  }

  /// Wait for a specific pattern to appear in the output
  /// Returns true if pattern was found, false if timeout
  Future<bool> waitForOutput(
    String pattern, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_outputMonitor == null) {
      Logger.warning('Output monitoring not available');
      return false;
    }

    final regex = RegExp(pattern);
    final completer = Completer<bool>();

    StreamSubscription<String>? subscription;
    Timer? timeoutTimer;

    subscription = _outputMonitor!.stream.listen((line) {
      if (regex.hasMatch(line)) {
        timeoutTimer?.cancel();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    timeoutTimer = Timer(timeout, () {
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    return completer.future;
  }

  /// Restart the Minecraft process
  /// Stops the current process and starts a fresh one
  /// If [worldName] is provided, auto-join that world using Quick Play.
  Future<void> restart({String? worldName}) async {
    // Stop the current process
    await stop();

    // Reset the exit completer for the new process
    _exitCompleter = Completer<int>();

    // Start fresh with optional quick play world
    await start(quickPlayWorld: worldName);
  }

  /// Regular expression to detect world loading from Minecraft log output.
  /// The Java bridge logs: "[redstone] Loaded world: <world_folder_name>"
  /// This is logged in DartModLoader.java when SERVER_STARTED fires.
  static final _worldJoinRegex = RegExp(r'\[redstone\] Loaded world:\s*(.+)');

  /// Detect world name from Minecraft log output
  void _detectWorldName(String line) {
    final match = _worldJoinRegex.firstMatch(line);
    if (match != null) {
      _currentWorldName = match.group(1)?.trim();
      Logger.info('Detected world name: $_currentWorldName');
    }
  }
}
