import 'package:dart_mc/dart_mc.dart';

/// Registers all event handlers.
void registerEventHandlers() {
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
