// Barrel export file for all block entities
export 'example_furnace.dart';

import 'package:dart_mod_server/dart_mod_server.dart';

import 'example_furnace.dart';

/// Registers all custom block entity types.
///
/// Must be called BEFORE [registerBlocks] since the block entity type
/// must be registered before the associated block.
void registerBlockEntities() {
  // Register the example furnace block entity type
  BlockEntityRegistry.registerTypeFromFactory(() => ExampleFurnace());
}
