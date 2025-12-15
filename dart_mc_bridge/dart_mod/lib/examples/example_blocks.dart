/// Example custom blocks defined in Dart.
///
/// These demonstrate how to create custom Minecraft blocks entirely in Dart.
/// Now includes showcases for all our new APIs: Player, Entity, Inventory, World utilities!
library;

import 'dart:math';

import '../api/custom_block.dart';
import '../api/block_registry.dart';
import '../api/world.dart';
import '../api/block.dart';
import '../api/player.dart';
import '../api/entity.dart';
import '../api/item.dart';
import '../api/inventory.dart';
import '../src/bridge.dart';
import '../src/types.dart';
import 'demo_screen.dart';

/// Helper function to send a chat message to a player.
void _chat(int playerId, String message) {
  Bridge.sendChatMessage(playerId, message);
}

/// A simple custom block that sends chat messages when used.
class ExampleBlock extends CustomBlock {
  ExampleBlock()
      : super(
          id: 'dartmod:example_block',
          settings: BlockSettings(
            hardness: 2.0,
            resistance: 6.0,
          ),
        );

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    _chat(playerId, '§e[Dart] §fYou broke the example block at ($x, $y, $z)!');
    return true; // Allow break
  }

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    _chat(playerId, '§b[Dart] §fHello from Dart! This block is 100% defined in Dart code.');
    _chat(playerId, '§7Position: ($x, $y, $z)');
    return ActionResult.success;
  }
}

/// A counting block that tracks how many times it's been clicked.
class CounterBlock extends CustomBlock {
  static int _globalClickCount = 0;

  CounterBlock()
      : super(
          id: 'dartmod:counter_block',
          settings: BlockSettings(
            hardness: 1.5,
            resistance: 3.0,
          ),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    _globalClickCount++;
    _chat(playerId, '§a[Counter] §fClick count: §e$_globalClickCount');

    // Special messages at milestones
    if (_globalClickCount == 10) {
      _chat(playerId, '§6[Counter] §fWow, 10 clicks! Keep going!');
    } else if (_globalClickCount == 50) {
      _chat(playerId, '§d[Counter] §f50 clicks! You\'re dedicated!');
    } else if (_globalClickCount == 100) {
      _chat(playerId, '§c[Counter] §f100 CLICKS! You\'re a legend!');
    }

    return ActionResult.success;
  }
}

/// A block that prevents being broken (like bedrock).
class UnbreakableBlock extends CustomBlock {
  UnbreakableBlock()
      : super(
          id: 'dartmod:unbreakable_block',
          settings: BlockSettings(
            hardness: -1.0, // -1 = unbreakable in Minecraft
            resistance: 3600000.0, // Very high resistance
            requiresTool: true,
          ),
        );

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    _chat(playerId, '§c[Dart] §BUBUBUBUBUBU');
    return true; // Cancel break - make it truly unbreakable
  }

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    _chat(playerId, '§5[Dart] §fYou touched the unbreakable block!');
    _chat(playerId, '§8This block cannot be destroyed.');
    return ActionResult.consume;
  }
}

// =============================================================================
// World API Demo Blocks
// =============================================================================

/// A block that transforms a 5x5 area into grass and flowers when right-clicked.
/// Demonstrates the setBlock API.
class TerraformerBlock extends CustomBlock {
  TerraformerBlock()
      : super(
          id: 'dartmod:terraformer',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;
    _chat(playerId, '§a[Terraformer] §fTransforming area...');

    int count = 0;
    for (var dx = -2; dx <= 2; dx++) {
      for (var dz = -2; dz <= 2; dz++) {
        if (dx == 0 && dz == 0) continue; // Skip the block itself
        final pos = BlockPos(x + dx, y, z + dz);
        // Alternate between grass and flowers
        final block = ((dx + dz) % 2 == 0) ? Block.grass : Block('minecraft:dandelion');
        if (world.setBlock(pos, block)) count++;
      }
    }

    _chat(playerId, '§a[Terraformer] §fTransformed $count blocks!');
    return ActionResult.success;
  }
}

/// A block that inspects and reports what blocks are above and below it.
/// Demonstrates the getBlock and isAir APIs.
class BlockInspectorBlock extends CustomBlock {
  BlockInspectorBlock()
      : super(
          id: 'dartmod:inspector',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;

    // Check blocks in all directions
    final below = world.getBlock(BlockPos(x, y - 1, z));
    final above = world.getBlock(BlockPos(x, y + 1, z));

    _chat(playerId, '§6[Inspector] §fBlock Analysis:');
    _chat(playerId, '§7  Below: §f${below.id}');
    _chat(playerId, '§7  Above: §f${above.id}');

    if (world.isAir(BlockPos(x, y + 1, z))) {
      _chat(playerId, '§7  (Space above is empty)');
    }

    return ActionResult.success;
  }
}

