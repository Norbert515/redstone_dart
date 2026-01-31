/// Base class for custom screens (non-container fullscreen UIs).
library;

import 'package:flutter/widgets.dart';

import 'screen_manager.dart';

/// Base class for custom screens (non-container fullscreen UIs).
///
/// Mod developers extend this to create custom screens like:
/// - Settings menus
/// - Tutorial screens
/// - Custom crafting UIs (without container slots)
///
/// Example:
/// ```dart
/// class SettingsScreen extends CustomScreen {
///   const SettingsScreen({super.key});
///
///   @override
///   String get screenId => 'mymod:settings';
///
///   @override
///   State<SettingsScreen> createState() => _SettingsScreenState();
/// }
///
/// class _SettingsScreenState extends State<SettingsScreen>
///     with CustomScreenStateMixin<SettingsScreen> {
///   @override
///   Widget build(BuildContext context) {
///     return Center(
///       child: ElevatedButton(
///         onPressed: close,
///         child: Text('Close'),
///       ),
///     );
///   }
/// }
/// ```
abstract class CustomScreen extends StatefulWidget {
  const CustomScreen({super.key});

  /// Unique identifier for this screen type.
  String get screenId;

  /// Called when the screen is about to close.
  /// Override to perform cleanup or validation.
  /// Return false to prevent closing.
  bool onClosing() => true;
}

/// State mixin for CustomScreen implementations.
/// Provides access to screen lifecycle methods.
mixin CustomScreenStateMixin<T extends CustomScreen> on State<T> {
  /// Request to close this screen.
  void close() {
    if (widget.onClosing()) {
      ScreenManager.close();
    }
  }
}
