import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../assets/asset_generator.dart';
import '../project/bridge_sync.dart';
import '../project/native_build_sync.dart';
import '../project/redstone_project.dart';
import '../util/logger.dart';

/// Information about a detected VM service
class VmServiceInfo {
  final String httpUri;
  final String wsUri;
  final bool isClient;

  VmServiceInfo({
    required this.httpUri,
    required this.wsUri,
    required this.isClient,
  });

  @override
  String toString() =>
      'VmServiceInfo(httpUri: $httpUri, wsUri: $wsUri, isClient: $isClient)';
}

/// Manages the Minecraft process lifecycle
class MinecraftRunner {
  final RedstoneProject project;
  final bool testMode;
  final bool clientTestMode;
  final bool flutterMode;

  /// Enable dual-runtime mode (server dart_dll + client Flutter)
  final bool dualRuntimeMode;

  /// Port for server Dart VM service (for hot reload). 0 means let the VM pick a free port.
  final int serverVmServicePort;

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

  /// Detected server VM service info
  VmServiceInfo? _serverVmService;

  /// Detected client VM service info
  VmServiceInfo? _clientVmService;

  /// Callbacks for when VM services are detected
  void Function(VmServiceInfo)? onServerVmServiceDetected;
  void Function(VmServiceInfo)? onClientVmServiceDetected;

  MinecraftRunner(
    this.project, {
    this.testMode = false,
    this.clientTestMode = false,
    this.flutterMode = false,
    this.dualRuntimeMode = false,
    this.serverVmServicePort = 5858, // Fixed port for server Dart VM service
  });

  /// Get the currently detected world name
  String? get worldName => _currentWorldName;

  /// Get the detected server VM service info
  VmServiceInfo? get serverVmService => _serverVmService;

  /// Get the detected client VM service info
  VmServiceInfo? get clientVmService => _clientVmService;

  /// Exit code future - completes when Minecraft exits
  Future<int> get exitCode => _exitCompleter.future;

  /// Stream of stdout lines (only available in test mode).
  /// This is a broadcast stream so multiple listeners can subscribe.
  Stream<String>? get stdoutLines => _stdoutController?.stream;

  /// Start Minecraft with the mod
  /// If [quickPlayWorld] is provided, Minecraft will auto-join that world on startup.
  Future<void> start({String? quickPlayWorld}) async {
    // Reset VM service detections
    _serverVmService = null;
    _clientVmService = null;

    // First, prepare files (assets, native libs, etc.)
    await _prepareFiles();

    // Start Minecraft via Gradle
    final gradlew = Platform.isWindows ? 'gradlew.bat' : './gradlew';

    // Determine which Gradle task to use:
    // - clientTestMode: runClient (client tests with visual testing)
    // - testMode: runServer (headless server tests)
    // - normal: runClient (interactive development)
    final gradleTask = testMode && !clientTestMode ? 'runServer' : 'runClient';

    Logger.debug(
        'Starting Minecraft from ${project.minecraftDir} with task: $gradleTask');

    // Determine the script path for Dart VM
    final scriptPath = _getDartScriptPath();
    final packageConfigPath = _getPackageConfigPath();
    Logger.debug('Dart script path: $scriptPath');
    Logger.debug('Package config path: $packageConfigPath');

    // Pass the script path via Gradle project property
    // This is more reliable than environment variables because Gradle daemon
    // uses its own environment that was set when it started
    final gradleArgs = [
      gradleTask,
      '-PdartScriptPath=$scriptPath',
      '-PdartPackageConfigPath=$packageConfigPath',
    ];

    // Add quick play world if provided (for auto-rejoin after restart)
    if (quickPlayWorld != null) {
      gradleArgs.add('-PquickPlayWorld=$quickPlayWorld');
      Logger.debug('Quick play world: $quickPlayWorld');
    }

    // Enable dual runtime mode if specified
    if (dualRuntimeMode) {
      gradleArgs.add('-PdualRuntimeMode=true');
      Logger.debug('Dual runtime mode enabled');
    }

    // Pass server VM service port for hot reload support
    if (serverVmServicePort > 0) {
      gradleArgs.add('-PserverVmServicePort=$serverVmServicePort');
      Logger.debug('Server VM service port: $serverVmServicePort');
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
        // Also detect VM service URLs in test mode
        _detectVmServiceUrl(line);
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
        // Detect VM service URLs for hot reload
        _detectVmServiceUrl(line);
      });
      _stderrSubscription = _process!.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        stderr.writeln(line);
        _outputMonitor?.add(line);
        // Also check stderr for VM service URLs (some runtimes print there)
        _detectVmServiceUrl(line);
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
  /// In normal mode, this is the project's server entry point (for dual-runtime)
  /// or main entry point (for single runtime).
  String _getDartScriptPath() {
    if (testMode || clientTestMode) {
      // Use the test harness as entry point
      // Client tests use a different harness file
      final harnessName =
          clientTestMode ? 'client_test_harness.dart' : 'test_harness.dart';
      return p.join(project.rootDir, '.redstone', 'test', harnessName);
    } else if (dualRuntimeMode) {
      // In dual-runtime mode, use the configured server entry point
      return project.serverEntry;
    } else {
      // Use the project's main entry point
      return project.entryPoint;
    }
  }

