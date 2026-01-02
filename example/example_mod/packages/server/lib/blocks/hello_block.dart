import 'package:dart_mod_server/dart_mod_server.dart';

/// Example custom block that shows a message when right-clicked.
///
/// This demonstrates how to create custom blocks in Dart.
/// The block will appear in the creative menu under "Building Blocks".
/// When mined, it drops a DartItem instead of itself.
class HelloBlock extends CustomBlock {
  HelloBlock()
      : super(
          id: 'example_mod:hello_block',
          settings: BlockSettings(
            hardness: 4.0,
            resistance: 1.0,
            requiresTool: false,
          ),
          model: BlockModel.cubeAll(texture: 'assets/textures/block/hello_block.png'),
          drops: 'example_mod:dart_item',
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    // Get player info and send a message
    final player = Players.getPlayer(playerId);
    if (player != null) {
      player.sendMessage('Hello from Basic Dart Mod! You clicked at ($x, $y, $z)');
    }
    return ActionResult.success;
  }

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    print('HelloBlock broken at ($x, $y, $z) by player $playerId');
    return true; // Allow the block to be broken
  }
}
