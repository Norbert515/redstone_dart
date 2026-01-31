import 'package:dart_mod_server/dart_mod_server.dart';

/// Example custom helmet that gives night vision while wearing.
///
/// Demonstrates:
/// - CustomHelmet extending CustomArmor
/// - Custom ArmorMaterial with ruby-like stats
/// - onArmorTick for passive effects while equipped
class RubyHelmet extends CustomHelmet {
  /// Custom ruby armor material
  static final _rubyMaterial = ArmorMaterial(
    durability: 25, // Between iron (15) and diamond (33)
    protection: ArmorMaterial.makeProtection(2, 5, 6, 3), // boots, legs, chest, helmet
    enchantability: 15, // Good enchantability
    toughness: 1.0, // Some toughness like diamond
    repairItem: 'minecraft:redstone', // Repair with redstone (stand-in for ruby)
  );

  RubyHelmet()
      : super(
          id: 'example_mod:ruby_helmet',
          material: _rubyMaterial,
          model: ItemModel.generated(
            texture: 'assets/textures/item/dart_item.png', // Reuse existing texture
          ),
        );

  @override
  void onArmorTick(int worldId, int playerId) {
    final player = Players.getPlayer(playerId);
    if (player == null) return;

    final entity = LivingEntity(playerId);

    // Check if the player already has night vision
    if (!entity.hasEffect(StatusEffect.nightVision)) {
      // Apply night vision effect for 15 seconds (300 ticks)
      // We apply it regularly so it never runs out while wearing
      entity.addEffect(
        StatusEffect.nightVision,
        300, // 15 seconds
        amplifier: 0,
        ambient: true, // Less intrusive particles
        showParticles: false, // No particles for cleaner visuals
      );
    }
  }
}
