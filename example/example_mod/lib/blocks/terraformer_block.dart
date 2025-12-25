import 'package:dart_mc/dart_mc.dart';

/// A block that transforms a 5x5 area into grass and flowers when right-clicked.
/// Demonstrates the setBlock API.
class TerraformerBlock extends CustomBlock {
  TerraformerBlock()
      : super(
          id: 'example_mod:terraformer',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;
    final player = Players.getPlayer(playerId);
    player?.sendMessage('§a[Terraformer] §fTransforming area...');

    int count = 0;
    for (var dx = -2; dx <= 2; dx++) {
      for (var dz = -2; dz <= 2; dz++) {
        if (dx == 0 && dz == 0) continue; // Skip the block itself
        final pos = BlockPos(x + dx, y, z + dz);
        // Alternate between grass and flowers
        final block = ((dx + dz) % 2 == 0) ? Block.grass : Block('minecraft:dandelion');
        if (world.setBlock(pos, block)) count++;
      }
    }

    player?.sendMessage('§a[Terraformer] §fTransformed $count blocks!');
    return ActionResult.success;
  }
}
