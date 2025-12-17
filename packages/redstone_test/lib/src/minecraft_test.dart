/// Main test function for Minecraft mod tests.
///
/// Provides [testMinecraft] which runs tests immediately inside Minecraft,
/// and [group] for organizing tests.
library;

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

/// Define a group of related tests.
///
/// Groups can be nested and help organize test output.
/// The body is async so that `testMinecraft` calls can be awaited.
///
/// [skip] can be:
/// - `false` (default): don't skip
/// - `true`: skip without reason
/// - `String`: skip with the given reason
Future<void> group(
  String description,
  Future<void> Function() body, {
  Object? skip = false,
}) async {
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

/// Define a Minecraft mod test.
///
/// Unlike package:test's `test()`, this runs the test immediately
/// rather than registering it for later execution. This is necessary
/// because we run inside the Minecraft VM where the test package's
/// zone-based auto-execution doesn't work.
///
/// [skip] can be:
/// - `false` (default): don't skip
/// - `true`: skip without reason
/// - `String`: skip with the given reason
///
/// Example:
/// ```dart
/// testMinecraft('placing a block changes the world', (game) async {
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
Future<void> testMinecraft(
  String description,
  Future<void> Function(MinecraftGameContext game) callback, {
  Object? skip = false,
  Duration timeout = _defaultTimeout,
  dynamic tags,
}) async {
  final fullName =
      _groupPrefix.isEmpty ? description : '$_groupPrefix > $description';

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

    // Run with timeout
    await callback(context).timeout(timeout);

    stopwatch.stop();
    _testResults.passed++;
    emitEvent(TestPassEvent(
      name: fullName,
      durationMs: stopwatch.elapsedMilliseconds,
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
