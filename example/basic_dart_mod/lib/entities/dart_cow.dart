import 'package:dart_mc/dart_mc.dart';

/// A friendly cow-like animal that can be bred with wheat.
///
/// Demonstrates: CustomAnimal with breeding mechanics.
/// This animal is passive and can be bred using wheat.
class DartCow extends CustomAnimal {
  DartCow()
      : super(
          id: 'basic_dart_mod:dart_cow',
          settings: AnimalSettings(
            maxHealth: 15,
            movementSpeed: 0.2,
            width: 0.9,
            height: 1.4,
            breedingItem: 'minecraft:wheat',
            model: EntityModel.quadruped(
              texture: 'textures/entity/dart_cow.png',
            ),
          ),
        );

  @override
  void onSpawn(int entityId, int worldId) {
    print('[DartCow] Moo! Spawned with entity ID: $entityId');
  }

  @override
  void onBreed(int entityId, int partnerId, int babyId) {
    print('[DartCow] Baby cow born! Parent: $entityId, Partner: $partnerId, Baby: $babyId');
  }

  @override
  void onDeath(int entityId, String damageSource) {
    print('[DartCow] A DartCow has died from: $damageSource');
  }
}
