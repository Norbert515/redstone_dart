/// World API for interacting with the Minecraft world.
library;

// Imports for future API expansion:
// import '../src/types.dart';
// import 'block.dart';

/// Represents a Minecraft world/dimension.
class World {
  /// The dimension identifier.
  final String dimensionId;

  const World(this.dimensionId);

  /// Common dimensions
  static const overworld = World('minecraft:overworld');
  static const nether = World('minecraft:the_nether');
  static const end = World('minecraft:the_end');

  @override
  String toString() => 'World($dimensionId)';

  @override
  bool operator ==(Object other) => other is World && dimensionId == other.dimensionId;

  @override
  int get hashCode => dimensionId.hashCode;
}

/// Time of day in Minecraft.
class GameTime {
  /// The current tick (0-24000 for a full day cycle).
  final int tick;

  const GameTime(this.tick);

  /// Time in ticks within the current day (0-24000).
  int get dayTime => tick % 24000;

  /// Current day number.
  int get day => tick ~/ 24000;

  /// Is it daytime (6am-6pm in Minecraft time)?
  bool get isDay => dayTime >= 0 && dayTime < 12000;

  /// Is it nighttime?
  bool get isNight => !isDay;

  @override
  String toString() => 'GameTime(day $day, tick $dayTime)';
}

/// Weather conditions.
enum Weather {
  clear,
  rain,
  thunder,
}

// TODO: Add methods to interact with the world via native bridge
// These will require additional JNI functions
//
// Example future API:
// class WorldApi {
//   static BlockState? getBlock(World world, BlockPos pos) { ... }
//   static void setBlock(World world, BlockPos pos, Block block) { ... }
//   static GameTime getTime(World world) { ... }
//   static Weather getWeather(World world) { ... }
//   static void spawnParticle(World world, BlockPos pos, String particle) { ... }
// }
