import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:flutter/widgets.dart';

import 'slot_position_registry.dart';

/// InheritedWidget that provides SlotPositionRegistry to descendants.
///
/// Wrap your container screen with this to enable slot position tracking.
/// When not present, SlotReporter widgets work normally but don't report positions.
class SlotPositionScope extends StatefulWidget {
  /// The menu ID to associate with slot positions.
  final int menuId;

  /// The child widget tree containing SlotReporter widgets.
  final Widget child;

  const SlotPositionScope({
    super.key,
    required this.menuId,
    required this.child,
  });

  /// Get the registry from context, or null if not in a SlotPositionScope.
  static SlotPositionRegistry? of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_SlotPositionInherited>();
    return scope?.registry;
  }

  /// Get the registry without creating a dependency.
  static SlotPositionRegistry? maybeOf(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<_SlotPositionInherited>();
    return scope?.registry;
  }

  @override
  State<SlotPositionScope> createState() => _SlotPositionScopeState();
}

class _SlotPositionScopeState extends State<SlotPositionScope> {
  late SlotPositionRegistry _registry;

  @override
  void initState() {
    super.initState();
    _registry = SlotPositionRegistry(
      menuId: widget.menuId,
      onPositionsChanged: _onPositionsChanged,
    );
  }

  @override
  void didUpdateWidget(SlotPositionScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuId != widget.menuId) {
      // Menu ID changed, create new registry
      _registry.clear();
      _registry = SlotPositionRegistry(
        menuId: widget.menuId,
        onPositionsChanged: _onPositionsChanged,
      );
    }
  }

  void _onPositionsChanged(int menuId, Map<int, Rect> positions) {
    // Send positions to Java via JNI
    // Build comma-separated string: slotIndex,x,y,width,height,...
    print('[SlotPositionScope] _onPositionsChanged called: menuId=$menuId, positions=${positions.length}');

    if (positions.isEmpty) {
      GenericJniBridge.callStaticVoidMethod(
        'com/redstone/DartBridgeClient',
        'onSlotPositionsUpdateFromString',
        '(ILjava/lang/String;)V',
        [menuId, ''],
      );
      return;
    }

    final buffer = StringBuffer();
    var first = true;
    for (final entry in positions.entries) {
      if (!first) buffer.write(',');
      first = false;
      buffer.write(entry.key); // slotIndex
      buffer.write(',');
      buffer.write(entry.value.left.round()); // x
      buffer.write(',');
      buffer.write(entry.value.top.round()); // y
      buffer.write(',');
      buffer.write(entry.value.width.round()); // width
      buffer.write(',');
      buffer.write(entry.value.height.round()); // height
    }

    final dataStr = buffer.toString();
    print('[SlotPositionScope] Sending slot positions via JNI: ${dataStr.length} chars');

    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridgeClient',
      'onSlotPositionsUpdateFromString',
      '(ILjava/lang/String;)V',
      [menuId, dataStr],
    );
  }

  @override
  void dispose() {
    _registry.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SlotPositionInherited(
      registry: _registry,
      child: widget.child,
    );
  }
}

class _SlotPositionInherited extends InheritedWidget {
  final SlotPositionRegistry registry;

  const _SlotPositionInherited({
    required this.registry,
    required super.child,
  });

  @override
  bool updateShouldNotify(_SlotPositionInherited oldWidget) {
    return registry != oldWidget.registry;
  }
}
