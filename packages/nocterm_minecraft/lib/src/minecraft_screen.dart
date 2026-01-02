import 'package:dart_mod_common/dart_mod_common.dart';

/// Defines a rectangular screen surface in Minecraft world.
///
/// A MinecraftScreen represents a vertical plane of blocks that can be used
/// as a display surface. The screen must be coplanar (all blocks share the
/// same X coordinate or the same Z coordinate).
class MinecraftScreen {
  /// First corner position used to define the screen.
  final BlockPos corner1;

  /// Second corner position used to define the screen.
  final BlockPos corner2;

  /// The Minecraft dimension this screen is in.
  final String dimension;

  /// The axis that is constant (either 'x' or 'z').
  ///
  /// If 'x', the screen lies on a plane where X is constant.
  /// If 'z', the screen lies on a plane where Z is constant.
  final String planeAxis;

  /// Screen width in blocks.
  final int width;

  /// Screen height in blocks.
  final int height;

  /// Top-left corner of the screen (minimum horizontal, maximum Y).
  ///
  /// This is the reference point for coordinate mapping:
  /// - Buffer (0,0) maps to this world position
  /// - Buffer X increases in the positive horizontal direction
  /// - Buffer Y increases downward (opposite to world Y)
  final BlockPos topLeft;

  MinecraftScreen._({
    required this.corner1,
    required this.corner2,
    required this.dimension,
    required this.planeAxis,
    required this.width,
    required this.height,
    required this.topLeft,
  });

  /// Create a screen from two corner blocks.
  ///
  /// The corners define opposite corners of a rectangular screen surface.
  /// They must be in the same vertical plane (same X or same Z coordinate).
  ///
  /// Throws [ArgumentError] if corners are not coplanar.
  factory MinecraftScreen.fromCorners(
    BlockPos c1,
    BlockPos c2, {
    String dimension = 'minecraft:overworld',
  }) {
    // Determine plane orientation
    String axis;
    if (c1.x == c2.x) {
      axis = 'x';
    } else if (c1.z == c2.z) {
      axis = 'z';
    } else {
      throw ArgumentError(
        'Corners must be in the same vertical plane (same X or same Z). '
        'Got: $c1 and $c2',
      );
    }

    // Calculate dimensions
    final int screenWidth;
    final int screenHeight;

    if (axis == 'x') {
      // Screen spans Z and Y
      screenWidth = (c1.z - c2.z).abs() + 1;
      screenHeight = (c1.y - c2.y).abs() + 1;
    } else {
      // Screen spans X and Y
      screenWidth = (c1.x - c2.x).abs() + 1;
      screenHeight = (c1.y - c2.y).abs() + 1;
    }

    // Find top-left corner (min horizontal, max Y)
    final int topY = c1.y > c2.y ? c1.y : c2.y;
    final BlockPos screenTopLeft;

    if (axis == 'x') {
      final minZ = c1.z < c2.z ? c1.z : c2.z;
      screenTopLeft = BlockPos(c1.x, topY, minZ);
    } else {
      final minX = c1.x < c2.x ? c1.x : c2.x;
      screenTopLeft = BlockPos(minX, topY, c1.z);
    }

    return MinecraftScreen._(
      corner1: c1,
      corner2: c2,
      dimension: dimension,
      planeAxis: axis,
      width: screenWidth,
      height: screenHeight,
      topLeft: screenTopLeft,
    );
  }

  /// Convert buffer coordinates to world position.
  ///
  /// Buffer coordinate system:
  /// - (0, 0) is top-left of the screen
  /// - X increases to the right (positive Z for x-plane, positive X for z-plane)
  /// - Y increases downward
  ///
  /// World coordinate system:
  /// - Y increases upward
  ///
  /// Returns the [BlockPos] in world coordinates corresponding to the given
  /// buffer coordinates.
  BlockPos bufferToWorld(int bufferX, int bufferY) {
    if (planeAxis == 'x') {
      // Screen on X plane, spans Z horizontally
      return BlockPos(
        topLeft.x,
        topLeft.y - bufferY, // Y flipped: buffer Y down = world Y down
        topLeft.z + bufferX,
      );
    } else {
      // Screen on Z plane, spans X horizontally
      return BlockPos(
        topLeft.x + bufferX,
        topLeft.y - bufferY, // Y flipped: buffer Y down = world Y down
        topLeft.z,
      );
    }
  }

  /// Check if buffer coordinates are within the screen bounds.
  bool isInBounds(int bufferX, int bufferY) {
    return bufferX >= 0 && bufferX < width && bufferY >= 0 && bufferY < height;
  }

  /// Total number of blocks in the screen.
  int get blockCount => width * height;

  @override
  String toString() =>
      'MinecraftScreen(${width}x$height on $planeAxis plane, topLeft: $topLeft)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MinecraftScreen &&
          corner1 == other.corner1 &&
          corner2 == other.corner2 &&
          dimension == other.dimension;

  @override
  int get hashCode => Object.hash(corner1, corner2, dimension);
}
