/// Synced value types for block entities.
///
/// These values automatically sync to clients via ContainerData.
library;

/// A synchronized integer value that syncs to clients via ContainerData.
///
/// Implements a [ValueNotifier]-like pattern for reactive updates.
/// Can be used with Flutter's [ValueListenableBuilder] for UI binding.
///
/// The [dataSlotIndex] maps to the ContainerData slot index, which is
/// auto-assigned by [ContainerDefinition.syncedValues].
///
/// For furnace-like block entities:
/// - 0: litTime (current burn time remaining)
/// - 1: litDuration (total burn time of current fuel)
/// - 2: cookingProgress (current cooking progress)
/// - 3: cookingTotalTime (total cooking time for recipe)
class SyncedInt {
  /// The ContainerData slot index for this value.
  /// This is assigned automatically by [ContainerDefinition.syncedValues].
  int dataSlotIndex;

  int _value;
  final List<void Function()> _listeners = [];

  /// Creates a synced integer with an optional initial value.
  ///
  /// The [dataSlotIndex] will be assigned by [ContainerDefinition.syncedValues].
  SyncedInt([this._value = 0]) : dataSlotIndex = -1;

  /// Creates a synced integer with a specific data slot index.
  ///
  /// Use this when manually managing slot indices outside of [ContainerDefinition].
  SyncedInt.withIndex(this.dataSlotIndex, [this._value = 0]);

  /// The current value.
  int get value => _value;

  /// Set the value and notify listeners.
  ///
  /// On the server side, this writes to ContainerData for syncing to clients.
  set value(int v) {
    if (_value != v) {
      _value = v;
      _notifyListeners();
    }
  }

  /// Update the value from a sync without triggering server-side write.
  ///
  /// Use this on the client side when receiving updates from the server.
  /// This updates the local value and notifies listeners for UI updates,
  /// but does not mark the value as needing to sync back to the server.
  void updateFromSync(int v) {
    if (_value != v) {
      _value = v;
      _notifyListeners();
    }
  }

  /// Called by Java via native bridge to get current value for ContainerData.
  int toContainerData() => _value;

  /// Called by Java via native bridge to set value from ContainerData.
  void fromContainerData(int v) => updateFromSync(v);

  /// Add a listener that will be called when the value changes.
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// Remove a previously added listener.
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of a value change.
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Whether this value has any listeners.
  bool get hasListeners => _listeners.isNotEmpty;

  @override
  String toString() => 'SyncedInt(index: $dataSlotIndex, value: $_value)';
}
