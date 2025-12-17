/// World API tests.
///
/// Tests for world manipulation including time, weather, game rules,
/// world border, spawn point, and difficulty settings.
import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  await group('Time of day', () async {
    await testMinecraft('can get time of day', (game) async {
      final time = game.world.timeOfDay;
      // Time should be between 0 and 24000
      expect(time, inInclusiveRange(0, 24000));
    });

    await testMinecraft('can set time of day', (game) async {
      // Set to noon (6000)
      game.setTimeOfDay(6000);
      await game.waitTicks(1);

      final time = game.world.timeOfDay;
      expect(time, equals(6000));
    });

    await testMinecraft('isDaytime is true during day', (game) async {
      game.setTimeOfDay(6000); // Noon
      await game.waitTicks(1);

      expect(game.world.isDaytime, isTrue);
      expect(game.world.isNighttime, isFalse);
    });

    await testMinecraft('isNighttime is true during night', (game) async {
      game.setTimeOfDay(18000); // Midnight
      await game.waitTicks(1);

      expect(game.world.isNighttime, isTrue);
      expect(game.world.isDaytime, isFalse);
    });

    await testMinecraft('can get day count', (game) async {
      final dayCount = game.world.dayCount;
      expect(dayCount, greaterThanOrEqualTo(0));
    });

    await testMinecraft('can get full game time', (game) async {
      final gameTime = game.world.gameTime;
      expect(gameTime, greaterThanOrEqualTo(0));
    });
  });

  await group('Weather', () async {
    await testMinecraft('can get weather', (game) async {
      final weather = game.world.weather;
      expect(weather, isA<Weather>());
    });

    await testMinecraft('can set weather to clear', (game) async {
      game.setWeather(Weather.clear, durationTicks: 6000);
      await game.waitTicks(5);

      expect(game.world.isRaining, isFalse);
      expect(game.world.isThundering, isFalse);
    });

    await testMinecraft('can set weather to rain', (game) async {
      game.setWeather(Weather.rain, durationTicks: 6000);
      await game.waitTicks(5);

      expect(game.world.isRaining, isTrue);
      expect(game.world.isThundering, isFalse);
    });

    await testMinecraft('can set weather to thunder', (game) async {
      game.setWeather(Weather.thunder, durationTicks: 6000);
      await game.waitTicks(5);

      expect(game.world.isThundering, isTrue);
    });
  });

  await group('Difficulty', () async {
    await testMinecraft('can get difficulty', (game) async {
      final difficulty = game.world.difficulty;
      expect(difficulty, isA<Difficulty>());
    });

    await testMinecraft('can set difficulty to peaceful', (game) async {
      game.world.difficulty = Difficulty.peaceful;
      await game.waitTicks(1);

      expect(game.world.difficulty, equals(Difficulty.peaceful));
    });

    await testMinecraft('can set difficulty to easy', (game) async {
      game.world.difficulty = Difficulty.easy;
      await game.waitTicks(1);

      expect(game.world.difficulty, equals(Difficulty.easy));
    });

    await testMinecraft('can set difficulty to normal', (game) async {
      game.world.difficulty = Difficulty.normal;
      await game.waitTicks(1);

      expect(game.world.difficulty, equals(Difficulty.normal));
    });

    await testMinecraft('can set difficulty to hard', (game) async {
      game.world.difficulty = Difficulty.hard;
      await game.waitTicks(1);

      expect(game.world.difficulty, equals(Difficulty.hard));
    });
  });

  await group('Game rules', () async {
    await testMinecraft('can get doDaylightCycle', (game) async {
      final value = game.world.doDaylightCycle;
      expect(value, isA<bool>());
    });

    await testMinecraft('can set doDaylightCycle', (game) async {
      // Save original value
      final original = game.world.doDaylightCycle;

      // Toggle it
      game.world.doDaylightCycle = !original;
      await game.waitTicks(1);
      expect(game.world.doDaylightCycle, equals(!original));

      // Restore original
      game.world.doDaylightCycle = original;
    });

    await testMinecraft('can get and set doWeatherCycle', (game) async {
      final value = game.world.doWeatherCycle;
      expect(value, isA<bool>());
    });

    await testMinecraft('can get and set keepInventory', (game) async {
      final value = game.world.keepInventory;
      expect(value, isA<bool>());
    });

    await testMinecraft('can get and set doMobSpawning', (game) async {
      final value = game.world.doMobSpawning;
      expect(value, isA<bool>());
    });

    await testMinecraft('can get and set mobGriefing', (game) async {
      final value = game.world.mobGriefing;
      expect(value, isA<bool>());
    });

    await testMinecraft('can get randomTickSpeed', (game) async {
      final value = game.world.randomTickSpeed;
      expect(value, greaterThanOrEqualTo(0));
    });

    await testMinecraft('can set randomTickSpeed', (game) async {
      final original = game.world.randomTickSpeed;

      game.world.randomTickSpeed = 10;
      await game.waitTicks(1);
      expect(game.world.randomTickSpeed, equals(10));

      // Restore
      game.world.randomTickSpeed = original;
    });
  });

  await group('Spawn point', () async {
    await testMinecraft('can get spawn point', (game) async {
      final spawnPoint = game.world.spawnPoint;
      expect(spawnPoint, isA<BlockPos>());
    });

    await testMinecraft('can set spawn point', (game) async {
      final newSpawn = const BlockPos(100, 70, 100);

      game.world.spawnPoint = newSpawn;
      await game.waitTicks(1);

      final spawnPoint = game.world.spawnPoint;
      expect(spawnPoint.x, equals(newSpawn.x));
      expect(spawnPoint.y, equals(newSpawn.y));
      expect(spawnPoint.z, equals(newSpawn.z));
    });
  });

  await group('World border', () async {
    await testMinecraft('can get world border size', (game) async {
      final size = game.world.worldBorderSize;
      expect(size, greaterThan(0));
    });

    await testMinecraft('can get world border center', (game) async {
      final center = game.world.worldBorderCenter;
      expect(center, isA<Vec3>());
    });

    await testMinecraft('can set world border size', (game) async {
      final originalSize = game.world.worldBorderSize;

      game.world.worldBorderSize = 1000;
      await game.waitTicks(5);

      // Size should be close to 1000 (might have some rounding)
      expect(game.world.worldBorderSize, closeTo(1000, 10));

      // Restore original
      game.world.worldBorderSize = originalSize;
    });

    await testMinecraft('can set world border center', (game) async {
      final newCenter = Vec3(50, 0, 50);

      game.world.worldBorderCenter = newCenter;
      await game.waitTicks(1);

      final center = game.world.worldBorderCenter;
      expect(center.x, closeTo(50, 1));
      expect(center.z, closeTo(50, 1));
    });
  });

  await group('Multi-dimension support', () async {
    await testMinecraft('overworld has correct dimension ID', (game) async {
      expect(game.world.dimensionId, equals('minecraft:overworld'));
    });

    await testMinecraft('nether has correct dimension ID', (game) async {
      expect(game.nether.dimensionId, equals('minecraft:the_nether'));
    });

    await testMinecraft('end has correct dimension ID', (game) async {
      expect(game.end.dimensionId, equals('minecraft:the_end'));
    });

    await testMinecraft('can get custom world by ID', (game) async {
      final customWorld = game.getWorld('minecraft:overworld');
      expect(customWorld.dimensionId, equals('minecraft:overworld'));
    });
  });
}

/// Matcher for approximate double equality.
Matcher closeTo(num value, num delta) =>
    inInclusiveRange(value - delta, value + delta);
