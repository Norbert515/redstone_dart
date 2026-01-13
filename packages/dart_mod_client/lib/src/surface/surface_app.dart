import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'surface_router.dart';

/// A minimal Flutter app that renders a single widget based on the route.
///
/// This is used as the entry point for spawned Flutter engines (multi-surface).
/// Each spawned engine runs this app with a `--route=` argument specifying
/// which widget to render.
///
/// **IMPORTANT:** Mods must define their own `surfaceMain` entry point that:
/// 1. Accepts `List<String> args` parameter (receives route via dart_entrypoint_argv)
/// 2. Registers routes (calling the same registration function as main())
/// 3. Parses route from args and runs SurfaceApp
///
/// Example:
/// ```dart
/// // In your mod's client/lib/main.dart:
///
/// void main() {
///   registerSurfaceWidgets();  // Register routes in main engine
///   runApp(MyApp());
/// }
///
/// @pragma('vm:entry-point')
/// void surfaceMain(List<String> args) {
///   registerSurfaceWidgets();  // Register routes in spawned engine too!
///   final route = SurfaceRouter.parseRouteFromArgs(args);
///   runApp(SurfaceApp(route: route));
/// }
///
/// void registerSurfaceWidgets() {
///   SurfaceRouter.register('/clock', () => ClockWidget());
///   SurfaceRouter.register('/health', () => HealthBarWidget());
/// }
/// ```
class SurfaceApp extends StatelessWidget {
  /// The route for this surface (parsed from command line args).
  final String? route;

  const SurfaceApp({super.key, this.route});

  /// Create a SurfaceApp by parsing route from Platform.executableArguments.
  factory SurfaceApp.fromArgs() {
    final route =
        SurfaceRouter.parseRouteFromArgs(Platform.executableArguments);
    print('[SurfaceApp] fromArgs: route=$route, args=${Platform.executableArguments}');
    return SurfaceApp(route: route);
  }

  @override
  Widget build(BuildContext context) {
    print('[SurfaceApp] build: route=$route, registered routes=${SurfaceRouter.routes}');
    final widget = route != null ? SurfaceRouter.getWidget(route!) : null;
    print('[SurfaceApp] widget for route: ${widget != null ? 'found' : 'NOT found'}');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
      home: widget ?? _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.red.withValues(alpha: 0.8),
      child: Center(
        child: Text(
          route != null ? 'Unknown route: $route' : 'No route specified',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

// NOTE: The default surfaceMain is intentionally removed.
// Each mod must define their own surfaceMain that registers routes before
// running SurfaceApp. See the class documentation above for an example.
