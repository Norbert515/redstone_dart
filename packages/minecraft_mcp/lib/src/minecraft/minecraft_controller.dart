import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:redstone_cli/redstone_cli.dart';

import 'game_client.dart';

/// Status of the Minecraft instance.
enum MinecraftStatus {
  /// Not running.
  stopped,

  /// Starting up (CLI building/launching).
  starting,

  /// Running and ready for commands.
  running,

  /// Stopping.
  stopping,
}

/// Controls the lifecycle of a Minecraft client instance.
///
/// This controller manages starting and stopping Minecraft with the MCP game
/// server enabled, allowing AI agents to control the game via HTTP.
class MinecraftController {
  /// Path to the mod project directory.
  final String modPath;

  /// Port for the HTTP game server inside Minecraft.
  final int httpPort;

  /// The running Minecraft process.
  Process? _process;

  /// Current status.
  MinecraftStatus _status = MinecraftStatus.stopped;

  /// Stream controller for output lines.
  final _outputController = StreamController<String>.broadcast();

  /// Completer for process exit.
  Completer<int>? _exitCompleter;

  /// HTTP client for communicating with the game server.
  GameClient? _gameClient;

  /// Detected world name from Minecraft output.
  String? _worldName;

  /// Create a new Minecraft controller.
  MinecraftController({
    required this.modPath,
    this.httpPort = 8765,
  });

  /// Current status of Minecraft.
  MinecraftStatus get status => _status;

  /// Whether Minecraft is currently running.
  bool get isRunning => _status == MinecraftStatus.running;

  /// Stream of output lines from Minecraft.
  Stream<String> get output => _outputController.stream;

  /// The detected world name (set when Minecraft loads a world).
  String? get worldName => _worldName;

  /// HTTP client for the game server (available when running).
  GameClient? get gameClient => _gameClient;

  /// Path to the Minecraft log file.
  String? get logFilePath {
    final minecraftDir = _findMinecraftDir(modPath);
    if (minecraftDir == null) return null;
    return p.join(minecraftDir, 'run', 'logs', 'latest.log');
  }

  /// Start Minecraft client with the MCP game server enabled.
  ///
  /// This uses `redstone run` CLI command which handles:
  /// - Building the mod
  /// - Configuring options.txt
  /// - Starting Minecraft with the mod loaded
  ///
  /// Throws [StateError] if Minecraft is already running.
  Future<void> start() async {
    if (_status != MinecraftStatus.stopped) {
      throw StateError('Minecraft is already ${_status.name}');
    }

    _status = MinecraftStatus.starting;
    _exitCompleter = Completer<int>();
    _worldName = null;

    try {
      // Resolve the mod path to absolute
      final absoluteModPath = p.absolute(modPath);

      // Prepare the test world (redstone run --world doesn't do this automatically)
      await _prepareTestWorld(absoluteModPath);

      // Get the redstone CLI command
      final (executable, baseArgs) = await _getRedstoneCommand(absoluteModPath);

      // Build args for redstone run
      final args = [
        ...baseArgs,
        'run',
        '--world', 'dart_visual_test', // Auto-join this world
        '--no-hot-reload', // We don't need hot reload for MCP
        '--mcp-mode', // Enable MCP mode
        '--mcp-port', httpPort.toString(),
        '--background', // Prevent window focus stealing for automated testing
      ];

      // Start the process
      _process = await Process.start(
        executable,
        args,
        workingDirectory: absoluteModPath,
        mode: ProcessStartMode.normal,
      );

      // Forward stdout
      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _outputController.add(line);
        _processOutputLine(line);
      });

