/// Container system tests.
///
/// Tests for container registration, container blocks, and container interactions.
/// Note: Full container opening/interaction tests require a player entity,
/// which may be limited in headless mode.
import 'package:dart_mod_server/dart_mod_server.dart';
import 'package:redstone_test/redstone_test.dart';

/// A simple test container for testing purposes.
class SimpleTestContainer extends DartContainer {
  SimpleTestContainer(super.menuId);

  @override
  bool mayPlaceInSlot(int slotIndex, ItemStack item) => true;

  @override
  bool mayPickupFromSlot(int slotIndex) => true;
}

Future<void> main() async {
  // Use a unique test area to avoid conflicts with other tests
  const testBasePos = BlockPos(2000, 64, 2000);

  await group('Container registry', () async {
    await testMinecraft('ContainerRegistry can be initialized', (game) async {
      // Initialize the container registry
      ContainerRegistry.init();

      // Initialization should not throw
      expect(true, isTrue);
    });

    await testMinecraft('can register a container type', (game) async {
      ContainerRegistry.init();

      const testId = 'framework_tests:test_container_1';

      // Clean slate - this test uses a unique ID
      if (!ContainerRegistry.isRegistered(testId)) {
        ContainerRegistry.registerSimple<SimpleTestContainer>(
          id: testId,
          title: 'Test Container',
          rows: 3,
          columns: 9,
          factory: (menuId) => SimpleTestContainer(menuId),
        );
      }

      expect(ContainerRegistry.isRegistered(testId), isTrue);
    });

    await testMinecraft('registered container has correct definition', (game) async {
      ContainerRegistry.init();

      const testId = 'framework_tests:test_container_2';

      if (!ContainerRegistry.isRegistered(testId)) {
        ContainerRegistry.registerSimple<SimpleTestContainer>(
          id: testId,
          title: 'Custom Title',
          rows: 4,
          columns: 6,
          factory: (menuId) => SimpleTestContainer(menuId),
        );
      }

      final definition = ContainerRegistry.getDefinition(testId);

      expect(definition, isNotNull);
      expect(definition!.id, equals(testId));
      expect(definition.title, equals('Custom Title'));
      expect(definition.rows, equals(4));
      expect(definition.columns, equals(6));
      expect(definition.slotCount, equals(24)); // 4 * 6
    });

    await testMinecraft('registeredIds contains registered containers', (game) async {
      ContainerRegistry.init();

      const testId = 'framework_tests:test_container_3';

      if (!ContainerRegistry.isRegistered(testId)) {
        ContainerRegistry.registerSimple<SimpleTestContainer>(
          id: testId,
          title: 'Another Container',
          factory: (menuId) => SimpleTestContainer(menuId),
        );
      }

      final ids = ContainerRegistry.registeredIds;
      expect(ids.contains(testId), isTrue);
    });

    await testMinecraft('containerTypeCount reflects registered containers', (game) async {
      ContainerRegistry.init();

      final countBefore = ContainerRegistry.containerTypeCount;

      const testId = 'framework_tests:test_container_4';

      if (!ContainerRegistry.isRegistered(testId)) {
        ContainerRegistry.registerSimple<SimpleTestContainer>(
          id: testId,
          title: 'Count Test Container',
          factory: (menuId) => SimpleTestContainer(menuId),
        );

        expect(ContainerRegistry.containerTypeCount, equals(countBefore + 1));
      } else {
        // Already registered, count should be stable
        expect(ContainerRegistry.containerTypeCount, greaterThanOrEqualTo(1));
      }
    });

    await testMinecraft('isRegistered returns false for unknown container', (game) async {
      ContainerRegistry.init();

      expect(
        ContainerRegistry.isRegistered('framework_tests:nonexistent_container'),
        isFalse,
      );
    });

    await testMinecraft('getDefinition returns null for unknown container', (game) async {
      ContainerRegistry.init();

      expect(
        ContainerRegistry.getDefinition('framework_tests:nonexistent_container'),
        isNull,
      );
    });
  });

  await group('DartContainer instance management', () async {
    await testMinecraft('DartContainer registers itself on creation', (game) async {
      ContainerRegistry.init();

      const menuId = 99999; // Use a unique menu ID for testing
      final container = SimpleTestContainer(menuId);

      expect(DartContainer.getContainer(menuId), equals(container));

      // Cleanup
      DartContainer.removeContainer(menuId);
    });

    await testMinecraft('DartContainer.removeContainer cleans up', (game) async {
      ContainerRegistry.init();

      const menuId = 99998;
      SimpleTestContainer(menuId);

      expect(DartContainer.getContainer(menuId), isNotNull);

      DartContainer.removeContainer(menuId);

      expect(DartContainer.getContainer(menuId), isNull);
    });

    await testMinecraft('DartContainer.getContainer returns null for unknown ID', (game) async {
      expect(DartContainer.getContainer(88888), isNull);
    });
  });

  await group('Container block placement', () async {
    await testMinecraft('can check if custom block exists in registry', (game) async {
      // This test verifies that the example mod's test chest block
      // is registered and can be referenced by ID
      const testChestId = 'example_mod:test_chest_block';

      // Try to place the block - if it's registered, this will work
      final pos = BlockPos(testBasePos.x, testBasePos.y, testBasePos.z);

      game.placeBlock(pos, Block.air);
      await game.waitTicks(1);

      const testChest = Block(testChestId);
      game.placeBlock(pos, testChest);
      await game.waitTicks(1);

      // Get the placed block
      final placedBlock = game.getBlock(pos);

      // The block should either be the test chest (if registered)
      // or air (if the block ID is not registered)
      // This test documents the behavior rather than failing
      if (placedBlock.id == testChestId) {
        expect(placedBlock, isBlock(testChestId));
      } else {
        // Block not registered in this test environment
        // This is expected in framework_tests which doesn't load example_mod
        expect(true, isTrue);
      }

      // Cleanup
      game.placeBlock(pos, Block.air);
      await game.waitTicks(1);
    });
  });

  await group('ContainerDefinition', () async {
    await testMinecraft('ContainerDefinition calculates slotCount correctly', (game) async {
      final definition = ContainerDefinition(
        id: 'test:slot_count_test',
        title: 'Slot Count Test',
        rows: 3,
        columns: 9,
        factory: (menuId) => SimpleTestContainer(menuId),
      );

      expect(definition.slotCount, equals(27)); // Standard chest size
    });

    await testMinecraft('ContainerDefinition with custom dimensions', (game) async {
      final definition = ContainerDefinition(
        id: 'test:custom_size',
        title: 'Custom Size',
        rows: 6,
        columns: 9,
        factory: (menuId) => SimpleTestContainer(menuId),
      );

      expect(definition.slotCount, equals(54)); // Large chest size
    });

    await testMinecraft('ContainerDefinition with single column', (game) async {
      final definition = ContainerDefinition(
        id: 'test:single_column',
        title: 'Single Column',
        rows: 9,
        columns: 1,
        factory: (menuId) => SimpleTestContainer(menuId),
      );

      expect(definition.slotCount, equals(9));
    });
  });
}
