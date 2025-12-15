/// Example custom entities demonstrating the entity API.
library;

import '../api/custom_entity.dart';
import '../api/entity_registry.dart';

/// A custom zombie with extra health and damage.
class CustomZombie extends CustomEntity {
  CustomZombie()
      : super(
          id: 'mymod:custom_zombie',
          settings: EntitySettings(
            width: 0.6,
            height: 1.95,
            maxHealth: 40.0,
            attackDamage: 5.0,
            movementSpeed: 0.3,
            spawnGroup: SpawnGroup.monster,
          ),
        );

  @override
  void onSpawn(int entityId, int worldId) {
    print('[CustomZombie] Spawned! Entity ID: $entityId');
  }

  @override
  void onTick(int entityId) {
    // Custom tick behavior - called 20 times per second
    // Keep this lightweight for performance!
  }

  @override
  void onDeath(int entityId, String damageSource) {
    print('[CustomZombie] Died from: $damageSource');
  }

  @override
  bool onDamage(int entityId, String damageSource, double amount) {
    print('[CustomZombie] Taking $amount damage from $damageSource');
    return true; // Allow damage
  }

  @override
  void onAttack(int entityId, int targetId) {
    print('[CustomZombie] Attacking entity: $targetId');
  }

  @override
  void onTargetAcquired(int entityId, int targetId) {
    print('[CustomZombie] Acquired target: $targetId');
  }
}

/// Register all example entities.
void registerExampleEntities() {
  print('Registering example entities...');
  EntityRegistry.register(CustomZombie());
  print('Registered ${EntityRegistry.entityCount} custom entities');
}