/// A block that builds a tower of 5 blocks upward when right-clicked.
/// Demonstrates the setBlock + isAir combination.
class TowerBuilderBlock extends CustomBlock {
  TowerBuilderBlock()
      : super(
          id: 'dartmod:tower_builder',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;
    _chat(playerId, '§d[Tower] §fBuilding tower...');

    int built = 0;
    for (var dy = 1; dy <= 5; dy++) {
      final pos = BlockPos(x, y + dy, z);
      if (world.isAir(pos)) {
        // Alternate between bricks and stone bricks for a nice pattern
        final block = (dy % 2 == 0) ? Block('minecraft:stone_bricks') : Block('minecraft:bricks');
        if (world.setBlock(pos, block)) built++;
      } else {
        _chat(playerId, '§c[Tower] §fBlocked at height $dy!');
        break;
      }
    }

    _chat(playerId, '§d[Tower] §fBuilt $built blocks high!');
    return ActionResult.success;
  }
}

/// A block that turns all stone-like blocks in a 3x3x3 area into gold.
/// Demonstrates the getBlock + setBlock combination.
class MidasBlock extends CustomBlock {
  MidasBlock()
      : super(
          id: 'dartmod:midas',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;
    _chat(playerId, '§6[Midas] §fThe golden touch spreads...');

    int transformed = 0;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (var dz = -1; dz <= 1; dz++) {
          if (dx == 0 && dy == 0 && dz == 0) continue;

          final pos = BlockPos(x + dx, y + dy, z + dz);
          final block = world.getBlock(pos);

          // Turn stone-like blocks into gold
          if (block.id == 'minecraft:stone' ||
              block.id == 'minecraft:cobblestone' ||
              block.id == 'minecraft:andesite' ||
              block.id == 'minecraft:diorite' ||
              block.id == 'minecraft:granite') {
            world.setBlock(pos, Block('minecraft:gold_block'));
            transformed++;
          }
        }
      }
    }

    if (transformed > 0) {
      _chat(playerId, '§6[Midas] §fTransformed $transformed blocks to gold!');
    } else {
      _chat(playerId, '§6[Midas] §7No stone nearby to transform...');
    }

    return ActionResult.success;
  }
}

// =============================================================================
// Player API Demo Blocks
// =============================================================================

/// Healer Block - Heals player to full health and gives regeneration effect.
/// Demonstrates: Player health API, status effects, sounds, particles.
class HealerBlock extends CustomBlock {
  HealerBlock()
      : super(
          id: 'dartmod:healer',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    // Heal to full health
    final oldHealth = player.health;
    player.health = player.maxHealth;

    // Also restore food
    player.foodLevel = 20;
    player.saturation = 5.0;

    // Give regeneration effect (5 seconds, level 1)
    final entity = LivingEntity(playerId);
    entity.addEffect(StatusEffect.regeneration, 100, amplifier: 1);

    // Visual and audio feedback
    world.spawnParticles(Particles.heart, pos, count: 20, delta: Vec3(0.5, 0.5, 0.5));
    world.playSound(pos, Sounds.levelUp, volume: 0.8);

    player.sendMessage('§a[Healer] §fRestored §c${(player.maxHealth - oldHealth).toStringAsFixed(1)}§f health!');
    player.sendActionBar('§a❤ FULLY HEALED ❤');

    return ActionResult.success;
  }
}

/// Launcher Block - Launches player into the air with style!
/// Demonstrates: Player position, velocity via entity API, effects, particles.
class LauncherBlock extends CustomBlock {
  LauncherBlock()
      : super(
          id: 'dartmod:launcher',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final entity = Entity(playerId);
    final world = World.overworld;
    final pos = player.precisePosition;

    // Launch the player upward!
    entity.velocity = Vec3(0, 1.5, 0);

    // Give slow falling so they don't die
    final livingEntity = LivingEntity(playerId);
    livingEntity.addEffect(StatusEffect.slowFalling, 200, amplifier: 0); // 10 seconds

    // Visual effects
    world.spawnParticles(Particles.cloud, pos, count: 30, delta: Vec3(0.3, 0.1, 0.3));
    world.playSound(pos, 'minecraft:block.piston.extend', volume: 1.0, pitch: 0.8);

    player.sendActionBar('§b⬆ LAUNCHED! ⬆');
    player.sendMessage('§b[Launcher] §fEnjoy the view! Slow falling active for 10 seconds.');

    return ActionResult.success;
  }
}

