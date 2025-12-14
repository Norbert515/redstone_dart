/// Example custom blocks defined in Dart.
///
/// These demonstrate how to create custom Minecraft blocks entirely in Dart.
library;

import '../api/custom_block.dart';
import '../api/block_registry.dart';
import '../api/world.dart';
import '../api/block.dart';
import '../src/bridge.dart';
import '../src/types.dart';

/// Helper function to send a chat message to a player.
void _chat(int playerId, String message) {
  Bridge.sendChatMessage(playerId, message);
}

/// A simple custom block that sends chat messages when used.
class ExampleBlock extends CustomBlock {
  ExampleBlock()
      : super(
          id: 'dartmod:example_block',
          settings: BlockSettings(
            hardness: 2.0,
            resistance: 6.0,
          ),
        );

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    _chat(playerId, '§e[Dart] §fYou broke the example block at ($x, $y, $z)!');
    return true; // Allow break
  }

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    _chat(playerId,
        '§b[Dart] §fHello from Dart! This block is 100% defined in Dart code.');
    _chat(playerId, '§7Position: ($x, $y, $z)');
    return ActionResult.success;
  }
}

/// A counting block that tracks how many times it's been clicked.
class CounterBlock extends CustomBlock {
  static int _globalClickCount = 0;

  CounterBlock()
      : super(
          id: 'dartmod:counter_block',
          settings: BlockSettings(
            hardness: 1.5,
            resistance: 3.0,
          ),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    _globalClickCount++;
    _chat(playerId, '§a[Counter] §fClick count: §e$_globalClickCount');

    // Special messages at milestones
    if (_globalClickCount == 10) {
      _chat(playerId, '§6[Counter] §fWow, 10 clicks! Keep going!');
    } else if (_globalClickCount == 50) {
      _chat(playerId, '§d[Counter] §f50 clicks! You\'re dedicated!');
    } else if (_globalClickCount == 100) {
      _chat(playerId, '§c[Counter] §f100 CLICKS! You\'re a legend!');
    }

    return ActionResult.success;
  }
}

/// A block that prevents being broken (like bedrock).
class UnbreakableBlock extends CustomBlock {
  UnbreakableBlock()
      : super(
          id: 'dartmod:unbreakable_block',
          settings: BlockSettings(
            hardness: -1.0, // -1 = unbreakable in Minecraft
            resistance: 3600000.0, // Very high resistance
            requiresTool: true,
          ),
        );

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    _chat(playerId, '§c[Dart] §BUBUBUBUBUBU');
    return true; // Cancel break - make it truly unbreakable
  }

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    _chat(playerId, '§5[Dart] §fYou touched the unbreakable block!');
    _chat(playerId, '§8This block cannot be destroyed.');
    return ActionResult.consume;
  }
}

// =============================================================================
// World API Demo Blocks
// =============================================================================

/// A block that transforms a 5x5 area into grass and flowers when right-clicked.
/// Demonstrates the setBlock API.
class TerraformerBlock extends CustomBlock {
  TerraformerBlock()
      : super(
          id: 'dartmod:terraformer',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;
    _chat(playerId, '§a[Terraformer] §fTransforming area...');

    int count = 0;
    for (var dx = -2; dx <= 2; dx++) {
      for (var dz = -2; dz <= 2; dz++) {
        if (dx == 0 && dz == 0) continue; // Skip the block itself
        final pos = BlockPos(x + dx, y, z + dz);
        // Alternate between grass and flowers
        final block =
            ((dx + dz) % 2 == 0) ? Block.grass : Block('minecraft:dandelion');
        if (world.setBlock(pos, block)) count++;
      }
    }

    _chat(playerId, '§a[Terraformer] §fTransformed $count blocks!');
    return ActionResult.success;
  }
}

/// A block that inspects and reports what blocks are above and below it.
/// Demonstrates the getBlock and isAir APIs.
class BlockInspectorBlock extends CustomBlock {
  BlockInspectorBlock()
      : super(
          id: 'dartmod:inspector',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;

    // Check blocks in all directions
    final below = world.getBlock(BlockPos(x, y - 1, z));
    final above = world.getBlock(BlockPos(x, y + 1, z));

    _chat(playerId, '§6[Inspector] §fBlock Analysis:');
    _chat(playerId, '§7  Below: §f${below.id}');
    _chat(playerId, '§7  Above: §f${above.id}');

    if (world.isAir(BlockPos(x, y + 1, z))) {
      _chat(playerId, '§7  (Space above is empty)');
    }

    return ActionResult.success;
  }
}

/// A block that builds a tower of 5 blocks upward when right-clicked.
/// Demonstrates the setBlock + isAir combination.
class TowerBuilderBlock extends CustomBlock {
  TowerBuilderBlock()
      : super(
          id: 'dartmod:tower_builder',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;
    _chat(playerId, '§d[Tower] §fBuilding tower...');

    int built = 0;
    for (var dy = 1; dy <= 5; dy++) {
      final pos = BlockPos(x, y + dy, z);
      if (world.isAir(pos)) {
        // Alternate between bricks and stone bricks for a nice pattern
        final block = (dy % 2 == 0)
            ? Block('minecraft:stone_bricks')
            : Block('minecraft:bricks');
        if (world.setBlock(pos, block)) built++;
      } else {
        _chat(playerId, '§c[Tower] §fBlocked at height $dy!');
        break;
      }
    }

    _chat(playerId, '§d[Tower] §fBuilt $built blocks high!');
    return ActionResult.success;
  }
}

/// A block that turns all stone-like blocks in a 3x3x3 area into gold.
/// Demonstrates the getBlock + setBlock combination.
class MidasBlock extends CustomBlock {
  MidasBlock()
      : super(
          id: 'dartmod:midas',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;
    _chat(playerId, '§6[Midas] §fThe golden touch spreads...');

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
      _chat(playerId, '§6[Midas] §fTransformed $transformed blocks to gold!');
    } else {
      _chat(playerId, '§6[Midas] §7No stone nearby to transform...');
    }

    return ActionResult.success;
  }
}

/// Register all example blocks.
/// Call this during mod initialization.
void registerExampleBlocks() {
  print('Registering example Dart blocks...');

  // Basic demo blocks
  BlockRegistry.register(ExampleBlock());
  BlockRegistry.register(CounterBlock());
  BlockRegistry.register(UnbreakableBlock());

  // World API demo blocks
  BlockRegistry.register(TerraformerBlock());
  BlockRegistry.register(BlockInspectorBlock());
  BlockRegistry.register(TowerBuilderBlock());
  BlockRegistry.register(MidasBlock());

  print('Example blocks registered: ${BlockRegistry.blockCount} blocks total');
}
