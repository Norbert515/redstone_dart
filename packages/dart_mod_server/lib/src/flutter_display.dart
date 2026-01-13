/// Flutter display entity API for rendering Flutter UI content in the world.
///
/// Flutter displays are entities that render Flutter widget content as
/// floating rectangles in the 3D world. They support:
/// - Billboard modes (face camera, fixed orientation)
/// - Custom dimensions (width/height in world units)
/// - Position and rotation control
///
/// Example:
/// ```dart
/// final display = await FlutterDisplay.spawn(
///   position: Vec3(0, 65, 0),
///   width: 2.0,
///   height: 1.5,
///   mode: BillboardMode.center, // Always face camera
/// );
///
/// // Update position
/// display.position = Vec3(0, 66, 0);
///
/// // Clean up when done
/// display.dispose();
/// ```
library;

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:dart_mod_common/src/jni/jni_internal.dart';

import 'entity.dart';

/// The Java class name for DartBridge.
const _dartBridge = 'com/redstone/DartBridge';

/// Billboard mode for Flutter displays.
///
/// Determines how the display rotates relative to the camera.
enum BillboardMode {
  /// No automatic rotation - display maintains fixed orientation.
  fixed(0),

  /// Rotate around the vertical (Y) axis to face the camera.
  ///
  /// The display will always face the camera horizontally but maintain
  /// its vertical pitch angle.
  vertical(1),

  /// Rotate around the horizontal axis to face the camera.
  ///
  /// Less commonly used - maintains yaw but adjusts pitch.
  horizontal(2),

  /// Full billboard - always face the camera completely.
  ///
  /// The display will rotate both horizontally and vertically to
  /// always directly face the camera.
  center(3);

  final int value;
  const BillboardMode(this.value);

  static BillboardMode fromValue(int value) {
    return BillboardMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => BillboardMode.fixed,
    );
  }
}

/// A display entity that renders Flutter UI content in the world.
///
/// Flutter displays appear as floating rectangles that can show Flutter
/// widget content. They support billboard modes for automatic camera-facing
/// and can be positioned anywhere in the world.
///
/// Note: Multi-surface support (different content per display) is planned.
/// Currently all displays share the main Flutter surface.
class FlutterDisplay {
  /// The Minecraft entity ID for this display.
  final int entityId;

  /// The Flutter surface ID this display renders.
  ///
  /// Currently always 0 (main surface). Multi-surface support coming soon.
  final int surfaceId;

  FlutterDisplay._internal(this.entityId, this.surfaceId);

  /// Spawn a new Flutter display entity.
  ///
  /// [position] - World position to spawn the display
  /// [width] - Width in world units (blocks), default 1.0
  /// [height] - Height in world units (blocks), default 1.0
  /// [mode] - Billboard mode for camera-facing behavior
  /// [yaw] - Initial yaw rotation (horizontal), only used with fixed mode
  /// [pitch] - Initial pitch rotation (vertical), only used with fixed mode
  /// [world] - Optional world to spawn in (default: overworld)
  ///
  /// Returns the spawned FlutterDisplay, or null if spawn failed.
  static FlutterDisplay? spawn({
    required Vec3 position,
    double width = 1.0,
    double height = 1.0,
    BillboardMode mode = BillboardMode.fixed,
    double yaw = 0.0,
    double pitch = 0.0,
    World? world,
  }) {
    final targetWorld = world ?? World.overworld;

    // Spawn the Flutter display entity via JNI
    final entityId = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'spawnFlutterDisplay',
      '(Ljava/lang/String;DDDFFIFF)I',
      [
        targetWorld.dimensionId,
        position.x,
        position.y,
        position.z,
        yaw,
        pitch,
        mode.value,
        width,
        height,
      ],
    );

    if (entityId < 0) {
      return null;
    }

    // Surface ID 0 = main Flutter surface
    return FlutterDisplay._internal(entityId, 0);
  }

  /// Get the display's current position.
  Vec3 get position {
    final x = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityX',
      '(I)D',
      [entityId],
    );
    final y = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityY',
      '(I)D',
      [entityId],
    );
    final z = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityZ',
      '(I)D',
      [entityId],
    );
    return Vec3(x, y, z);
  }

  /// Set the display's position.
  set position(Vec3 pos) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setEntityPosition',
      '(IDDD)V',
      [entityId, pos.x, pos.y, pos.z],
    );
  }

  /// Get the display width in world units.
  double get width {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getFlutterDisplayWidth',
      '(I)D',
      [entityId],
    );
  }

  /// Set the display width in world units.
  set width(double value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setFlutterDisplayWidth',
      '(IF)V',
      [entityId, value],
    );
  }

  /// Get the display height in world units.
  double get height {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getFlutterDisplayHeight',
      '(I)D',
      [entityId],
    );
  }

  /// Set the display height in world units.
  set height(double value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setFlutterDisplayHeight',
      '(IF)V',
      [entityId, value],
    );
  }

  /// Get the display's billboard mode.
  BillboardMode get billboardMode {
    final value = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getFlutterDisplayBillboardMode',
      '(I)I',
      [entityId],
    );
    return BillboardMode.fromValue(value);
  }

  /// Set the display's billboard mode.
  set billboardMode(BillboardMode mode) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setFlutterDisplayBillboardMode',
      '(II)V',
      [entityId, mode.value],
    );
  }

  /// Get the display's yaw rotation (horizontal angle).
  double get yaw {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityYaw',
      '(I)D',
      [entityId],
    );
  }

  /// Get the display's pitch rotation (vertical angle).
  double get pitch {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityPitch',
      '(I)D',
      [entityId],
    );
  }

  /// Set the display's rotation.
  void setRotation(double yaw, double pitch) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setEntityRotation',
      '(IFF)V',
      [entityId, yaw, pitch],
    );
  }

  /// Remove the display from the world.
  void dispose() {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'discardEntity',
      '(I)V',
      [entityId],
    );
  }

  /// Convert this to a generic Entity for use with the entity API.
  Entity toEntity() => Entity(entityId);

  @override
  String toString() =>
      'FlutterDisplay($entityId, ${width}x$height, surface=$surfaceId)';

  @override
  bool operator ==(Object other) =>
      other is FlutterDisplay && entityId == other.entityId;

  @override
  int get hashCode => entityId.hashCode;
}
