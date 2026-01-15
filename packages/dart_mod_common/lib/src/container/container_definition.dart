/// Base class for defining container types with synchronized data.
library;

import '../block_entity/synced_value.dart';

/// Interface for reading container data slot values.
///
/// This abstraction allows [ContainerDefinition] to initialize its synced
/// values from any data source (client cache, server state, etc.) without
/// depending on platform-specific code.
///
/// Implementations:
/// - Client: [ClientContainerView] reads from Java-side cache via JNI
/// - Server: Block entity reads directly from its own state
abstract interface class ContainerDataSource {
  /// Get the value at the given data slot index.
  ///
  /// Returns 0 if the index is out of range or no data is available.
  int getDataSlot(int index);
}

/// Base class for container definitions.
///
/// A container definition describes the structure of a menu/container,
/// including its inventory slots and synchronized data values.
///
/// Subclass this to define custom container types for block entities
/// like furnaces, crafting tables, or custom machines.
///
/// Example:
/// ```dart
/// class SimpleFurnaceContainer extends ContainerDefinition {
///   @override
///   String get id => 'example_mod:simple_furnace';
///
///   @override
///   int get slotCount => 3;
///
///   final burnProgress = SyncedInt();
///   final maxBurnTime = SyncedInt();
///   final cookProgress = SyncedInt();
///   final maxCookTime = SyncedInt();
///
///   SimpleFurnaceContainer() {
///     syncedValues([burnProgress, maxBurnTime, cookProgress, maxCookTime]);
///   }
/// }
/// ```
abstract class ContainerDefinition {
  /// The unique identifier for this container type.
  ///
  /// Should be in the format 'modid:container_name'.
  String get id;

  /// The number of inventory slots in this container.
  int get slotCount;

  /// All registered synced values for this container.
  final List<SyncedInt> _syncedValues = [];

  /// Get all registered synced values.
  List<SyncedInt> get syncedValuesList => List.unmodifiable(_syncedValues);

  /// The number of data slots (synced values) in this container.
  int get dataSlotCount => _syncedValues.length;

  /// Register synced values and auto-assign their data slot indices.
  ///
  /// Call this in your constructor after declaring all [SyncedInt] fields.
  /// The indices are assigned in order starting from 0.
  ///
  /// Example:
  /// ```dart
  /// SimpleFurnaceContainer() {
  ///   syncedValues([burnProgress, maxBurnTime, cookProgress, maxCookTime]);
  /// }
  /// ```
  void syncedValues(List<SyncedInt> values) {
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      value.dataSlotIndex = i;
      _syncedValues.add(value);
    }
  }

  /// Get the value at the given data slot index.
  ///
  /// Used by the Java bridge to read ContainerData values.
  int getDataSlot(int index) {
    if (index < 0 || index >= _syncedValues.length) {
      throw RangeError.index(index, _syncedValues, 'index', null, dataSlotCount);
    }
    return _syncedValues[index].toContainerData();
  }

  /// Set the value at the given data slot index.
  ///
  /// Used by the Java bridge to write ContainerData values (client sync).
  void setDataSlot(int index, int value) {
    if (index < 0 || index >= _syncedValues.length) {
      throw RangeError.index(index, _syncedValues, 'index', null, dataSlotCount);
    }
    _syncedValues[index].updateFromSync(value);
  }

  /// Initialize all synced values from a data source.
  ///
  /// This method solves a critical race condition: when a container opens,
  /// the server sends initial ContainerData values before the Flutter widget
  /// tree is built. By calling this method with the current cached values,
  /// we ensure the container starts with the correct state.
  ///
  /// This is called automatically by [ContainerScope] on the client side.
  /// You typically don't need to call this manually.
  ///
  /// Example:
  /// ```dart
  /// // ContainerScope does this internally:
  /// container.initializeFromCache(ClientContainerView());
  /// ```
  void initializeFromCache(ContainerDataSource source) {
    for (final syncedValue in _syncedValues) {
      final cachedValue = source.getDataSlot(syncedValue.dataSlotIndex);
      if (cachedValue != syncedValue.value) {
        syncedValue.updateFromSync(cachedValue);
      }
    }
  }
}
