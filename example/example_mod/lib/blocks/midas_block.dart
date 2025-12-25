import 'package:dart_mc/dart_mc.dart';

/// A block that turns all stone-like blocks in a 3x3x3 area into gold.
/// Demonstrates the getBlock + setBlock combination.
class MidasBlock extends CustomBlock {
  MidasBlock()
      : super(
          id: 'example_mod:midas',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;
    final player = Players.getPlayer(playerId);
    player?.sendMessage('§6[Midas] §fThe golden touch spreads...');

    int transformed = 0;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (var dz = -1; dz <= 1; dz++) {
          if (dx == 0 && dy == 0 && dz == 0) continue;

          final pos = BlockPos(x + dx, y + dy, z + dz);
          final block = world.getBlock(pos);

          // Turn stone-like blocks into gold
          if (block.id == 'minecraft:stone' ||
              block.id == 'minecraft:cobblestone' ||
              block.id == 'minecraft:andesite' ||
              block.id == 'minecraft:diorite' ||
              block.id == 'minecraft:granite') {
            world.setBlock(pos, Block('minecraft:gold_block'));
            transformed++;
          }
        }
      }
    }

    if (transformed > 0) {
      player?.sendMessage('§6[Midas] §fTransformed $transformed blocks to gold!');
    } else {
      player?.sendMessage('§6[Midas] §7No stone nearby to transform...');
    }

    return ActionResult.success;
  }
}
