import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:redstone_test/redstone_test.dart';

import '../project/redstone_project.dart';
import '../runner/minecraft_runner.dart';
import '../test/test_harness_generator.dart';
import '../util/logger.dart';

/// Command for running Dart tests inside a Minecraft environment.
///
/// Usage: redstone test [test files] [dart test args]
///
/// Example:
///   redstone test                          # Run all tests
///   redstone test test/block_test.dart     # Run specific test file
///   redstone test --name "placement"       # Filter by test name
class TestCommand extends Command<int> {
  @override
  final name = 'test';

  @override
  final description = 'Run Dart tests inside a Minecraft environment.';

  @override
  final takesArguments = true;

  TestCommand() {
    argParser.addOption(
      'name',
      abbr: 'n',
      help: 'Run only tests whose names match this substring/regex.',
    );
    argParser.addOption(
      'plain-name',
      abbr: 'N',
      help: 'Run only tests whose names match this plain-text substring.',
    );
    argParser.addMultiOption(
      'tags',
      abbr: 't',
      help: 'Run only tests with all the specified tags.',
    );
    argParser.addMultiOption(
      'exclude-tags',
      abbr: 'x',
      help: 'Don\'t run tests with any of the specified tags.',
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
    Logger.header('🧪 Running tests for ${project.name}');
    Logger.newLine();

    // Collect test files from args (positional arguments that look like paths)
    final testFiles = <String>[];
    for (final arg in argResults!.rest) {
      if (arg.endsWith('.dart') || await Directory(arg).exists()) {
        testFiles.add(arg);
      }
    }

    // If no test files specified, use test/ directory
    if (testFiles.isEmpty) {
      final testDir = Directory(p.join(project.rootDir, 'test'));
      if (!testDir.existsSync()) {
        Logger.error('No test/ directory found.');
        return 1;
      }
      testFiles.add('test/');
    }

    // Build filter args to pass to the test harness
    final filterArgs = <String>[];

    final nameFilter = argResults!['name'] as String?;
    if (nameFilter != null) {
      filterArgs.addAll(['--name', nameFilter]);
    }

    final plainNameFilter = argResults!['plain-name'] as String?;
    if (plainNameFilter != null) {
      filterArgs.addAll(['--plain-name', plainNameFilter]);
    }

    final tags = argResults!['tags'] as List<String>;
    for (final tag in tags) {
      filterArgs.addAll(['--tags', tag]);
    }

    final excludeTags = argResults!['exclude-tags'] as List<String>;
    for (final tag in excludeTags) {
      filterArgs.addAll(['--exclude-tags', tag]);
    }

    // Generate test harness
    Logger.info('Generating test harness...');
    final generator = TestHarnessGenerator(project);
    final harnessFile = await generator.generate(
      testFiles: testFiles,
      filterArgs: filterArgs,
    );

    Logger.info('Test harness generated at: ${harnessFile.path}');

    // Start Minecraft with the test harness
    Logger.info('Starting Minecraft with test harness...');
    final runner = MinecraftRunner(project, testMode: true);
    final verbose = argResults!['verbose'] as bool;

    try {
      await runner.start();

      // Wait for tests to complete by listening to stdout events
      Logger.info('Waiting for tests to complete...');

      final exitCode = await _waitForTestCompletion(runner: runner, verbose: verbose);

      // Clean up
      await runner.stop();

      // Delete world for clean test runs
      await _cleanupWorld(project);

      if (exitCode == 0) {
        Logger.newLine();
        Logger.success('All tests passed!');
      } else {
        Logger.newLine();
        Logger.error('Some tests failed.');
      }

      return exitCode;
    } catch (e) {
      Logger.error('Error: $e');
      await runner.stop();
      return 1;
    }
  }

  /// Wait for test completion by listening to stdout JSON events.
  Future<int> _waitForTestCompletion({
    required MinecraftRunner runner,
    required bool verbose,
  }) async {
    final completer = Completer<int>();
    final stdoutLines = runner.stdoutLines;

    if (stdoutLines == null) {
      // Fallback: just wait for process exit
      final code = await runner.exitCode;
      return code == 0 ? 0 : 1;
    }

    // Listen to stdout lines
    final subscription = stdoutLines.listen((line) {
      // Try to parse as a test event
      final event = TestEvent.tryParse(line);

      if (event != null) {
        _handleTestEvent(event, completer);
      } else if (verbose) {
        // Not a test event, forward to stdout (game logs) only in verbose mode
        print(line);
      }
    });

    // Also complete if Minecraft exits without sending done event
    runner.exitCode.then((code) {
      if (!completer.isCompleted) {
        // Process exited without done event, treat as failure
        completer.complete(1);
      }
    });

    try {
      return await completer.future;
    } finally {
      await subscription.cancel();
    }
  }

  /// Handle a parsed test event and update UI.
  void _handleTestEvent(TestEvent event, Completer<int> completer) {
    switch (event) {
      case SuiteStartEvent(:final name):
        _printColored('\n📁 Suite: $name', _AnsiColor.cyan);
      case SuiteEndEvent():
        break; // No output needed
      case GroupStartEvent(:final name):
        _printColored('\n  📂 $name', _AnsiColor.blue);
      case GroupEndEvent():
        break; // No output needed
      case TestStartEvent(:final name):
        // Could show "running..." but might be too noisy
        stdout.write('    ⏳ $name...');

      case TestPassEvent(:final name, :final durationMs):
        // Clear the "running" line and print pass
        stdout.write('\r');
        _printColored('    ✅ $name (${durationMs}ms)', _AnsiColor.green);

      case TestFailEvent(:final name, :final error, :final stack):
        stdout.write('\r');
        _printColored('    ❌ $name', _AnsiColor.red);
        _printColored('       Error: $error', _AnsiColor.red);
        if (stack != null && stack.isNotEmpty) {
          // Print first few lines of stack
          final stackLines = stack.split('\n').take(5);
          for (final line in stackLines) {
            _printColored('       $line', _AnsiColor.gray);
          }
        }

      case TestSkipEvent(:final name, :final reason):
        stdout.write('\r');
        final reasonSuffix = reason != null ? ' ($reason)' : '';
        _printColored('    ⏭️  $name$reasonSuffix', _AnsiColor.yellow);

      case DoneEvent(:final passed, :final failed, :final skipped, :final exitCode):
        Logger.newLine();
        _printColored('=' * 60, _AnsiColor.gray);
        _printColored(
          'Results: $passed passed, $failed failed, $skipped skipped',
          failed > 0 ? _AnsiColor.red : _AnsiColor.green,
        );
        _printColored('=' * 60, _AnsiColor.gray);

        if (!completer.isCompleted) {
          completer.complete(exitCode);
        }
    }
  }

  /// Print with ANSI color if stdout supports it.
  void _printColored(String message, _AnsiColor color) {
    if (stdout.supportsAnsiEscapes) {
      print('${color.code}$message${_AnsiColor.reset.code}');
    } else {
      print(message);
    }
  }

  /// Delete the Minecraft world directory for clean test runs.
  Future<void> _cleanupWorld(RedstoneProject project) async {
    final worldDir = Directory(p.join(project.minecraftDir, 'run', 'world'));
    if (worldDir.existsSync()) {
      Logger.debug('Cleaning up test world...');
      try {
        await worldDir.delete(recursive: true);
      } catch (e) {
        Logger.warning('Failed to delete world directory: $e');
      }
    }
  }
}

/// ANSI color codes for terminal output.
enum _AnsiColor {
  reset('\x1B[0m'),
  red('\x1B[31m'),
  green('\x1B[32m'),
  yellow('\x1B[33m'),
  blue('\x1B[34m'),
  cyan('\x1B[36m'),
  gray('\x1B[90m');

  final String code;
  const _AnsiColor(this.code);
}
