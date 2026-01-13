import 'package:flutter/widgets.dart';

/// Registry for mapping routes to widget builders for multi-surface rendering.
///
/// Mod developers register widgets with routes:
/// ```dart
/// SurfaceRouter.register('/clock', () => ClockWidget());
/// SurfaceRouter.register('/health', () => HealthBarWidget());
/// ```
///
/// When a FlutterDisplayEntity is spawned with that route, the corresponding
/// widget is rendered on that surface.
///
/// **Important for multi-surface rendering:**
/// Spawned Flutter engines run in **completely separate Dart isolates** and
/// don't share any state (including static variables) with the main engine.
///
/// To make routes available in spawned engines, you MUST define your own
/// `surfaceMain` entry point that registers routes before running SurfaceApp:
///
/// ```dart
/// void main() {
///   registerSurfaceWidgets();  // Register routes in main engine
///   runApp(MyApp());
/// }
///
/// @pragma('vm:entry-point')
/// void surfaceMain(List<String> args) {
///   registerSurfaceWidgets();  // MUST register in spawned engine too!
///   final route = SurfaceRouter.parseRouteFromArgs(args);
///   runApp(SurfaceApp(route: route));
/// }
///
/// void registerSurfaceWidgets() {
///   SurfaceRouter.register('/clock', () => ClockWidget());
///   SurfaceRouter.register('/health', () => HealthBarWidget());
/// }
/// ```
class SurfaceRouter {
  static final Map<String, Widget Function()> _routes = {};

  /// Register a widget builder for a route.
  ///
  /// Example:
  /// ```dart
  /// SurfaceRouter.register('/widgets/clock', () => ClockWidget());
  /// ```
  static void register(String route, Widget Function() builder) {
    _routes[route] = builder;
    print('[SurfaceRouter] Registered route: $route');
  }

  /// Unregister a route.
  static void unregister(String route) {
    _routes.remove(route);
  }

  /// Get the widget for a route, or null if not registered.
  static Widget? getWidget(String route) {
    final builder = _routes[route];
    if (builder != null) {
      return builder();
    }
    return null;
  }

  /// Check if a route is registered.
  static bool hasRoute(String route) {
    return _routes.containsKey(route);
  }

  /// Get all registered routes.
  static List<String> get routes => _routes.keys.toList();

  /// Parse the route from command line arguments.
  ///
  /// Looks for `--route=/path` argument.
  /// Returns null if not found.
  static String? parseRouteFromArgs(List<String> args) {
    for (final arg in args) {
      if (arg.startsWith('--route=')) {
        return arg.substring('--route='.length);
      }
    }
    return null;
  }
}
