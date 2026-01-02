/// Block settings for creating custom blocks.
library;

/// Settings for creating a block.
class BlockSettings {
  final double hardness;
  final double resistance;
  final bool requiresTool;

  /// Light emission level (0-15). Default is 0 (no light).
  final int luminance;

  /// Slipperiness factor. Default is 0.6, ice is 0.98.
  final double slipperiness;

  /// Movement speed multiplier. Default is 1.0, soul sand is 0.4.
  final double velocityMultiplier;

  /// Jump height multiplier. Default is 1.0, honey is 0.5.
  final double jumpVelocityMultiplier;

  /// Whether this block receives random ticks (for crops, spreading, etc.).
  final bool ticksRandomly;

  /// Whether entities collide with this block. Default is true.
  final bool collidable;

  /// Whether this block can be replaced when placing other blocks.
  final bool replaceable;

  /// Whether this block can catch fire.
  final bool burnable;

  const BlockSettings({
    this.hardness = 1.0,
    this.resistance = 1.0,
    this.requiresTool = false,
    this.luminance = 0,
    this.slipperiness = 0.6,
    this.velocityMultiplier = 1.0,
    this.jumpVelocityMultiplier = 1.0,
    this.ticksRandomly = false,
    this.collidable = true,
    this.replaceable = false,
    this.burnable = false,
  });
}
