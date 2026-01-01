import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'slot_position_registry.dart';
import 'slot_position_scope.dart';

/// A widget that reports its position to the SlotPositionRegistry.
///
/// Wrap McSlot (or any slot widget) with this to enable position tracking.
/// When used outside a SlotPositionScope, this widget is a no-op passthrough.
class SlotReporter extends SingleChildRenderObjectWidget {
  /// The slot index in the container menu.
  final int slotIndex;

  const SlotReporter({
    super.key,
    required this.slotIndex,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    final registry = SlotPositionScope.maybeOf(context);
    print('[SlotReporter] createRenderObject slot=$slotIndex, registry=${registry != null ? "found" : "null"}');
    return RenderSlotReporter(
      slotIndex: slotIndex,
      registry: registry,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSlotReporter renderObject) {
    renderObject
      ..slotIndex = slotIndex
      ..registry = SlotPositionScope.maybeOf(context);
  }
}

/// RenderObject that tracks its position and reports to the registry.
class RenderSlotReporter extends RenderProxyBox {
  int _slotIndex;
  SlotPositionRegistry? _registry;
  Offset? _lastPosition;
  Size? _lastSize;

  RenderSlotReporter({
    required int slotIndex,
    SlotPositionRegistry? registry,
  })  : _slotIndex = slotIndex,
        _registry = registry;

  int get slotIndex => _slotIndex;
  set slotIndex(int value) {
    if (_slotIndex != value) {
      // Remove old slot from registry
      _registry?.removeSlot(_slotIndex);
      _slotIndex = value;
      // Force re-report with new index
      _lastPosition = null;
      _lastSize = null;
      markNeedsLayout();
    }
  }

  SlotPositionRegistry? get registry => _registry;
  set registry(SlotPositionRegistry? value) {
    if (_registry != value) {
      // Remove from old registry
      _registry?.removeSlot(_slotIndex);
      _registry = value;
      // Force re-report to new registry
      _lastPosition = null;
      _lastSize = null;
      if (hasSize) {
        _reportPosition();
      }
    }
  }

  @override
  void performLayout() {
    super.performLayout();
    _reportPosition();
  }

  void _reportPosition() {
    if (_registry == null) return;

    // Get global position
    if (!attached) return;

    try {
      final position = localToGlobal(Offset.zero);
      final currentSize = size;

      // Only report if position or size changed
      if (position != _lastPosition || currentSize != _lastSize) {
        _lastPosition = position;
        _lastSize = currentSize;
        _registry!.reportSlot(
          _slotIndex,
          Rect.fromLTWH(
              position.dx, position.dy, currentSize.width, currentSize.height),
        );
      }
    } catch (e) {
      // Ignore errors during position calculation (e.g., not yet attached)
    }
  }

  @override
  void dispose() {
    _registry?.removeSlot(_slotIndex);
    super.dispose();
  }
}
