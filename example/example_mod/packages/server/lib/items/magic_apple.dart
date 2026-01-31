import 'package:dart_mod_server/dart_mod_server.dart';

/// Example custom food item with healing effects.
///
/// Demonstrates:
/// - CustomFood extending CustomItem
/// - FoodSettings with status effects
/// - onEat callback for additional effects
class MagicApple extends CustomFood {
  MagicApple()
      : super(
          id: 'example_mod:magic_apple',
          food: FoodSettings(
            nutrition: 4, // Same as regular apple
            saturationModifier: 1.2, // High saturation like golden apple
            alwaysEdible: true, // Can eat even when not hungry
            consumeSeconds: 1.0, // Faster than normal (1.6s default)
            effects: [
              // Regeneration II for 5 seconds
              StatusEffectInstance.regeneration(
                duration: 100, // 5 seconds = 100 ticks
                amplifier: 1, // Level II
              ),
              // Absorption I for 2 minutes
              StatusEffectInstance.absorption(
                duration: 2400, // 2 minutes = 2400 ticks
                amplifier: 0, // Level I
              ),
            ],
          ),
          model: ItemModel.generated(
            texture: 'assets/textures/item/healing_orb.png', // Reuse existing texture
          ),
          maxStackSize: 16, // Stack like golden apples
        );

  @override
  void onEat(int worldId, int playerId) {
    final player = Players.getPlayer(playerId);
    if (player == null) return;

    final world = World.overworld;

    // Additional custom effect: restore some health immediately
    player.health = (player.health + 4).clamp(0.0, player.maxHealth);

    // Visual feedback
    world.spawnParticles(
      Particles.heart,
      player.precisePosition + const Vec3(0, 1.5, 0),
      count: 8,
      delta: Vec3(0.5, 0.3, 0.5),
    );

    world.spawnParticles(
      Particles.enchant,
      player.precisePosition + const Vec3(0, 1, 0),
      count: 20,
      delta: Vec3(0.5, 0.5, 0.5),
    );

    // Sound effect
    world.playSound(player.precisePosition, Sounds.levelUp, volume: 0.5);

    // Message
    player.sendActionBar('§d✨ You feel rejuvenated! ✨');
  }
}
