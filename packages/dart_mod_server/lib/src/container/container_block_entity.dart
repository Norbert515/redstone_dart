/// Generic container-based block entity for custom menus.
library;

import 'package:dart_mod_common/dart_mod_common.dart';

/// A generic block entity that uses a [ContainerDefinition] for its data.
///
/// This provides a cleaner way to define container-style block entities
/// by separating the container structure (slots, synced data) from the
/// block entity logic (ticking, processing).
///
/// ## Example
///
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
///
///   SimpleFurnaceContainer() {
///     syncedValues([burnProgress, maxBurnTime]);
///   }
/// }
///
/// class SimpleFurnaceEntity extends ContainerBlockEntity<SimpleFurnaceContainer> {
///   SimpleFurnaceEntity() : super(container: SimpleFurnaceContainer());
///
///   @override
///   void serverTick() {
///     if (container.burnProgress.value > 0) {
///       container.burnProgress.value--;
///     }
///   }
/// }
/// ```
abstract class ContainerBlockEntity<T extends ContainerDefinition>
    extends BlockEntityWithInventory {
  /// The container definition managing slots and synced data.
  final T container;

  /// Creates a container block entity with the given container definition.
  ///
  /// The inventory slot count is derived from [ContainerDefinition.slotCount].
  ContainerBlockEntity({
    required this.container,
  }) : super(
          settings: BlockEntitySettings(id: container.id),
          slotCount: container.slotCount,
        );

  /// Called every server tick (20 times per second).
  ///
  /// Override to implement processing logic using [container]'s synced values.
  @override
  void serverTick();

  // ============ Data Slot Access (for Java bridge) ============

  /// Get a ContainerData slot value by index.
  ///
  /// Delegates to the container's [ContainerDefinition.getDataSlot].
  /// Used by the Java bridge to sync data to clients.
  int getDataSlot(int index) {
    return container.getDataSlot(index);
  }

  /// Set a ContainerData slot value by index.
  ///
  /// Delegates to the container's [ContainerDefinition.setDataSlot].
  /// Used by the Java bridge when receiving data from clients.
  void setDataSlot(int index, int value) {
    container.setDataSlot(index, value);
  }

  /// The number of data slots in this container.
  int get dataSlotCount => container.dataSlotCount;

  // ============ Save/Load ============

  @override
  Map<String, dynamic> onSave() {
    final base = super.onSave();
    // Save synced values by their indices
    for (final syncedValue in container.syncedValuesList) {
      base['data_${syncedValue.dataSlotIndex}'] = syncedValue.value;
    }
    return base;
  }

  @override
  void onLoad(Map<String, dynamic> nbt) {
    super.onLoad(nbt);
    // Load synced values by their indices
    for (final syncedValue in container.syncedValuesList) {
      final key = 'data_${syncedValue.dataSlotIndex}';
      if (nbt.containsKey(key)) {
        syncedValue.updateFromSync(nbt[key] as int);
      }
    }
  }
}
