import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:nocterm/nocterm.dart' hide Logger;
import 'package:path/path.dart' as p;
import 'package:redstone_test/redstone_test.dart';

import '../project/redstone_project.dart';
import '../runner/minecraft_runner.dart';
import '../test/test_harness_generator.dart';
import '../test/test_runner_ui.dart';
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

  /// Wait for test completion using Nocterm TUI.
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

    // Create a stream controller to transform lines to events
    final eventController = StreamController<TestEvent>();

    // Listen to stdout and parse events
    final subscription = stdoutLines.listen((line) {
      final event = TestEvent.tryParse(line);
      if (event != null) {
        eventController.add(event);
      } else if (verbose) {
        print(line);
      }
    });

    // Handle process exit
    runner.exitCode.then((code) {
      if (!completer.isCompleted) {
        completer.complete(1);
      }
    });

    // Run Nocterm UI
    await runApp(
      TestRunnerUI(
        eventStream: eventController.stream,
        exitCodeCompleter: completer,
      ),
      screenMode: ScreenMode.inline,
      inlineExitBehavior: InlineExitBehavior.preserve,
    );

    await subscription.cancel();
    await eventController.close();

    return completer.future;
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
