/// A declarative router for container GUI screens.
library;

import 'dart:async';

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:flutter/widgets.dart';

import '../events/container_events.dart';
import '../inventory/client_container_view.dart';
import 'container_info.dart';
import 'gui_route.dart';
import 'slot_definition.dart';
import 'slot_position_scope.dart';

/// A declarative router for container GUI screens.
///
/// Routes container types to their corresponding Flutter screen widgets.
/// Handles container open/close events and manages screen lifecycle.
///
/// The router uses [ContainerEvents] for event-driven container detection,
/// with a fallback to polling if events aren't available.
///
/// Example:
/// ```dart
/// GuiRouter(
///   routes: [
///     GuiRoute(
///       containerId: 'mymod:custom_chest',
///       builder: (context, info) => MyChestScreen(info: info),
///     ),
///     GuiRoute(
///       containerId: 'mymod:furnace',
///       builder: (context, info) => MyFurnaceScreen(info: info),
///       slots: [
///         SlotDefinition(index: 0, x: 56, y: 17),
///         SlotDefinition(index: 1, x: 56, y: 53),
///         SlotDefinition(index: 2, x: 116, y: 35),
///       ],
///     ),
///   ],
///   background: Container(color: Colors.transparent),
///   fallback: (context, info) => GenericContainerScreen(info: info),
/// )
/// ```
class GuiRouter extends StatefulWidget {
  /// List of GUI routes mapping container types to screen builders.
  final List<GuiRoute> routes;

  /// Widget to show when no container is open.
  ///
  /// If null, shows nothing (transparent/empty).
  final Widget? background;

  /// Builder for containers that don't match any route.
  ///
  /// If null, containers without a matching route will show nothing.
  final Widget Function(BuildContext context, ContainerInfo info)? fallback;

  /// Creates a GUI router.
  ///
  /// The [routes] list defines which containers map to which screen builders.
  /// The [background] widget is shown when no container is open.
  /// The [fallback] builder handles containers without a matching route.
  const GuiRouter({
    super.key,
    required this.routes,
    this.background,
    this.fallback,
  });

  @override
  State<GuiRouter> createState() => _GuiRouterState();
}

class _GuiRouterState extends State<GuiRouter> {
  /// Current container info, or null if no container is open.
  ContainerInfo? _currentContainer;

  /// Current matched route, or null if none matched.
  GuiRoute? _currentRoute;

  /// Stream subscriptions for container events.
  StreamSubscription<ContainerOpenEvent>? _openSubscription;
  StreamSubscription<int>? _closeSubscription;

  /// Timer for polling fallback (used when events aren't available).
  Timer? _pollTimer;

  /// Container view for checking state.
  final _containerView = const ClientContainerView();

  /// Last known menu ID (for detecting changes in polling mode).
  int _lastMenuId = -1;

  @override
  void initState() {
    super.initState();
    _initializeEventListeners();
  }

  void _initializeEventListeners() {
    // Try to use event-driven approach first
    try {
      ContainerEvents.initialize();

      _openSubscription = ContainerEvents.onOpen.listen(_onContainerOpen);
      _closeSubscription = ContainerEvents.onClose.listen(_onContainerClose);

      print('[GuiRouter] Using event-driven container detection');

      // Check if a container is already open (e.g., if we initialized late)
      _checkCurrentContainer();
    } catch (e) {
      // Fall back to polling if events aren't available
      print('[GuiRouter] Events not available, falling back to polling: $e');
      _startPolling();
    }
  }

