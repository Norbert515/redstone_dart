/// A declarative router for custom (non-container) screens.
library;

import 'dart:async';

import 'package:dart_mod_common/src/jni/jni_internal.dart';
import 'package:flutter/widgets.dart';

import 'screen_events.dart';
import 'screen_route.dart';

/// Router for custom (non-container) screens.
///
/// Routes screen types to their corresponding Flutter screen widgets.
/// Handles screen open/close events and manages screen lifecycle.
///
/// The router uses [ScreenEvents] for event-driven screen detection.
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
class ScreenRouter extends StatefulWidget {
  /// List of screen routes mapping screen types to screen builders.
  final List<ScreenRoute> routes;

  /// Widget to show when no custom screen is open.
  ///
  /// If null, shows nothing (transparent/empty).
  final Widget? background;

  /// Creates a screen router.
  ///
  /// The [routes] list defines which screen types map to which screen builders.
  /// The [background] widget is shown when no custom screen is open.
  const ScreenRouter({
    super.key,
    required this.routes,
    this.background,
  });

  @override
  State<ScreenRouter> createState() => _ScreenRouterState();
}

class _ScreenRouterState extends State<ScreenRouter> {
  /// Current screen event, or null if no screen is open.
  ScreenOpenEvent? _currentScreen;

  /// Current matched route, or null if none matched.
  ScreenRoute? _currentRoute;

  /// Stream subscriptions for screen events.
  StreamSubscription<ScreenOpenEvent>? _openSubscription;
  StreamSubscription<ScreenCloseEvent>? _closeSubscription;

  @override
  void initState() {
    super.initState();
    _initializeEventListeners();
  }

  void _initializeEventListeners() {
    print('[ScreenRouter] _initializeEventListeners called');
    try {
      ScreenEvents.initialize();
      print('[ScreenRouter] ScreenEvents initialized successfully');

      _openSubscription = ScreenEvents.onOpen.listen(_onScreenOpen);
      _closeSubscription = ScreenEvents.onClose.listen(_onScreenClose);
    } catch (e) {
      print('[ScreenRouter] Event initialization failed: $e');
    }
  }

  void _onScreenOpen(ScreenOpenEvent event) {
    print('[ScreenRouter] Screen open: ${event.screenType}');

    final route = _findRoute(event.screenType);

    setState(() {
      _currentScreen = event;
      _currentRoute = route;
    });

    // Signal Java that screen is ready
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridgeClient',
      'signalScreenFrameReady',
      '()V',
      [],
    );
  }

  void _onScreenClose(ScreenCloseEvent event) {
    if (_currentScreen?.screenId == event.screenId) {
      setState(() {
        _currentScreen = null;
        _currentRoute = null;
      });
    }
  }

  ScreenRoute? _findRoute(String screenType) {
    for (final route in widget.routes) {
      if (route.matches(screenType)) {
        return route;
      }
    }
    return null;
  }

  @override
  void didUpdateWidget(ScreenRouter oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If routes changed and we have an active screen, re-find the route
    if (_currentScreen != null) {
      final newRoute = _findRoute(_currentScreen!.screenType);
      if (newRoute != _currentRoute) {
        setState(() {
          _currentRoute = newRoute;
        });
      }
    }
  }

  @override
  void dispose() {
    _openSubscription?.cancel();
    _closeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No screen open - show background
    if (_currentScreen == null || _currentRoute == null) {
      return widget.background ?? const SizedBox.shrink();
    }

    return _currentRoute!.builder(context);
  }
}
