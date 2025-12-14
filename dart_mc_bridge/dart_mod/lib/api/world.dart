/// World API for interacting with the Minecraft world.
library;

import '../src/jni/generic_bridge.dart';
import '../src/types.dart';
import 'block.dart';

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

  // ==========================================================================
  // Block Manipulation APIs
  // ==========================================================================

  /// Get the block at a position in this world.
  /// Returns the block, or [Block.air] if the position is invalid/unloaded.
  Block getBlock(BlockPos pos) {
    final blockId = GenericJniBridge.callStaticStringMethod(
      'com/example/dartbridge/DartBridge',
      'getBlockId',
      '(Ljava/lang/String;III)Ljava/lang/String;',
      [dimensionId, pos.x, pos.y, pos.z],
    );
    if (blockId == null) return Block.air;
    return Block(blockId);
  }

  /// Set a block at a position in this world.
  /// Returns true if successful.
  bool setBlock(BlockPos pos, Block block) {
    return GenericJniBridge.callStaticBoolMethod(
      'com/example/dartbridge/DartBridge',
      'setBlock',
      '(Ljava/lang/String;IIILjava/lang/String;)Z',
      [dimensionId, pos.x, pos.y, pos.z, block.id],
    );
  }

  /// Check if a position contains air.
  bool isAir(BlockPos pos) {
    return GenericJniBridge.callStaticBoolMethod(
      'com/example/dartbridge/DartBridge',
      'isAirBlock',
      '(Ljava/lang/String;III)Z',
      [dimensionId, pos.x, pos.y, pos.z],
    );
  }
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
