/// Declarative world configuration for client E2E tests.
///
/// Provides a way to configure test world setup declaratively
/// instead of using imperative API calls.
library;

import 'package:dart_mod_server/dart_mod_server.dart';

import 'client_game_context.dart';

/// Declarative world configuration for client E2E tests.
///
/// Use this to configure the test world state before your test runs.
/// All settings are optional - only specified settings will be applied.
///
/// Example:
/// ```dart
/// await testMinecraftFull('test with defaults',
///   world: TestWorld.superflat(),
///   (game) async {
///     // World is set up with sensible defaults
///   },
/// );
/// ```
class TestWorld {
  /// Spawn position for the player.
  final BlockPos? spawn;

  /// Time of day.
  ///
  /// Common values:
  /// - 0 = sunrise (6:00 AM)
  /// - 6000 = noon (12:00 PM)
  /// - 12000 = sunset (6:00 PM)
  /// - 18000 = midnight (12:00 AM)
  final int? time;

  /// Weather condition.
  final Weather? weather;

  /// Player's game mode.
  final GameMode? gameMode;

  /// Radius around spawn to clear to air.
  ///
  /// When set, clears a cubic area around the spawn position.
  /// Height range is spawn.y - 5 to spawn.y + 50.
  final int? clearRadius;

  /// Initial blocks to place in the world.
  ///
  /// Each entry maps a position to a block to place there.
  final Map<BlockPos, Block>? initialBlocks;

  /// Create a custom test world configuration.
  ///
  /// All parameters are optional - only specified settings will be applied.
  const TestWorld({
    this.spawn,
    this.time,
    this.weather,
    this.gameMode,
    this.clearRadius,
    this.initialBlocks,
  });

  /// Create a superflat world with sensible defaults.
  ///
  /// Default configuration:
  /// - Spawn at (0, 64, 0)
  /// - Time: noon (6000)
  /// - Weather: clear
  /// - Game mode: creative
  /// - Clear radius: 50 blocks around spawn
  const TestWorld.superflat({
    BlockPos? spawn,
    int time = 6000,
    Weather weather = Weather.clear,
    GameMode gameMode = GameMode.creative,
    int clearRadius = 50,
    Map<BlockPos, Block>? initialBlocks,
  })  : spawn = spawn ?? const BlockPos(0, 64, 0),
        time = time,
        weather = weather,
        gameMode = gameMode,
        clearRadius = clearRadius,
        initialBlocks = initialBlocks;

  /// Create an empty void world - just air everywhere.
  ///
  /// Similar to superflat but with a larger clear radius by default.
  factory TestWorld.empty({
    BlockPos? spawn,
    int time = 6000,
    Weather weather = Weather.clear,
    GameMode gameMode = GameMode.creative,
    int clearRadius = 100,
    Map<BlockPos, Block>? initialBlocks,
  }) {
    return TestWorld(
      spawn: spawn ?? const BlockPos(0, 64, 0),
      time: time,
      weather: weather,
      gameMode: gameMode,
      clearRadius: clearRadius,
      initialBlocks: initialBlocks,
    );
  }

  /// Create a nether dimension setup.
  ///
  /// Note: This sets up the overworld but with nether-appropriate defaults.
  /// For actual nether testing, you'll need to handle dimension switching.
  factory TestWorld.nether({
    BlockPos? spawn,
    int time = 18000, // Always dark in nether
    Weather weather = Weather.clear, // No weather in nether
    GameMode gameMode = GameMode.creative,
    int clearRadius = 50,
    Map<BlockPos, Block>? initialBlocks,
  }) {
    return TestWorld(
      spawn: spawn ?? const BlockPos(0, 64, 0),
      time: time,
      weather: weather,
      gameMode: gameMode,
      clearRadius: clearRadius,
      initialBlocks: initialBlocks,
    );
  }

  /// Apply this world configuration to the game.
  ///
  /// This is called automatically by [testMinecraftFull] when a world
  /// configuration is provided.
  Future<void> apply(ClientGameContext game) async {
    // Teleport first so clearing happens around the right position
    if (spawn != null) {
      await game.teleportPlayer(spawn!);
    }

    // Clear area around spawn
    if (clearRadius != null && spawn != null) {
      game.clearArea(
        BlockPos(
          spawn!.x - clearRadius!,
          spawn!.y - 5,
          spawn!.z - clearRadius!,
        ),
        BlockPos(
          spawn!.x + clearRadius!,
          spawn!.y + 50,
          spawn!.z + clearRadius!,
        ),
      );
    }

    // Set time
    if (time != null) {
      game.setTime(time!);
    }

    // Set weather
    if (weather != null) {
      game.setWeather(weather!);
    }

    // Set game mode
    if (gameMode != null) {
      game.setGameMode(gameMode!);
    }

    // Place initial blocks
    if (initialBlocks != null) {
      for (final entry in initialBlocks!.entries) {
        game.placeBlock(entry.key, entry.value);
      }
    }

    // Wait a tick for all changes to take effect
    await game.waitTicks(1);
  }
}
