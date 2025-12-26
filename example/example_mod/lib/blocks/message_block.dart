import 'package:dart_mc/dart_mc.dart';

/// Block that displays a welcome title when clicked
class MessageBlock extends CustomBlock {
  MessageBlock()
      : super(
          id: 'example_mod:message_block',
          settings: const BlockSettings(hardness: 2.0),
          model: BlockModel.cubeAll(
              texture: 'assets/textures/block/message.png'),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    player?.sendTitle('\u00A7b\u00A7lWelcome!', subtitle: '\u00A77Thanks for clicking');
    return ActionResult.success;
  }
}
