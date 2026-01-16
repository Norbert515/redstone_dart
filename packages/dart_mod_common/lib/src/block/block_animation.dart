/// Block animation types for animated blocks in the Redstone framework.
///
/// This library provides a sealed class hierarchy for defining block animations
/// that transform the block model over time (rotation, translation, scale).
library;

import 'dart:math';

/// Axis enum for 3D rotations
enum Axis3D { x, y, z }

/// 3D vector for pivot points and positions
class AnimationVec3 {
  final double x, y, z;
  const AnimationVec3(this.x, this.y, this.z);

  /// Common pivot points
  static const center = AnimationVec3(0.5, 0.5, 0.5);
  static const bottom = AnimationVec3(0.5, 0.0, 0.5);
  static const top = AnimationVec3(0.5, 1.0, 0.5);
  static const origin = AnimationVec3(0, 0, 0);

  List<double> toJson() => [x, y, z];
}

/// Animation state that gets synced to the renderer
class AnimationState {
  // Rotation in degrees
  double rotationX = 0;
  double rotationY = 0;
  double rotationZ = 0;

  // Translation in blocks
  double translateX = 0;
  double translateY = 0;
  double translateZ = 0;

  // Scale factors (1.0 = normal)
  double scaleX = 1;
  double scaleY = 1;
  double scaleZ = 1;

  // Pivot point for rotation/scale
  AnimationVec3 pivot = AnimationVec3.center;

  /// Set uniform scale
  void setScale(double scale) {
    scaleX = scaleY = scaleZ = scale;
  }

  Map<String, dynamic> toJson() => {
        'rotX': rotationX,
        'rotY': rotationY,
        'rotZ': rotationZ,
        'transX': translateX,
        'transY': translateY,
        'transZ': translateZ,
        'scaleX': scaleX,
        'scaleY': scaleY,
        'scaleZ': scaleZ,
        'pivotX': pivot.x,
        'pivotY': pivot.y,
        'pivotZ': pivot.z,
      };

  void reset() {
    rotationX = rotationY = rotationZ = 0;
    translateX = translateY = translateZ = 0;
    scaleX = scaleY = scaleZ = 1;
  }
}

/// Base class for block animations
sealed class BlockAnimation {
  const BlockAnimation();

  /// Continuous rotation around an axis
  ///
  /// Example:
  /// ```dart
  /// animation: BlockAnimation.spin(speed: 1.0)  // 1 rotation per second around Y
  /// animation: BlockAnimation.spin(axis: Axis3D.x, speed: 0.5, pivot: AnimationVec3.bottom)
  /// ```
  factory BlockAnimation.spin({
    Axis3D axis = Axis3D.y,
    double speed = 1.0,
    AnimationVec3 pivot = AnimationVec3.center,
  }) {
    assert(speed != 0, 'Speed cannot be zero');
    return SpinAnimation(axis: axis, speed: speed, pivot: pivot);
  }

  /// Bobbing up and down (floating effect)
  ///
  /// Example:
  /// ```dart
  /// animation: BlockAnimation.bob(amplitude: 0.1, frequency: 1.0)
  /// ```
  factory BlockAnimation.bob({
    double amplitude = 0.1,
    double frequency = 1.0,
  }) {
    assert(amplitude > 0, 'Amplitude must be positive');
    assert(frequency > 0, 'Frequency must be positive');
    return BobAnimation(amplitude: amplitude, frequency: frequency);
  }

  /// Scale pulsing (breathing effect)
  ///
  /// Example:
  /// ```dart
  /// animation: BlockAnimation.pulse(minScale: 0.9, maxScale: 1.1)
  /// ```
  factory BlockAnimation.pulse({
    double minScale = 0.9,
    double maxScale = 1.1,
    double frequency = 1.0,
    AnimationVec3 pivot = AnimationVec3.center,
  }) {
    assert(minScale > 0, 'minScale must be positive');
    assert(maxScale > minScale, 'maxScale must be greater than minScale');
    assert(frequency > 0, 'Frequency must be positive');
    return PulseAnimation(
      minScale: minScale,
      maxScale: maxScale,
      frequency: frequency,
      pivot: pivot,
    );
  }

