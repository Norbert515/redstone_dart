import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

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

    // Start Minecraft
    final runner = MinecraftRunner(project);

    try {
      await runner.start();

      if (hotReloadEnabled) {
        Logger.info('Hot reload enabled. Connecting to Dart VM...');

        final hotReload = HotReloadClient();

        // Race connection against process exit to detect build failures early
        bool connected = false;
        try {
          connected = await Future.any([
            hotReload.connect(),
            runner.exitCode.then((code) {
              // Process exited before we could connect
              throw ProcessExitException(code);
            }),
          ]);
        } on ProcessExitException catch (e) {
          Logger.error(
              'Process exited with code ${e.exitCode} before hot reload could connect');
          hotReload.cancel();
          await runner.stop();
          // Use exit() to force quit - the hotReload.connect() Future.delayed
          // timer may still be pending and would keep the event loop alive
          exit(e.exitCode);
        }

        if (connected) {
          Logger.success('Connected to Dart VM service');
          Logger.newLine();
          _printHelp();
          Logger.newLine();

          // Set up a completer that resolves when we should exit
          final exitCompleter = Completer<int>();

          // Monitor process exit
          runner.exitCode.then((code) {
            if (!exitCompleter.isCompleted) {
              Logger.newLine();
              Logger.info('Process exited with code $code');
              exitCompleter.complete(code);
            }
          });

          // Listen for keyboard input using TtyInput (survives subprocess restarts)
          _ttyInput.setRawMode();

          // Periodically restore terminal state (Gradle subprocess may override)
          final terminalRestoreTimer = Timer.periodic(const Duration(seconds: 2), (_) {
            _ttyInput.setRawMode();
          });

          // Start listening for input
          _setupInputListener(runner, hotReload, exitCompleter);

          // Wait for exit (either from process dying or user pressing 'q')
          final exitCode = await exitCompleter.future;
          terminalRestoreTimer.cancel();
          await _stdinSubscription?.cancel();
          return exitCode;
        } else {
          Logger.warning('Could not connect to Dart VM. Hot reload disabled.');
        }
      }

      // Wait for Minecraft to exit
      final exitCode = await runner.exitCode;
      return exitCode;
    } catch (e) {
      Logger.error('Error: $e');
      await runner.stop();
      return 1;
    } finally {
      // Restore terminal
      _ttyInput.restoreMode();
    }
  }

  /// Set up the input listener for keyboard commands
  void _setupInputListener(
    MinecraftRunner runner,
    HotReloadClient hotReload,
    Completer<int> exitCompleter,
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
        case 'R':
          if (_isRestarting) {
            Logger.warning('Hot restart already in progress...');
            break;
          }
          Logger.info('Performing hot restart...');
          _performHotRestart(runner, hotReload, exitCompleter).catchError((e) {
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
        case 'c':
          // Clear screen
          stdout.write('\x1B[2J\x1B[H');
          _printHelp();
          break;
        case 'h':
          Logger.newLine();
          _printHelp();
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

  void _printHelp() {
    Logger.info('Press:');
    Logger.step('r  Hot reload');
    Logger.step('R  Hot restart');
    Logger.step('q  Quit');
    Logger.step('c  Clear screen');
    Logger.step('h  Show this help');
  }

  /// Perform a full hot restart: save world, stop, rebuild, restart
  Future<void> _performHotRestart(
    MinecraftRunner runner,
    HotReloadClient hotReload,
    Completer<int> exitCompleter,
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

      // Step 3: Cancel the old stdin subscription before stopping
      // (subprocess exit corrupts stdin, so we'll create a fresh one)
      await _stdinSubscription?.cancel();
      _stdinSubscription = null;

      // Step 4: Stop Minecraft
      Logger.step('Stopping Minecraft...');
      await runner.stop();

      // Step 5: Wait briefly for full exit
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 6: Restart Minecraft (includes rebuild) with auto-rejoin world
      Logger.step('Restarting Minecraft...');
      await runner.restart(worldName: savedWorldName);

      // Step 7: Reconnect hot reload
      Logger.step('Reconnecting hot reload...');

      // Race connection against process exit to detect build failures
      bool connected = false;
      try {
        connected = await Future.any([
          hotReload.connect(),
          runner.exitCode.then((code) {
            throw ProcessExitException(code);
          }),
        ]);
      } on ProcessExitException catch (e) {
        Logger.error('Process exited with code ${e.exitCode} during restart');
        hotReload.cancel();
        if (!exitCompleter.isCompleted) {
          exitCompleter.complete(e.exitCode);
        }
        return;
      }

      if (connected) {
        // Re-attach exit listener to new process
        runner.exitCode.then((code) {
          if (!exitCompleter.isCompleted) {
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
            case 'R':
              if (_isRestarting) {
                Logger.warning('Hot restart already in progress...');
                break;
              }
              Logger.info('Performing hot restart...');
              _performHotRestart(runner, hotReload, exitCompleter).catchError((e) {
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
            case 'c':
              stdout.write('\x1B[2J\x1B[H');
              _printHelp();
              break;
            case 'h':
              Logger.newLine();
              _printHelp();
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
        _printHelp();
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
