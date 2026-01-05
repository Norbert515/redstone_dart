/// Simple furnace block implementation.
library;

import 'package:dart_mod_common/dart_mod_common.dart';

import '../block_entity/block_entity_registry.dart';
import '../registries.dart' show BlockRegistry;
import 'simple_furnace_entity.dart';

/// A simple furnace block that demonstrates the Container API.
///
/// This block:
/// - Has a [SimpleFurnaceEntity] for server-side smelting logic
/// - Opens a Flutter-based container screen when right-clicked
/// - Syncs furnace state (burn progress, cook progress) to clients
///
/// ## Registration
///
/// ```dart
/// void registerBlocks() {
///   // Register the block entity first
///   BlockEntityRegistry.registerType(
///     SimpleFurnaceBlock.blockId,
///     SimpleFurnaceEntity.new,
///     inventorySize: 3,
///     containerTitle: 'Simple Furnace',
///   );
///
///   // Then register the block
///   BlockRegistry.register(SimpleFurnaceBlock());
/// }
/// ```
class SimpleFurnaceBlock extends CustomBlock {
  /// The block ID for the simple furnace.
  static const String blockId = 'example_mod:simple_furnace';

  /// Singleton instance.
  static final SimpleFurnaceBlock instance = SimpleFurnaceBlock._();

  SimpleFurnaceBlock._()
      : super(
          id: blockId,
          settings: const BlockSettings(
            hardness: 3.5,
            resistance: 3.5,
            requiresTool: true,
          ),
          model: BlockModel.cubeAll(
            texture: 'assets/textures/block/simple_furnace.png',
          ),
        );

  /// Creates a new SimpleFurnaceBlock instance.
  factory SimpleFurnaceBlock() => instance;

  /// Register the block and its block entity.
  ///
  /// Call this during mod initialization.
  static void register() {
    // Register the block entity type
    BlockEntityRegistry.registerType(
      blockId,
      SimpleFurnaceEntity.new,
      inventorySize: 3,
      containerTitle: 'Simple Furnace',
      ticks: true,
    );

    // Register the block
    BlockRegistry.register(instance);
  }

  // Note: The block entity handles opening the container automatically.
  // When DartBlockWithEntity's useWithoutItem is called, it opens the
  // MenuProvider (ProcessingBlockEntity) for the player.
}
