import 'package:dart_mod_server/dart_mod_server.dart';

/// A fireball projectile that explodes on impact.
///
/// Demonstrates: CustomProjectile with hit detection.
/// This projectile has low gravity and explodes when hitting blocks or entities.
class DartFireball extends CustomProjectile {
  DartFireball()
      : super(
          id: 'example_mod:dart_fireball',
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
