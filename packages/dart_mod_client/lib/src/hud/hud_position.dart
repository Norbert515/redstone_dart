/// Position anchors and offsets for HUD overlays.
library;

/// Position anchors for HUD overlays.
///
/// Defines where the overlay anchors on the screen. The overlay's
/// position is calculated relative to this anchor point.
enum HudPosition {
  /// Top-left corner of the screen.
  topLeft,

  /// Top-center of the screen.
  topCenter,

  /// Top-right corner of the screen.
  topRight,

  /// Center-left of the screen.
  centerLeft,

  /// Center of the screen.
  center,

  /// Center-right of the screen.
  centerRight,

  /// Bottom-left corner of the screen.
  bottomLeft,

  /// Bottom-center of the screen.
  bottomCenter,

  /// Bottom-right corner of the screen.
  bottomRight,
}

/// Offset from the anchor position in logical pixels.
///
/// Used to fine-tune the position of a HUD overlay after anchoring.
class HudOffset {
  /// Horizontal offset in logical pixels.
  final double x;

  /// Vertical offset in logical pixels.
  final double y;

  /// Creates a HUD offset with the given x and y values.
  const HudOffset(this.x, this.y);

  /// Zero offset.
  static const zero = HudOffset(0, 0);

  @override
  String toString() => 'HudOffset($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HudOffset && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}
