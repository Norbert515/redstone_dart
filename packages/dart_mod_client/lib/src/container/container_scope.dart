/// ContainerScope - InheritedWidget for providing containers to descendant widgets.
///
/// Provides automatic rebuild when container data changes via push-based events.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:dart_mod_common/dart_mod_common.dart';

import '../events/container_data_events.dart';
import '../inventory/client_container_view.dart';

/// Provides a container to descendant widgets with automatic rebuild on data changes.
///
/// Usage:
/// ```dart
/// // In your screen builder:
/// ContainerScope<MyContainer>(
///   container: container,
///   menuId: menuId,
///   child: MyContainerScreen(),
/// )
///
/// // In descendant widgets:
/// final container = ContainerScope.of<MyContainer>(context);
/// return Text('Value: ${container.someValue.value}');
/// ```
///
/// Widgets that call `ContainerScope.of()` will automatically rebuild when
/// any SyncedValue in the container changes.
class ContainerScope<T extends ContainerDefinition> extends StatefulWidget {
  /// The container definition providing synced values.
  final T container;

  /// The menu ID for filtering data change events.
  final int menuId;

  /// The child widget tree that can access the container.
  final Widget child;

  const ContainerScope({
    super.key,
    required this.container,
    required this.menuId,
    required this.child,
  });

  /// Get the container from the nearest ContainerScope ancestor.
  ///
  /// The calling widget will rebuild when container data changes.
  static T of<T extends ContainerDefinition>(BuildContext context) {
    // First try exact type match
    var scope =
        context.dependOnInheritedWidgetOfExactType<_ContainerScopeInherited<T>>();

    // If not found, try base ContainerDefinition type and cast
    // This handles the case where GuiRouter creates ContainerScope<ContainerDefinition>
    // but the screen requests a specific subtype
    if (scope == null) {
      final baseScope = context
          .dependOnInheritedWidgetOfExactType<_ContainerScopeInherited<ContainerDefinition>>();
      if (baseScope != null && baseScope.container is T) {
        return baseScope.container as T;
      }
    }

    if (scope == null) {
      throw FlutterError(
        'ContainerScope.of<$T>() called without a ContainerScope<$T> ancestor.\n'
        'Make sure your screen is wrapped in a ContainerScope.',
      );
    }
    return scope.container;
  }

  /// Get the container without registering as a dependent (no auto-rebuild).
  ///
  /// Use this when you need the container but don't want to rebuild when data changes.
  static T read<T extends ContainerDefinition>(BuildContext context) {
    // First try exact type match
    var scope =
        context.getInheritedWidgetOfExactType<_ContainerScopeInherited<T>>();

    // If not found, try base ContainerDefinition type and cast
    if (scope == null) {
      final baseScope = context
          .getInheritedWidgetOfExactType<_ContainerScopeInherited<ContainerDefinition>>();
      if (baseScope != null && baseScope.container is T) {
        return baseScope.container as T;
      }
    }

    if (scope == null) {
      throw FlutterError(
        'ContainerScope.read<$T>() called without a ContainerScope<$T> ancestor.',
      );
    }
    return scope.container;
  }

  /// Try to get the container, returning null if not found.
  ///
  /// Useful when the container may not be available.
  static T? maybeOf<T extends ContainerDefinition>(BuildContext context) {
    // First try exact type match
    var scope =
        context.dependOnInheritedWidgetOfExactType<_ContainerScopeInherited<T>>();
    if (scope != null) {
      return scope.container;
    }

    // If not found, try base ContainerDefinition type and cast
    final baseScope = context
        .dependOnInheritedWidgetOfExactType<_ContainerScopeInherited<ContainerDefinition>>();
    if (baseScope != null && baseScope.container is T) {
      return baseScope.container as T;
    }

    return null;
  }

  @override
  State<ContainerScope<T>> createState() => _ContainerScopeState<T>();
}

class _ContainerScopeState<T extends ContainerDefinition>
    extends State<ContainerScope<T>> {
  StreamSubscription<ContainerDataChangedEvent>? _subscription;
  int _updateCount = 0;
  static const _containerView = ClientContainerView();

  @override
  void initState() {
    super.initState();
    _loadInitialValues();
    _subscribeToDataChanges();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Load initial values from Java via JNI polling.
  /// This ensures we have correct values immediately on container open,
  /// even for values that don't change frequently (like litDuration).
  void _loadInitialValues() {
    print('[ContainerScope] _loadInitialValues: menuId=${widget.menuId}, container=${widget.container.runtimeType}');
    final syncedValues = widget.container.syncedValuesList;
    print('[ContainerScope] Found ${syncedValues.length} synced values');
    for (final syncedValue in syncedValues) {
      if (syncedValue.dataSlotIndex >= 0) {
        final value = _containerView.getContainerDataSlot(syncedValue.dataSlotIndex);
        print('[ContainerScope] Initial load slot ${syncedValue.dataSlotIndex}: got value $value');
        syncedValue.updateFromSync(value);
      }
    }
  }

  void _subscribeToDataChanges() {
    print('[ContainerScope] _subscribeToDataChanges: subscribing for menuId=${widget.menuId}');
    _subscription = ContainerDataEvents.onDataChanged.listen((event) {
      print('[ContainerScope] onDataChanged: event.menuId=${event.menuId}, slotIndex=${event.slotIndex}, value=${event.value}, our menuId=${widget.menuId}');
      // Only handle events for our menu
      if (event.menuId != widget.menuId) return;

      // Find the SyncedValue with this slot index and update it
      final syncedValues = widget.container.syncedValuesList;
      for (final syncedValue in syncedValues) {
        if (syncedValue.dataSlotIndex == event.slotIndex) {
          print('[ContainerScope] Updating syncedValue at slot ${syncedValue.dataSlotIndex} from ${syncedValue.value} to ${event.value}');
          syncedValue.updateFromSync(event.value);
          // Trigger rebuild
          if (mounted) {
            setState(() {
              _updateCount++;
            });
          }
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ContainerScopeInherited<T>(
      container: widget.container,
      updateCount: _updateCount,
      child: widget.child,
    );
  }
}

class _ContainerScopeInherited<T extends ContainerDefinition>
    extends InheritedWidget {
  final T container;
  final int updateCount;

  const _ContainerScopeInherited({
    required this.container,
    required this.updateCount,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ContainerScopeInherited<T> oldWidget) {
    // Notify when update count changes (data was updated)
    return updateCount != oldWidget.updateCount;
  }
}
