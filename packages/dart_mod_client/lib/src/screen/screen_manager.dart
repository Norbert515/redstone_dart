/// Manager for opening and closing custom screens.
library;

import 'package:dart_mod_common/src/jni/jni_internal.dart';

/// Manager for opening and closing custom screens.
///
/// Screens can be opened from either server-side or client-side code.
/// When opened from server, a packet is sent to client which triggers
/// the screen open event.
///
/// Example:
/// ```dart
/// // Open a custom screen
/// ScreenManager.open('mymod:settings');
///
/// // Close the current screen
/// ScreenManager.close();
/// ```
class ScreenManager {
  /// Open a custom screen by type.
  ///
  /// This is typically called from server-side code via a network packet,
  /// but can also be used from client-side code for client-only screens.
  ///
  /// [screenType] is the screen type identifier (e.g., 'mymod:settings').
  static void open(String screenType) {
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridgeClient',
      'openCustomScreen',
      '(Ljava/lang/String;)V',
      [screenType],
    );
  }

  /// Close the current custom screen.
  ///
  /// This signals Java to close the FlutterCustomScreen and return
  /// to normal gameplay.
  static void close() {
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridgeClient',
      'closeCustomScreen',
      '()V',
      [],
    );
  }
}