/// Lightning Rod Block - Summons lightning where the player is looking.
/// Demonstrates: Player rotation (yaw/pitch), world lightning API, math for direction.
class LightningRodBlock extends CustomBlock {
  LightningRodBlock()
      : super(
          id: 'dartmod:lightning_rod',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final world = World.overworld;

    // Calculate position 10 blocks in front of player based on their facing
    final yawRad = player.yaw * (3.14159 / 180.0);
    final pitchRad = player.pitch * (3.14159 / 180.0);

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
          id: 'dartmod:mob_spawner',
          settings: BlockSettings(hardness: 1.5, resistance: 3.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
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
      world.playSound(spawnPos, 'minecraft:entity.experience_orb.pickup', volume: 0.8);

      player.sendMessage('§a[Spawner] §fSpawned $mobName§f!');
    } else {
      player.sendMessage('§c[Spawner] §fFailed to spawn mob.');
    }

    return ActionResult.success;
  }
}

// =============================================================================
// World Utility Demo Blocks
// =============================================================================

/// Time Controller Block - Cycles between day and night.
/// Demonstrates: World time API.
class TimeControllerBlock extends CustomBlock {
  TimeControllerBlock()
      : super(
          id: 'dartmod:time_controller',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    // Toggle between day (6000) and night (18000)
    final currentTime = world.timeOfDay;
    final isDay = currentTime >= 0 && currentTime < 12000;

    if (isDay) {
      world.timeOfDay = 18000; // Set to midnight
      player.sendActionBar('§9🌙 Night Time 🌙');
      player.sendMessage('§9[Time] §fSet to §bnight§f (18000 ticks)');
    } else {
      world.timeOfDay = 6000; // Set to noon
      player.sendActionBar('§e☀ Day Time ☀');
      player.sendMessage('§e[Time] §fSet to §6day§f (6000 ticks)');
    }

    world.playSound(pos, Sounds.click, volume: 0.5);

    return ActionResult.success;
  }
}

/// Weather Controller Block - Cycles through weather states.
/// Demonstrates: World weather API.
class WeatherControllerBlock extends CustomBlock {
  WeatherControllerBlock()
      : super(
          id: 'dartmod:weather_controller',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    // Cycle: clear -> rain -> thunder -> clear
    final currentWeather = world.weather;
    final Weather newWeather;
    final String weatherName;
    final String weatherIcon;

    switch (currentWeather) {
      case Weather.clear:
        newWeather = Weather.rain;
        weatherName = 'Rain';
        weatherIcon = '🌧';
      case Weather.rain:
        newWeather = Weather.thunder;
        weatherName = 'Thunderstorm';
        weatherIcon = '⛈';
      case Weather.thunder:
        newWeather = Weather.clear;
        weatherName = 'Clear';
        weatherIcon = '☀';
    }

    world.setWeather(newWeather, 12000); // 10 minutes

    player.sendActionBar('§b$weatherIcon $weatherName $weatherIcon');
    player.sendMessage('§b[Weather] §fSet to §e$weatherName');
    world.playSound(pos, Sounds.click, volume: 0.5);

    return ActionResult.success;
  }
}

/// Gift Box Block - Gives player random valuable items.
/// Demonstrates: Inventory giveItem API, random item selection.
class GiftBoxBlock extends CustomBlock {
  static final _gifts = [
    (Item.diamond, 1, 3, '§bDiamond'),
    (Item.emerald, 1, 5, '§aEmerald'),
    (Item.goldIngot, 2, 8, '§6Gold Ingot'),
    (Item.ironIngot, 4, 16, '§7Iron Ingot'),
    (Item.goldenApple, 1, 2, '§6Golden Apple'),
    (Item.enderPearl, 1, 4, '§5Ender Pearl'),
  ];
  static final _random = Random();

  GiftBoxBlock()
      : super(
          id: 'dartmod:gift_box',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    // Pick a random gift
    final gift = _gifts[_random.nextInt(_gifts.length)];
    final item = gift.$1;
    final minCount = gift.$2;
    final maxCount = gift.$3;
    final name = gift.$4;
    final count = minCount + _random.nextInt(maxCount - minCount + 1);

    // Give the item to the player
    player.inventory.giveItem(ItemStack(item, count));

    // Celebration effects
    world.spawnParticles(Particles.villagerHappy, pos, count: 25, delta: Vec3(0.5, 0.5, 0.5));
    world.spawnParticles(Particles.totemOfUndying, pos, count: 10, delta: Vec3(0.3, 0.3, 0.3));
    world.playSound(pos, Sounds.levelUp, volume: 0.8);

    player.sendMessage('§6[Gift] §fYou received §e${count}x $name§f!');
    player.sendActionBar('§6🎁 GIFT RECEIVED! 🎁');

    return ActionResult.success;
  }
}

