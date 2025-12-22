// basic_dart_mod - A Minecraft mod built with Redstone
//
// This is your mod's entry point. Register your blocks, entities,
// and other game objects here.
//
// This example showcases many dart_mc APIs:
// - Custom blocks with interactive behavior
// - Custom items with use callbacks
// - Commands (heal, feed, fly, spawn, time)
// - Crafting recipes (shaped and shapeless)
// - Loot table modifications
// - Event handlers (player join, death, damage, chat)

import 'dart:math';

// Dart MC API imports
import 'package:dart_mc/dart_mc.dart';
// Additional API imports (not yet exported from main package)
import 'package:dart_mc/api/commands.dart';
import 'package:dart_mc/api/recipes.dart';
import 'package:dart_mc/api/loot_tables.dart';

/// Example custom item that demonstrates the item system.
///
/// This item is dropped by HelloBlock and can be picked up by players.
class DartItem extends CustomItem {
  DartItem()
      : super(
          id: 'basic_dart_mod:dart_item',
          settings: ItemSettings(maxStackSize: 64),
          model: ItemModel.generated(texture: 'assets/textures/item/dart_item.png'),
        );
}

/// A stick made from obsidian - used to craft the Peer Schwert.
class ObsidianStick extends CustomItem {
  ObsidianStick()
      : super(
          id: 'basic_dart_mod:obsidian_stick',
          settings: ItemSettings(maxStackSize: 64),
          model: ItemModel.generated(texture: 'assets/textures/item/obsidian_stick.png'),
        );
}

/// A custom sword item - the Peer Schwert.
/// Summons lightning on hit!
class PeerSchwert extends CustomItem {
  PeerSchwert()
      : super(
          id: 'basic_dart_mod:peer_schwert',
          settings: ItemSettings(
            maxStackSize: 1, // Swords don't stack
            maxDamage: 250, // Durability (iron sword level)
            combat: CombatAttributes.sword(damage: 6.0),
          ),
          model: ItemModel.handheld(
            texture: 'assets/textures/item/peer-schwert.png',
          ),
        );

  @override
  bool onAttackEntity(int worldId, int attackerId, int targetId) {
    final target = Entity(targetId);
    final world = World.overworld;
    world.spawnLightning(target.position);
    return true;
  }
}

/// Example custom block that shows a message when right-clicked.
///
/// This demonstrates how to create custom blocks in Dart.
/// The block will appear in the creative menu under "Building Blocks".
/// When mined, it drops a DartItem instead of itself.
class HelloBlock extends CustomBlock {
  HelloBlock()
      : super(
          id: 'basic_dart_mod:hello_block',
          settings: BlockSettings(
            hardness: 4.0,
            resistance: 1.0,
            requiresTool: false,
          ),
          model: BlockModel.cubeAll(texture: 'assets/textures/block/hello_block.png'),
          drops: 'basic_dart_mod:dart_item',
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    // Get player info and send a message
    final player = Players.getPlayer(playerId);
    if (player != null) {
      player.sendMessage('Hello from Basic Dart Mod! You clicked at ($x, $y, $z)');
    }
    return ActionResult.success;
  }

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    print('HelloBlock broken at ($x, $y, $z) by player $playerId');
    return true; // Allow the block to be broken
  }
}

/// A block that transforms a 5x5 area into grass and flowers when right-clicked.
/// Demonstrates the setBlock API.
class TerraformerBlock extends CustomBlock {
  TerraformerBlock()
      : super(
          id: 'basic_dart_mod:terraformer',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;
    final player = Players.getPlayer(playerId);
    player?.sendMessage('§a[Terraformer] §fTransforming area...');

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

    player?.sendMessage('§a[Terraformer] §fTransformed $count blocks!');
    return ActionResult.success;
  }
}

/// A block that turns all stone-like blocks in a 3x3x3 area into gold.
/// Demonstrates the getBlock + setBlock combination.
class MidasBlock extends CustomBlock {
  MidasBlock()
      : super(
          id: 'basic_dart_mod:midas',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final world = World.overworld;
    final player = Players.getPlayer(playerId);
    player?.sendMessage('§6[Midas] §fThe golden touch spreads...');

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
      player?.sendMessage('§6[Midas] §fTransformed $transformed blocks to gold!');
    } else {
      player?.sendMessage('§6[Midas] §7No stone nearby to transform...');
    }