      // Forward stderr
      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _outputController.add('[stderr] $line');
      });

      // Handle process exit
      _process!.exitCode.then((code) {
        _status = MinecraftStatus.stopped;
        _gameClient?.close();
        _gameClient = null;
        if (_exitCompleter != null && !_exitCompleter!.isCompleted) {
          _exitCompleter!.complete(code);
        }
      });

      // Create game client
      _gameClient = GameClient(port: httpPort);
    } catch (e) {
      _status = MinecraftStatus.stopped;
      rethrow;
    }
  }

  /// Get the redstone CLI command and base arguments.
  ///
  /// Returns a tuple of (executable, baseArgs) where:
  /// - If `redstone` is in PATH: ('redstone', [])
  /// - Otherwise: ('dart', ['run', 'redstone_cli:redstone'])
  Future<(String, List<String>)> _getRedstoneCommand(String modPath) async {
    // Try to find redstone in PATH
    final which = Platform.isWindows
        ? await Process.run('where', ['redstone'])
        : await Process.run('which', ['redstone']);

    if (which.exitCode == 0) {
      return ('redstone', <String>[]);
    }

    // Fall back to dart run from the mod directory
    // This works because mod projects have redstone_cli as a dev dependency
    return ('dart', ['run', 'redstone_cli:redstone']);
  }

  /// Wait for Minecraft to be ready (HTTP server responding).
  ///
  /// Returns true if ready, false if timeout.
  Future<bool> waitForReady({
    Duration timeout = const Duration(minutes: 2),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    if (_gameClient == null) {
      return false;
    }

    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final healthy = await _gameClient!.isHealthy();
        if (healthy) {
          _status = MinecraftStatus.running;
          return true;
        }
      } catch (_) {
        // Server not ready yet
      }

      // Check if process exited
      if (_exitCompleter?.isCompleted ?? false) {
        return false;
      }

      await Future<void>.delayed(pollInterval);
    }

    return false;
  }

  /// Stop the running Minecraft instance.
  Future<void> stop() async {
    if (_status == MinecraftStatus.stopped) {
      return;
    }

    _status = MinecraftStatus.stopping;

    if (!Platform.isWindows) {
      // On Unix, we need to kill both the Minecraft Java process and the gradle wrapper.
      // The gradle wrapper spawns Minecraft as a child process, but they're not in
      // the same process group, so we need to kill them separately by pattern matching.

      // Step 1: Try graceful shutdown with SIGTERM
      try {
        await Process.run('pkill', ['-TERM', '-f', 'fabric.dli.main']);
      } catch (_) {
        // Ignore errors (process may not exist)
      }
      try {
        await Process.run('pkill', ['-TERM', '-f', 'gradle-wrapper.jar runClient']);
      } catch (_) {
        // Ignore errors
      }

      // Wait for graceful shutdown
      await Future<void>.delayed(const Duration(seconds: 2));

      // Step 2: Check if Minecraft is still running and force kill if needed
      final checkResult = await Process.run('pgrep', ['-f', 'fabric.dli.main']);
      if (checkResult.exitCode == 0) {
        // Still running, force kill
        try {
          await Process.run('pkill', ['-9', '-f', 'fabric.dli.main']);
        } catch (_) {
          // Ignore errors
        }
        try {
          await Process.run('pkill', ['-9', '-f', 'gradle-wrapper.jar runClient']);
        } catch (_) {
          // Ignore errors
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } else {
      // On Windows, use taskkill with /T to kill the process tree
      if (_process != null) {
        try {
          await Process.run('taskkill', ['/F', '/T', '/PID', _process!.pid.toString()]);
        } catch (_) {
          _process!.kill(ProcessSignal.sigkill);
        }
      }
    }

    // Clean up process reference
    _process = null;
    _gameClient?.close();
    _gameClient = null;
    _status = MinecraftStatus.stopped;
  }

  /// Wait for the process to exit.
  Future<int> waitForExit() {
    return _exitCompleter?.future ?? Future.value(0);
  }

  /// Dispose of resources.
  void dispose() {
    stop();
    _outputController.close();
  }

  /// Regular expression to detect world loading from Minecraft log output.
  static final _worldJoinRegex = RegExp(r'\[redstone\] Loaded world:\s*(.+)');

  /// Regular expression to detect MCP server ready marker.
  static final _mcpReadyRegex = RegExp(r'\[MCP\] Server ready on port (\d+)');

  /// Process output line for patterns.
  void _processOutputLine(String line) {
    // Detect world name
    final worldMatch = _worldJoinRegex.firstMatch(line);
    if (worldMatch != null) {
      _worldName = worldMatch.group(1)?.trim();
    }

    // Detect MCP server ready
    final mcpMatch = _mcpReadyRegex.firstMatch(line);
    if (mcpMatch != null) {
      _status = MinecraftStatus.running;
    }
  }

  /// Prepare the test world for MCP-controlled Minecraft.
  ///
  /// Generates the template world if needed and copies it to the Minecraft
  /// saves directory so Quick Play can join it automatically.
  ///
  /// Note: `redstone run --world` doesn't prepare the test world automatically,
  /// so we need to do it here.
  Future<void> _prepareTestWorld(String modPath) async {
    // Find the root directory (contains .redstone folder or packages)
    var rootDir = modPath;
    var current = Directory(modPath);
    while (current.path != current.parent.path) {
      if (Directory(p.join(current.path, '.redstone')).existsSync() ||
          Directory(p.join(current.path, 'packages')).existsSync()) {
        rootDir = current.path;
        break;
      }
      current = current.parent;
    }

    // Find the Minecraft directory for saves path
    final minecraftDir = _findMinecraftDir(modPath);
    if (minecraftDir == null) {
      throw StateError(
        'Could not find Minecraft directory (minecraft/). '
        'Ensure you are running from within a Redstone mod project.',
      );
    }

    // Generate template if needed
    final generator = TemplateWorldGenerator(rootDir);
    await generator.generateIfNeeded();

    // Copy template to Minecraft saves directory
    final savesDir = p.join(minecraftDir, 'run', 'saves');
    await generator.copyToSaves(savesDir);
  }

  /// Find the Minecraft directory within the mod project.
  ///
  /// This is the 'minecraft' subdirectory of the mod root, where Gradle
  /// runs Minecraft from and where saves are stored.
  String? _findMinecraftDir(String modPath) {
    // The minecraft dir is directly inside the mod path
    final minecraftDir = Directory(p.join(modPath, 'minecraft'));
    if (minecraftDir.existsSync()) {
      return minecraftDir.path;
    }
    return null;
  }
}
