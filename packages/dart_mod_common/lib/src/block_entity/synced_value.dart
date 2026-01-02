/// Synced value types for block entities.
///
/// These values automatically sync to clients via ContainerData.
library;

/// A synchronized integer value that syncs to clients via ContainerData.
///
/// The [dataIndex] maps to the ContainerData slot index.
/// For furnace-like block entities:
/// - 0: litTime (current burn time remaining)
/// - 1: litDuration (total burn time of current fuel)
/// - 2: cookingProgress (current cooking progress)
/// - 3: cookingTotalTime (total cooking time for recipe)
class SyncedInt {
  /// The ContainerData slot index for this value.
  final int dataIndex;
  int _value;

  /// Creates a synced integer with the given data index and optional initial value.
  SyncedInt(this.dataIndex, [this._value = 0]);

  /// The current value.
  int get value => _value;

  /// Set the value (marks block entity as needing sync).
  set value(int v) => _value = v;

  /// Called by Java via native bridge to get current value for ContainerData.
  int toContainerData() => _value;

  /// Called by Java via native bridge to set value from ContainerData.
  void fromContainerData(int v) => _value = v;

  @override
  String toString() => 'SyncedInt(index: $dataIndex, value: $_value)';
}
