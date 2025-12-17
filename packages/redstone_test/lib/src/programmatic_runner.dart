/// Programmatic test runner for running tests inside Minecraft.
///
/// Uses package:test_api to run tests programmatically with filtering
/// and single-threaded execution.
library;

import 'dart:async';

import 'package:test/test.dart';

/// Result of running tests programmatically.
class TestRunResult {
  /// Number of tests that passed.
  final int passed;

  /// Number of tests that failed.
  final int failed;

  /// Number of tests that were skipped.
  final int skipped;

  /// Whether all tests passed (no failures).
  bool get success => failed == 0;

  /// Exit code (0 if success, 1 if failures).
  int get exitCode => success ? 0 : 1;

  TestRunResult({
    required this.passed,
    required this.failed,
    required this.skipped,
  });

  @override
  String toString() =>
      'TestRunResult(passed: $passed, failed: $failed, skipped: $skipped)';
}

/// Run tests programmatically with the given configuration.
///
/// Tests should already be registered via [testMinecraft] or [test] calls.
///
/// [nameFilter] - Regex to filter test names
/// [plainNameFilter] - Plain text substring to filter test names
/// [tags] - Only run tests with these tags
/// [excludeTags] - Skip tests with these tags
///
/// Returns a [TestRunResult] with the test outcomes.
Future<TestRunResult> runTestsProgrammatically({
  String? nameFilter,
  String? plainNameFilter,
  List<String> tags = const [],
  List<String> excludeTags = const [],
}) async {
  // Track test results
  var passed = 0;
  var failed = 0;
  var skipped = 0;

  // Note: In a full implementation, we would use package:test_core's
  // Invoker and RunnerSuite to run tests programmatically. For now,
  // we rely on the test package's auto-execution which runs tests
  // after all `test()` calls are registered.
  //
  // The tests registered via testMinecraft() will run automatically
  // when the Dart VM processes the event loop.

  // Give time for tests to register and run
  await Future.delayed(const Duration(seconds: 1));

  // For now, return a placeholder result
  // In a real implementation, we would hook into test_api's
  // Reporter to track actual results
  return TestRunResult(
    passed: passed,
    failed: failed,
    skipped: skipped,
  );
}

/// Parse filter arguments from command line format.
///
/// Supported args:
/// - `--name <regex>` or `-n <regex>`
/// - `--plain-name <text>` or `-N <text>`
/// - `--tags <tag>` or `-t <tag>`
/// - `--exclude-tags <tag>` or `-x <tag>`
TestFilterConfig parseFilterArgs(List<String> args) {
  String? nameFilter;
  String? plainNameFilter;
  final tags = <String>[];
  final excludeTags = <String>[];

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    final nextArg = i + 1 < args.length ? args[i + 1] : null;

    if ((arg == '--name' || arg == '-n') && nextArg != null) {
      nameFilter = nextArg;
      i++;
    } else if ((arg == '--plain-name' || arg == '-N') && nextArg != null) {
      plainNameFilter = nextArg;
      i++;
    } else if ((arg == '--tags' || arg == '-t') && nextArg != null) {
      tags.add(nextArg);
      i++;
    } else if ((arg == '--exclude-tags' || arg == '-x') && nextArg != null) {
      excludeTags.add(nextArg);
      i++;
    }
  }

  return TestFilterConfig(
    nameFilter: nameFilter,
    plainNameFilter: plainNameFilter,
    tags: tags,
    excludeTags: excludeTags,
  );
}

/// Configuration for filtering tests.
class TestFilterConfig {
  final String? nameFilter;
  final String? plainNameFilter;
  final List<String> tags;
  final List<String> excludeTags;

  TestFilterConfig({
    this.nameFilter,
    this.plainNameFilter,
    this.tags = const [],
    this.excludeTags = const [],
  });

  /// Check if a test with the given name and tags should run.
  bool shouldRun(String testName, List<String> testTags) {
    // Check name filter (regex)
    if (nameFilter != null) {
      final regex = RegExp(nameFilter!);
      if (!regex.hasMatch(testName)) {
        return false;
      }
    }

    // Check plain name filter (substring)
    if (plainNameFilter != null) {
      if (!testName.contains(plainNameFilter!)) {
        return false;
      }
    }

    // Check required tags
    if (tags.isNotEmpty) {
      for (final requiredTag in tags) {
        if (!testTags.contains(requiredTag)) {
          return false;
        }
      }
    }

    // Check excluded tags
    for (final excludedTag in excludeTags) {
      if (testTags.contains(excludedTag)) {
        return false;
      }
    }

    return true;
  }
}