  /// Get the path to the package_config.json for the Dart VM.
  ///
  /// In test mode, this is the test harness's package_config.json.
  /// In normal mode, this is the project's package_config.json.
  String _getPackageConfigPath() {
    if (testMode || clientTestMode) {
      // Use the test harness's package config (generated by pub get in the harness dir)
      return p.join(
          project.rootDir, '.redstone', 'test', '.dart_tool', 'package_config.json');
    } else {
      // Use the project's package config
      return project.packagesConfigPath;
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
    final nativeRebuilt = await NativeBuildSync.rebuildIfNeeded(
      project.rootDir,
      flutterMode: flutterMode,
    );
    if (nativeRebuilt) {
      Logger.info('Native library rebuilt');
    }

    // Generate assets first (blockstates, models, textures)
    await _generateAssets();

    // Copy native libs to run/natives/
    await _copyNativeLibs();

    // Copy Flutter assets if in Flutter mode
    if (flutterMode) {
      await _copyFlutterAssets();
    }

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
    // Priority order:
    // 1. Configured datagen entry point from redstone.yaml
    // 2. Server entry point (for dual-runtime packages structure)
    // 3. main_datagen.dart (legacy Flutter mods)
    // 4. main.dart (legacy single-file mods)
    final datagenScript = File(project.datagenEntry);
    final serverScript = File(project.serverEntry);
    final mainDatagenScript = File(p.join(project.rootDir, 'lib', 'main_datagen.dart'));
    final mainScript = File(p.join(project.rootDir, 'lib', 'main.dart'));

    String scriptPath;
    if (datagenScript.existsSync()) {
      // Use configured datagen entry point
      scriptPath = p.relative(project.datagenEntry, from: project.rootDir);
    } else if (serverScript.existsSync()) {
      // Use server entry point for dual-runtime mode
      scriptPath = p.relative(project.serverEntry, from: project.rootDir);
    } else if (mainDatagenScript.existsSync()) {
      // Fall back to main_datagen.dart for legacy Flutter mods
      scriptPath = 'lib/main_datagen.dart';
    } else if (mainScript.existsSync()) {
      // Fall back to main.dart for legacy single-file mods
      scriptPath = 'lib/main.dart';
    } else {
      Logger.error('No entry point found for datagen.');
      Logger.info('Expected one of:');
      Logger.info('  - ${project.datagenEntry}');
      Logger.info('  - ${project.serverEntry}');
      Logger.info('  - lib/main_datagen.dart');
      Logger.info('  - lib/main.dart');
      throw Exception('No datagen entry point found');
    }

    Logger.info('Running mod in datagen mode ($scriptPath)...');
    final result = await Process.run(
      'dart',
      ['run', scriptPath],
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
    final targetDir =
        Directory(p.join(project.minecraftDir, 'run', 'natives'));

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

  /// Copy Flutter assets to mods folder for Minecraft to find them
  Future<void> _copyFlutterAssets() async {
    final sourceDir = Directory(project.flutterAssetsDir);
    final targetDir = Directory(
      p.join(project.minecraftDir, 'run', 'mods', 'dart_mc', 'flutter_assets'),
    );

    if (!sourceDir.existsSync()) {
      Logger.warning('Flutter assets not found at ${sourceDir.path}');
      return;
    }

    Logger.debug('Copying Flutter assets to ${targetDir.path}');

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    await _copyDirectoryRecursive(sourceDir, targetDir);
  }

  /// Recursively copy all files from source directory to target directory
  Future<void> _copyDirectoryRecursive(
    Directory source,
    Directory target,
  ) async {
    await for (final entity in source.list()) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        entity.copySync(targetPath);
      } else if (entity is Directory) {
        final targetSubDir = Directory(targetPath);
        if (!targetSubDir.existsSync()) {
          targetSubDir.createSync(recursive: true);
        }
        await _copyDirectoryRecursive(entity, targetSubDir);
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

  /// Regular expression to detect Dart VM service URL from output.
  /// Server Dart VM prints: "The Dart VM service is listening on http://127.0.0.1:5858/..."
  /// Note: No "flutter:" prefix for server dart_dll runtime.
  static final _serverVmServiceRegex = RegExp(
    r'(?<!flutter:\s*)The Dart VM service is listening on (http://[\d\.]+:\d+/[^\s]+)',
  );

  /// Regular expression to detect Flutter/Client VM service URL from output.
  /// Flutter prints: "flutter: The Dart VM service is listening on http://127.0.0.1:XXXX/..."
  static final _clientVmServiceRegex = RegExp(
    r'flutter:\s*The Dart VM service is listening on (http://[\d\.]+:\d+/[^\s]+)',
  );

  /// Detect world name from Minecraft log output
  void _detectWorldName(String line) {
    final match = _worldJoinRegex.firstMatch(line);
    if (match != null) {
      _currentWorldName = match.group(1)?.trim();
      Logger.info('Detected world name: $_currentWorldName');
    }
  }

  /// Detect VM service URL from Minecraft/runtime output
  void _detectVmServiceUrl(String line) {
    // Check for client (Flutter) VM service first (more specific pattern)
    final clientMatch = _clientVmServiceRegex.firstMatch(line);
    if (clientMatch != null) {
      final httpUri = clientMatch.group(1)!;
      final wsUri = _httpToWsUri(httpUri);
      _clientVmService = VmServiceInfo(
        httpUri: httpUri,
        wsUri: wsUri,
        isClient: true,
      );
      Logger.debug('Detected client VM service: $httpUri');
      onClientVmServiceDetected?.call(_clientVmService!);
      return;
    }

    // Check for server (dart_dll) VM service
    final serverMatch = _serverVmServiceRegex.firstMatch(line);
    if (serverMatch != null) {
      final httpUri = serverMatch.group(1)!;
      final wsUri = _httpToWsUri(httpUri);
      _serverVmService = VmServiceInfo(
        httpUri: httpUri,
        wsUri: wsUri,
        isClient: false,
      );
      Logger.debug('Detected server VM service: $httpUri');
      onServerVmServiceDetected?.call(_serverVmService!);
      return;
    }
  }

  /// Convert HTTP URI to WebSocket URI for VM service connection
  String _httpToWsUri(String httpUri) {
    // http://127.0.0.1:5858/abc123/ -> ws://127.0.0.1:5858/abc123/ws
    var wsUri = httpUri.replaceFirst('http://', 'ws://');
    if (!wsUri.endsWith('/')) {
      wsUri += '/';
    }
    wsUri += 'ws';
    return wsUri;
  }
}
