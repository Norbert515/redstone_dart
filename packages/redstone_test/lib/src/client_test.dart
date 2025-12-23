/// Client test function for Minecraft visual tests.
///
/// Provides [testMinecraftClient] which runs tests inside the Minecraft client
/// with access to client-only features like screenshots.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import 'client_game_context.dart';
import 'client_test_binding.dart';
import 'test_event.dart';
import 'minecraft_test.dart' show testResults;

/// Default timeout for client tests (3 minutes).
///
/// Client tests may take longer due to rendering operations.
const _defaultClientTimeout = Duration(minutes: 3);

/// Current group prefix for test names.
String _groupPrefix = '';

/// Track inherited skip reason from group.
String? _groupSkip;

/// Define a group of related client tests.
///
/// Groups can be nested and help organize test output.
/// The body is async so that `testMinecraftClient` calls can be awaited.
Future<void> clientGroup(
  String description,
  Future<void> Function() body, {
  Object? skip = false,
}) async {
  final previousPrefix = _groupPrefix;
  final previousSkip = _groupSkip;

  _groupPrefix =
      _groupPrefix.isEmpty ? description : '$_groupPrefix > $description';

  if (skip == true) {
    _groupSkip = '';
  } else if (skip is String) {
    _groupSkip = skip;
  }

  emitEvent(GroupStartEvent(name: _groupPrefix));
  print('\n[$_groupPrefix]');

  await body();

  emitEvent(GroupEndEvent(name: _groupPrefix));

  _groupPrefix = previousPrefix;
  _groupSkip = previousSkip;
}

/// Define a Minecraft client test for visual testing.
///
/// Unlike `testMinecraft`, this runs in the Minecraft client with
/// access to client-only features like screenshots and rendering.
///
/// The test has access to [ClientGameContext] which provides:
/// - `takeScreenshot(name)` - Capture a screenshot
/// - `positionCamera(x, y, z, yaw, pitch)` - Position the camera
/// - `lookAt(x, y, z)` - Look at a position
/// - `waitTicks(n)` - Wait for game ticks
///
/// Example:
/// ```dart
/// testMinecraftClient('entity renders correctly', (game) async {
///   // Position camera
///   await game.positionCamera(100, 70, 200, yaw: 45, pitch: 30);
///
///   // Spawn entity to test
///   game.spawnEntity('mymod:custom_entity', Vec3(100, 64, 200));
///   await game.waitTicks(5);
///
///   // Take screenshot
///   final path = await game.takeScreenshot('entity_render_test');
///   expect(path, isNotNull);
/// });
/// ```
@isTest
Future<void> testMinecraftClient(
  String description,
  Future<void> Function(ClientGameContext game) callback, {
  Object? skip = false,
  Duration timeout = _defaultClientTimeout,
  dynamic tags,
}) async {
  final fullName =
      _groupPrefix.isEmpty ? description : '$_groupPrefix > $description';

  // Determine effective skip reason
  String? skipReason;
  if (_groupSkip != null) {
    skipReason = _groupSkip;
  } else if (skip == true) {
    skipReason = '';
  } else if (skip is String) {
    skipReason = skip;
  }

  if (skipReason != null) {
    testResults.skipped++;
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
    final binding = ClientTestBinding.ensureInitialized();
    final context = ClientGameContext(binding);

    // Wait for client to be ready
    if (!binding.isClientReady) {
      print('    Waiting for client to be ready...');
      await binding.waitForClientReady();
    }

    // Run with timeout, capturing print output
    await runZoned(
      () => callback(context).timeout(timeout),
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          emitEvent(PrintEvent(message: line));
          parent.print(zone, line);
        },
      ),
    );

    stopwatch.stop();
    testResults.passed++;
    emitEvent(TestPassEvent(
      name: fullName,
      durationMicros: stopwatch.elapsedMicroseconds,
    ));
    print('  PASS: $description (${stopwatch.elapsedMilliseconds}ms)');
  } catch (e, st) {
    stopwatch.stop();
    testResults.failed++;
    testResults.failures.add('$fullName: $e');
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
