/// Custom block model E2E tests.
///
/// Tests for BlockModel.elements() functionality - verifying that blocks
/// defined with programmatic elements can be placed and retrieved.
import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  const testBasePos = BlockPos(1000, 64, 1000);

  await group('Custom block models (BlockModel.elements)', () async {
    await testMinecraft('can place block with custom elements model',
        (game) async {
      final pos = BlockPos(testBasePos.x + 100, testBasePos.y, testBasePos.z);

      // Clear the position first
      game.placeBlock(pos, Block.air);
      await game.waitTicks(1);

      // Place the custom elements block (pedestal)
      game.placeBlock(pos, const Block('framework_tests:pedestal'));
      await game.waitTicks(1);

      // Verify it was placed correctly
      expect(game.getBlock(pos), isBlock('framework_tests:pedestal'));
    });

    await testMinecraft('can retrieve custom elements block type', (game) async {
      final pos = BlockPos(testBasePos.x + 101, testBasePos.y, testBasePos.z);

      // Place the pedestal
      game.placeBlock(pos, const Block('framework_tests:pedestal'));
      await game.waitTicks(1);

      // Verify block type matches
      final block = game.getBlock(pos);
      expect(block.id, equals('framework_tests:pedestal'));
    });

    await testMinecraft('can replace custom elements block', (game) async {
      final pos = BlockPos(testBasePos.x + 102, testBasePos.y, testBasePos.z);

      // Place the pedestal
      game.placeBlock(pos, const Block('framework_tests:pedestal'));
      await game.waitTicks(1);
      expect(game.getBlock(pos), isBlock('framework_tests:pedestal'));

      // Replace with stone
      game.placeBlock(pos, Block.stone);
      await game.waitTicks(1);
      expect(game.getBlock(pos), isBlock(Block.stone));

      // Replace back to pedestal
      game.placeBlock(pos, const Block('framework_tests:pedestal'));
      await game.waitTicks(1);
      expect(game.getBlock(pos), isBlock('framework_tests:pedestal'));
    });

    await testMinecraft('can clear custom elements block to air', (game) async {
      final pos = BlockPos(testBasePos.x + 103, testBasePos.y, testBasePos.z);

      // Place the pedestal
      game.placeBlock(pos, const Block('framework_tests:pedestal'));
      await game.waitTicks(1);
      expect(game.getBlock(pos), isBlock('framework_tests:pedestal'));

      // Clear to air
      game.placeBlock(pos, Block.air);
      await game.waitTicks(1);
      expect(game.getBlock(pos), isAirBlock);
    });

    await testMinecraft('custom elements block is not air', (game) async {
      final pos = BlockPos(testBasePos.x + 104, testBasePos.y, testBasePos.z);

      // Place the pedestal
      game.placeBlock(pos, const Block('framework_tests:pedestal'));
      await game.waitTicks(1);

      // Verify it's not air
      expect(game.isAir(pos), isFalse);
      expect(game.getBlock(pos), isNotAirBlock);
    });

    await testMinecraft('fillBlocks works with custom elements block',
        (game) async {
      final from =
          BlockPos(testBasePos.x + 110, testBasePos.y, testBasePos.z + 10);
      final to =
          BlockPos(testBasePos.x + 112, testBasePos.y + 2, testBasePos.z + 12);

      // Fill a 3x3x3 region with pedestals
      game.fillBlocks(from, to, const Block('framework_tests:pedestal'));
      await game.waitTicks(5);

      // Check corners
      expect(game.getBlock(from), isBlock('framework_tests:pedestal'));
      expect(game.getBlock(to), isBlock('framework_tests:pedestal'));

      // Check a middle block
      final middle = BlockPos(
        testBasePos.x + 111,
        testBasePos.y + 1,
        testBasePos.z + 11,
      );
      expect(game.getBlock(middle), isBlock('framework_tests:pedestal'));
    });
  });
}
