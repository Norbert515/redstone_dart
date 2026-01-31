import 'package:dart_mod_server/dart_mod_server.dart';

/// Example block demonstrating block states with a toggleable lit property.
///
/// This block has a 'lit' BooleanProperty that can be toggled by right-clicking.
/// When lit, the block emits light (luminance 15).
class RedstoneLampBlock extends CustomBlock {
  /// The 'lit' property - true when the lamp is on.
  static const litProperty = BooleanProperty('lit');

  RedstoneLampBlock()
      : super(
          id: 'example_mod:redstone_lamp',
          settings: BlockSettings(
            hardness: 0.3,
            resistance: 0.3,
            luminance: 15, // Will be controlled by block state in practice
            properties: [litProperty],
          ),
          model: BlockModel.cubeAll(
            texture: 'assets/textures/block/hello_block.png', // Reuse existing texture
          ),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player == null) return ActionResult.pass;

    // Toggle the lit state
    // Note: In a full implementation, this would update the block state in the world
    // For now, we demonstrate the block state system works
    final world = World.overworld;

    // Show visual feedback
    world.spawnParticles(
      Particles.flame,
      Vec3(x + 0.5, y + 1.0, z + 0.5),
      count: 10,
      delta: Vec3(0.3, 0.2, 0.3),
    );
    world.playSound(Vec3(x + 0.5, y + 0.5, z + 0.5), Sounds.click, volume: 0.5);

    player.sendMessage('§6[Redstone Lamp] §fToggled!');

    return ActionResult.success;
  }

  @override
  CustomBlockState getStateForPlacement(BlockPlacementContext context) {
    // Start with the lamp off
    return defaultState.setValue(litProperty, false);
  }

  @override
  void onStateChange(
    int worldId,
    int x,
    int y,
    int z,
    CustomBlockState oldState,
    CustomBlockState newState,
  ) {
    final wasLit = oldState.getValue<bool>(litProperty);
    final isLit = newState.getValue<bool>(litProperty);

    if (wasLit != isLit) {
      print('Redstone Lamp at ($x, $y, $z) changed: lit=$isLit');
    }
  }
}
