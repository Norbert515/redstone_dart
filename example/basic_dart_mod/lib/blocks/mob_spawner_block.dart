import 'dart:math';

import 'package:dart_mc/dart_mc.dart';

/// Mob Spawner Block - Spawns random friendly mobs with custom names.
/// Demonstrates: Entity spawning, custom names, glowing effect.
class MobSpawnerBlock extends CustomBlock {
  static final _mobs = [
    'minecraft:pig',
    'minecraft:cow',
    'minecraft:sheep',
    'minecraft:chicken',
  ];
  static final _names = [
    '§aDart Buddy',
    '§bCode Companion',
    '§dFlutter Friend',
    '§6Mod Mascot',
  ];
  static final _random = Random();

  MobSpawnerBlock()
      : super(
          id: 'basic_dart_mod:mob_spawner',
          settings: BlockSettings(hardness: 1.5, resistance: 3.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    final world = World.overworld;
    final spawnPos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    // Pick random mob and name
    final mobType = _mobs[_random.nextInt(_mobs.length)];
    final mobName = _names[_random.nextInt(_names.length)];

    // Spawn the entity
    final entity = Entities.spawn(world, mobType, spawnPos);
    if (entity != null) {
      // Give it a custom name and make it glow
      entity.customName = mobName;
      entity.isCustomNameVisible = true;
      entity.isGlowing = true;

      // Make it persistent so it doesn't despawn
      if (entity is MobEntity) {
        entity.isPersistent = true;
      }

      // Effects
      world.spawnParticles(Particles.villagerHappy, spawnPos, count: 15, delta: Vec3(0.3, 0.3, 0.3));
      world.playSound(spawnPos, Sounds.xpOrb, volume: 0.8);

      player?.sendMessage('§a[Spawner] §fSpawned $mobName§f!');
    } else {
      player?.sendMessage('§c[Spawner] §fFailed to spawn mob.');
    }

    return ActionResult.success;
  }
}
