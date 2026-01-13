/// Client-side bridge for visual testing and client operations.
///
/// This file provides JNI bindings to DartBridgeClient.java for client-only
/// operations like taking screenshots, positioning the camera, etc.
///
/// Note: Client tick and ready events use a polling approach via
/// [isClientReady] called from server tick events. This avoids the
/// complexity of additional FFI callback bindings.
library;

import 'package:dart_mod_common/src/jni/jni_internal.dart';

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

  // ==========================================================================
  // Input Simulation Methods (for testing)
  // ==========================================================================

  /// Simulate a key press (down then up).
  ///
  /// [keyCode] - GLFW key code (see GlfwKeys constants).
  static void pressKey(int keyCode) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'pressKey',
      '(I)V',
      [keyCode],
    );
  }

  /// Hold a key down. Call [releaseKey] to release.
  ///
  /// [keyCode] - GLFW key code (see GlfwKeys constants).
  static void holdKey(int keyCode) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'holdKey',
      '(I)V',
      [keyCode],
    );
  }

  /// Release a held key.
  ///
  /// [keyCode] - GLFW key code (see GlfwKeys constants).
  static void releaseKey(int keyCode) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'releaseKey',
      '(I)V',
      [keyCode],
    );
  }

  /// Type a single character (for text input).
  ///
  /// [codePoint] - Unicode code point of the character.
  static void typeChar(int codePoint) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'typeChar',
      '(I)V',
      [codePoint],
    );
  }

  /// Type a string of characters.
  ///
  /// [text] - The text to type.
  static void typeChars(String text) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'typeChars',
      '(Ljava/lang/String;)V',
      [text],
    );
  }

  /// Click a mouse button (press and release).
  ///
  /// [button] - Mouse button (0=left, 1=right, 2=middle).
  static void clickMouse(int button) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'clickMouse',
      '(I)V',
      [button],
    );
  }

  /// Hold a mouse button down.
  ///
  /// [button] - Mouse button (0=left, 1=right, 2=middle).
  static void holdMouse(int button) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'holdMouse',
      '(I)V',
      [button],
    );
  }

  /// Release a held mouse button.
  ///
  /// [button] - Mouse button (0=left, 1=right, 2=middle).
  static void releaseMouse(int button) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'releaseMouse',
      '(I)V',
      [button],
    );
  }

  /// Set cursor position (GUI coordinates).
  ///
  /// [x], [y] - Position in GUI pixels.
  static void setCursorPos(double x, double y) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'setCursorPos',
      '(DD)V',
      [x, y],
    );
  }

  /// Scroll the mouse wheel.
  ///
  /// [horizontal] - Horizontal scroll amount.
  /// [vertical] - Vertical scroll amount.
  static void scroll(double horizontal, double vertical) {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'scroll',
      '(DD)V',
      [horizontal, vertical],
    );
  }

  /// Release all held inputs (cleanup for tests).
  static void releaseAllInputs() {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'releaseAllInputs',
      '()V',
    );
  }

  /// Ensure a clean UI state for testing - close any open screens.
  ///
  /// This method closes any open GUI screens (inventory, menus, etc.)
  /// and any open container menus. Call this before running tests to
  /// ensure a consistent starting state.
  static void ensureCleanUIState() {
    GenericJniBridge.callStaticVoidMethod(
      _className,
      'ensureCleanUIState',
      '()V',
    );
  }

  // ==========================================================================
  // Local Player State Methods (for testing)
  // ==========================================================================

  /// Check if LocalPlayer exists on the client.
  static bool hasLocalPlayer() {
    return GenericJniBridge.callStaticBoolMethod(
      _className,
      'hasLocalPlayer',
      '()Z',
    );
  }

  /// Get LocalPlayer's X coordinate.
  static double getLocalPlayerX() {
    return GenericJniBridge.callStaticDoubleMethod(
      _className,
      'getLocalPlayerX',
      '()D',
    );
  }

  /// Get LocalPlayer's Y coordinate.
  static double getLocalPlayerY() {
    return GenericJniBridge.callStaticDoubleMethod(
      _className,
      'getLocalPlayerY',
      '()D',
    );
  }

  /// Get LocalPlayer's Z coordinate.
  static double getLocalPlayerZ() {
    return GenericJniBridge.callStaticDoubleMethod(
      _className,
      'getLocalPlayerZ',
      '()D',
    );
  }

  /// Check if LocalPlayer is sneaking (shift key down).
  static bool isLocalPlayerSneaking() {
    return GenericJniBridge.callStaticBoolMethod(
      _className,
      'isLocalPlayerSneaking',
      '()Z',
    );
  }

  /// Check if LocalPlayer is sprinting.
  static bool isLocalPlayerSprinting() {
    return GenericJniBridge.callStaticBoolMethod(
      _className,
      'isLocalPlayerSprinting',
      '()Z',
    );
  }

  /// Get debug information about LocalPlayer's current input state.
  static String getLocalPlayerInputDebug() {
    return GenericJniBridge.callStaticStringMethod(
      _className,
      'getLocalPlayerInputDebug',
      '()Ljava/lang/String;',
    ) ?? 'JNI call failed';
  }
}
