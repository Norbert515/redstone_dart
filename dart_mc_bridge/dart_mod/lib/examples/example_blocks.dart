/// Example custom blocks defined in Dart.
///
/// These demonstrate how to create custom Minecraft blocks entirely in Dart.
library;

import '../api/custom_block.dart';
import '../api/block_registry.dart';
import '../src/bridge.dart';

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
    _chat(playerId, '§b[Dart] §fHello from Dart! This block is 100% defined in Dart code.');
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
    _chat(playerId, '§c[Dart] §fNice try, but this block is unbreakable!');
    return false; // Cancel break - make it truly unbreakable
  }

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    _chat(playerId, '§5[Dart] §fYou touched the unbreakable block!');
    _chat(playerId, '§8This block cannot be destroyed.');
    return ActionResult.consume;
  }
}

/// Register all example blocks.
/// Call this during mod initialization.
void registerExampleBlocks() {
  print('Registering example Dart blocks...');

  BlockRegistry.register(ExampleBlock());
  BlockRegistry.register(CounterBlock());
  BlockRegistry.register(UnbreakableBlock());

  print('Example blocks registered: ${BlockRegistry.blockCount} blocks total');
}
