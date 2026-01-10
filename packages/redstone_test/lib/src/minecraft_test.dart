/// Main test function for Minecraft mod tests (server-side).
///
/// Provides [testMinecraftServer] which runs tests immediately inside Minecraft,
/// and [serverGroup] for organizing tests.
///
/// Also provides aliases [testMinecraft] and [group] for backwards compatibility.
library;

import 'dart:async';

import 'package:dart_mod_server/dart_mod_server.dart';
import 'package:meta/meta.dart';

import 'game_context.dart';
import 'test_binding.dart';
import 'test_event.dart';

/// Default timeout for Minecraft tests (2 minutes).
///
/// Game operations can be slow, so we use a longer timeout than the default.
const _defaultTimeout = Duration(minutes: 2);

/// Global test tracker for results
final _testResults = TestResults();

/// Get the current test results.
TestResults get testResults => _testResults;

/// Track test outcomes.
class TestResults {
  int passed = 0;
  int failed = 0;
  int skipped = 0;
  final List<String> failures = [];

  bool get success => failed == 0;
  int get exitCode => success ? 0 : 1;
  int get total => passed + failed + skipped;

  void reset() {
    passed = 0;
    failed = 0;
    skipped = 0;
    failures.clear();
  }

  void printSummary() {
    print('');
    print('=' * 60);
    print('Test Results: $passed passed, $failed failed, $skipped skipped');
    if (failures.isNotEmpty) {
      print('');
      print('Failures:');
      for (final failure in failures) {
        print('  - $failure');
      }
    }
    print('=' * 60);
  }
}

/// Current group prefix for test names.
String _groupPrefix = '';

/// Track inherited skip reason from group.
String? _groupSkip;

/// Whether we're running in full mode (with client).
/// This is set by the test runner via environment variable.
bool get _isFullMode {
  // Check if we're in full mode by checking if the client is available
  // In full mode (client tests), ClientBridge.isClientReady() will be true
  // once the world loads. In server-only mode, it's always false.
  try {
    return ClientBridge.isClientReady();
  } catch (_) {
    return false;
  }
}

/// Define a group of related server tests.
///
/// Groups can be nested and help organize test output.
/// The body is async so that `testMinecraftServer` calls can be awaited.
///
/// [skip] can be:
/// - `false` (default): don't skip
/// - `true`: skip without reason
/// - `String`: skip with the given reason
Future<void> serverGroup(
  String description,
  Future<void> Function() body, {
  Object? skip = false,
}) async {
  // If running in full mode, skip server groups with a message
  if (_isFullMode) {
    _testResults.skipped++;
    emitEvent(TestSkipEvent(
      name: description,
      reason: 'Skipping server group - use fullGroup for full tests',
    ));
    print('  SKIP: $description (server group skipped in full mode)');
    return;
  }

  final previousPrefix = _groupPrefix;
  final previousSkip = _groupSkip;

  _groupPrefix =
      _groupPrefix.isEmpty ? description : '$_groupPrefix > $description';

  // Determine skip reason
  if (skip == true) {
    _groupSkip = ''; // Skip without reason
  } else if (skip is String) {
    _groupSkip = skip; // Skip with reason
  }
  // If skip == false, inherit from parent (_groupSkip unchanged)

  emitEvent(GroupStartEvent(name: _groupPrefix));
  print('\n[$_groupPrefix]');

  await body();

  emitEvent(GroupEndEvent(name: _groupPrefix));

  _groupPrefix = previousPrefix;
  _groupSkip = previousSkip;
}

/// Alias for [serverGroup] - backwards compatibility.
///
/// Define a group of related server tests.
Future<void> group(
  String description,
  Future<void> Function() body, {
  Object? skip = false,
}) =>
    serverGroup(description, body, skip: skip);

/// Define a Minecraft server test.
///
/// Unlike package:test's `test()`, this runs the test immediately
/// rather than registering it for later execution. This is necessary
/// because we run inside the Minecraft VM where the test package's
/// zone-based auto-execution doesn't work.
///
/// In full mode (with client), server tests are gracefully skipped
/// with a message. Use [testMinecraftFull] for tests that require
/// the client.
///
/// [skip] can be:
/// - `false` (default): don't skip
/// - `true`: skip without reason
/// - `String`: skip with the given reason
///
/// Example:
/// ```dart
/// testMinecraftServer('placing a block changes the world', (game) async {
///   final pos = BlockPos(0, 64, 0);
///
///   game.placeBlock(pos, Block.stone);
///
///   expect(game.getBlock(pos), equals(Block.stone));
/// });
/// ```
///
/// The test runs inside the Minecraft process and has access to the
/// full game state through the [MinecraftGameContext].
@isTest
Future<void> testMinecraftServer(
  String description,
  Future<void> Function(MinecraftGameContext game) callback, {
  Object? skip = false,
  Duration timeout = _defaultTimeout,
  dynamic tags,
}) async {
  final fullName =
      _groupPrefix.isEmpty ? description : '$_groupPrefix > $description';

  // If running in full mode, skip server tests with a message
  if (_isFullMode) {
    _testResults.skipped++;
    emitEvent(TestSkipEvent(
      name: fullName,
      reason: 'Skipping server test - use testMinecraftFull for full tests',
    ));
    print('  SKIP: $description (server test skipped in full mode)');
    return;
  }

  // Determine effective skip reason
  String? skipReason;
  if (_groupSkip != null) {
    skipReason = _groupSkip; // Inherited from group
  } else if (skip == true) {
    skipReason = '';
  } else if (skip is String) {
    skipReason = skip;
  }

  if (skipReason != null) {
    _testResults.skipped++;
    emitEvent(TestSkipEvent(
      name: fullName,
      reason: skipReason.isEmpty ? null : skipReason,
    ));
    final reasonSuffix = skipReason.isEmpty ? '' : ' ($skipReason)';
    print('  SKIP: $description$reasonSuffix');
    return;
  }

  emitEvent(TestStartEvent(name: fullName));
  final stopwatch = Stopwatch()..start();

  try {
    final binding = MinecraftTestBinding.ensureInitialized();
    final context = MinecraftGameContext(binding);

    // Run with timeout, capturing print output
    await runZoned(
      () => callback(context).timeout(timeout),
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          // Emit as PrintEvent for the UI to capture
          emitEvent(PrintEvent(message: line));
          // Also print to actual stdout for logging
          parent.print(zone, line);
        },
      ),
    );

    stopwatch.stop();
    _testResults.passed++;
    emitEvent(TestPassEvent(
      name: fullName,
      durationMicros: stopwatch.elapsedMicroseconds,
    ));
    print('  PASS: $description (${stopwatch.elapsedMilliseconds}ms)');
  } catch (e, st) {
    stopwatch.stop();
    _testResults.failed++;
    _testResults.failures.add('$fullName: $e');
    emitEvent(TestFailEvent(
      name: fullName,
      error: e.toString(),
      stack: st.toString(),
    ));
    print('  FAIL: $description');
    print('    Error: $e');
    print('    Stack: $st');
  }
}

/// Alias for [testMinecraftServer] - backwards compatibility.
///
/// Define a Minecraft server test.
@isTest
Future<void> testMinecraft(
  String description,
  Future<void> Function(MinecraftGameContext game) callback, {
  Object? skip = false,
  Duration timeout = _defaultTimeout,
  dynamic tags,
}) =>
    testMinecraftServer(description, callback,
        skip: skip, timeout: timeout, tags: tags);
