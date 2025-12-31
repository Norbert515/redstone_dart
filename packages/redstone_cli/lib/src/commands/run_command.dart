import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../flutter/flutter.dart';
import '../project/redstone_project.dart';
import '../runner/minecraft_runner.dart';
import '../runner/hot_reload_client.dart';
import '../util/logger.dart';

/// Exception thrown when the process exits before an operation completes.
class ProcessExitException implements Exception {
  final int exitCode;
  ProcessExitException(this.exitCode);
}

/// Helper class to read from /dev/tty directly, which survives subprocess restarts.
/// When stdin gets corrupted by a subprocess, we can create a fresh stream from /dev/tty.
class TtyInput {
  Stream<List<int>>? _stream;
  IOSink? _sink;

  /// Get an input stream from /dev/tty (Unix) or stdin (Windows/fallback)
  Stream<List<int>> getInputStream() {
    if (_stream != null) return _stream!;

    if (!Platform.isWindows) {
      try {
        final ttyFile = File('/dev/tty');
        _stream = ttyFile.openRead();
        return _stream!;
      } catch (e) {
        Logger.debug('Could not open /dev/tty: $e, using stdin');
      }
    }

    // Fallback to stdin
    _stream = stdin;
    return _stream!;
  }

  /// Create a fresh input stream (call after subprocess restart)
  Stream<List<int>> refreshInputStream() {
    _stream = null;
    return getInputStream();
  }

  /// Set terminal to raw mode
  void setRawMode() {
    try {
      if (stdin.hasTerminal) {
        stdin.echoMode = false;
        stdin.lineMode = false;
      }
    } catch (_) {}
  }

  /// Restore terminal to normal mode
  void restoreMode() {
    try {
      stdin.echoMode = true;
      stdin.lineMode = true;
    } catch (_) {}
  }
}

class RunCommand extends Command<int> {
  @override
  final name = 'run';

  @override
  final description = 'Build and run your Redstone mod in Minecraft.';

  /// Flag to prevent concurrent hot restarts
  bool _isRestarting = false;

  /// TTY input helper for reading keyboard input
  final _ttyInput = TtyInput();

  /// Current stdin subscription (can be recreated after restart)
  StreamSubscription<List<int>>? _stdinSubscription;

  /// File watcher subscriptions for auto-reload
  final List<StreamSubscription> _fileWatcherSubscriptions = [];

  /// Frontend server manager for incremental compilation
  FrontendServerManager? _frontendServer;

  /// Flutter SDK reference
  FlutterSdk? _flutterSdk;

  RunCommand() {
    argParser.addOption(
      'device',
      abbr: 'd',
      help: 'Target Minecraft version/device.',
    );
    argParser.addFlag(
      'hot-reload',
      help: 'Enable hot reload (default: on).',
      defaultsTo: true,
    );
    argParser.addFlag(
      'flutter',
      help: 'Enable Flutter embedding mode (experimental).',
      negatable: false,
    );
    argParser.addFlag(
      'dual-runtime',
      help:
          'Enable dual runtime mode (server dart_dll + client Flutter). Implies --flutter.',
      negatable: false,
    );
    argParser.addFlag(
      'watch',
      help: 'Watch for file changes and auto-reload.',
      defaultsTo: true,
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show verbose output.',
      negatable: false,
    );
  }

