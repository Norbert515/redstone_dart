/// Core bridge functionality tests.
///
/// These tests verify that the Dart↔C++↔Java bridge is properly initialized
/// and can handle basic communication patterns.
import 'dart:async';

import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  await group('Bridge initialization', () async {
    await testMinecraft('bridge is initialized and running', (game) async {
      // If we reach this point, the bridge has successfully initialized
      // and the test framework is connected to Minecraft
      expect(true, isTrue);
    });

    await testMinecraft('can access world object', (game) async {
      // Verify we can access the world - this tests basic JNI communication
      final world = game.world;
      expect(world, isNotNull);
      expect(world.dimensionId, equals('minecraft:overworld'));
    });

    await testMinecraft('can access nether dimension', (game) async {
      final nether = game.nether;
      expect(nether, isNotNull);
      expect(nether.dimensionId, equals('minecraft:the_nether'));
    });

    await testMinecraft('can access end dimension', (game) async {
      final end = game.end;
      expect(end, isNotNull);
      expect(end.dimensionId, equals('minecraft:the_end'));
    });
  });

  await group('Tick system', () async {
    await testMinecraft('can survive a single tick', (game) async {
      await game.waitTicks(1);
      expect(game.currentTick, greaterThan(0));
    });

    await testMinecraft('can survive multiple ticks', (game) async {
      final startTick = game.currentTick;
      await game.waitTicks(100);
      expect(game.currentTick, greaterThanOrEqualTo(startTick + 100));
    });

    await testMinecraft('waitTicks advances correctly', (game) async {
      final startTick = game.currentTick;
      const ticksToWait = 20;

      await game.waitTicks(ticksToWait);

      // Tick count should have increased by at least the waited amount
      expect(game.currentTick, greaterThanOrEqualTo(startTick + ticksToWait));
    });

    await testMinecraft('waitTicks(0) returns immediately', (game) async {
      final startTick = game.currentTick;
      await game.waitTicks(0);
      // Should return immediately, tick might or might not have advanced
      expect(game.currentTick, greaterThanOrEqualTo(startTick));
    });
  });

  await group('waitUntil functionality', () async {
    await testMinecraft('waitUntil returns true when condition met', (game) async {
      var counter = 0;

      // Schedule counter increment
      final result = await game.waitUntil(
        () {
          counter++;
          return counter >= 5;
        },
        maxTicks: 50,
        pollInterval: 1,
      );

      expect(result, isTrue);
      expect(counter, greaterThanOrEqualTo(5));
    });

    await testMinecraft('waitUntil returns false on timeout', (game) async {
      // Condition that never becomes true
      final result = await game.waitUntil(
        () => false,
        maxTicks: 10,
        pollInterval: 1,
      );

      expect(result, isFalse);
    });

    await testMinecraft('waitUntilOrThrow throws on timeout', (game) async {
      expect(
        () async => await game.waitUntilOrThrow(
          () => false,
          maxTicks: 5,
          reason: 'Test timeout',
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  await group('Game time', () async {
    await testMinecraft('can read game time', (game) async {
      final gameTime = game.gameTime;
      expect(gameTime, greaterThanOrEqualTo(0));
    });

    await testMinecraft('game time advances with ticks', (game) async {
      final startTime = game.gameTime;
      await game.waitTicks(10);
      final endTime = game.gameTime;

      // Game time should advance (may be more than 10 ticks due to processing)
      expect(endTime, greaterThan(startTime));
    });
  });
}
