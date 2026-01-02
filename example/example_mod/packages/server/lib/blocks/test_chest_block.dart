import 'package:dart_mod_server/dart_mod_server.dart';

/// A test chest block that opens a Flutter-based container UI.
///
/// Right-click to open a 3x9 chest interface with Flutter slot rendering.
/// This block demonstrates the integration between Dart containers and
/// Flutter-based slot rendering.
class TestChestBlock extends CustomBlock {
  /// The container type ID for the test chest.
  static const String containerId = 'example_mod:test_chest';

  TestChestBlock()
      : super(
          id: 'example_mod:test_chest_block',
          settings: BlockSettings(
            hardness: 2.5,
            resistance: 2.5,
            requiresTool: false,
          ),
          model: BlockModel.cubeAll(
            texture: 'assets/textures/block/test_chest.png',
          ),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    // Open the container for the player via JNI
    final success = _openContainerForPlayer(playerId, containerId);
    if (success) {
      return ActionResult.success;
    }
    return ActionResult.pass;
  }

  /// Opens a container menu for a player via JNI.
  ///
  /// This calls DartBridge.openContainerForPlayer in Java to open
  /// the container screen for the player.
  static bool _openContainerForPlayer(int playerId, String containerId) {
    try {
      return GenericJniBridge.callStaticBoolMethod(
        'com/redstone/DartBridge',
        'openContainerForPlayer',
        '(ILjava/lang/String;)Z',
        [playerId, containerId],
      );
    } catch (e) {
      print('TestChestBlock: Failed to open container: $e');
      return false;
    }
  }
}
