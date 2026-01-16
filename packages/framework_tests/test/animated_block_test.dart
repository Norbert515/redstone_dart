/// Animated block E2E tests.
///
/// Tests for BlockAnimation functionality - verifying that blocks
/// with animations (spin, bob, combine) can be placed and retrieved.
import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  const testBasePos = BlockPos(1000, 64, 1000);

  await group('Animated blocks', () async {
    await testMinecraft('can place spinning block', (game) async {
      final pos = BlockPos(testBasePos.x + 200, testBasePos.y, testBasePos.z);

      // Clear the position first
      game.placeBlock(pos, Block.air);
      await game.waitTicks(1);

      // Place the spinning block
      game.placeBlock(pos, const Block('framework_tests:spinning_block'));
      await game.waitTicks(1);

      expect(game.getBlock(pos), isBlock('framework_tests:spinning_block'));
    });

    await testMinecraft('can place floating crystal block', (game) async {
      final pos = BlockPos(testBasePos.x + 201, testBasePos.y, testBasePos.z);

      // Clear the position first
      game.placeBlock(pos, Block.air);
      await game.waitTicks(1);

      // Place the floating crystal block (combined animation)
      game.placeBlock(pos, const Block('framework_tests:floating_crystal'));
      await game.waitTicks(1);

      expect(game.getBlock(pos), isBlock('framework_tests:floating_crystal'));
    });

    await testMinecraft('animated block persists after waiting', (game) async {
      final pos = BlockPos(testBasePos.x + 202, testBasePos.y, testBasePos.z);

      // Place the spinning block
      game.placeBlock(pos, const Block('framework_tests:spinning_block'));
      await game.waitTicks(100); // Wait 5 seconds (animation running)

      // Block should still be there
      expect(game.getBlock(pos), isBlock('framework_tests:spinning_block'));
    });

    await testMinecraft('can break animated block', (game) async {
      final pos = BlockPos(testBasePos.x + 203, testBasePos.y, testBasePos.z);

      // Place the spinning block
      game.placeBlock(pos, const Block('framework_tests:spinning_block'));
      await game.waitTicks(1);

      // Break it (replace with air)
      game.placeBlock(pos, Block.air);
      await game.waitTicks(1);

      expect(game.getBlock(pos), isAirBlock);
    });

    await testMinecraft('can replace animated block with another animated block',
        (game) async {
      final pos = BlockPos(testBasePos.x + 204, testBasePos.y, testBasePos.z);

      // Place the spinning block
      game.placeBlock(pos, const Block('framework_tests:spinning_block'));
      await game.waitTicks(1);
      expect(game.getBlock(pos), isBlock('framework_tests:spinning_block'));

      // Replace with floating crystal
      game.placeBlock(pos, const Block('framework_tests:floating_crystal'));
      await game.waitTicks(1);

      expect(game.getBlock(pos), isBlock('framework_tests:floating_crystal'));
    });

    await testMinecraft('can replace animated block with normal block',
        (game) async {
      final pos = BlockPos(testBasePos.x + 205, testBasePos.y, testBasePos.z);

      // Place the spinning block
      game.placeBlock(pos, const Block('framework_tests:spinning_block'));
      await game.waitTicks(1);
      expect(game.getBlock(pos), isBlock('framework_tests:spinning_block'));

      // Replace with stone
      game.placeBlock(pos, Block.stone);
      await game.waitTicks(1);

      expect(game.getBlock(pos), isBlock(Block.stone));
    });

    await testMinecraft('can replace normal block with animated block',
        (game) async {
      final pos = BlockPos(testBasePos.x + 206, testBasePos.y, testBasePos.z);

      // Place stone
      game.placeBlock(pos, Block.stone);
      await game.waitTicks(1);
      expect(game.getBlock(pos), isBlock(Block.stone));

      // Replace with spinning block
      game.placeBlock(pos, const Block('framework_tests:spinning_block'));
      await game.waitTicks(1);

      expect(game.getBlock(pos), isBlock('framework_tests:spinning_block'));
    });

    await testMinecraft('animated block is not air', (game) async {
      final pos = BlockPos(testBasePos.x + 207, testBasePos.y, testBasePos.z);

      // Place the floating crystal
      game.placeBlock(pos, const Block('framework_tests:floating_crystal'));
      await game.waitTicks(1);

      // Verify it's not air
      expect(game.isAir(pos), isFalse);
      expect(game.getBlock(pos), isNotAirBlock);
    });

    await testMinecraft('fillBlocks works with animated blocks', (game) async {
      final from =
          BlockPos(testBasePos.x + 210, testBasePos.y, testBasePos.z + 20);
      final to =
          BlockPos(testBasePos.x + 212, testBasePos.y + 2, testBasePos.z + 22);

      // Fill a 3x3x3 region with spinning blocks
      game.fillBlocks(from, to, const Block('framework_tests:spinning_block'));
      await game.waitTicks(5);

      // Check corners
      expect(game.getBlock(from), isBlock('framework_tests:spinning_block'));
      expect(game.getBlock(to), isBlock('framework_tests:spinning_block'));

      // Check a middle block
      final middle = BlockPos(
        testBasePos.x + 211,
        testBasePos.y + 1,
        testBasePos.z + 21,
      );
      expect(game.getBlock(middle), isBlock('framework_tests:spinning_block'));
    });
  });
}
