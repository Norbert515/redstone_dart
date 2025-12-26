import 'dart:math';

import 'package:dart_mc/dart_mc.dart';
import 'package:dart_mc/api/commands.dart';

import '../gui/gui.dart';

/// Registers all custom commands.
void registerCommands() {
  // /heal [amount] - Heals the player
  Commands.register(
    'heal',
    execute: (context) {
      final amount = context.getArgument<int>('amount');
      final player = context.source;

      if (amount != null && amount > 0) {
        final newHealth = (player.health + amount).clamp(0.0, player.maxHealth);
        player.health = newHealth;
        context.sendFeedback(
            '§a[Heal] §fHealed for §c$amount§f hearts. Health: §c${newHealth.toInt()}§f/§c${player.maxHealth.toInt()}');
      } else {
        player.health = player.maxHealth;
        context.sendFeedback('§a[Heal] §fFully healed to §c${player.maxHealth.toInt()}§f hearts!');
      }

      return 1;
    },
    description: 'Heals the player',
    arguments: [
      CommandArgument('amount', ArgumentType.integer, required: false),
    ],
  );

  // /feed - Restores food and saturation
  Commands.register(
    'feed',
    execute: (context) {
      final player = context.source;
      player.foodLevel = 20;
      player.saturation = 20.0;
      context.sendFeedback('§a[Feed] §fFood and saturation fully restored!');
      return 1;
    },
    description: 'Restores food and saturation to full',
  );

  // /fly - Toggles creative flight
  Commands.register(
    'fly',
    execute: (context) {
      final player = context.source;

      // Toggle game mode between survival and creative for flight
      if (player.gameMode == GameMode.creative) {
        player.gameMode = GameMode.survival;
        context.sendFeedback('§e[Fly] §fFlight disabled - switched to Survival mode');
      } else {
        player.gameMode = GameMode.creative;
        context.sendFeedback('§e[Fly] §fFlight enabled - switched to Creative mode');
      }

      return 1;
    },
    description: 'Toggles creative flight by switching game modes',
  );

  // /spawn <entity_type> - Spawns an entity at player's location
  Commands.register(
    'spawn',
    execute: (context) {
      final entityType = context.requireArgument<String>('entity_type');
      final player = context.source;
      final world = World.overworld;

      // Ensure minecraft: prefix if not present
      final fullType = entityType.contains(':') ? entityType : 'minecraft:$entityType';

      final entity = Entities.spawn(world, fullType, player.precisePosition);
      if (entity != null) {
        context.sendFeedback('§a[Spawn] §fSpawned §b$fullType§f at your location!');
        // Spawn particles around the new entity
        world.spawnParticles(Particles.cloud, player.precisePosition, count: 20, delta: Vec3(0.5, 0.5, 0.5));
        return 1;
      } else {
        context.sendError('§c[Spawn] §fFailed to spawn entity: $fullType');
        return 0;
      }
    },
    description: 'Spawns an entity at your location',
    arguments: [
      CommandArgument('entity_type', ArgumentType.string),
    ],
  );

  // /time <set|add> <value> - Controls world time
  Commands.register(
    'dtime',
    execute: (context) {
      final action = context.requireArgument<String>('action');
      final value = context.requireArgument<int>('value');
      final world = World.overworld;

      switch (action.toLowerCase()) {
        case 'set':
          world.timeOfDay = value.clamp(0, 24000);
          context.sendFeedback('§e[Time] §fTime set to §a$value§f ticks');
          return 1;
        case 'add':
          final newTime = (world.timeOfDay + value) % 24000;
          world.timeOfDay = newTime;
          context.sendFeedback('§e[Time] §fAdded §a$value§f ticks. Current time: §a$newTime');
          return 1;
        default:
          context.sendError('§c[Time] §fInvalid action. Use "set" or "add"');
          return 0;
      }
    },
    description: 'Controls world time (set or add ticks)',
    arguments: [
      CommandArgument('action', ArgumentType.string),
      CommandArgument('value', ArgumentType.integer),
    ],
  );

  // =========================================================================
  // Custom Entity Spawn Commands
  // These commands make it easy to test the custom entities
  // =========================================================================

  // /spawnzombie - Spawns a DartZombie at the player's location
  Commands.register(
    'spawnzombie',
    execute: (context) {
      final player = context.source;
      final world = World.overworld;

      final entity = Entities.spawn(world, 'example_mod:dart_zombie', player.precisePosition);
      if (entity != null) {
        context.sendFeedback('§c[DartZombie] §fSpawned a hostile Dart Zombie!');
        world.spawnParticles(Particles.smoke, player.precisePosition, count: 30, delta: Vec3(0.5, 1.0, 0.5));
        world.playSound(player.precisePosition, Sounds.hurt, volume: 1.0);
        return 1;
      }
      context.sendError('§c[DartZombie] §fFailed to spawn entity');
      return 0;
    },
    description: 'Spawns a custom DartZombie at your location',
  );

  // /spawncow - Spawns a DartCow at the player's location
  Commands.register(
    'spawncow',
    execute: (context) {
      final player = context.source;
      final world = World.overworld;

      final entity = Entities.spawn(world, 'example_mod:dart_cow', player.precisePosition);
      if (entity != null) {
        context.sendFeedback('§a[DartCow] §fSpawned a friendly Dart Cow! (Breed with wheat)');
        world.spawnParticles(Particles.heart, player.precisePosition, count: 10, delta: Vec3(0.5, 0.5, 0.5));
        world.playSound(player.precisePosition, Sounds.eat, volume: 1.0);
        return 1;
      }
      context.sendError('§a[DartCow] §fFailed to spawn entity');
      return 0;
    },
    description: 'Spawns a custom DartCow at your location',
  );

  // /fireball - Spawns a DartFireball projectile in the player's facing direction
  Commands.register(
    'fireball',
    execute: (context) {
      final player = context.source;
      final world = World.overworld;

      // Spawn the fireball slightly in front of the player
      final yawRad = player.yaw * (pi / 180.0);
      final dx = -sin(yawRad);
      final dz = cos(yawRad);

      final spawnPos = player.precisePosition + Vec3(dx * 2, 1.5, dz * 2);

      final entity = Entities.spawn(world, 'example_mod:dart_fireball', spawnPos);
      if (entity != null) {
        context.sendFeedback('§6[DartFireball] §fLaunched a fireball!');
        world.spawnParticles(Particles.flame, spawnPos, count: 20, delta: Vec3(0.2, 0.2, 0.2));
        world.playSound(player.precisePosition, Sounds.explosion, volume: 0.5);
        return 1;
      }
      context.sendError('§6[DartFireball] §fFailed to spawn projectile');
      return 0;
    },
    description: 'Spawns a custom DartFireball projectile',
  );

  // /spawncustomzombie - Spawns a CustomGoalZombie with Dart-defined AI
  Commands.register(
    'spawncustomzombie',
    execute: (context) {
      final player = context.source;
      final world = World.overworld;

      final entity = Entities.spawn(world, 'example_mod:custom_goal_zombie', player.precisePosition);
      if (entity != null) {
        context.sendFeedback('§d[CustomGoalZombie] §fSpawned a zombie with CUSTOM DART AI!');
        context.sendFeedback('§7Watch it spin when no player is nearby, and chase aggressively when you get close!');
        world.spawnParticles(Particles.smoke, player.precisePosition, count: 30, delta: Vec3(0.5, 1.0, 0.5));
        world.playSound(player.precisePosition, Sounds.levelUp, volume: 1.0);
        return 1;
      }
      context.sendError('§d[CustomGoalZombie] §fFailed to spawn entity');
      return 0;
    },
    description: 'Spawns a CustomGoalZombie with Dart-defined AI behaviors',
  );

  // /give_xp <amount> - Give experience points
  Commands.register(
    'give_xp',
    description: 'Give experience points',
    arguments: [
      const CommandArgument('amount', ArgumentType.integer),
    ],
    execute: (context) {
      final amount = context.requireArgument<int>('amount');
      context.source.giveExperience(amount);
      context.sendFeedback('\u00A7a\u2726 Gave $amount XP!');
      return 1;
    },
  );

  // /showcase_gui - Open the showcase GUI
  Commands.register(
    'showcase_gui',
    description: 'Open the showcase GUI',
    execute: (context) {
      ShowcaseScreen().show();
      return 1;
    },
  );

  print('Commands: Registered 11 custom commands');
}
