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

class RunCommand extends Command<int> {
  @override
  final name = 'run';

  @override
  final description = 'Build and run your Redstone mod in Minecraft.';

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

          // Listen for keyboard input
          stdin.echoMode = false;
          stdin.lineMode = false;

          final stdinSubscription = stdin.listen((input) {
            final char = String.fromCharCode(input.first);

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
                Logger.info('Performing hot restart...');
                // TODO: Implement hot restart
                Logger.warning('Hot restart not yet implemented');
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
          });

          // Wait for exit (either from process dying or user pressing 'q')
          final exitCode = await exitCompleter.future;
          await stdinSubscription.cancel();
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
      try {
        stdin.echoMode = true;
        stdin.lineMode = true;
      } catch (_) {}
    }
  }

  void _printHelp() {
    Logger.info('Press:');
    Logger.step('r  Hot reload');
    Logger.step('R  Hot restart');
    Logger.step('q  Quit');
    Logger.step('c  Clear screen');
    Logger.step('h  Show this help');
  }
}
