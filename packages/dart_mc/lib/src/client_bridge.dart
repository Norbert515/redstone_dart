/// Client-side bridge for visual testing and client operations.
///
/// This file provides JNI bindings to DartBridgeClient.java for client-only
/// operations like taking screenshots, positioning the camera, etc.
///
/// Note: Client tick and ready events use a polling approach via
/// [isClientReady] called from server tick events. This avoids the
/// complexity of additional FFI callback bindings.
library;

import 'jni/generic_bridge.dart';

/// Client-side bridge for Minecraft client operations.
///
/// Provides methods for visual testing such as taking screenshots
/// and positioning the camera. Only available when running in client mode.
///
/// For client readiness detection, use [isClientReady] to poll from
/// server tick events (in singleplayer, the integrated server runs
/// alongside the client).
class ClientBridge {
  ClientBridge._();

  static const String _className = 'com/redstone/DartBridgeClient';

  /// Take a screenshot and save it with the specified filename.
  ///
  /// [name] - The filename (without extension) for the screenshot.
  /// Returns the absolute path to the saved screenshot file, or null on failure.
  ///
  /// Example:
  /// ```dart
  /// final path = ClientBridge.takeScreenshot('entity_test');
  /// print('Screenshot saved to: $path');
  /// ```
  static String? takeScreenshot(String name) {
    return GenericJniBridge.callStaticStringMethod(
      _className,
      'takeScreenshot',
      '(Ljava/lang/String;)Ljava/lang/String;',
      [name],
    );
  }

  /// Position the camera (player) at the specified coordinates with rotation.
  ///
  /// [x], [y], [z] - The coordinates to position at.
  /// [yaw] - Horizontal rotation (0 = south, 90 = west, 180 = north, -90 = east).
  /// [pitch] - Vertical rotation (-90 = up, 0 = horizon, 90 = down).
  ///
  /// Example:
  /// ```dart
  /// ClientBridge.positionCamera(100, 70, 200, yaw: 45, pitch: -30);
  /// ```
  static void positionCamera(
    double x,
    double y,
    double z, {
    double yaw = 0,
    double pitch = 0,
  }) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'positionCamera',
      '(DDDFF)V',
      [x, y, z, yaw, pitch],
    );
  }

  /// Look at a specific position from the current player position.
  ///
  /// Calculates the appropriate yaw and pitch to look at the target.
  ///
  /// Example:
  /// ```dart
  /// ClientBridge.lookAt(100, 65, 200);
  /// ```
  static void lookAt(double x, double y, double z) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'lookAt',
      '(DDD)V',
      [x, y, z],
    );
  }

  /// Check if the client is ready (has a player and world).
  static bool isClientReady() {
    return GenericJniBridge.callStaticBoolMethod(
      _className,
      'isClientReady',
      '()Z',
    );
  }

  /// Get the current client tick.
  static int getClientTick() {
    return GenericJniBridge.callStaticLongMethod(
      _className,
      'getClientTick',
      '()J',
    );
  }

  /// Get the window width.
  static int getWindowWidth() {
    return GenericJniBridge.callStaticIntMethod(
      _className,
      'getWindowWidth',
      '()I',
    );
  }

  /// Get the window height.
  static int getWindowHeight() {
    return GenericJniBridge.callStaticIntMethod(
      _className,
      'getWindowHeight',
      '()I',
    );
  }

  /// Get the screenshots directory path.
  static String? getScreenshotsDirectory() {
    return GenericJniBridge.callStaticStringMethod(
      _className,
      'getScreenshotsDirectory',
      '()Ljava/lang/String;',
    );
  }

  /// Enable or disable visual test mode.
  ///
  /// When enabled, the client will automatically join a test world on startup
  /// (or create one if it doesn't exist). This is used for visual/client testing.
  ///
  /// [enabled] - Whether to enable visual test mode.
  static void setVisualTestMode(bool enabled) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'setVisualTestMode',
      '(Z)V',
      [enabled],
    );
  }

  /// Check if visual test mode is enabled.
  static bool isVisualTestMode() {
    return GenericJniBridge.callStaticBoolMethod(
      _className,
      'isVisualTestMode',
      '()Z',
    );
  }
}
