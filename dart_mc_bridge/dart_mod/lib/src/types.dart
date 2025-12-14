/// Common type definitions for the Minecraft Dart mod.
library;

/// Result of an event handler.
///
/// Used to indicate whether an event should be allowed to proceed
/// or should be cancelled.
enum EventResult {
  /// Allow the event to proceed normally.
  allow(1),

  /// Cancel the event (prevent it from happening).
  cancel(0);

  final int value;
  const EventResult(this.value);

  static EventResult fromValue(int value) {
    return value == 0 ? EventResult.cancel : EventResult.allow;
  }
}

/// Represents a position in 3D space.
class BlockPos {
  final int x;
  final int y;
  final int z;

  const BlockPos(this.x, this.y, this.z);

  BlockPos offset(int dx, int dy, int dz) {
    return BlockPos(x + dx, y + dy, z + dz);
  }

  BlockPos up([int n = 1]) => offset(0, n, 0);
  BlockPos down([int n = 1]) => offset(0, -n, 0);
  BlockPos north([int n = 1]) => offset(0, 0, -n);
  BlockPos south([int n = 1]) => offset(0, 0, n);
  BlockPos east([int n = 1]) => offset(n, 0, 0);
  BlockPos west([int n = 1]) => offset(-n, 0, 0);

  @override
  String toString() => 'BlockPos($x, $y, $z)';

  @override
  bool operator ==(Object other) =>
      other is BlockPos && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// Hand used for interactions.
enum Hand {
  mainHand(0),
  offHand(1);

  final int value;
  const Hand(this.value);

  static Hand fromValue(int value) {
    return value == 1 ? Hand.offHand : Hand.mainHand;
  }
}

/// Direction/facing in Minecraft.
enum Direction {
  down(0, 0, -1, 0),
  up(1, 0, 1, 0),
  north(2, 0, 0, -1),
  south(3, 0, 0, 1),
  west(4, -1, 0, 0),
  east(5, 1, 0, 0);

  final int id;
  final int offsetX;
  final int offsetY;
  final int offsetZ;

  const Direction(this.id, this.offsetX, this.offsetY, this.offsetZ);

  BlockPos offset(BlockPos pos) {
    return pos.offset(offsetX, offsetY, offsetZ);
  }

  Direction get opposite {
    return switch (this) {
      Direction.down => Direction.up,
      Direction.up => Direction.down,
      Direction.north => Direction.south,
      Direction.south => Direction.north,
      Direction.west => Direction.east,
      Direction.east => Direction.west,
    };
  }
}
