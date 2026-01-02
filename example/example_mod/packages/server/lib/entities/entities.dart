// Barrel export file for all entities
export 'dart_cow.dart';
export 'dart_fireball.dart';
export 'dart_zombie.dart';
export 'custom_goal_zombie.dart';

import 'package:dart_mod_server/dart_mod_server.dart';

import 'dart_cow.dart';
import 'dart_fireball.dart';
import 'dart_zombie.dart';
import 'custom_goal_zombie.dart';

/// Registers all custom entities and freezes the entity registry.
void registerEntities() {
  // Register custom goals FIRST (before entities that use them)
  registerCustomGoals();

  EntityRegistry.register(DartZombie()); // Hostile mob that burns in daylight
  EntityRegistry.register(DartCow()); // Passive animal that can be bred
  EntityRegistry.register(DartFireball()); // Projectile entity
  EntityRegistry.register(CustomGoalZombie()); // Zombie with CUSTOM DART AI!
  EntityRegistry.freeze();
}
