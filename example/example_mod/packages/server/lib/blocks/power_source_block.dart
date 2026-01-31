import 'package:dart_mod_server/dart_mod_server.dart';

/// Example block demonstrating redstone power emission.
///
/// This block is a constant redstone power source that emits signal level 15
/// in all directions. Similar to a redstone block, but custom!
class PowerSourceBlock extends CustomBlock {
  PowerSourceBlock()
      : super(
          id: 'example_mod:power_source',
          settings: BlockSettings(
            hardness: 5.0,
            resistance: 6.0,
            luminance: 7, // Subtle glow to indicate it's powered
            isRedstoneSource: true, // Mark as a redstone signal source
          ),
          model: BlockModel.cubeAll(
            texture: 'assets/textures/block/hello_block.png', // Reuse existing texture
          ),
        );

  @override
  int getSignal(CustomBlockState state, Direction direction) {
    // Emit full redstone power (15) in all directions
    return 15;
  }

  @override
  int getDirectSignal(CustomBlockState state, Direction direction) {
    // Also emit strong/direct power for powering through blocks
    return 15;
  }

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player == null) return ActionResult.pass;

    player.sendMessage('§c[Power Source] §fEmitting redstone power level 15!');

    // Show redstone particles
    final world = World.overworld;
    world.spawnParticles(
      'minecraft:dust',
      Vec3(x + 0.5, y + 1.0, z + 0.5),
      count: 15,
      delta: Vec3(0.5, 0.5, 0.5),
    );

    return ActionResult.success;
  }

  @override
  void onPlaced(int worldId, int x, int y, int z, int playerId) {
    print('Power Source placed at ($x, $y, $z) - emitting signal 15');
  }
}
