/// A block that drives connected screen blocks to form a multi-block display.
library;

import 'package:dart_mod_server/dart_mod_server.dart';

import 'screen_controller_entity.dart';

/// A block that drives connected screen blocks to form a multi-block display.
///
/// When powered by redstone:
/// 1. Traverses adjacent ScreenBlocks (orthogonally, max 64 blocks)
/// 2. Calculates the bounding box of connected blocks
/// 3. Spawns a single FlutterDisplay covering the entire grid
/// 4. Passes grid layout info to Flutter for gap handling
///
/// When power is removed, the display is despawned.
class ScreenControllerBlock extends CustomBlock {
  static const String blockId = 'minecraft_flutter_dev:screen_controller';

  static final ScreenControllerBlock _instance = ScreenControllerBlock._();

  ScreenControllerBlock._()
      : super(
          id: blockId,
          settings: const BlockSettings(
            hardness: 2.0,
            resistance: 6.0,
            requiresTool: false,
          ),
          model: BlockModel.cubeAll(
            texture: 'assets/textures/block/screen_controller.png',
          ),
        );

  factory ScreenControllerBlock() => _instance;

  /// Register the block and block entity.
  static void register() {
    // Register block entity first
    BlockEntityRegistry.registerType(
      blockId,
      ScreenControllerEntity.new,
      inventorySize: 0,
      containerTitle: 'Screen Controller',
      ticks: true, // Enable serverTick()
      dataSlotCount: 1, // isActive
    );

    // Register the block
    BlockRegistry.register(_instance);
  }

  @override
  void neighborChanged(
    int worldId,
    int x,
    int y,
    int z,
    int neighborX,
    int neighborY,
    int neighborZ,
  ) {
    // Block entity's serverTick will handle redstone detection.
    // This callback ensures we're notified of neighbor changes.
  }
}
