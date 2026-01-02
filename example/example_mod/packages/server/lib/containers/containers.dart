// Barrel export file for all containers
export 'test_chest_container.dart';

import 'package:dart_mod_server/dart_mod_server.dart';

import '../blocks/test_chest_block.dart';
import 'test_chest_container.dart';

/// Registers all custom container types.
/// Must be called before blocks that use these containers.
void registerContainers() {
  // Initialize the container registry
  ContainerRegistry.init();

  // Register the test chest container type
  ContainerRegistry.registerSimple<TestChestContainer>(
    id: TestChestBlock.containerId,
    title: 'Test Chest',
    rows: 3,
    columns: 9,
    factory: (menuId) => TestChestContainer(menuId),
  );
}