    return ActionResult.success;
  }
}

/// Lightning Rod Block - Summons lightning where the player is looking.
/// Demonstrates: Player rotation (yaw/pitch), world lightning API, math for direction.
class LightningRodBlock extends CustomBlock {
  LightningRodBlock()
      : super(
          id: 'basic_dart_mod:lightning_rod',
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

/// Party Block - Creates a celebration effect with title and particles.
/// Demonstrates: Player titles, multiple particle types, sounds.
class PartyBlock extends CustomBlock {
  PartyBlock()
      : super(
          id: 'basic_dart_mod:party_block',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player == null) return ActionResult.pass;

    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    // Big title
    player.sendTitle('§6§lPARTY TIME!', subtitle: '§e✨ Let\'s celebrate! ✨', fadeIn: 5, stay: 40, fadeOut: 10);

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

// =============================================================================
// NEW API SHOWCASE: Custom Blocks
// =============================================================================

/// Weather Control Block - Cycles through weather states and advances time.
/// Demonstrates: Weather API, time control, action bar messages, sneak detection.
class WeatherControlBlock extends CustomBlock {
  WeatherControlBlock()
      : super(
          id: 'basic_dart_mod:weather_control',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player == null) return ActionResult.pass;

    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    if (player.isSneaking) {
      // Sneak + right-click: Advance time by 1000 ticks
      final currentTime = world.timeOfDay;
      final newTime = (currentTime + 1000) % 24000;
      world.timeOfDay = newTime;

      final timeLabel = _getTimeLabel(newTime);
      player.sendActionBar('§e⏰ Time advanced to $timeLabel ($newTime ticks)');
      player.sendMessage('§e[Weather Control] §fAdvanced time to §a$timeLabel');
      world.playSound(pos, Sounds.click, volume: 0.8);
    } else {
      // Regular right-click: Cycle weather
      final currentWeather = world.weather;
      final Weather newWeather;
      final String weatherName;

      switch (currentWeather) {
        case Weather.clear:
          newWeather = Weather.rain;
          weatherName = '§9Rain';
        case Weather.rain:
          newWeather = Weather.thunder;
          weatherName = '§5Thunder';
        case Weather.thunder:
          newWeather = Weather.clear;
          weatherName = '§eClear';
      }

      world.setWeather(newWeather, 6000); // 5 minutes
      player.sendActionBar('§b☁ Weather changed to $weatherName');
      player.sendMessage('§b[Weather Control] §fWeather set to $weatherName §ffor 5 minutes');

      // Play appropriate sound
      if (newWeather == Weather.thunder) {
        world.playSound(pos, Sounds.thunder, volume: 0.5);
      } else {
        world.playSound(pos, Sounds.click, volume: 0.8);
      }
    }

    // Spawn particles around the block
    world.spawnParticles(Particles.enchant, pos, count: 30, delta: Vec3(0.5, 0.5, 0.5));

    return ActionResult.success;
  }

  String _getTimeLabel(int time) {
    if (time >= 0 && time < 6000) return 'Morning';
    if (time >= 6000 && time < 12000) return 'Noon';
    if (time >= 12000 && time < 18000) return 'Evening';
    return 'Night';
  }
}

/// Entity Radar Block - Finds and lists entities within 20 blocks.
/// Demonstrates: Entities.getEntitiesInRadius(), distance calculation, entity types.
class EntityRadarBlock extends CustomBlock {
  EntityRadarBlock()
      : super(
          id: 'basic_dart_mod:entity_radar',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
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

// =============================================================================
// NEW API SHOWCASE: Custom Items
// =============================================================================

/// Effect Wand - Applies effects to self or entities.
/// Demonstrates: Custom item onUse/onUseOnEntity, status effects, cooldowns.
class EffectWand extends CustomItem {
  // Track cooldown per player (simple in-memory, resets on mod reload)
  static final Map<int, int> _lastUseTick = {};
  static const int _cooldownTicks = 600; // 30 seconds

  EffectWand()
      : super(
          id: 'basic_dart_mod:effect_wand',
          settings: ItemSettings(maxStackSize: 1),
          model: ItemModel.generated(texture: 'assets/textures/item/dart_item.png'),
        );

  @override
  ItemActionResult onUse(int worldId, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player == null) return ItemActionResult.pass;

    final world = World.overworld;

    // Check cooldown
    final lastUse = _lastUseTick[playerId] ?? 0;
    final currentTick = world.gameTime;

    if (currentTick - lastUse < _cooldownTicks) {
      final remaining = ((_cooldownTicks - (currentTick - lastUse)) / 20).ceil();
      player.sendActionBar('§c⏳ Wand on cooldown: ${remaining}s');
      return ItemActionResult.fail;
    }

    // Apply speed and jump boost to the player
    final playerEntity = LivingEntity(playerId);
    playerEntity.addEffect(StatusEffect.speed, 600, amplifier: 1); // 30 seconds, Speed II
    playerEntity.addEffect(StatusEffect.jumpBoost, 600, amplifier: 1); // 30 seconds, Jump II

    _lastUseTick[playerId] = currentTick;

    player.sendMessage('§d[Effect Wand] §fYou feel faster and lighter!');
    player.sendActionBar('§d✨ Speed II + Jump Boost II (30s)');

    // Visual effects
    world.spawnParticles(Particles.witch, player.precisePosition, count: 30, delta: Vec3(0.5, 1.0, 0.5));
    world.playSound(player.precisePosition, Sounds.levelUp, volume: 0.8);

    return ItemActionResult.success;
  }

  @override
  ItemActionResult onUseOnEntity(int worldId, int entityId, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player == null) return ItemActionResult.pass;

    final world = World.overworld;
    final target = Entities.getTypedEntity(entityId);
    if (target == null) return ItemActionResult.pass;

    // Only apply to living entities
    if (target is! LivingEntity) {
      player.sendMessage('§c[Effect Wand] §fTarget must be a living entity!');
      return ItemActionResult.fail;
    }

    // Apply glowing and slowness to the target
    target.addEffect(StatusEffect.glowing, 600); // 30 seconds
    target.addEffect(StatusEffect.slowness, 600, amplifier: 1); // Slowness II

    player.sendMessage('§d[Effect Wand] §fTarget is now glowing and slowed!');
    player.sendActionBar('§d✨ Applied Glowing + Slowness II');

    // Visual effects
    world.spawnParticles(Particles.witch, target.position, count: 20, delta: Vec3(0.3, 0.5, 0.3));
    world.playSound(target.position, Sounds.anvil, volume: 0.5);

    return ItemActionResult.success;
  }
}

// =============================================================================
// CUSTOM ENTITIES SHOWCASE
// =============================================================================
//
// The entity system allows you to create custom mobs with Dart behavior.
// There are three base types:
//
// 1. CustomMonster - Hostile mobs that attack players (zombies, skeletons, etc.)
// 2. CustomAnimal - Passive mobs that can be bred (cows, pigs, etc.)
// 3. CustomProjectile - Throwable/shootable entities (arrows, fireballs, etc.)
//
// Each entity type has specific settings and lifecycle hooks you can override.
// =============================================================================

/// A hostile zombie-like mob that burns in daylight.
///
/// Demonstrates: CustomMonster with hostile AI behavior.
/// This mob will attack players on sight and burns in sunlight.
class DartZombie extends CustomMonster {
  DartZombie()
      : super(
          id: 'basic_dart_mod:dart_zombie',
          settings: MonsterSettings(
            maxHealth: 30,
            attackDamage: 4,
            movementSpeed: 0.25,
            burnsInDaylight: true,
            model: EntityModel.humanoid(
              texture: 'textures/entity/dart_zombie.png',
            ),
          ),
        );

  @override
  void onSpawn(int entityId, int worldId) {
    print('[DartZombie] Spawned with entity ID: $entityId in world: $worldId');
  }

  @override
  void onTick(int entityId) {
    // Custom behavior every tick - use sparingly for performance!
    // Example: Could add special abilities, check conditions, etc.
  }

  @override
  void onDeath(int entityId, String damageSource) {
    print('[DartZombie] Died from: $damageSource');
  }

  @override
  bool onDamage(int entityId, String damageSource, double amount) {
    // Example: Take half damage from fire
    if (damageSource.contains('fire')) {
      print('[DartZombie] Resisting fire damage!');
      // Still take damage but we logged it
    }
    return true; // Allow the damage
  }

  @override
  void onAttack(int entityId, int targetId) {
    print('[DartZombie] Attacking target: $targetId');
  }
}

/// A friendly cow-like animal that can be bred with wheat.
///
/// Demonstrates: CustomAnimal with breeding mechanics.
/// This animal is passive and can be bred using wheat.
class DartCow extends CustomAnimal {
  DartCow()
      : super(
          id: 'basic_dart_mod:dart_cow',
          settings: AnimalSettings(
            maxHealth: 15,
            movementSpeed: 0.2,
            width: 0.9,
            height: 1.4,
            breedingItem: 'minecraft:wheat',
            model: EntityModel.quadruped(
              texture: 'textures/entity/dart_cow.png',
            ),
          ),
        );

  @override
  void onSpawn(int entityId, int worldId) {
    print('[DartCow] Moo! Spawned with entity ID: $entityId');
  }

  @override
  void onBreed(int entityId, int partnerId, int babyId) {
    print('[DartCow] Baby cow born! Parent: $entityId, Partner: $partnerId, Baby: $babyId');
  }

  @override
  void onDeath(int entityId, String damageSource) {
    print('[DartCow] A DartCow has died from: $damageSource');
  }
}

/// A fireball projectile that explodes on impact.
///
/// Demonstrates: CustomProjectile with hit detection.
/// This projectile has low gravity and explodes when hitting blocks or entities.
class DartFireball extends CustomProjectile {
  DartFireball()
      : super(
          id: 'basic_dart_mod:dart_fireball',
          settings: const ProjectileSettings(
            width: 0.5,
            height: 0.5,
            gravity: 0.01, // Low gravity for longer range
            noClip: false,
          ),
        );

  @override
  void onSpawn(int entityId, int worldId) {
    print('[DartFireball] Launched with entity ID: $entityId');
  }

  @override
  void onHitEntity(int projectileId, int targetId) {
    print('[DartFireball] Hit entity: $targetId - dealing fire damage!');
    // The actual damage/explosion logic would be handled by the Java proxy
  }

  @override
  void onHitBlock(int projectileId, int x, int y, int z, String side) {
    print('[DartFireball] Hit block at ($x, $y, $z) from side: $side - exploding!');
    // The actual explosion logic would be handled by the Java proxy
  }
}

/// Main entry point for your mod.
///
/// This is called when the Dart VM is initialized by the native bridge.
void main() {
  print('Basic Dart Mod mod initialized!');

  // Initialize the native bridge
  Bridge.initialize();

  // Register proxy handlers (required for custom blocks and items)
  Events.registerProxyBlockHandlers();
  Events.registerProxyItemHandlers();

  // =========================================================================
  // Register your custom items here
  // Items must be registered BEFORE blocks that reference them as drops
  // =========================================================================
  ItemRegistry.register(DartItem());
  ItemRegistry.register(EffectWand()); // NEW: Effect wand item
  ItemRegistry.register(ObsidianStick()); // Obsidian stick for crafting
  ItemRegistry.register(PeerSchwert()); // Custom sword item
  ItemRegistry.freeze();

  // =========================================================================
  // Register your custom blocks here
  // This MUST happen before the registry freezes (during mod initialization)
  // =========================================================================
  BlockRegistry.register(HelloBlock());
  BlockRegistry.register(TerraformerBlock());
  BlockRegistry.register(MidasBlock());
  BlockRegistry.register(LightningRodBlock());
  BlockRegistry.register(MobSpawnerBlock());
  BlockRegistry.register(PartyBlock());
  // NEW: API showcase blocks
  BlockRegistry.register(WeatherControlBlock());
  BlockRegistry.register(EntityRadarBlock());

  // Freeze the block registry (no more blocks can be registered after this)
  BlockRegistry.freeze();

  // =========================================================================
  // Register custom entities
  // Demonstrates the Entity System API (CustomMonster, CustomAnimal, CustomProjectile)
  // =========================================================================
  EntityRegistry.register(DartZombie()); // Hostile mob that burns in daylight
  EntityRegistry.register(DartCow()); // Passive animal that can be bred
  EntityRegistry.register(DartFireball()); // Projectile entity
  EntityRegistry.freeze();

  // =========================================================================
  // NEW: Register custom commands
  // Demonstrates the Commands API
  // =========================================================================
  _registerCommands();

  // =========================================================================
  // NEW: Register crafting recipes
  // Demonstrates the Recipes API
  // =========================================================================
  _registerRecipes();

  // =========================================================================
  // NEW: Register loot table modifications
  // Demonstrates the LootTables API
  // =========================================================================
  _registerLootTables();

  // =========================================================================
  // Register event handlers
  // Demonstrates the Events API
  // =========================================================================
  _registerEventHandlers();

  print(
      'Basic Dart Mod ready with ${BlockRegistry.blockCount} custom blocks and ${EntityRegistry.entityCount} custom entities!');
  print('  Commands: /heal, /feed, /fly, /spawn, /time, /spawnzombie, /spawncow, /fireball');
  print('  Items: DartItem, EffectWand');
  print('  Blocks: HelloBlock, TerraformerBlock, MidasBlock, LightningRodBlock,');
  print('          MobSpawnerBlock, PartyBlock, WeatherControlBlock, EntityRadarBlock');
  print('  Entities: DartZombie (monster), DartCow (animal), DartFireball (projectile)');
}

// =============================================================================
// Commands Registration
// =============================================================================

void _registerCommands() {
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

      final entity = Entities.spawn(world, 'basic_dart_mod:dart_zombie', player.precisePosition);
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

      final entity = Entities.spawn(world, 'basic_dart_mod:dart_cow', player.precisePosition);
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

      final entity = Entities.spawn(world, 'basic_dart_mod:dart_fireball', spawnPos);
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

  print('Commands: Registered 8 custom commands');
}

// =============================================================================
// Recipes Registration
// =============================================================================

void _registerRecipes() {
  // Shaped recipe: HelloBlock (diamond + redstone pattern)
  Recipes.shaped(
    'basic_dart_mod:hello_block',
    pattern: [
      'DRD',
      'RSR',
      'DRD',
    ],
    keys: {
      'D': 'minecraft:diamond',
      'R': 'minecraft:redstone',
      'S': 'minecraft:stone',
    },
    result: 'basic_dart_mod:hello_block',
  );

  // Shapeless recipe: DartItem from stick + diamond
  Recipes.shapeless(
    'basic_dart_mod:dart_item',
    ingredients: ['minecraft:stick', 'minecraft:diamond'],
    result: 'basic_dart_mod:dart_item',
    count: 4,
  );

  // Shaped recipe: Weather Control Block
  Recipes.shaped(
    'basic_dart_mod:weather_control',
    pattern: [
      'LGL',
      'GDG',
      'LGL',
    ],
    keys: {
      'L': 'minecraft:lapis_lazuli',
      'G': 'minecraft:gold_ingot',
      'D': 'minecraft:diamond',
    },
    result: 'basic_dart_mod:weather_control',
  );

  // Shaped recipe: Entity Radar Block
  Recipes.shaped(
    'basic_dart_mod:entity_radar',
    pattern: [
      'ERE',
      'RCR',
      'ERE',
    ],
    keys: {
      'E': 'minecraft:ender_pearl',
      'R': 'minecraft:redstone',
      'C': 'minecraft:compass',
    },
    result: 'basic_dart_mod:entity_radar',
  );

  // Shaped recipe: Effect Wand
  Recipes.shaped(
    'basic_dart_mod:effect_wand',
    pattern: [
      '  A',
      ' B ',
      'B  ',
    ],
    keys: {
      'A': 'minecraft:amethyst_shard',
      'B': 'minecraft:blaze_rod',
    },
    result: 'basic_dart_mod:effect_wand',
  );

  // Smelting recipe: Cook DartItem into emerald
  Recipes.smelting(
    'basic_dart_mod:smelt_dart_item',
    input: 'basic_dart_mod:dart_item',
    result: 'minecraft:emerald',
    experience: 1.0,
  );

  // Shaped recipe: Obsidian Stick (stick + 2 obsidian)
  Recipes.shaped(
    'basic_dart_mod:obsidian_stick',
    pattern: [
      'O',
      'O',
      'S',
    ],
    keys: {
      'O': 'minecraft:obsidian',
      'S': 'minecraft:stick',
    },
    result: 'basic_dart_mod:obsidian_stick',
    count: 1,
  );

  // Shaped recipe: Peer Schwert (obsidian stick + 2 obsidian)
  Recipes.shaped(
    'basic_dart_mod:peer_schwert',
    pattern: [
      'O',
      'O',
      'I',
    ],
    keys: {
      'O': 'minecraft:obsidian',
      'I': 'basic_dart_mod:obsidian_stick',
    },
    result: 'basic_dart_mod:peer_schwert',
    count: 1,
  );

  print('Recipes: Registered 8 custom recipes');
}

// =============================================================================
// Loot Tables Registration
// =============================================================================

void _registerLootTables() {
  // Zombies have 10% chance to drop DartItem
  LootTables.modify('minecraft:entities/zombie', (builder) {
    builder.addItem(
      'basic_dart_mod:dart_item',
      chance: 0.10,
      minCount: 1,
      maxCount: 1,
    );
  });

  // Skeletons have 5% chance to drop HelloBlock
  LootTables.modify('minecraft:entities/skeleton', (builder) {
    builder.addItem(
      'basic_dart_mod:hello_block',
      chance: 0.05,
      minCount: 1,
      maxCount: 1,
    );
  });

  // Creepers drop extra gunpowder with looting bonus
  LootTables.modify('minecraft:entities/creeper', (builder) {
    builder.addItemWithFunctions(
      'minecraft:gunpowder',
      [
        LootFunction.setCount(1, 2),
        LootFunction.lootingEnchant(min: 0, max: 2),
      ],
      chance: 0.5,
    );
  });

  // Endermen have rare chance to drop Effect Wand
  LootTables.modify('minecraft:entities/enderman', (builder) {
    builder.addItemWithCondition(
      'basic_dart_mod:effect_wand',
      LootCondition.randomChanceWithLooting(0.02, lootingMultiplier: 0.01),
    );
  });

  print('LootTables: Added 4 loot table modifications');
}

// =============================================================================
// Event Handlers Registration
// =============================================================================

void _registerEventHandlers() {
  // Player join event - Welcome message with title
  Events.onPlayerJoin((player) {
    player.sendTitle(
      '§6Welcome!',
      subtitle: '§e${player.name} joined the server',
      fadeIn: 10,
      stay: 60,
      fadeOut: 20,
    );
    player.sendMessage('§a[Basic Dart Mod] §fWelcome, §b${player.name}§f!');
    player.sendMessage('§7Try the new commands: /heal, /feed, /fly, /spawn, /dtime');
  });

  // Player death event - Custom death message
  Events.onPlayerDeath = (player, damageSource) {
    // Return a custom death message, or null for default
    if (damageSource.contains('fall')) {
      return '§c${player.name}§f believed they could fly... they were wrong.';
    }
    if (damageSource.contains('explosion')) {
      return '§c${player.name}§f went out with a bang!';
    }
    // Return null for default death message
    return null;
  };

  // Entity damage event - Reduce fall damage by 50%
  Events.onEntityDamage = (entity, damageSource, amount) {
    if (damageSource.contains('fall')) {
      // Reduce fall damage by 50%
      if (entity is LivingEntity) {
        final reducedDamage = amount * 0.5;
        entity.hurt(reducedDamage);
        return false; // Cancel the original damage (we applied reduced damage)
      }
    }
    return true; // Allow normal damage
  };

  // Player chat event - Add [MOD] prefix to messages
  Events.onPlayerChat = (player, message) {
    // Modify the message to add a prefix
    return '§7[MOD]§f $message';
  };

  // Block break event (already exists, but let's enhance it)
  Events.onBlockBreak((x, y, z, playerId) {
    // Just allow all breaks - this is a showcase of the event
    return EventResult.allow;
  });

  // Tick listener for periodic effects
  Events.addTickListener((tick) {
    // Every 5 minutes (6000 ticks), show a reminder
    if (tick > 0 && tick % 6000 == 0) {
      for (final player in Players.getAllPlayers()) {
        player.sendActionBar('§7Basic Dart Mod is running!');
      }
    }
  });

  print('Events: Registered 6 event handlers');
}