  /// Combine multiple animations
  ///
  /// Example:
  /// ```dart
  /// animation: BlockAnimation.combine([
  ///   BlockAnimation.spin(speed: 1.0),
  ///   BlockAnimation.bob(amplitude: 0.2),
  /// ])
  /// ```
  factory BlockAnimation.combine(List<BlockAnimation> animations) {
    assert(animations.isNotEmpty, 'Must provide at least one animation');
    assert(
      !animations.any((a) => a is CombinedAnimation),
      'Cannot nest combined animations',
    );
    return CombinedAnimation(animations: animations);
  }

  /// Custom animation with full control via callback
  ///
  /// Example:
  /// ```dart
  /// animation: BlockAnimation.custom((state, time) {
  ///   state.rotationY = sin(time) * 45;  // Oscillate 45 degrees
  ///   state.translateY = (sin(time * 2) + 1) * 0.1;  // Bob
  /// })
  /// ```
  factory BlockAnimation.custom(
    void Function(AnimationState state, double time) update,
  ) = CustomAnimation;

  /// Apply this animation to the given state at the given time
  void apply(AnimationState state, double time);

  /// Serialize for manifest
  Map<String, dynamic> toJson();
}

/// Continuous rotation animation
final class SpinAnimation extends BlockAnimation {
  final Axis3D axis;
  final double speed;
  final AnimationVec3 pivot;

  const SpinAnimation({
    required this.axis,
    required this.speed,
    required this.pivot,
  });

  @override
  void apply(AnimationState state, double time) {
    final angle = (time * speed * 360) % 360;
    state.pivot = pivot;
    switch (axis) {
      case Axis3D.x:
        state.rotationX += angle;
      case Axis3D.y:
        state.rotationY += angle;
      case Axis3D.z:
        state.rotationZ += angle;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'spin',
        'axis': axis.name,
        'speed': speed,
        'pivot': pivot.toJson(),
      };
}

/// Bobbing/floating animation
final class BobAnimation extends BlockAnimation {
  final double amplitude;
  final double frequency;

  const BobAnimation({
    required this.amplitude,
    required this.frequency,
  });

  @override
  void apply(AnimationState state, double time) {
    state.translateY += sin(time * frequency * 2 * pi) * amplitude;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'bob',
        'amplitude': amplitude,
        'frequency': frequency,
      };
}

/// Scale pulsing animation
final class PulseAnimation extends BlockAnimation {
  final double minScale;
  final double maxScale;
  final double frequency;
  final AnimationVec3 pivot;

  const PulseAnimation({
    required this.minScale,
    required this.maxScale,
    required this.frequency,
    required this.pivot,
  });

  @override
  void apply(AnimationState state, double time) {
    // Oscillate between 0 and 1
    final t = (sin(time * frequency * 2 * pi) + 1) / 2;
    final scale = minScale + (maxScale - minScale) * t;
    state.pivot = pivot;
    state.scaleX *= scale;
    state.scaleY *= scale;
    state.scaleZ *= scale;
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pulse',
        'minScale': minScale,
        'maxScale': maxScale,
        'frequency': frequency,
        'pivot': pivot.toJson(),
      };
}

/// Combined multiple animations
final class CombinedAnimation extends BlockAnimation {
  final List<BlockAnimation> animations;

  const CombinedAnimation({required this.animations});

  @override
  void apply(AnimationState state, double time) {
    for (final animation in animations) {
      animation.apply(state, time);
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'combined',
        'animations': animations.map((a) => a.toJson()).toList(),
      };
}

/// Custom animation with user-provided update function
final class CustomAnimation extends BlockAnimation {
  final void Function(AnimationState state, double time) update;

  const CustomAnimation(this.update);

  @override
  void apply(AnimationState state, double time) {
    update(state, time);
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'custom',
      };
}
