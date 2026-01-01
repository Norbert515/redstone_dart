/// Settings classes for block entities.
library;

/// Base settings for block entities.
class BlockEntitySettings {
  /// The unique identifier for this block entity type (e.g., 'mymod:my_furnace').
  final String id;

  const BlockEntitySettings({required this.id});
}

/// Slot configuration for container-style block entities.
class SlotConfig {
  /// The slot index for input items.
  final int inputSlot;

  /// The slot index for fuel items.
  final int fuelSlot;

  /// The slot index for output items.
  final int outputSlot;

  /// The total number of slots in the container.
  final int totalSlots;

  const SlotConfig({
    required this.inputSlot,
    required this.fuelSlot,
    required this.outputSlot,
    required this.totalSlots,
  });

  /// Standard furnace slot configuration:
  /// - Slot 0: Input
  /// - Slot 1: Fuel
  /// - Slot 2: Output
  const SlotConfig.furnace()
      : inputSlot = 0,
        fuelSlot = 1,
        outputSlot = 2,
        totalSlots = 3;

  /// Custom configuration with only input and output (no fuel slot).
  const SlotConfig.simple({
    this.inputSlot = 0,
    this.outputSlot = 1,
    this.totalSlots = 2,
  }) : fuelSlot = -1;
}

/// Settings for processing block entities (furnace-like).
class ProcessingSettings extends BlockEntitySettings {
  /// Block hardness for mining.
  final double hardness;

  /// Time in ticks to process one item (200 = 10 seconds).
  final int processTime;

  /// Slot configuration for this block entity.
  final SlotConfig slots;

  const ProcessingSettings({
    required super.id,
    this.hardness = 3.5,
    this.processTime = 200,
    this.slots = const SlotConfig.furnace(),
  });
}
