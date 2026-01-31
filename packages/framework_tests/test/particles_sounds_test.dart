/// Particles & Sounds API tests.
///
/// Tests for particle spawning and sound playback APIs.
import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  await group('Particles', () async {
    await testMinecraft('can spawn particles at position', (game) async {
      final pos = Vec3(0, -59, 0);

      // Should not throw
      game.world.spawnParticles(Particles.flame, pos);
      await game.waitTicks(1);
    });

    await testMinecraft('can spawn multiple particles', (game) async {
      final pos = Vec3(0, -59, 0);

      // Spawn 10 particles at once
      game.world.spawnParticles(Particles.smoke, pos, count: 10);
      await game.waitTicks(1);
    });

    await testMinecraft('can spawn particles with spread', (game) async {
      final pos = Vec3(0, -59, 0);
      final delta = Vec3(0.5, 0.5, 0.5);

      // Spawn particles with random offset
      game.world.spawnParticles(Particles.heart, pos, delta: delta);
      await game.waitTicks(1);
    });

    await testMinecraft('can spawn particles with speed', (game) async {
      final pos = Vec3(0, -59, 0);

      // Spawn particles with velocity
      game.world.spawnParticles(Particles.explosion, pos, speed: 0.5);
      await game.waitTicks(1);
    });

    await testMinecraft('can spawn various particle types', (game) async {
      final pos = Vec3(0, -59, 0);

      // Test several particle types from the Particles class
      final particleTypes = [
        Particles.flame,
        Particles.smoke,
        Particles.heart,
        Particles.explosion,
        Particles.enchant,
        Particles.crit,
        Particles.portal,
        Particles.note,
      ];

      for (final particle in particleTypes) {
        game.world.spawnParticles(particle, pos);
      }
      await game.waitTicks(1);
    });

    await testMinecraft('can spawn particles with all parameters', (game) async {
      final pos = Vec3(5, -58, 5);
      final delta = Vec3(1, 0.5, 1);

      // Test with all parameters combined
      game.world.spawnParticles(
        Particles.flame,
        pos,
        count: 20,
        delta: delta,
        speed: 0.1,
      );
      await game.waitTicks(1);
    });

    await testMinecraft('can spawn particles to specific player', (game) async {
      final pos = Vec3(0, -59, 0);

      if (game.players.isNotEmpty) {
        final player = game.players.first;
        // Spawn particles only visible to this player
        game.world.spawnParticlesToPlayer(player, Particles.heart, pos);
        await game.waitTicks(1);
      }
      // Test passes even without players - just verifies API exists
    });

    await testMinecraft(
        'can spawn particles to player with all parameters', (game) async {
      final pos = Vec3(0, -59, 0);
      final delta = Vec3(0.2, 0.2, 0.2);

      if (game.players.isNotEmpty) {
        final player = game.players.first;
        game.world.spawnParticlesToPlayer(
          player,
          Particles.enchant,
          pos,
          count: 15,
          delta: delta,
          speed: 0.05,
        );
        await game.waitTicks(1);
      }
    });
  });

  await group('Sounds', () async {
    await testMinecraft('can play sound at position', (game) async {
      final pos = Vec3(0, -59, 0);

      // Should not throw
      game.world.playSound(pos, Sounds.explosion);
      await game.waitTicks(1);
    });

    await testMinecraft('can play sound with volume', (game) async {
      final pos = Vec3(0, -59, 0);

      // Play at half volume
      game.world.playSound(pos, Sounds.levelUp, volume: 0.5);
      await game.waitTicks(1);
    });

    await testMinecraft('can play sound with pitch', (game) async {
      final pos = Vec3(0, -59, 0);

      // Play at higher pitch
      game.world.playSound(pos, Sounds.click, pitch: 1.5);
      await game.waitTicks(1);

      // Play at lower pitch
      game.world.playSound(pos, Sounds.click, pitch: 0.5);
      await game.waitTicks(1);
    });

    await testMinecraft('can play sound with category', (game) async {
      final pos = Vec3(0, -59, 0);

      // Test different sound categories
      game.world.playSound(pos, Sounds.explosion, category: SoundCategory.blocks);
      await game.waitTicks(1);

      game.world.playSound(pos, Sounds.levelUp, category: SoundCategory.players);
      await game.waitTicks(1);

      game.world.playSound(pos, Sounds.thunder, category: SoundCategory.weather);
      await game.waitTicks(1);

      game.world.playSound(pos, Sounds.hurt, category: SoundCategory.hostile);
      await game.waitTicks(1);
    });

    await testMinecraft('can play various sounds', (game) async {
      final pos = Vec3(0, -59, 0);

      // Test several sounds from the Sounds class
      final sounds = [
        Sounds.explosion,
        Sounds.levelUp,
        Sounds.click,
        Sounds.xpOrb,
        Sounds.itemPickup,
        Sounds.doorOpen,
        Sounds.chest,
      ];

      for (final sound in sounds) {
        game.world.playSound(pos, sound);
      }
      await game.waitTicks(1);
    });

    await testMinecraft('can play sound with all parameters', (game) async {
      final pos = Vec3(5, -58, 5);

      // Test with all parameters combined
      game.world.playSound(
        pos,
        Sounds.anvil,
        category: SoundCategory.blocks,
        volume: 0.8,
        pitch: 0.9,
      );
      await game.waitTicks(1);
    });

    await testMinecraft('can play sound to specific player', (game) async {
      if (game.players.isNotEmpty) {
        final player = game.players.first;
        // Play sound only audible to this player
        game.world.playSoundToPlayer(player, Sounds.levelUp);
        await game.waitTicks(1);
      }
      // Test passes even without players - just verifies API exists
    });

    await testMinecraft(
        'can play sound to player with all parameters', (game) async {
      if (game.players.isNotEmpty) {
        final player = game.players.first;
        game.world.playSoundToPlayer(
          player,
          Sounds.xpOrb,
          category: SoundCategory.players,
          volume: 0.7,
          pitch: 1.2,
        );
        await game.waitTicks(1);
      }
    });

    await testMinecraft('can play all sound categories', (game) async {
      final pos = Vec3(0, -59, 0);

      // Iterate through all sound categories
      for (final category in SoundCategory.values) {
        game.world.playSound(pos, Sounds.click, category: category);
      }
      await game.waitTicks(1);
    });
  });
}
