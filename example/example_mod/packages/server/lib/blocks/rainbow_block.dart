import 'package:dart_mod_server/dart_mod_server.dart';

/// A colorful glowing block that spawns heart particles when clicked
class RainbowBlock extends CustomBlock {
  RainbowBlock()
      : super(
          id: 'example_mod:rainbow_block',
          settings: const BlockSettings(
            hardness: 1.0,
            luminance: 10,
          ),
          model: BlockModel.cubeAll(
              texture: 'assets/textures/block/rainbow.png'),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    player?.sendMessage('\u00A76\u2728 Rainbow magic activated!');
    World.overworld.spawnParticles(
      Particles.heart,
      Vec3(x + 0.5, y + 1.5, z + 0.5),
      count: 10,
    );
    return ActionResult.success;
  }
}
