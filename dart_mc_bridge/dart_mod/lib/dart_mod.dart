/// Main entry point for the Dart Minecraft mod.
///
/// This file is loaded by the native bridge when the Dart VM is initialized.
/// All event handlers should be registered here.
library dart_mod;

import 'src/bridge.dart';
import 'src/events.dart';
import 'src/types.dart';
import 'api/block_registry.dart';
import 'api/player.dart';
import 'api/world.dart';
import 'api/item.dart';
import 'api/inventory.dart';
import 'examples/example_blocks.dart';
import 'examples/nocterm_minecraft_example.dart';

export 'src/bridge.dart';
export 'src/events.dart';
export 'src/types.dart';
export 'api/block.dart';
export 'api/player.dart';
export 'api/world.dart';
export 'api/entity.dart';
export 'api/item.dart';
export 'api/inventory.dart';
export 'api/custom_block.dart';
export 'api/block_registry.dart';

/// Main entry point called when the Dart VM is initialized.
void main() {
  print('Dart Mod initialized!');

  // Initialize the native bridge
  Bridge.initialize();

  // Register proxy block handlers (for Dart-defined custom blocks)
  Events.registerProxyBlockHandlers();

  // =========================================================================
  // Register custom blocks defined in Dart
  // This MUST happen before the registry freezes (during mod initialization)
  // =========================================================================
  registerExampleBlocks();
  registerNoctermMinecraftBlocks();

  // Freeze the block registry (no more blocks can be registered after this)
  BlockRegistry.freeze();

  // Register event handlers
  Events.onBlockBreak((x, y, z, playerId) {
    print('Block broken at ($x, $y, $z) by player $playerId');
    return EventResult.allow;
  });

  Events.onBlockInteract((x, y, z, playerId, hand) {
    print('Block interacted at ($x, $y, $z) by player $playerId with hand $hand');
    return EventResult.allow;
  });

  Events.onTick((tick) {
    // Called every game tick (20 times per second)
    // Update nocterm animations
    noctermTick(tick);
  });

  // ===========================================================================
  // Player Connection Events - Welcome & Farewell
  // ===========================================================================

  Events.onPlayerJoin((player) {
    // Welcome message with title
    player.sendTitle(
      '§6Welcome!',
      subtitle: '§eEnjoy the Dart mod demo!',
      fadeIn: 10,
      stay: 60,
      fadeOut: 20,
    );

    // Chat welcome with instructions
    player.sendMessage('§6═══════════════════════════════════════');
    player.sendMessage('§6   Welcome to the §bDart Minecraft Mod§6!');
    player.sendMessage('§6═══════════════════════════════════════');
    player.sendMessage('§7Try out these custom blocks:');
    player.sendMessage('§a  • §fHealer Block §7- Heal to full health');
    player.sendMessage('§a  • §fLauncher Block §7- Launch into the air');
    player.sendMessage('§a  • §fLightning Rod §7- Summon lightning');
    player.sendMessage('§a  • §fMob Spawner §7- Spawn friendly mobs');
    player.sendMessage('§a  • §fTime/Weather Controller §7- Control world');
    player.sendMessage('§a  • §fGift Box §7- Random valuable items');
    player.sendMessage('§a  • §fParty Block §7- Celebration effects!');
    player.sendMessage('§6═══════════════════════════════════════');

    // Give starter kit
    player.inventory.giveItem(const ItemStack(Item.diamondSword, 1));
    player.inventory.giveItem(const ItemStack(Item.goldenApple, 5));
    player.inventory.giveItem(const ItemStack(Item.enderPearl, 3));

    // Spawn celebration particles around them
    final pos = player.precisePosition;
    World.overworld.spawnParticles(Particles.totemOfUndying, pos, count: 50, delta: const Vec3(1.0, 1.0, 1.0));
    World.overworld.playSound(pos, Sounds.levelUp);

    // Broadcast to other players
    for (final p in Players.getAllPlayers()) {
      if (p.id != player.id) {
        p.sendMessage('§a+ §f${player.name} §7joined the server');
      }
    }
  });

  Events.onPlayerLeave((player) {
    // Broadcast to other players
    for (final p in Players.getAllPlayers()) {
      if (p.id != player.id) {
        p.sendMessage('§c- §f${player.name} §7left the server');
      }
    }
  });

  // ===========================================================================
  // Chat Enhancement - Fun chat modifications
  // ===========================================================================

  Events.onPlayerChat = (player, message) {
    // Add sparkles to greetings
    if (message.toLowerCase().contains('hello') ||
        message.toLowerCase().contains('hi') ||
        message.toLowerCase().contains('hey')) {
      // Replace greeting with sparkly version
      final modified = message
          .replaceAll(RegExp(r'hello', caseSensitive: false), '§b✨ HELLO ✨§r')
          .replaceAll(RegExp(r'\bhi\b', caseSensitive: false), '§b✨ HI ✨§r')
          .replaceAll(RegExp(r'\bhey\b', caseSensitive: false), '§b✨ HEY ✨§r');
      return '§a${player.name}§r: $modified';
    }

    // Make "gg" more exciting
    if (message.toLowerCase() == 'gg') {
      return '§6${player.name}§r: §e⭐ GG! ⭐';
    }

    // Pass through unchanged
    return null;
  };

  // ===========================================================================
  // Entity Damage - Demo damage indication
  // ===========================================================================

  Events.onEntityDamage = (entity, source, amount) {
    // If it's a player, show damage in action bar
    if (entity.isPlayer) {
      final player = Player(entity.id);
      player.sendActionBar('§c-${amount.toStringAsFixed(1)} ❤ §7(from $source)');
    }
    return true; // Allow damage
  };

  // ===========================================================================
  // Server Lifecycle Events
  // ===========================================================================

  Events.onServerStarted(() {
    print('═══════════════════════════════════════════════════');
    print('   Dart Minecraft Mod - Server Ready!');
    print('   ${BlockRegistry.blockCount} custom blocks loaded');
    print('   All APIs initialized and ready');
    print('═══════════════════════════════════════════════════');
  });

  print('Event handlers registered!');
  print('Dart mod ready with ${BlockRegistry.blockCount} custom blocks!');
}
