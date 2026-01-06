/// Synced value types for block entities.
///
/// These values automatically sync to clients via ContainerData.
library;

/// A synchronized value that syncs to clients via ContainerData.
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
class SyncedValue<T> {
  /// The ContainerData slot index for this value.
  /// This is assigned automatically by [ContainerDefinition.syncedValues].
  int dataSlotIndex;

  T _value;
  final List<void Function()> _listeners = [];

  /// Creates a synced value with an initial value.
  ///
  /// The [dataSlotIndex] will be assigned by [ContainerDefinition.syncedValues].
  SyncedValue(this._value) : dataSlotIndex = -1;

  /// Creates a synced value with a specific data slot index.
  ///
  /// Use this when manually managing slot indices outside of [ContainerDefinition].
  SyncedValue.withIndex(this.dataSlotIndex, this._value);

  /// The current value.
  T get value => _value;

  /// Set the value and notify listeners.
  ///
  /// On the server side, this writes to ContainerData for syncing to clients.
  set value(T v) {
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
  void updateFromSync(T v) {
    if (_value != v) {
      _value = v;
      _notifyListeners();
    }
  }

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
  String toString() => 'SyncedValue<$T>(index: $dataSlotIndex, value: $_value)';
}

/// A synchronized integer value that syncs to clients via ContainerData.
///
/// This is the most common synced value type, used for furnace progress,
/// burn time, and other numeric container data.
///
/// Provides additional methods for ContainerData interop.
class SyncedInt extends SyncedValue<int> {
  /// Creates a synced integer with an optional initial value.
  ///
  /// The [dataSlotIndex] will be assigned by [ContainerDefinition.syncedValues].
  SyncedInt([super.value = 0]);

  /// Creates a synced integer with a specific data slot index.
  ///
  /// Use this when manually managing slot indices outside of [ContainerDefinition].
  SyncedInt.withIndex(super.dataSlotIndex, [super.value = 0]) : super.withIndex();

  /// Called by Java via native bridge to get current value for ContainerData.
  int toContainerData() => _value;

  /// Called by Java via native bridge to set value from ContainerData.
  void fromContainerData(int v) => updateFromSync(v);

  @override
  String toString() => 'SyncedInt(index: $dataSlotIndex, value: $_value)';
}
