import 'package:dart_mod_server/dart_mod_server.dart';

/// Example furnace block with a block entity for processing items.
///
/// This block uses the ProcessingBlockEntity system to provide furnace-like
/// behavior. When right-clicked, it opens a furnace GUI with input, fuel,
/// and output slots.
///
/// The block entity handles:
/// - Fuel burning and burn time tracking
/// - Recipe processing (smelting ores, cooking food)
/// - ContainerData sync to client for progress display
class ExampleFurnaceBlock extends CustomBlock {
  ExampleFurnaceBlock()
      : super(
          id: 'example_mod:example_furnace',
          settings: BlockSettings(
            hardness: 3.5,
            resistance: 3.5,
            requiresTool: true,
          ),
          model: BlockModel.cubeAll(
            texture: 'assets/textures/block/example_furnace.png',
          ),
        );

  // Note: The block entity handles opening the container automatically.
  // When DartBlockWithEntity's useWithoutItem is called, it opens the
  // MenuProvider (DartProcessingBlockEntity) for the player.
}
