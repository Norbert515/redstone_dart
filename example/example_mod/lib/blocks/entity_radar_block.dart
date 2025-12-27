import 'package:dart_mc/dart_mc.dart';

/// Entity Radar Block - Finds and lists entities within 20 blocks.
/// Demonstrates: Entities.getEntitiesInRadius(), distance calculation, entity types.
class EntityRadarBlock extends CustomBlock {
  EntityRadarBlock()
      : super(
          id: 'example_mod:entity_radar',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
          model: BlockModel.cubeAll(texture: 'assets/textures/block/entity_radar_block.png'),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player == null) return ActionResult.pass;

    final world = World.overworld;
    final blockCenter = Vec3(x + 0.5, y + 0.5, z + 0.5);

    // Get all entities within 20 blocks
    final entities = Entities.getEntitiesInRadius(world, blockCenter, 20.0);

    // Filter out the player who clicked
    final otherEntities = entities.where((e) => e.id != playerId).toList();

    if (otherEntities.isEmpty) {
      player.sendMessage('§c[Radar] §fNo entities detected within 20 blocks.');
      player.sendActionBar('§c⚠ No entities nearby');
    } else {
      player.sendMessage('§a[Radar] §fFound §e${otherEntities.length}§f entities within 20 blocks:');
      player.sendMessage('§7─────────────────────────');

      // Group entities by type
      final entityCounts = <String, int>{};
      final entityDistances = <String, List<double>>{};

      for (final entity in otherEntities) {
        final type = entity.type.replaceFirst('minecraft:', '');
        entityCounts[type] = (entityCounts[type] ?? 0) + 1;

        final distance = blockCenter.distanceTo(entity.position);
        entityDistances.putIfAbsent(type, () => []).add(distance);
      }

      // Display grouped results
      for (final entry in entityCounts.entries) {
        final distances = entityDistances[entry.key]!;
        final nearestDist = distances.reduce((a, b) => a < b ? a : b);
        player.sendMessage(
          '§f  • §b${entry.key}§f x${entry.value} §7(nearest: ${nearestDist.toStringAsFixed(1)}m)',
        );
      }

      player.sendActionBar('§a✓ ${otherEntities.length} entities detected');
    }

    // Visual effect
    world.spawnParticles(Particles.portal, blockCenter, count: 50, delta: Vec3(1.0, 1.0, 1.0));
    world.playSound(blockCenter, Sounds.xpOrb, volume: 0.5);

    return ActionResult.success;
  }
}