  void _startPolling() {
    // Poll every 50ms for container changes (matches existing behavior)
    _pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _checkCurrentContainer();
    });
  }

  void _checkCurrentContainer() {
    final menuId = _containerView.menuId;

    if (menuId != _lastMenuId) {
      _lastMenuId = menuId;

      if (menuId >= 0) {
        // Container opened
        // Note: When using polling fallback, containerId and title are not available
        // The event-driven path via ContainerEvents provides these values
        _onContainerOpen(ContainerOpenEvent(menuId, _containerView.slotCount, '', ''));
      } else if (_currentContainer != null) {
        // Container closed
        _onContainerClose(_currentContainer!.menuId);
      }
    }
  }

  void _onContainerOpen(ContainerOpenEvent event) {
    print('[GuiRouter] Container opened: menuId=${event.menuId}, '
        'slotCount=${event.slotCount}, containerId=${event.containerId}, '
        'title=${event.title}');

    // Use containerId from event (passed from Java)
    final containerId = event.containerId;

    // Calculate rows/columns based on slot count
    // Standard containers have 9 columns
    final containerSlotCount = event.slotCount > 36
        ? event.slotCount - 36 // Subtract player inventory (36 slots)
        : event.slotCount;
    final columns = 9;
    final rows = (containerSlotCount / columns).ceil();

    final info = ContainerInfo(
      menuId: event.menuId,
      containerId: containerId,
      title: event.title,
      rows: rows,
      columns: columns,
    );

    // Find matching route (try containerId first, then title)
    final route = _findRoute(containerId, event.title);

    // Send pre-registered or cached slots if available
    final effectiveSlots = route?.effectiveSlots;
    if (effectiveSlots != null && effectiveSlots.isNotEmpty) {
      _sendPreRegisteredSlots(event.menuId, effectiveSlots);
    }

    setState(() {
      _currentContainer = info;
      _currentRoute = route;
    });
  }

  void _onContainerClose(int menuId) {
    print('[GuiRouter] Container closed: menuId=$menuId');

    if (_currentContainer?.menuId == menuId) {
      setState(() {
        _currentContainer = null;
        _currentRoute = null;
      });
    }
  }

  GuiRoute? _findRoute(String containerId, String title) {
    for (final route in widget.routes) {
      if (route.matches(containerId, title)) {
        return route;
      }
    }
    return null;
  }

  void _sendPreRegisteredSlots(int menuId, List<SlotDefinition> slots) {
    if (slots.isEmpty) return;

    // Build comma-separated string: slotIndex,x,y,width,height,...
    final buffer = StringBuffer();
    var first = true;
    for (final slot in slots) {
      if (!first) buffer.write(',');
      first = false;
      buffer.write(slot.index);
      buffer.write(',');
      buffer.write(slot.x.round());
      buffer.write(',');
      buffer.write(slot.y.round());
      buffer.write(',');
      buffer.write(slot.width.round());
      buffer.write(',');
      buffer.write(slot.height.round());
    }

    final dataStr = buffer.toString();

    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridgeClient',
      'onSlotPositionsUpdateFromString',
      '(ILjava/lang/String;)V',
      [menuId, dataStr],
    );
  }

  @override
  void didUpdateWidget(GuiRouter oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If routes changed and we have an active container, re-find the route
    if (_currentContainer != null) {
      final newRoute = _findRoute(_currentContainer!.containerId, _currentContainer!.title);
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
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No container open - show background
    if (_currentContainer == null) {
      return widget.background ?? const SizedBox.shrink();
    }

    final info = _currentContainer!;

    // Find the builder to use
    Widget Function(BuildContext, ContainerInfo)? builder;

    if (_currentRoute != null) {
      builder = _currentRoute!.builder;
    } else if (widget.fallback != null) {
      builder = widget.fallback!;
    }

    // No matching route and no fallback - show nothing
    if (builder == null) {
      return widget.background ?? const SizedBox.shrink();
    }

    // Wrap with SlotPositionScope to enable dynamic slot tracking
    // (for any slots not pre-registered)
    // Pass cacheKey if the route wants position caching
    final cacheKey = _currentRoute?.cacheSlotPositions == true
        ? _currentRoute!.routeKey
        : null;

    return SlotPositionScope(
      menuId: info.menuId,
      cacheKey: cacheKey,
      child: builder(context, info),
    );
  }
}
