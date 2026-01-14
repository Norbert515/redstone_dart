import 'package:flutter/widgets.dart';

/// Registry for mapping routes to widget builders for multi-surface rendering.
///
/// Mod developers register widgets with routes:
/// ```dart
/// SurfaceRouter.register('clock', () => ClockWidget());
/// SurfaceRouter.register('health', () => HealthBarWidget());
/// ```
///
/// Routes can also include query parameters:
/// ```dart
/// // Register with parameter support
/// SurfaceRouter.registerWithParams('multiscreen', (params) {
///   return MultiBlockScreen(grid: params['grid'] ?? '');
/// });
///
/// // When spawned with 'multiscreen?grid=111,101,111', the params map
/// // will contain {'grid': '111,101,111'}
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
///   SurfaceRouter.register('clock', () => ClockWidget());
///   SurfaceRouter.register('health', () => HealthBarWidget());
/// }
/// ```
class SurfaceRouter {
  static final Map<String, Widget Function()> _routes = {};
  static final Map<String, Widget Function(Map<String, String>)>
      _paramRoutes = {};

  /// Register a widget builder for a route (no parameters).
  ///
  /// Example:
  /// ```dart
  /// SurfaceRouter.register('clock', () => ClockWidget());
  /// ```
  static void register(String route, Widget Function() builder) {
    _routes[route] = builder;
    print('[SurfaceRouter] Registered route: $route');
  }

  /// Register a widget builder that receives query parameters.
  ///
  /// Example:
  /// ```dart
  /// SurfaceRouter.registerWithParams('multiscreen', (params) {
  ///   return MultiBlockScreen(grid: params['grid'] ?? '');
  /// });
  /// ```
  ///
  /// When the route 'multiscreen?grid=111,101,111' is requested,
  /// the params map will contain {'grid': '111,101,111'}.
  static void registerWithParams(
    String route,
    Widget Function(Map<String, String> params) builder,
  ) {
    _paramRoutes[route] = builder;
    print('[SurfaceRouter] Registered parameterized route: $route');
  }

  /// Unregister a route.
  static void unregister(String route) {
    _routes.remove(route);
    _paramRoutes.remove(route);
  }

  /// Get the widget for a route, or null if not registered.
  ///
  /// Supports query parameters: 'myroute?key=value&other=data'
  static Widget? getWidget(String route) {
    // Parse route and query parameters
    final uri = Uri.tryParse('scheme://host/$route');
    final basePath = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : route.split('?').first;
    final params = uri?.queryParameters ?? {};

    print('[SurfaceRouter] getWidget: route=$route, basePath=$basePath, params=$params');

    // Try parameterized route first
    final paramBuilder = _paramRoutes[basePath];
    if (paramBuilder != null) {
      return paramBuilder(params);
    }

    // Try simple route
    final builder = _routes[basePath];
    if (builder != null) {
      return builder();
    }

    // Also try exact match (backwards compatibility)
    final exactBuilder = _routes[route];
    if (exactBuilder != null) {
      return exactBuilder();
    }

    return null;
  }

  /// Check if a route is registered.
  static bool hasRoute(String route) {
    final basePath = route.split('?').first;
    return _routes.containsKey(route) ||
        _routes.containsKey(basePath) ||
        _paramRoutes.containsKey(basePath);
  }

  /// Get all registered routes.
  static List<String> get routes =>
      [..._routes.keys, ..._paramRoutes.keys].toList();

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
