/// Example custom blocks defined in Dart.
///
/// These demonstrate how to create custom Minecraft blocks entirely in Dart.
library;

import '../api/custom_block.dart';
import '../api/block_registry.dart';

/// A simple custom block that prints a message when used.
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
    print('ExampleBlock broken at ($x, $y, $z) by player $playerId!');
    return true; // Allow break
  }

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    print('ExampleBlock used at ($x, $y, $z) by player $playerId!');
    print('Hello from Dart! This block is 100% defined in Dart code.');
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
    print('CounterBlock clicked! Total clicks: $_globalClickCount');
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
    print('Nice try, but this block is unbreakable!');
    return false; // Cancel break - make it truly unbreakable
  }

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    print('You touched the unbreakable block!');
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
