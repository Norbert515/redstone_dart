/// A passive display block that forms part of a multi-block screen.
///
/// This block does nothing on its own - it simply marks a position as
/// "part of a screen". The [ScreenControllerBlock] traverses adjacent
/// ScreenBlocks to form a grid and spawns a FlutterDisplay covering them.
library;

import 'package:dart_mod_server/dart_mod_server.dart';

/// A passive display block that forms part of a multi-block screen.
///
/// ScreenBlocks are simple blocks with no block entity. They exist only
/// to mark positions that should be included in a multi-block screen.
/// When a [ScreenControllerBlock] is powered, it traverses adjacent
/// ScreenBlocks and creates a single FlutterDisplay covering the grid.
class ScreenBlock extends CustomBlock {
  static const String blockId = 'minecraft_flutter_dev:screen_block';

  static final ScreenBlock _instance = ScreenBlock._();

  ScreenBlock._()
      : super(
          id: blockId,
          settings: const BlockSettings(
            hardness: 1.0,
            resistance: 3.0,
            requiresTool: false,
          ),
          model: BlockModel.cubeAll(
            texture: 'assets/textures/block/screen_block.png',
          ),
        );

  factory ScreenBlock() => _instance;

  /// Register the block.
  static void register() {
    BlockRegistry.register(_instance);
  }
}
