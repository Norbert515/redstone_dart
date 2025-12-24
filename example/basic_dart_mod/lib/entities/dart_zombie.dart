import 'package:dart_mc/dart_mc.dart';

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
