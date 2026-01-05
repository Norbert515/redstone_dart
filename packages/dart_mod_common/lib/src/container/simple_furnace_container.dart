/// Container definition for a simple furnace block.
library;

import '../block_entity/synced_value.dart';
import 'container_definition.dart';

/// Container definition for a simple furnace block.
///
/// This defines the structure of the furnace menu with 3 slots
/// (input, fuel, output) and 4 synced values for client UI updates.
///
/// Used by both server (SimpleFurnaceEntity) and client (SimpleFurnaceScreen).
class SimpleFurnaceContainer extends ContainerDefinition {
  @override
  String get id => 'example_mod:simple_furnace';

  @override
  int get slotCount => 3; // input, fuel, output

  // Slot indices
  static const int inputSlot = 0;
  static const int fuelSlot = 1;
  static const int outputSlot = 2;

  // Synced data (matching vanilla furnace pattern)
  /// Current burn time remaining (ticks).
  final SyncedInt litTime = SyncedInt();

  /// Total burn time of current fuel (ticks).
  final SyncedInt litDuration = SyncedInt();

  /// Current cooking progress (ticks).
  final SyncedInt cookingProgress = SyncedInt();

  /// Total cooking time for the current recipe (ticks).
  final SyncedInt cookingTotalTime = SyncedInt();

  SimpleFurnaceContainer() {
    syncedValues([litTime, litDuration, cookingProgress, cookingTotalTime]);
  }

  /// Is the furnace currently burning fuel?
  bool get isLit => litTime.value > 0;

  /// Burn progress as 0.0-1.0 (for UI fire animation).
  double get burnProgress =>
      litDuration.value > 0 ? litTime.value / litDuration.value : 0.0;

  /// Cook progress as 0.0-1.0 (for UI arrow animation).
  double get cookProgress => cookingTotalTime.value > 0
      ? cookingProgress.value / cookingTotalTime.value
      : 0.0;
}