  @override
  Future<int> run() async {
    // Find project
    final project = RedstoneProject.find();
    if (project == null) {
      Logger.error('No Redstone project found.');
      Logger.info('Run this command from within a Redstone project directory.');
      return 1;
    }

    Logger.newLine();
    Logger.header('🔥 Redstone is running ${project.name}');
    Logger.newLine();

    final hotReloadEnabled = argResults!['hot-reload'] as bool;
    final flutterEnabled = argResults!['flutter'] as bool;
    final dualRuntimeFlagEnabled = argResults!['dual-runtime'] as bool;
    final watchEnabled = argResults!['watch'] as bool;

    // Auto-detect dual-runtime mode if project has custom entry points configured
    // or if explicitly enabled via --dual-runtime flag
    final dualRuntimeEnabled = dualRuntimeFlagEnabled || project.hasDualRuntime;

    if (project.hasDualRuntime && !dualRuntimeFlagEnabled) {
      Logger.info('Auto-detected dual-runtime mode from redstone.yaml');
    }

    // Dual runtime implies Flutter mode
    final effectiveFlutterEnabled = flutterEnabled || dualRuntimeEnabled;

    // If Flutter mode is enabled, prepare Flutter assets
    if (effectiveFlutterEnabled) {
      final flutterResult = await _prepareFlutterAssets(
        project,
        dualRuntime: dualRuntimeEnabled,
      );
      if (!flutterResult) {
        return 1;
      }
    }

    // Start Minecraft
    final runner = MinecraftRunner(
      project,
      flutterMode: effectiveFlutterEnabled,
      dualRuntimeMode: dualRuntimeEnabled,
    );

    try {
      // Create hot reload client
      final hotReload = HotReloadClient();

      // If Flutter mode is enabled, set up frontend server for incremental compilation
      if (effectiveFlutterEnabled && _frontendServer != null) {
        hotReload.setFrontendServer(_frontendServer!);
      }

      // Set up VM service detection callbacks for dual-runtime mode
      if (dualRuntimeEnabled) {
        runner.onServerVmServiceDetected = (vmService) {
          hotReload.setServerUri(vmService.wsUri);
          Logger.info('Server VM service detected: ${vmService.httpUri}');
        };
        runner.onClientVmServiceDetected = (vmService) {
          hotReload.setClientUri(vmService.wsUri);
          Logger.info('Client VM service detected: ${vmService.httpUri}');
        };
      }

      await runner.start();

      if (hotReloadEnabled) {
        if (dualRuntimeEnabled) {
          Logger.info(
              'Hot reload enabled (dual-runtime). Waiting for VM services...');
        } else {
          Logger.info('Hot reload enabled. Connecting to Dart VM...');
        }

        // Race connection against process exit to detect build failures early
        bool connected = false;
        try {
          if (dualRuntimeEnabled) {
            // In dual-runtime mode, wait for both VM services to be detected
            connected = await _waitForDualRuntimeConnection(
              runner,
              hotReload,
            );
          } else {
            connected = await Future.any([
              hotReload.connect(),
              runner.exitCode.then((code) {
                // Process exited before we could connect
                throw ProcessExitException(code);
              }),
            ]);
          }
        } on ProcessExitException catch (e) {
          Logger.error(
              'Process exited with code ${e.exitCode} before hot reload could connect');
          hotReload.cancel();
          await _cleanup();
          await runner.stop();
          // Use exit() to force quit - the hotReload.connect() Future.delayed
          // timer may still be pending and would keep the event loop alive
          exit(e.exitCode);
        }

        if (connected) {
          Logger.success('Connected to Dart VM service');
          Logger.newLine();
          _printHelp(dualRuntimeEnabled);
          Logger.newLine();

          // Set up a completer that resolves when we should exit
          final exitCompleter = Completer<int>();

          // Monitor process exit (but ignore during hot restart)
          void attachExitListener() {
            runner.exitCode.then((code) {
              if (!exitCompleter.isCompleted && !_isRestarting) {
                Logger.newLine();
                Logger.info('Process exited with code $code');
                exitCompleter.complete(code);
              }
            });
          }

          attachExitListener();

          // Listen for keyboard input using TtyInput (survives subprocess restarts)
          _ttyInput.setRawMode();

          // Periodically restore terminal state (Gradle subprocess may override)
          final terminalRestoreTimer =
              Timer.periodic(const Duration(seconds: 2), (_) {
            _ttyInput.setRawMode();
          });

          // Start listening for input
          _setupInputListener(
            runner,
            hotReload,
            exitCompleter,
            dualRuntimeEnabled,
          );

          // Start file watcher for auto-reload if enabled
          if (watchEnabled) {
            _startFileWatcher(project, hotReload, dualRuntimeEnabled);
          }

          // Wait for exit (either from process dying or user pressing 'q')
          final exitCode = await exitCompleter.future;
          terminalRestoreTimer.cancel();
          await _cleanup();
          _ttyInput.restoreMode();
          // Force exit - /dev/tty stream keeps event loop alive
          exit(exitCode);
        } else {
          Logger.warning('Could not connect to Dart VM. Hot reload disabled.');
        }
      }

      // Wait for Minecraft to exit
      final exitCode = await runner.exitCode;
      return exitCode;
    } catch (e) {
      Logger.error('Error: $e');
      await _cleanup();
      await runner.stop();
      return 1;
    } finally {
      // Restore terminal
      _ttyInput.restoreMode();
      await _cleanup();
    }
  }

