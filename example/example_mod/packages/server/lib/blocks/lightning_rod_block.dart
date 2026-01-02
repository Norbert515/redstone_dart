import 'dart:math';

import 'package:dart_mod_server/dart_mod_server.dart';

/// Lightning Rod Block - Summons lightning where the player is looking.
/// Demonstrates: Player rotation (yaw/pitch), world lightning API, math for direction.
class LightningRodBlock extends CustomBlock {
  LightningRodBlock()
      : super(
          id: 'example_mod:lightning_rod',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player == null) return ActionResult.pass;

    final world = World.overworld;

    // Calculate position 10 blocks in front of player based on their facing
    final yawRad = player.yaw * (pi / 180.0);
    final pitchRad = player.pitch * (pi / 180.0);

    // Direction vector from yaw/pitch
    final dx = -sin(yawRad) * cos(pitchRad);
    final dy = -sin(pitchRad);
    final dz = cos(yawRad) * cos(pitchRad);

    final targetPos = player.precisePosition + Vec3(dx * 10, dy * 10, dz * 10);

    // Spawn lightning at target position
    world.spawnLightning(targetPos);

    // Thunder sound and message
    world.playSound(player.precisePosition, Sounds.thunder, volume: 0.5);
    player.sendMessage('§e[Lightning] §f⚡ STRIKE! ⚡');
    player.sendActionBar('§e⚡ THUNDER ⚡');

    return ActionResult.success;
  }
}
