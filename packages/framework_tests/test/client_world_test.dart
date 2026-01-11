/// Client world configuration tests.
///
/// Tests for TestWorld declarative configuration and imperative world APIs.
/// These tests verify that the ClientGameContext's world setup functionality
/// works correctly for E2E client tests.
import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  await fullGroup('Client World Configuration', () async {
    await testMinecraftFull(
      'TestWorld.superflat() applies default configuration',
      world: TestWorld.superflat(),
      (game) async {
        // Verify player exists
        final player = game.player;
        expect(player, isNotNull);

        final pos = player!.position;
        // Player should be near (0, 64, 0) - allow some tolerance for player movement
        expect(pos.x, inInclusiveRange(-5, 5));
        expect(pos.z, inInclusiveRange(-5, 5));

        // Verify game mode is creative (default for superflat)
        expect(player.gameMode, equals(GameMode.creative));

        // Verify area is cleared (should be air above ground level)
        expect(game.isAir(BlockPos(0, 65, 0)), isTrue);
      },
    );

    await testMinecraftFull(
      'TestWorld.superflat() with custom spawn',
      world: TestWorld.superflat(
        spawn: BlockPos(1000, 64, 1000),
      ),
      (game) async {
        final player = game.player;
        expect(player, isNotNull);

        final pos = player!.position;
        expect(pos.x, inInclusiveRange(995, 1005));
        expect(pos.z, inInclusiveRange(995, 1005));
      },
    );

    await testMinecraftFull(
      'TestWorld with custom time and weather',
      world: TestWorld.superflat(
        time: 18000, // midnight
        weather: Weather.rain,
      ),
      (game) async {
        // Just verify no errors - time/weather hard to assert
        final player = game.player;
        expect(player, isNotNull);
      },
    );

    await testMinecraftFull(
      'Imperative world setup works',
      (game) async {
        // Use imperative APIs directly
        await game.teleportPlayer(BlockPos(2000, 64, 2000));
        await game.waitTicks(5);

        final player = game.player;
        expect(player, isNotNull);

        final pos = player!.position;
        expect(pos.x, inInclusiveRange(1995, 2005));
        expect(pos.z, inInclusiveRange(1995, 2005));

        // Test other imperative APIs
        game.setTime(6000);
        game.setGameMode(GameMode.survival);
        expect(player.gameMode, equals(GameMode.survival));
      },
    );

    await testMinecraftFull(
      'Hybrid: declarative base with imperative tweaks',
      world: TestWorld.superflat(),
      (game) async {
        // Start with superflat defaults, then tweak
        game.setTime(18000); // change to midnight
        game.setGameMode(GameMode.survival);

        final player = game.player;
        expect(player, isNotNull);
        expect(player!.gameMode, equals(GameMode.survival));

        // Verify spawn was still at default
        final pos = player.position;
        expect(pos.x, inInclusiveRange(-5, 5));
        expect(pos.z, inInclusiveRange(-5, 5));
      },
    );

    await testMinecraftFull(
      'clearArea and fillArea work correctly',
      world: TestWorld.superflat(),
      (game) async {
        // Place some blocks using fillArea
        game.fillArea(
          BlockPos(-5, 64, -5),
          BlockPos(5, 64, 5),
          Block.stone,
        );
        await game.waitTicks(1);

        // Verify blocks placed
        expect(game.getBlock(BlockPos(0, 64, 0)), isBlock(Block.stone));

        // Clear the area
        game.clearArea(
          BlockPos(-5, 64, -5),
          BlockPos(5, 64, 5),
        );
        await game.waitTicks(1);

        // Verify cleared
        expect(game.isAir(BlockPos(0, 64, 0)), isTrue);
      },
    );

    await testMinecraftFull(
      'TestWorld.empty() creates void world',
      world: TestWorld.empty(),
      (game) async {
        final player = game.player;
        expect(player, isNotNull);

        // Verify player is at default spawn
        final pos = player!.position;
        expect(pos.x, inInclusiveRange(-5, 5));
        expect(pos.z, inInclusiveRange(-5, 5));

        // Verify area is cleared (larger radius than superflat)
        expect(game.isAir(BlockPos(50, 65, 50)), isTrue);
      },
    );

    await testMinecraftFull(
      'TestWorld with initial blocks',
      world: TestWorld.superflat(
        initialBlocks: {
          BlockPos(0, 65, 0): Block.stone,
          BlockPos(1, 65, 0): Block.dirt,
          BlockPos(2, 65, 0): Block.cobblestone,
        },
      ),
      (game) async {
        // Verify initial blocks were placed
        expect(game.getBlock(BlockPos(0, 65, 0)), isBlock(Block.stone));
        expect(game.getBlock(BlockPos(1, 65, 0)), isBlock(Block.dirt));
        expect(game.getBlock(BlockPos(2, 65, 0)), isBlock(Block.cobblestone));
      },
    );
  });
}
