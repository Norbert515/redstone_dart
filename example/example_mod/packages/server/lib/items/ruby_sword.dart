import 'package:dart_mod_server/dart_mod_server.dart';

/// Example custom sword that sets targets on fire when hit.
///
/// Demonstrates:
/// - CustomSword extending CustomTool
/// - Using ToolMaterial for base stats
/// - Overriding onAttackEntity for custom hit effects
class RubySword extends CustomSword {
  RubySword()
      : super(
          id: 'example_mod:ruby_sword',
          material: ToolMaterial.diamond, // Diamond-tier stats
          model: ItemModel.handheld(
            texture: 'assets/textures/item/peer-schwert.png', // Reuse existing texture
          ),
        );

  @override
  bool onAttackEntity(int worldId, int attackerId, int targetId) {
    final target = Entity(targetId);
    final world = World.overworld;

    // Set the target on fire for 5 seconds
    target.setOnFire(5);

    // Visual effects - fire particles around the target
    world.spawnParticles(
      Particles.flame,
      target.position + const Vec3(0, 1, 0),
      count: 20,
      delta: Vec3(0.3, 0.5, 0.3),
    );

    // Sound effect
    world.playSound(target.position, 'minecraft:entity.blaze.shoot', volume: 0.5);

    // Notify the attacker
    final attacker = Players.getPlayer(attackerId);
    if (attacker != null) {
      attacker.sendActionBar('§6🔥 Target ignited!');
    }

    return true; // Allow the attack to proceed
  }
}
