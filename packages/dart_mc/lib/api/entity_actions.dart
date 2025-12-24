/// Provides movement and navigation actions for entities.
///
/// Used primarily in custom goals to control entity behavior.
library;

import '../src/jni/generic_bridge.dart';

/// The Java class name for DartBridge.
const _dartBridge = 'com/redstone/DartBridge';

/// Provides movement and navigation actions for entities.
///
/// Used primarily in custom goals to control entity behavior.
class EntityActions {
  EntityActions._(); // Prevent instantiation

  /// Move the entity towards a position.
  ///
  /// [entityId] - The entity to move
  /// [x], [y], [z] - Target position
  /// [speed] - Movement speed multiplier (default 1.0)
  static void moveTo(
    int entityId,
    double x,
    double y,
    double z, {
    double speed = 1.0,
  }) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'entityMoveTo',
      '(IDDDD)V',
      [entityId, x, y, z, speed],
    );
  }

  /// Make the entity look at a position.
  ///
  /// [entityId] - The entity
  /// [x], [y], [z] - Position to look at
  static void lookAt(int entityId, double x, double y, double z) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'entityLookAt',
      '(IDDD)V',
      [entityId, x, y, z],
    );
  }

  /// Make the entity look at another entity.
  ///
  /// [entityId] - The entity
  /// [targetId] - Entity to look at
  static void lookAtEntity(int entityId, int targetId) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'entityLookAtEntity',
      '(II)V',
      [entityId, targetId],
    );
  }

  /// Stop the entity's current movement.
  static void stopMoving(int entityId) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'entityStopMoving',
      '(I)V',
      [entityId],
    );
  }

  /// Get the distance between two entities.
  ///
  /// Returns the distance in blocks, or -1 if either entity doesn't exist.
  static double distanceTo(int entityId, int targetId) {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'entityDistanceTo',
      '(II)D',
      [entityId, targetId],
    );
  }

  /// Get the distance from an entity to a position.
  static double distanceToPos(int entityId, double x, double y, double z) {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'entityDistanceToPos',
      '(IDDD)D',
      [entityId, x, y, z],
    );
  }

  /// Check if there's a player within radius of the entity.
  static bool hasNearbyPlayer(int entityId, {double radius = 16.0}) {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'entityHasNearbyPlayer',
      '(ID)Z',
      [entityId, radius],
    );
  }

  /// Get the nearest player's entity ID, or -1 if none nearby.
  static int getNearestPlayerId(int entityId, {double radius = 16.0}) {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'entityGetNearestPlayer',
      '(ID)I',
      [entityId, radius],
    );
  }

  /// Get the entity's current target (from targetSelector), or -1 if none.
  static int getTarget(int entityId) {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'entityGetTarget',
      '(I)I',
      [entityId],
    );
  }

  /// Set the entity's target.
  static void setTarget(int entityId, int targetId) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'entitySetTarget',
      '(II)V',
      [entityId, targetId],
    );
  }

  /// Get the entity's current position as [x, y, z].
  static List<double> getPosition(int entityId) {
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
    return [x, y, z];
  }

  /// Check if the entity can see another entity (line of sight).
  static bool canSee(int entityId, int targetId) {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'entityCanSee',
      '(II)Z',
      [entityId, targetId],
    );
  }

  /// Make the entity jump.
  static void jump(int entityId) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'entityJump',
      '(I)V',
      [entityId],
    );
  }

  /// Set the entity's movement speed modifier.
  static void setSpeed(int entityId, double speed) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'entitySetSpeed',
      '(ID)V',
      [entityId, speed],
    );
  }
}
