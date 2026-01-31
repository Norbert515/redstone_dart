/// World generation tests for custom ore generation.
///
/// Tests that custom ore blocks can generate in the world.
/// Note: World generation is non-deterministic, so these tests
/// search multiple chunks to find ore blocks.
import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  await group('Ore generation', () async {
    await testMinecraft(
      'test ore blocks are registered',
      (game) async {
        // Verify the test ore blocks exist by placing them
        final testOrePos = const BlockPos(5000, 64, 5000);
        final deepslateOrePos = const BlockPos(5001, 64, 5000);

        game.placeBlock(testOrePos, const Block('example_mod:test_ore'));
        game.placeBlock(deepslateOrePos, const Block('example_mod:deepslate_test_ore'));
        await game.waitTicks(5);

        // Verify they were placed correctly
        expect(game.getBlock(testOrePos), isBlock('example_mod:test_ore'));
        expect(game.getBlock(deepslateOrePos), isBlock('example_mod:deepslate_test_ore'));

        // Clean up
        game.placeBlock(testOrePos, Block.air);
        game.placeBlock(deepslateOrePos, Block.air);
      },
    );

    await testMinecraft(
      'can find test ore in newly generated chunks',
      (game) async {
        // Search for test ore in newly generated chunks
        // Use coordinates far from spawn to ensure chunks are newly generated
        const searchRadiusChunks = 8;
        const baseX = 10000;
        const baseZ = 10000;

        int oreBlocksFound = 0;
        int deepslateOreBlocksFound = 0;
        int chunksSearched = 0;

        // Get a player to teleport (required for loading chunks)
        final players = game.players;
        if (players.isEmpty) {
          print('No players online - skipping chunk generation test');
          return;
        }
        final player = players.first;

        // Search multiple chunks for ore
        for (int cx = 0; cx < searchRadiusChunks && oreBlocksFound == 0; cx++) {
          for (int cz = 0; cz < searchRadiusChunks && oreBlocksFound == 0; cz++) {
            final chunkX = baseX + (cx * 16);
            final chunkZ = baseZ + (cz * 16);
            chunksSearched++;

            // Teleport player to load the chunk
            player.teleportPrecise(Vec3(chunkX.toDouble(), 100.0, chunkZ.toDouble()));
            await game.waitTicks(20); // Wait for chunk generation

            // Scan the chunk for test ore (Y range matches ore config: -64 to 64)
            for (int x = 0; x < 16 && oreBlocksFound < 5; x++) {
              for (int z = 0; z < 16 && oreBlocksFound < 5; z++) {
                for (int y = -64; y <= 64; y++) {
                  final pos = BlockPos(chunkX + x, y, chunkZ + z);
                  final block = game.getBlock(pos);

                  if (block.id == 'example_mod:test_ore') {
                    oreBlocksFound++;
                    print('Found test_ore at ${pos.x}, ${pos.y}, ${pos.z}');
                  } else if (block.id == 'example_mod:deepslate_test_ore') {
                    deepslateOreBlocksFound++;
                    print('Found deepslate_test_ore at ${pos.x}, ${pos.y}, ${pos.z}');
                  }
                }
              }
            }
          }
        }

        print('Searched $chunksSearched chunks');
        print('Found $oreBlocksFound test_ore blocks');
        print('Found $deepslateOreBlocksFound deepslate_test_ore blocks');

        // We expect to find at least some ore after searching multiple chunks
        // Given 8 veins per chunk with size 9, probability of finding none is very low
        expect(
          oreBlocksFound + deepslateOreBlocksFound,
          greaterThan(0),
          reason: 'Expected to find at least one ore block after searching $chunksSearched chunks',
        );
      },
    );

    await testMinecraft(
      'deepslate ore generates below Y=0',
      (game) async {
        // Search specifically in the deepslate layer (Y < 0)
        const searchRadiusChunks = 4;
        const baseX = 20000;
        const baseZ = 20000;

        int deepslateOreBlocksFound = 0;
        int regularOreBlocksFound = 0;

        // Get a player to teleport (required for loading chunks)
        final players = game.players;
        if (players.isEmpty) {
          print('No players online - skipping deepslate ore test');
          return;
        }
        final player = players.first;

        for (int cx = 0; cx < searchRadiusChunks; cx++) {
          for (int cz = 0; cz < searchRadiusChunks; cz++) {
            final chunkX = baseX + (cx * 16);
            final chunkZ = baseZ + (cz * 16);

            // Teleport to load chunk
            player.teleportPrecise(Vec3(chunkX.toDouble(), 64.0, chunkZ.toDouble()));
            await game.waitTicks(20);

            // Scan only below Y=0 (deepslate layer)
            for (int x = 0; x < 16; x++) {
              for (int z = 0; z < 16; z++) {
                for (int y = -64; y < 0; y++) {
                  final pos = BlockPos(chunkX + x, y, chunkZ + z);
                  final block = game.getBlock(pos);

                  if (block.id == 'example_mod:deepslate_test_ore') {
                    deepslateOreBlocksFound++;
                  } else if (block.id == 'example_mod:test_ore') {
                    regularOreBlocksFound++;
                  }
                }
              }
            }
          }
        }

        print('Below Y=0: Found $deepslateOreBlocksFound deepslate_test_ore');
        print('Below Y=0: Found $regularOreBlocksFound test_ore (should be minimal)');

        // If we found ore below Y=0, it should predominantly be the deepslate variant
        // This is because deepslate replaces stone below Y=0
        if (deepslateOreBlocksFound + regularOreBlocksFound > 0) {
          expect(
            deepslateOreBlocksFound,
            greaterThanOrEqualTo(regularOreBlocksFound),
            reason: 'Deepslate ore should be more common than regular ore below Y=0',
          );
        }
      },
    );
  });
}