/// Explosion Block - Creates a decorative explosion when broken.
/// Demonstrates: World explosion API with no block damage.
class ExplosionBlock extends CustomBlock {
  ExplosionBlock()
      : super(
          id: 'dartmod:explosion_block',
          settings: BlockSettings(hardness: 0.5, resistance: 0.5),
        );

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 0.5, z + 0.5);

    // Create explosion with no block damage (just visual + knockback)
    world.createExplosion(pos, 2.0, fire: false, mode: ExplosionMode.none);

    _chat(playerId, '§c[Boom] §fKABOOM! (No blocks harmed)');
    return true; // Allow the break
  }

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    _chat(playerId, '§c[Boom] §fBreak me for a surprise! §7(Safe explosion)');
    return ActionResult.success;
  }
}

/// Teleporter Block - Teleports player 50 blocks up.
/// Demonstrates: Player teleport API, particles at multiple locations.
class TeleporterBlock extends CustomBlock {
  TeleporterBlock()
      : super(
          id: 'dartmod:teleporter',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final world = World.overworld;
    final startPos = player.precisePosition;
    final endPos = startPos + Vec3(0, 50, 0);

    // Particles at start location
    world.spawnParticles(Particles.portal, startPos, count: 50, delta: Vec3(0.5, 1.0, 0.5));
    world.playSound(startPos, 'minecraft:entity.enderman.teleport', volume: 1.0);

    // Teleport player
    player.teleportPrecise(endPos);

    // Give slow falling for safety
    final entity = LivingEntity(playerId);
    entity.addEffect(StatusEffect.slowFalling, 400, amplifier: 0); // 20 seconds

    // Particles at destination
    world.spawnParticles(Particles.portal, endPos, count: 50, delta: Vec3(0.5, 1.0, 0.5));

    player.sendTitle('§5TELEPORTED!', subtitle: '§d50 blocks up • Slow falling active');
    player.sendMessage('§5[Teleporter] §fWhoosh! You\'re now 50 blocks higher.');

    return ActionResult.success;
  }
}

/// Party Block - Creates a celebration effect with title and particles.
/// Demonstrates: Player titles, multiple particle types, sounds.
class PartyBlock extends CustomBlock {
  PartyBlock()
      : super(
          id: 'dartmod:party_block',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    // Big title
    player.sendTitle('§6§lHEY X!', subtitle: '§e✨ Let\'s celebrate! ✨', fadeIn: 5, stay: 40, fadeOut: 10);

    // Lots of particles!
    world.spawnParticles(Particles.totemOfUndying, pos, count: 100, delta: Vec3(1.0, 1.5, 1.0), speed: 0.5);
    world.spawnParticles(Particles.firework, pos, count: 50, delta: Vec3(0.8, 1.0, 0.8), speed: 0.3);
    world.spawnParticles(Particles.note, pos, count: 20, delta: Vec3(0.5, 0.5, 0.5));

    // Totem sound (epic!)
    world.playSound(pos, Sounds.totem, volume: 1.0);

    // Give player some experience as a party favor
    player.giveExperience(100);

    player.sendMessage('§6[Party] §f🎉 You got §a100 XP§f as a party favor! 🎉');

    return ActionResult.success;
  }
}

/// Info Block - Displays comprehensive player stats.
/// Demonstrates: All player info APIs.
class InfoBlock extends CustomBlock {
  InfoBlock()
      : super(
          id: 'dartmod:info_block',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);

    player.sendMessage('§6═══════ Player Info ═══════');
    player.sendMessage('§7Name: §f${player.name}');
    player.sendMessage('§7Position: §f${player.position}');
    player.sendMessage('§7Health: §c${player.health.toStringAsFixed(1)}§7/§c${player.maxHealth.toStringAsFixed(1)} ❤');
    player.sendMessage('§7Food: §e${player.foodLevel}§7/§e20 🍖');
    player.sendMessage('§7Saturation: §e${player.saturation.toStringAsFixed(1)}');
    player.sendMessage('§7Game Mode: §a${player.gameMode.name}');
    player.sendMessage('§7XP Level: §b${player.experienceLevel}');
    player.sendMessage('§7On Ground: §f${player.isOnGround ? "Yes" : "No"}');
    player.sendMessage('§7Sneaking: §f${player.isSneaking ? "Yes" : "No"}');
    player.sendMessage('§7Flying: §f${player.isFlying ? "Yes" : "No"}');
    player.sendMessage('§6════════════════════════');

