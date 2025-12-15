/// Common type definitions for the Minecraft Dart mod.
library;

import 'dart:math' as math;

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

/// Represents a precise position in 3D space with double precision.
class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  /// Create a Vec3 from a BlockPos (uses block center).
  factory Vec3.fromBlockPos(BlockPos pos) {
    return Vec3(pos.x + 0.5, pos.y.toDouble(), pos.z + 0.5);
  }

  /// Convert to BlockPos (floor of each coordinate).
  BlockPos toBlockPos() => BlockPos(x.floor(), y.floor(), z.floor());

  /// Vector addition.
  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);

  /// Vector subtraction.
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);

  /// Scalar multiplication.
  Vec3 operator *(double scalar) => Vec3(x * scalar, y * scalar, z * scalar);

  /// Scalar division.
  Vec3 operator /(double scalar) => Vec3(x / scalar, y / scalar, z / scalar);

  /// Unary negation.
  Vec3 operator -() => Vec3(-x, -y, -z);

  /// Calculate distance to another Vec3.
  double distanceTo(Vec3 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Calculate squared distance to another Vec3 (faster, no sqrt).
  double distanceSquaredTo(Vec3 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return dx * dx + dy * dy + dz * dz;
  }

  /// Get the length (magnitude) of this vector.
  double get length => math.sqrt(x * x + y * y + z * z);

  /// Get the squared length (faster, no sqrt).
  double get lengthSquared => x * x + y * y + z * z;

  /// Normalize this vector (make it unit length).
  Vec3 get normalized {
    final len = length;
    if (len == 0) return Vec3.zero;
    return this / len;
  }

  /// Dot product with another vector.
  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  /// Cross product with another vector.
  Vec3 cross(Vec3 other) => Vec3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  /// Common vectors.
  static const zero = Vec3(0, 0, 0);
  static const one = Vec3(1, 1, 1);
  static const up = Vec3(0, 1, 0);
  static const down = Vec3(0, -1, 0);
  static const north = Vec3(0, 0, -1);
  static const south = Vec3(0, 0, 1);
  static const east = Vec3(1, 0, 0);
  static const west = Vec3(-1, 0, 0);

  @override
  String toString() => 'Vec3($x, $y, $z)';

  @override
  bool operator ==(Object other) =>
      other is Vec3 && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);
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