  /// Wait for dual-runtime VM services to be detected and connect
  Future<bool> _waitForDualRuntimeConnection(
    MinecraftRunner runner,
    HotReloadClient hotReload,
  ) async {
    const maxWaitTime = Duration(minutes: 2);
    const checkInterval = Duration(milliseconds: 500);
    final stopwatch = Stopwatch()..start();

    // Track if process exited
    var processExited = false;
    int? exitCodeValue;
    runner.exitCode.then((code) {
      processExited = true;
      exitCodeValue = code;
    });

    // Wait for both VM services to be detected
    while (stopwatch.elapsed < maxWaitTime) {
      // Check if process exited
      if (processExited) {
        throw ProcessExitException(exitCodeValue ?? 1);
      }

      final hasServer = runner.serverVmService != null;
      final hasClient = runner.clientVmService != null;

      if (hasServer && hasClient) {
        // Both detected, now connect
        Logger.debug('Both VM services detected, connecting...');
        return await hotReload.connect();
      }

      if (hasServer && !hasClient) {
        Logger.debug('Waiting for client VM service...');
      } else if (!hasServer && hasClient) {
        Logger.debug('Waiting for server VM service...');
      }

      await Future.delayed(checkInterval);
    }

    Logger.warning('Timeout waiting for dual-runtime VM services');
    return false;
  }