    return ActionResult.success;
  }
}

// =============================================================================
// GUI API Demo Blocks
// =============================================================================

/// GUI Demo Block - Opens a custom Dart screen when right-clicked.
/// Demonstrates: The new Screen/GuiGraphics GUI API.
///
/// This block showcases how to create and open custom screens entirely in Dart.
/// When a player right-clicks this block, it opens the DemoScreen which
/// demonstrates:
/// - Drawing text (centered, left-aligned)
/// - Filling rectangles with solid colors
/// - Gradient fills
/// - Drawing outlines
/// - Handling keyboard input (ESC to close)
/// - Handling mouse input (click counting)
/// - Animation using tick counts
class GuiDemoBlock extends CustomBlock {
  GuiDemoBlock()
      : super(
          id: 'dartmod:gui_demo',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    // Visual feedback when opening the screen
    world.spawnParticles(
      Particles.enchant,
      pos,
      count: 20,
      delta: Vec3(0.3, 0.5, 0.3),
    );
    world.playSound(pos, Sounds.click, volume: 0.5);

    // Send a message before opening
    player.sendMessage('§b[GUI Demo] §fOpening Dart GUI screen...');

    // Open the demo screen!
    showDemoScreen();

    return ActionResult.success;
  }

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    _chat(playerId, '§b[GUI Demo] §fGUI Demo Block broken!');
    return true; // Allow break
  }
}

// =============================================================================
// Container GUI API Demo Blocks
// =============================================================================

/// Container Demo Block - Opens a Dart container screen when right-clicked.
/// Demonstrates: The Container Screen API with real inventory slots.
///
/// This block showcases how to create container screens in Dart.
/// Container screens differ from regular screens in that:
/// - They have real inventory slots managed by Minecraft
/// - Items can be dragged, dropped, and shift-clicked
/// - Item synchronization is handled automatically
///
/// When a player right-clicks this block, Java creates the DartContainerMenu
/// on the server, which triggers the DartContainerScreen on the client.
/// Dart then receives callbacks to render the background and manage slots.
class ContainerDemoBlock extends CustomBlock {
  ContainerDemoBlock()
      : super(
          id: 'dartmod:container_demo',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    // Visual feedback when clicking the block
    world.spawnParticles(
      Particles.enchant,
      pos,
      count: 15,
      delta: Vec3(0.3, 0.5, 0.3),
    );
    world.playSound(pos, Sounds.click, volume: 0.5);

    // Send a message to the player
    player.sendMessage('§6[Container Demo] §fOpening Dart container screen...');
    player.sendMessage('§7(Note: Container is opened by the Java block)');

    // Note: The actual container opening is handled by Java.
    // This block needs to be placed by the Java DartContainerBlock
    // which implements MenuProvider and opens the DartContainerMenu.
    // The Dart side only handles the rendering via DemoContainerScreen.

    return ActionResult.success;
  }

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    _chat(playerId, '§6[Container Demo] §fContainer Demo Block broken!');
    return true; // Allow break
  }
}

/// Register all example blocks.
/// Call this during mod initialization.
void registerExampleBlocks() {
  print('Registering example Dart blocks...');

  // Basic demo blocks
  BlockRegistry.register(ExampleBlock());
  BlockRegistry.register(CounterBlock());
  BlockRegistry.register(UnbreakableBlock());

  // World API demo blocks
  BlockRegistry.register(TerraformerBlock());
  BlockRegistry.register(BlockInspectorBlock());
  BlockRegistry.register(TowerBuilderBlock());
  BlockRegistry.register(MidasBlock());

  // Player API demo blocks
  BlockRegistry.register(HealerBlock());
  BlockRegistry.register(LauncherBlock());
  BlockRegistry.register(LightningRodBlock());
  BlockRegistry.register(MobSpawnerBlock());

  // World utility demo blocks
  BlockRegistry.register(TimeControllerBlock());
  BlockRegistry.register(WeatherControllerBlock());
  BlockRegistry.register(GiftBoxBlock());
  BlockRegistry.register(ExplosionBlock());
  BlockRegistry.register(TeleporterBlock());
  BlockRegistry.register(PartyBlock());
  BlockRegistry.register(InfoBlock());

  // GUI API demo blocks
  BlockRegistry.register(GuiDemoBlock());

  // Container GUI API demo blocks
  BlockRegistry.register(ContainerDemoBlock());

  print('Example blocks registered: ${BlockRegistry.blockCount} blocks total');
}
