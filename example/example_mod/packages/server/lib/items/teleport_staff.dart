import 'dart:math' as math;
import 'package:dart_mod_server/dart_mod_server.dart';

/// Staff that teleports player 10 blocks forward
class TeleportStaff extends CustomItem {
  TeleportStaff()
      : super(
          id: 'example_mod:teleport_staff',
          settings: const ItemSettings(maxStackSize: 1),
          model: ItemModel.handheld(
              texture: 'assets/textures/item/teleport_staff.png'),
        );

  @override
  ItemActionResult onUse(int worldId, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player != null) {
      // Teleport 10 blocks forward based on yaw
      final yawRad = player.yaw * math.pi / 180.0;
      final dx = -10.0 * math.sin(yawRad);
      final dz = 10.0 * math.cos(yawRad);

      final newPos = Vec3(
        player.precisePosition.x + dx,
        player.precisePosition.y,
        player.precisePosition.z + dz,
      );

      // Spawn particles at old location
      World.overworld.spawnParticles(
        Particles.portal,
        player.precisePosition,
        count: 20,
      );

      player.teleportPrecise(newPos);
      player.sendMessage('\u00A7d\u2727 Teleported!');
    }
    return ItemActionResult.success;
  }
}
