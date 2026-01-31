/// A route definition for a custom screen.
library;

import 'package:flutter/widgets.dart';

/// A route definition for custom screens.
///
/// Routes map screen type identifiers to Flutter screen builders. When a
/// custom screen is opened, the [ScreenRouter] finds the matching route and builds
/// the screen.
///
/// Example:
/// ```dart
/// ScreenRouter(
///   routes: [
///     ScreenRoute(
///       screenType: 'mymod:settings',
///       builder: (context) => SettingsScreen(),
///     ),
///     ScreenRoute(
///       screenType: 'mymod:tutorial',
///       builder: (context) => TutorialScreen(),
///     ),
///   ],
///   background: Container(color: Colors.transparent),
/// )
/// ```
class ScreenRoute {
  /// The screen type identifier (e.g., 'mymod:settings').
  final String screenType;

  /// Builder for the screen widget.
  final Widget Function(BuildContext context) builder;

  /// Creates a screen route definition.
  ///
  /// [screenType] is the unique identifier for this screen type, typically
  /// in the format 'modid:screen_name'.
  ///
  /// [builder] creates the screen widget when this route matches.
  const ScreenRoute({
    required this.screenType,
    required this.builder,
  });

  /// Check if this route matches the given screen type.
  bool matches(String type) => screenType == type;

  @override
  String toString() => 'ScreenRoute(screenType: $screenType)';
}
