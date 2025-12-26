import 'package:dart_mc/dart_mc.dart';

/// Orb that heals the player to full health
class HealingOrb extends CustomItem {
  HealingOrb()
      : super(
          id: 'example_mod:healing_orb',
          settings: const ItemSettings(maxStackSize: 16),
          model: ItemModel.generated(
              texture: 'assets/textures/item/healing_orb.png'),
        );

  @override
  ItemActionResult onUse(int worldId, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player != null) {
      player.health = player.maxHealth;
      player.sendMessage('\u00A7a\u2764 Fully healed!');
      World.overworld.spawnParticles(
        Particles.heart,
        player.precisePosition + const Vec3(0, 1, 0),
        count: 5,
      );
    }
    return ItemActionResult.success;
  }
}
