/// A block that spawns Flutter displays when powered by redstone.
library;

import 'package:dart_mod_server/dart_mod_server.dart';

import 'flutter_display_controller_entity.dart';

/// A block that spawns Flutter displays when powered by redstone.
///
/// Right-click to open configuration GUI for width/height.
/// Apply redstone signal to spawn/despawn the display.
class FlutterDisplayControllerBlock extends CustomBlock {
  static const String blockId = 'minecraft_flutter_dev:flutter_display_controller';

  static final FlutterDisplayControllerBlock _instance =
      FlutterDisplayControllerBlock._();

  FlutterDisplayControllerBlock._()
      : super(
          id: blockId,
          settings: const BlockSettings(
            hardness: 2.0,
            resistance: 6.0,
            requiresTool: false,
          ),
          model: BlockModel.cubeAll(
            texture: 'assets/textures/block/flutter_display_controller.png',
          ),
        );

  factory FlutterDisplayControllerBlock() => _instance;

  /// Register the block and block entity.
  static void register() {
    // Register block entity first
    BlockEntityRegistry.registerType(
      blockId,
      FlutterDisplayControllerEntity.new,
      inventorySize: 0,
      containerTitle: 'Flutter Display Controller',
      ticks: true, // Enable serverTick()
      dataSlotCount: 3, // widthTenths, heightTenths, isActive
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
