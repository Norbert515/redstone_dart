/// Player API tests.
///
/// Tests for player operations including stats, communication, movement,
/// and game mode. Note: Many of these tests require at least one player
/// to be connected to the server.
import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  await group('Player list', () async {
    await testMinecraft('can get all players list', (game) async {
      final players = game.players;

      // Should return a list (may be empty if no players connected)
      expect(players, isA<List<Player>>());
    });

    await testMinecraft('Players.getAllPlayers returns list', (game) async {
      final players = Players.getAllPlayers();
      expect(players, isA<List<Player>>());
    });

    await testMinecraft('Players.playerCount returns a number', (game) async {
      final count = Players.playerCount;
      expect(count, greaterThanOrEqualTo(0));
    });
  });

  // The following tests require at least one player to be connected.
  // They will be skipped if no players are online.
  await group('Player properties (requires online player)', () async {
    await testMinecraft('player has valid name', (game) async {
      final players = game.players;
      if (players.isEmpty) {
        // Skip if no players online
        return;
      }

      final player = players.first;
      expect(player.name, isNotEmpty);
    });

    await testMinecraft('player has valid UUID', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.uuid, isNotEmpty);
    });

    await testMinecraft('player has valid ID', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.id, greaterThan(0));
    });
  });

  await group('Player position (requires online player)', () async {
    await testMinecraft('player has position', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final position = player.position;

      expect(position, isA<BlockPos>());
    });

    await testMinecraft('player has precise position', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final position = player.precisePosition;

      expect(position, isA<Vec3>());
    });

    await testMinecraft('player has yaw', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final yaw = player.yaw;

      // Yaw should be in reasonable range
      expect(yaw, isA<double>());
    });

    await testMinecraft('player has pitch', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final pitch = player.pitch;

      // Pitch should be between -90 and 90
      expect(pitch, inInclusiveRange(-90, 90));
    });
  });

  await group('Player health and food (requires online player)', () async {
    await testMinecraft('player has health', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.health, greaterThan(0));
      expect(player.health, lessThanOrEqualTo(player.maxHealth));
    });

    await testMinecraft('player has max health', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.maxHealth, greaterThan(0));
    });

    await testMinecraft('player has food level', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.foodLevel, inInclusiveRange(0, 20));
    });

    await testMinecraft('player has saturation', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.saturation, greaterThanOrEqualTo(0));
    });

    await testMinecraft('can set player health', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final originalHealth = player.health;

      player.health = 10;
      await game.waitTicks(1);
      expect(player.health, equals(10));

      // Restore original health
      player.health = originalHealth;
    });

    await testMinecraft('can set player food level', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final originalFood = player.foodLevel;

      player.foodLevel = 10;
      await game.waitTicks(1);
      expect(player.foodLevel, equals(10));

      // Restore
      player.foodLevel = originalFood;
    });
  });

  await group('Player game mode (requires online player)', () async {
    await testMinecraft('player has game mode', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.gameMode, isA<GameMode>());
    });

    await testMinecraft('hasGameMode matcher works', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final currentMode = player.gameMode;

      expect(player, hasGameMode(currentMode));
    });

    await testMinecraft('can change game mode to creative', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final originalMode = player.gameMode;

      player.gameMode = GameMode.creative;
      await game.waitTicks(1);
      expect(player.gameMode, equals(GameMode.creative));
      expect(player.isCreative, isTrue);

      // Restore
      player.gameMode = originalMode;
    });

    await testMinecraft('can change game mode to survival', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final originalMode = player.gameMode;

      player.gameMode = GameMode.survival;
      await game.waitTicks(1);
      expect(player.gameMode, equals(GameMode.survival));
      expect(player.isSurvival, isTrue);

      // Restore
      player.gameMode = originalMode;
    });

    await testMinecraft('can change game mode to spectator', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final originalMode = player.gameMode;

      player.gameMode = GameMode.spectator;
      await game.waitTicks(1);
      expect(player.gameMode, equals(GameMode.spectator));
      expect(player.isSpectator, isTrue);

      // Restore
      player.gameMode = originalMode;
    });

    await testMinecraft('can change game mode to adventure', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final originalMode = player.gameMode;

      player.gameMode = GameMode.adventure;
      await game.waitTicks(1);
      expect(player.gameMode, equals(GameMode.adventure));
      expect(player.isAdventure, isTrue);

      // Restore
      player.gameMode = originalMode;
    });
  });

  await group('Player experience (requires online player)', () async {
    await testMinecraft('player has experience level', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.experienceLevel, greaterThanOrEqualTo(0));
    });

    await testMinecraft('player has total experience', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.totalExperience, greaterThanOrEqualTo(0));
    });

    await testMinecraft('can set experience level', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final originalLevel = player.experienceLevel;

      player.experienceLevel = 10;
      await game.waitTicks(1);
      expect(player.experienceLevel, equals(10));

      // Restore
      player.experienceLevel = originalLevel;
    });

    await testMinecraft('can give experience', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final originalXp = player.totalExperience;

      player.giveExperience(100);
      await game.waitTicks(1);
      expect(player.totalExperience, greaterThan(originalXp));
    });
  });

  await group('Player state flags (requires online player)', () async {
    await testMinecraft('can check if player is on ground', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.isOnGround, isA<bool>());
    });

    await testMinecraft('can check if player is sneaking', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.isSneaking, isA<bool>());
    });

    await testMinecraft('can check if player is sprinting', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.isSprinting, isA<bool>());
    });

    await testMinecraft('can check if player is swimming', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.isSwimming, isA<bool>());
    });

    await testMinecraft('can check if player is flying', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      expect(player.isFlying, isA<bool>());
    });
  });

  await group('Player communication (requires online player)', () async {
    await testMinecraft('can send message to player', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;

      // This should not throw
      player.sendMessage('Test message from redstone_test_suite');
      await game.waitTicks(1);

      // No assertion needed - just verify no crash
      expect(true, isTrue);
    });

    await testMinecraft('can send action bar to player', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;

      player.sendActionBar('Test action bar');
      await game.waitTicks(1);

      expect(true, isTrue);
    });

    await testMinecraft('can send title to player', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;

      player.sendTitle(
        'Test Title',
        subtitle: 'Test Subtitle',
        fadeIn: 5,
        stay: 20,
        fadeOut: 5,
      );
      await game.waitTicks(1);

      expect(true, isTrue);
    });
  });

  await group('Player teleportation (requires online player)', () async {
    await testMinecraft('can teleport player to block position', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final targetPos = BlockPos(0, 100, 0);

      player.teleport(targetPos);
      await game.waitTicks(5);

      final newPos = player.position;
      expect(newPos.x, equals(0));
      expect(newPos.z, equals(0));
    });

    await testMinecraft('can teleport player with precise coordinates', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final targetPos = Vec3(10.5, 100, 10.5);

      player.teleportPrecise(targetPos);
      await game.waitTicks(5);

      final newPos = player.precisePosition;
      expect(newPos.x, closeTo(10.5, 1));
      expect(newPos.z, closeTo(10.5, 1));
    });

    await testMinecraft('can teleport player with rotation', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final targetPos = Vec3(20, 100, 20);

      player.teleportPrecise(targetPos, yaw: 90, pitch: 0);
      await game.waitTicks(5);

      expect(player.yaw, closeTo(90, 5));
    });
  });

  await group('Player lookup', () async {
    await testMinecraft('can get player by name', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final lookedUp = Players.getPlayerByName(player.name);

      expect(lookedUp, isNotNull);
      expect(lookedUp!.id, equals(player.id));
    });

    await testMinecraft('can get player by UUID', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final lookedUp = Players.getPlayerByUuid(player.uuid);

      expect(lookedUp, isNotNull);
      expect(lookedUp!.id, equals(player.id));
    });

    await testMinecraft('getting non-existent player returns null', (game) async {
      final player = Players.getPlayerByName('NonExistentPlayer12345');
      expect(player, isNull);
    });

    await testMinecraft('getting player by invalid UUID returns null', (game) async {
      final player = Players.getPlayerByUuid('invalid-uuid');
      expect(player, isNull);
    });
  });

  await group('PlayerInfo snapshot', () async {
    await testMinecraft('can create PlayerInfo from player', (game) async {
      final players = game.players;
      if (players.isEmpty) return;

      final player = players.first;
      final info = PlayerInfo.fromPlayer(player);

      expect(info.player, equals(player));
      expect(info.name, equals(player.name));
      expect(info.position, isA<BlockPos>());
      expect(info.precisePosition, isA<Vec3>());
      expect(info.health, equals(player.health));
      expect(info.maxHealth, equals(player.maxHealth));
      expect(info.foodLevel, equals(player.foodLevel));
      expect(info.gameMode, equals(player.gameMode));
    });
  });
}

/// Matcher for approximate double equality.
Matcher closeTo(num value, num delta) =>
    inInclusiveRange(value - delta, value + delta);
