import 'package:dart_mc/dart_mc.dart';

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
