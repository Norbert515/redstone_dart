import 'dart:ui';

import 'package:flutter/scheduler.dart';

/// Registry that collects slot positions and batches updates to native bridge.
class SlotPositionRegistry {
  final int menuId;
  final Map<int, Rect> _positions = {};
  final void Function(int menuId, Map<int, Rect> positions) _onPositionsChanged;
  bool _dirty = false;
  bool _scheduled = false;

  SlotPositionRegistry({
    required this.menuId,
    required void Function(int menuId, Map<int, Rect> positions)
        onPositionsChanged,
  }) : _onPositionsChanged = onPositionsChanged;

  /// Report a slot's position. Called by SlotReporter after layout.
  void reportSlot(int slotIndex, Rect position) {
    final existing = _positions[slotIndex];
    if (existing == null || existing != position) {
      _positions[slotIndex] = position;
      _dirty = true;
      _scheduleUpdate();
    }
  }

  /// Remove a slot from tracking (when widget is disposed).
  void removeSlot(int slotIndex) {
    if (_positions.remove(slotIndex) != null) {
      _dirty = true;
      _scheduleUpdate();
    }
  }

  void _scheduleUpdate() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_dirty) {
        _dirty = false;
        _onPositionsChanged(menuId, Map.unmodifiable(_positions));
      }
    });
  }

  /// Get all current slot positions.
  Map<int, Rect> get positions => Map.unmodifiable(_positions);

  /// Clear all tracked positions.
  void clear() {
    _positions.clear();
    _dirty = true;
    _scheduleUpdate();
  }
}