  /// Prepare Flutter assets for embedding mode
  Future<bool> _prepareFlutterAssets(
    RedstoneProject project, {
    bool dualRuntime = false,
  }) async {
    Logger.info('Preparing Flutter assets...');

    // 1. Locate Flutter SDK
    _flutterSdk = FlutterSdk.locate();
    if (_flutterSdk == null) {
      Logger.error('Flutter SDK not found.');
      Logger.info('Please install Flutter and ensure it is in your PATH.');
      Logger.info('Or set the FLUTTER_ROOT environment variable.');
      return false;
    }
    Logger.debug('Found Flutter SDK at: ${_flutterSdk!.path}');

    // 2. Ensure Flutter artifacts are downloaded
    if (!_flutterSdk!.hasRequiredArtifacts) {
      Logger.info('Downloading Flutter artifacts...');
      final downloaded = await _flutterSdk!.ensureArtifacts();
      if (!downloaded) {
        Logger.error('Failed to download Flutter artifacts.');
        Logger.info('Try running: flutter precache');
        return false;
      }
    }

    // 3. Create assets directory
    final assetsDir = Directory(project.flutterAssetsDir);
    if (!assetsDir.existsSync()) {
      assetsDir.createSync(recursive: true);
    }

    // 4. Build Flutter assets (compile mod to kernel_blob.bin)
    // In dual-runtime mode, use the configured client entry point
    final clientEntryPoint = dualRuntime
        ? project.clientEntry
        : project.entryPoint;

    Logger.step('Compiling Dart code to Flutter kernel...');
    final compiler = ModCompiler(flutterSdk: _flutterSdk!);
    final result = await compiler.compileToAssets(
      entryPoint: clientEntryPoint,
      assetsDir: project.flutterAssetsDir,
      packagesPath: project.packagesConfigPath,
    );

    if (!result.success) {
      Logger.error('Failed to compile mod:');
      if (result.errors.isNotEmpty) {
        Logger.error(result.errors);
      }
      return false;
    }
    Logger.success('Compiled to ${result.outputPath}');

    // 5. In dual-runtime mode, copy server sources for dart_dll runtime
    if (dualRuntime) {
      final serverResult = await _compileServerKernel(project);
      if (!serverResult) {
        return false;
      }
    }

    // 6. Start frontend_server for incremental compilation (hot reload)
    Logger.step('Starting frontend server for hot reload...');
    _frontendServer = FrontendServerManager(
      flutterSdk: _flutterSdk!,
      entryPoint: clientEntryPoint,
      outputDir: project.flutterAssetsDir,
      packagesPath: project.packagesConfigPath,
    );

    try {
      await _frontendServer!.start().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Frontend server startup timed out');
        },
      );
      Logger.success('Frontend server ready for incremental compilation');
    } catch (e) {
      Logger.warning('Failed to start frontend server: $e');
      Logger.info('Hot reload will use full recompilation');
      await _frontendServer?.stop();
      _frontendServer = null;
    }

    // 7. Copy Flutter dependencies to natives directory
    await _copyFlutterDependencies(project);

    return true;
  }

  /// Prepare server sources for dual-runtime mode
  ///
  /// The dart_dll runtime compiles Dart sources at runtime, so we need to
  /// copy the source files and package config to the mod directory.
  Future<bool> _compileServerKernel(RedstoneProject project) async {
    final serverEntryPoint = project.serverEntry;
    final serverEntryFile = File(serverEntryPoint);

    // Check if server entry point exists
    if (!serverEntryFile.existsSync()) {
      Logger.warning('Server entry point not found: $serverEntryPoint');
      Logger.info('Skipping server source copy.');
      Logger.info('Create the server entry point or configure it in redstone.yaml to enable dual-runtime mode.');
      return true; // Not an error, just skip
    }

    Logger.step('Copying server sources for dart_dll runtime...');

    // Target directory for server sources
    final targetModDir = p.join(
      project.minecraftDir,
      'run',
      'mods',
      'dart_mc',
    );

    final targetDir = Directory(targetModDir);
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    try {
      // 1. Copy server package's lib/ directory to mods/dart_mc/lib/
      // Use the configured server package directory (e.g., packages/server/lib)
      final serverPackageLibDir = p.join(project.serverPackageDir, 'lib');
      final sourceLibDir = Directory(serverPackageLibDir);
      final targetLibDir = Directory(p.join(targetModDir, 'lib'));

      // Delete existing lib dir to ensure clean copy
      if (targetLibDir.existsSync()) {
        targetLibDir.deleteSync(recursive: true);
      }

      await _copyDirectory(sourceLibDir, targetLibDir);
      Logger.success('Server sources copied from ${p.relative(serverPackageLibDir, from: project.rootDir)}');

      // 2. Copy .dart_tool/package_config.json with absolutized paths
      // Try server package's .dart_tool first, then fall back to root project's
      var sourcePackageConfig = File(p.join(project.serverPackageDir, '.dart_tool', 'package_config.json'));
      var pubGetDir = project.serverPackageDir;

      if (!sourcePackageConfig.existsSync()) {
        // Fall back to root project's package config (for workspace setups)
        sourcePackageConfig = File(p.join(project.rootDir, '.dart_tool', 'package_config.json'));
        pubGetDir = project.rootDir;
      }

      if (!sourcePackageConfig.existsSync()) {
        Logger.warning('Package config not found, running dart pub get...');
        await Process.run('dart', ['pub', 'get'], workingDirectory: pubGetDir);
      }

      if (sourcePackageConfig.existsSync()) {
        final targetDartToolDir = Directory(p.join(targetModDir, '.dart_tool'));
        if (!targetDartToolDir.existsSync()) {
          targetDartToolDir.createSync(recursive: true);
        }
        final targetPackageConfig = File(p.join(targetDartToolDir.path, 'package_config.json'));

        // Read and transform the package config to use absolute paths
        final sourceDir = p.dirname(sourcePackageConfig.path);
        final packageConfigContent = await sourcePackageConfig.readAsString();
        final packageConfig = jsonDecode(packageConfigContent) as Map<String, dynamic>;

        // Transform relative rootUri paths to absolute file:// URIs
        if (packageConfig['packages'] is List) {
          final packages = packageConfig['packages'] as List;
          for (final pkg in packages) {
            if (pkg is Map<String, dynamic>) {
              final rootUri = pkg['rootUri'] as String?;
              if (rootUri != null && !rootUri.startsWith('file://')) {
                // This is a relative path, make it absolute
                final absolutePath = p.normalize(p.join(sourceDir, rootUri));
                pkg['rootUri'] = 'file://$absolutePath';
              }
            }
          }
        }

        // Write the transformed package config
        final encoder = JsonEncoder.withIndent('  ');
        await targetPackageConfig.writeAsString(encoder.convert(packageConfig));
        Logger.success('Package config copied (with absolute paths) to ${targetPackageConfig.path}');
      }

      return true;
    } catch (e) {
      Logger.error('Failed to copy server sources: $e');
      return false;
    }
  }

  /// Copy Flutter engine dependencies to the mod's natives directory
  Future<void> _copyFlutterDependencies(RedstoneProject project) async {
    if (_flutterSdk == null) return;

    Logger.step('Copying Flutter dependencies...');
    final nativesDir =
        Directory(p.join(project.minecraftDir, 'run', 'natives'));
    if (!nativesDir.existsSync()) {
      nativesDir.createSync(recursive: true);
    }

    // Copy icudtl.dat
    final icuDataSource = File(_flutterSdk!.icuDataPath);
    if (icuDataSource.existsSync()) {
      final icuDataTarget = File(p.join(nativesDir.path, 'icudtl.dat'));
      await icuDataSource.copy(icuDataTarget.path);
      Logger.debug('Copied icudtl.dat');
    } else {
      Logger.warning('ICU data not found at ${_flutterSdk!.icuDataPath}');
    }

    // Copy Flutter engine library based on platform
    // On macOS, this is FlutterMacOS.framework
    // On Linux, it's libflutter_engine.so
    // On Windows, it's flutter_engine.dll
    final engineLibPath = _flutterSdk!.engineLibPath;
    final engineDir = Directory(engineLibPath);

    if (engineDir.existsSync()) {
      if (Platform.isMacOS) {
        // Copy FlutterMacOS.framework
        final frameworkPath = _flutterSdk!.flutterFrameworkPath;
        if (frameworkPath != null && Directory(frameworkPath).existsSync()) {
          final targetPath = p.join(nativesDir.path, 'FlutterMacOS.framework');
          await _copyDirectory(Directory(frameworkPath), Directory(targetPath));
          Logger.debug('Copied FlutterMacOS.framework');
        }
      } else if (Platform.isLinux) {
        // Copy libflutter_engine.so
        final engineFile = File(p.join(engineLibPath, 'libflutter_engine.so'));
        if (engineFile.existsSync()) {
          await engineFile
              .copy(p.join(nativesDir.path, 'libflutter_engine.so'));
          Logger.debug('Copied libflutter_engine.so');
        }
      } else if (Platform.isWindows) {
        // Copy flutter_engine.dll
        final engineFile = File(p.join(engineLibPath, 'flutter_engine.dll'));
        if (engineFile.existsSync()) {
          await engineFile.copy(p.join(nativesDir.path, 'flutter_engine.dll'));
          Logger.debug('Copied flutter_engine.dll');
        }
      }
    }

    Logger.success('Flutter dependencies copied');
  }

  /// Recursively copy a directory
  Future<void> _copyDirectory(Directory source, Directory target) async {
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

  /// Start watching for file changes with intelligent reload targeting
  void _startFileWatcher(
    RedstoneProject project,
    HotReloadClient hotReload,
    bool dualRuntimeMode,
  ) {
    Logger.debug('Starting file watcher for ${project.libDir}');

    if (dualRuntimeMode) {
      _printWatchingInfo(project);
    }

    final watcher = DirectoryWatcher(project.libDir);

    final subscription = watcher.events.listen((event) async {
      // Only react to Dart file changes
      if (!event.path.endsWith('.dart')) return;

      // Debounce rapid changes
      final changedFile = event.path;
      final relativePath = p.relative(changedFile, from: project.rootDir);
      Logger.info('File changed: $relativePath');

      // Determine which runtime to reload based on file path
      final target = _determineReloadTarget(project, relativePath, dualRuntimeMode);

      // Trigger appropriate reload
      bool success;
      if (dualRuntimeMode) {
        final targetName = _targetName(target);
        Logger.info('Reloading $targetName...');
        success = await hotReload.reloadTarget(
          target,
          changedFiles: [changedFile],
        );
      } else {
        success = await hotReload.reload(changedFiles: [changedFile]);
      }

      if (success) {
        Logger.success('Auto-reload completed');
      } else {
        Logger.error('Auto-reload failed');
      }
    });

    _fileWatcherSubscriptions.add(subscription);
    Logger.debug('File watcher started');
  }

  /// Print information about what's being watched
  void _printWatchingInfo(RedstoneProject project) {
    final serverDir = p.relative(project.serverPackageDir, from: project.rootDir);
    final clientDir = p.relative(project.clientPackageDir, from: project.rootDir);
    final commonDir = p.relative(project.commonPackageDir, from: project.rootDir);

    Logger.newLine();
    Logger.info('Watching for changes:');
    Logger.step('  [server] $serverDir/*.dart → reload server');
    Logger.step('  [client] $clientDir/*.dart → reload client');
    Logger.step('  [common] $commonDir/*.dart, lib/*.dart → reload both');
    Logger.newLine();
  }

  /// Determine which runtime to reload based on file path
  RuntimeTarget _determineReloadTarget(RedstoneProject project, String relativePath, bool dualRuntimeMode) {
    if (!dualRuntimeMode) {
      return RuntimeTarget.all;
    }

    // Normalize path separators
    final normalizedPath = relativePath.replaceAll('\\', '/');

    // Get relative paths for package directories
    final serverDir = p.relative(project.serverPackageDir, from: project.rootDir).replaceAll('\\', '/');
    final clientDir = p.relative(project.clientPackageDir, from: project.rootDir).replaceAll('\\', '/');
    final commonDir = p.relative(project.commonPackageDir, from: project.rootDir).replaceAll('\\', '/');

    // Check for server-specific files
    if (normalizedPath.startsWith('$serverDir/') ||
        normalizedPath.contains('/server/') ||
        normalizedPath.contains('_server.dart')) {
      return RuntimeTarget.server;
    }

    // Check for client-specific files
    if (normalizedPath.startsWith('$clientDir/') ||
        normalizedPath.contains('/client/') ||
        normalizedPath.contains('_client.dart') ||
        normalizedPath.contains('/ui/') ||
        normalizedPath.contains('/widgets/') ||
        normalizedPath.contains('/screens/')) {
      return RuntimeTarget.client;
    }

    // Check for common files (reload both)
    if (normalizedPath.startsWith('$commonDir/') ||
        normalizedPath.contains('/common/') ||
        normalizedPath.contains('/shared/') ||
        normalizedPath.contains('/models/') ||
        normalizedPath.contains('/utils/')) {
      return RuntimeTarget.all;
    }

    // Default: reload both for any other file in lib/
    return RuntimeTarget.all;
  }

  /// Get human-readable name for reload target
  String _targetName(RuntimeTarget target) {
    switch (target) {
      case RuntimeTarget.server:
        return 'server';
      case RuntimeTarget.client:
        return 'client';
      case RuntimeTarget.all:
        return 'all runtimes';
    }
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    // Stop file watchers
    for (final subscription in _fileWatcherSubscriptions) {
      await subscription.cancel();
    }
    _fileWatcherSubscriptions.clear();

    // Stop frontend server
    await _frontendServer?.stop();
    _frontendServer = null;
  }

  /// Set up the input listener for keyboard commands
  void _setupInputListener(
    MinecraftRunner runner,
    HotReloadClient hotReload,
    Completer<int> exitCompleter,
    bool dualRuntimeMode,
  ) {
    final inputStream = _ttyInput.getInputStream();
    _stdinSubscription = inputStream.listen(
      (input) {
        if (input.isEmpty) return;
        final char = String.fromCharCode(input.first);
        Logger.debug('Received input: "$char" (code: ${input.first})');

        switch (char) {
          case 'r':
            Logger.info('Performing hot reload...');
            hotReload.reload().then((success) {
              if (success) {
                Logger.success('Hot reload completed');
              } else {
                Logger.error('Hot reload failed');
              }
            });
            break;
          case 's':
            if (dualRuntimeMode) {
              Logger.info('Reloading server...');
              hotReload.reloadServer().then((success) {
                if (success) {
                  Logger.success('Server reload completed');
                } else {
                  Logger.error('Server reload failed');
                }
              });
            }
            break;
          case 'c':
            if (dualRuntimeMode) {
              Logger.info('Reloading client...');
              hotReload.reloadClient().then((success) {
                if (success) {
                  Logger.success('Client reload completed');
                } else {
                  Logger.error('Client reload failed');
                }
              });
            } else {
              // Clear screen in single-runtime mode
              stdout.write('\x1B[2J\x1B[H');
              _printHelp(dualRuntimeMode);
            }
            break;
          case 'C':
            // Clear screen (capital C in dual-runtime mode)
            stdout.write('\x1B[2J\x1B[H');
            _printHelp(dualRuntimeMode);
            break;
          case 'R':
            if (_isRestarting) {
              Logger.warning('Hot restart already in progress...');
              break;
            }
            Logger.info('Performing hot restart...');
            _performHotRestart(runner, hotReload, exitCompleter, dualRuntimeMode)
                .catchError((e) {
              Logger.error('Hot restart error: $e');
            });
            break;
          case 'q':
            Logger.info('Quitting...');
            runner.stop();
            if (!exitCompleter.isCompleted) {
              exitCompleter.complete(0);
            }
            break;
          case 'h':
            Logger.newLine();
            _printHelp(dualRuntimeMode);
            break;
        }
      },
      onError: (e) {
        Logger.error('stdin error: $e');
      },
      onDone: () {
        Logger.warning('stdin stream closed');
      },
      cancelOnError: false,
    );
  }

  void _printHelp(bool dualRuntimeMode) {
    Logger.info('Press:');
    Logger.step('r  Hot reload (all)');
    if (dualRuntimeMode) {
      Logger.step('s  Hot reload (server only)');
      Logger.step('c  Hot reload (client only)');
      Logger.step('C  Clear screen');
    } else {
      Logger.step('c  Clear screen');
    }
    Logger.step('R  Hot restart');
    Logger.step('q  Quit');
    Logger.step('h  Show this help');
  }

  /// Perform a full hot restart: save world, stop, rebuild, restart
  Future<void> _performHotRestart(
    MinecraftRunner runner,
    HotReloadClient hotReload,
    Completer<int> exitCompleter,
    bool dualRuntimeMode,
  ) async {
    _isRestarting = true;
    try {
      // Capture world name before stopping (for auto-rejoin after restart)
      final savedWorldName = runner.worldName;
      if (savedWorldName != null) {
        Logger.debug('Will auto-rejoin world: $savedWorldName');
      }

      // Step 1: Save the world
      Logger.step('Saving world...');
      runner.sendCommand('/save-all');

      // Wait for save confirmation (look for "Saved the game" or similar patterns)
      final saved = await runner.waitForOutput(
        r'(Saved the game|Saving|saved)',
        timeout: const Duration(seconds: 15),
      );

      if (saved) {
        Logger.success('World saved');
      } else {
        Logger.warning('Save confirmation not received, continuing anyway...');
      }

      // Step 2: Disconnect hot reload client
      Logger.step('Disconnecting hot reload...');
      await hotReload.disconnect();

      // Reset dual-runtime state for fresh reconnection
      if (dualRuntimeMode) {
        hotReload.resetDualRuntime();
      }

      // Step 3: Cancel the old stdin subscription before stopping
      // (subprocess exit corrupts stdin, so we'll create a fresh one)
      // Don't await - /dev/tty read blocks until input arrives
      _stdinSubscription?.cancel();
      _stdinSubscription = null;

      // Step 4: Stop Minecraft
      Logger.step('Stopping Minecraft...');
      await runner.stop();

      // Step 5: Wait briefly for full exit
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 6: Re-register VM service callbacks for dual-runtime mode
      if (dualRuntimeMode) {
        runner.onServerVmServiceDetected = (vmService) {
          hotReload.setServerUri(vmService.wsUri);
          Logger.info('Server VM service detected: ${vmService.httpUri}');
        };
        runner.onClientVmServiceDetected = (vmService) {
          hotReload.setClientUri(vmService.wsUri);
          Logger.info('Client VM service detected: ${vmService.httpUri}');
        };
      }

      // Step 7: Restart Minecraft (includes rebuild) with auto-rejoin world
      Logger.step('Restarting Minecraft...');
      await runner.restart(worldName: savedWorldName);

      // Step 8: Reconnect hot reload
      Logger.step('Reconnecting hot reload...');

      // Race connection against process exit to detect build failures
      bool connected = false;
      try {
        if (dualRuntimeMode) {
          connected = await _waitForDualRuntimeConnection(runner, hotReload);
        } else {
          connected = await Future.any([
            hotReload.connect(),
            runner.exitCode.then((code) {
              throw ProcessExitException(code);
            }),
          ]);
        }
      } on ProcessExitException catch (e) {
        Logger.error('Process exited with code ${e.exitCode} during restart');
        hotReload.cancel();
        if (!exitCompleter.isCompleted) {
          exitCompleter.complete(e.exitCode);
        }
        return;
      }

      if (connected) {
        // Re-attach exit listener to new process (ignore during hot restart)
        runner.exitCode.then((code) {
          if (!exitCompleter.isCompleted && !_isRestarting) {
            Logger.newLine();
            Logger.info('Process exited with code $code');
            exitCompleter.complete(code);
          }
        });

        // Create a FRESH input stream from /dev/tty (bypasses corrupted stdin)
        await Future.delayed(const Duration(milliseconds: 500));
        _ttyInput.setRawMode();

        // Create new input subscription from fresh /dev/tty stream
        final freshStream = _ttyInput.refreshInputStream();
        _stdinSubscription = freshStream.listen(
          (input) {
            if (input.isEmpty) return;
            final char = String.fromCharCode(input.first);
            Logger.debug('Received input: "$char" (code: ${input.first})');

            switch (char) {
              case 'r':
                Logger.info('Performing hot reload...');
                hotReload.reload().then((success) {
                  if (success) {
                    Logger.success('Hot reload completed');
                  } else {
                    Logger.error('Hot reload failed');
                  }
                });
                break;
              case 's':
                if (dualRuntimeMode) {
                  Logger.info('Reloading server...');
                  hotReload.reloadServer().then((success) {
                    if (success) {
                      Logger.success('Server reload completed');
                    } else {
                      Logger.error('Server reload failed');
                    }
                  });
                }
                break;
              case 'c':
                if (dualRuntimeMode) {
                  Logger.info('Reloading client...');
                  hotReload.reloadClient().then((success) {
                    if (success) {
                      Logger.success('Client reload completed');
                    } else {
                      Logger.error('Client reload failed');
                    }
                  });
                } else {
                  stdout.write('\x1B[2J\x1B[H');
                  _printHelp(dualRuntimeMode);
                }
                break;
              case 'C':
                stdout.write('\x1B[2J\x1B[H');
                _printHelp(dualRuntimeMode);
                break;
              case 'R':
                if (_isRestarting) {
                  Logger.warning('Hot restart already in progress...');
                  break;
                }
                Logger.info('Performing hot restart...');
                _performHotRestart(
                        runner, hotReload, exitCompleter, dualRuntimeMode)
                    .catchError((e) {
                  Logger.error('Hot restart error: $e');
                });
                break;
              case 'q':
                Logger.info('Quitting...');
                runner.stop();
                if (!exitCompleter.isCompleted) {
                  exitCompleter.complete(0);
                }
                break;
              case 'h':
                Logger.newLine();
                _printHelp(dualRuntimeMode);
                break;
            }
          },
          onError: (e) {
            Logger.error('stdin error: $e');
          },
          onDone: () {
            Logger.warning('stdin stream closed');
          },
          cancelOnError: false,
        );

        Logger.success('Hot restart completed');
        Logger.newLine();
        _printHelp(dualRuntimeMode);
      } else {
        Logger.warning('Hot reload reconnection failed');
      }
    } catch (e) {
      Logger.error('Hot restart failed: $e');
    } finally {
      _isRestarting = false;
    }
  }
}
