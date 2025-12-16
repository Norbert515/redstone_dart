// basic_dart_mod - A Minecraft mod built with Redstone
//
// This is your mod's entry point. Register your blocks, entities,
// and other game objects here.

import 'dart:math';

// Dart MC API imports
import 'package:dart_mc/dart_mc.dart';

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

/// Main entry point for your mod.
///
/// This is called when the Dart VM is initialized by the native bridge.
void main() {
  print('Basic Dart Mod mod initialized!');

  // Initialize the native bridge
  Bridge.initialize();

  // Register proxy block handlers (required for custom blocks)
  Events.registerProxyBlockHandlers();

  // =========================================================================
  // Register your custom items here
  // Items must be registered BEFORE blocks that reference them as drops
  // =========================================================================
  ItemRegistry.register(DartItem());
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

  // Freeze the block registry (no more blocks can be registered after this)
  BlockRegistry.freeze();

  // =========================================================================
  // Register event handlers (optional)
  // =========================================================================
  Events.onBlockBreak((x, y, z, playerId) {
    // Called when ANY block is broken
    // Return EventResult.deny to prevent breaking
    return EventResult.allow;
  });

  Events.onTick((tick) {
    // Called every game tick (20 times per second)
    // Use for animations, timers, etc.
  });

  print('Basic Dart Mod ready with ${BlockRegistry.blockCount} custom blocks!');
}
