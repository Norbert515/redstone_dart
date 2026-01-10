/// Full test function for Minecraft visual tests (client + server).
///
/// Provides [testMinecraftFull] which runs tests inside the Minecraft client
/// with access to client-only features like screenshots.
///
/// Also provides aliases [testMinecraftClient] and [clientGroup] for backwards compatibility.
library;

import 'dart:async';

import 'package:dart_mod_server/dart_mod_server.dart';
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

/// Whether we're running in server-only mode (no client).
/// In server-only mode, ClientBridge.isClientReady() is always false.
bool get _isServerOnlyMode {
  try {
    // In server-only mode, the client is never ready
    // We wait a bit and check - if still not ready, we're in server mode
    // However, for detection purposes, we use a simpler approach:
    // The test harness sets an environment variable or we check if client bridge works
    return !ClientBridge.isClientReady();
  } catch (_) {
    return true; // If ClientBridge fails, we're in server-only mode
  }
}

/// Define a group of related full tests (client + server).
///
/// Groups can be nested and help organize test output.
/// The body is async so that `testMinecraftFull` calls can be awaited.
Future<void> fullGroup(
  String description,
  Future<void> Function() body, {
  Object? skip = false,
}) async {
  // If running in server-only mode, skip full groups with a message
  if (_isServerOnlyMode) {
    testResults.skipped++;
    emitEvent(TestSkipEvent(
      name: description,
      reason: 'Skipping full group - run with --full flag',
    ));
    print('  SKIP: $description (full group skipped in server-only mode)');
    return;
  }

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

/// Alias for [fullGroup] - backwards compatibility.
///
/// Define a group of related full tests.
Future<void> clientGroup(
  String description,
  Future<void> Function() body, {
  Object? skip = false,
}) =>
    fullGroup(description, body, skip: skip);

/// Define a Minecraft full test for visual testing (client + server).
///
/// Unlike `testMinecraftServer`, this runs in the Minecraft client with
/// access to client-only features like screenshots and rendering.
///
/// In server-only mode, full tests are gracefully skipped with a message.
/// Run with `--full` flag to execute full tests.
///
/// The test has access to [ClientGameContext] which provides:
/// - `takeScreenshot(name)` - Capture a screenshot
/// - `positionCamera(x, y, z, yaw, pitch)` - Position the camera
/// - `lookAt(x, y, z)` - Look at a position
/// - `waitTicks(n)` - Wait for game ticks
///
/// Example:
/// ```dart
/// testMinecraftFull('entity renders correctly', (game) async {
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
Future<void> testMinecraftFull(
  String description,
  Future<void> Function(ClientGameContext game) callback, {
  Object? skip = false,
  Duration timeout = _defaultClientTimeout,
  dynamic tags,
}) async {
  final fullName =
      _groupPrefix.isEmpty ? description : '$_groupPrefix > $description';

  // If running in server-only mode, skip full tests with a message
  if (_isServerOnlyMode) {
    testResults.skipped++;
    emitEvent(TestSkipEvent(
      name: fullName,
      reason: 'Skipping full test - run with --full flag',
    ));
    print('  SKIP: $description (full test skipped in server-only mode)');
    return;
  }

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

/// Alias for [testMinecraftFull] - backwards compatibility.
///
/// Define a Minecraft full test for visual testing.
@isTest
Future<void> testMinecraftClient(
  String description,
  Future<void> Function(ClientGameContext game) callback, {
  Object? skip = false,
  Duration timeout = _defaultClientTimeout,
  dynamic tags,
}) =>
    testMinecraftFull(description, callback,
        skip: skip, timeout: timeout, tags: tags);
