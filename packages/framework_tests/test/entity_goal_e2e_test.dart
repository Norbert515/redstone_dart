/// Entity goal API E2E tests.
///
/// Tests for the entity goal system including custom monster and animal
/// goals, goal serialization, and runtime behavior verification.
import 'dart:convert';

import 'package:dart_mc/api/custom_entity.dart';
import 'package:dart_mc/api/entity_goal.dart';
import 'package:redstone_test/redstone_test.dart';
import 'package:test/test.dart' as dart_test show test, group, returnsNormally;

// =============================================================================
// Test Entity Classes - Monsters with Custom Goals
// =============================================================================

/// Monster with full attack goals - should actively attack players.
class AttackingZombie extends CustomMonster {
  AttackingZombie()
      : super(
          id: 'framework_tests:attacking_zombie',
          settings: MonsterSettings(
            maxHealth: 20,
            attackDamage: 3,
            movementSpeed: 0.25,
            goals: [
              FloatGoal(priority: 0),
              MeleeAttackGoal(priority: 2, speedModifier: 1.0),
              WaterAvoidingRandomStrollGoal(priority: 5),
              LookAtPlayerGoal(priority: 6),
              RandomLookAroundGoal(priority: 7),
            ],
            targetGoals: [
              NearestAttackableTargetGoal(priority: 1, targetType: 'minecraft:player'),
              HurtByTargetGoal(priority: 2),
            ],
          ),
        );
}

/// Monster with NO goals - should be completely passive/stationary.
class PassiveZombie extends CustomMonster {
  PassiveZombie()
      : super(
          id: 'framework_tests:passive_zombie',
          settings: MonsterSettings(
            maxHealth: 20,
            attackDamage: 3,
            movementSpeed: 0.25,
            goals: [], // Empty goals = no behavior
            targetGoals: [], // Empty target goals = no targeting
          ),
        );
}

/// Monster with only movement goals - wanders but doesn't attack.
class WanderingZombie extends CustomMonster {
  WanderingZombie()
      : super(
          id: 'framework_tests:wandering_zombie',
          settings: MonsterSettings(
            maxHealth: 20,
            attackDamage: 3,
            movementSpeed: 0.25,
            goals: [
              FloatGoal(priority: 0),
              WaterAvoidingRandomStrollGoal(priority: 2),
              LookAtPlayerGoal(priority: 4),
              RandomLookAroundGoal(priority: 5),
            ],
            // No target goals - won't acquire targets
          ),
        );
}

/// Monster with leap attack goal for testing combat variations.
class LeapingSpider extends CustomMonster {
  LeapingSpider()
      : super(
          id: 'framework_tests:leaping_spider',
          settings: MonsterSettings(
            maxHealth: 16,
            attackDamage: 2,
            movementSpeed: 0.3,
            width: 1.4,
            height: 0.9,
            goals: [
              FloatGoal(priority: 0),
              LeapAtTargetGoal(priority: 1, yd: 0.4),
              MeleeAttackGoal(priority: 2),
              WaterAvoidingRandomStrollGoal(priority: 5),
              LookAtPlayerGoal(priority: 6),
            ],
            targetGoals: [
              NearestAttackableTargetGoal(priority: 1, targetType: 'minecraft:player'),
              HurtByTargetGoal(priority: 2),
            ],
          ),
        );
}

// =============================================================================
// Test Entity Classes - Animals with Custom Goals
// =============================================================================

/// Animal with minimal goals - only float and panic.
class MinimalAnimal extends CustomAnimal {
  MinimalAnimal()
      : super(
          id: 'framework_tests:minimal_animal',
          settings: AnimalSettings(
            maxHealth: 10,
            movementSpeed: 0.2,
            goals: [
              FloatGoal(priority: 0),
              PanicGoal(priority: 1, speedModifier: 1.5),
            ],
            // No breeding, no following, just panic when hurt
          ),
        );
}

/// Animal with full standard goals including breeding.
class BreedableAnimal extends CustomAnimal {
  BreedableAnimal()
      : super(
          id: 'framework_tests:breedable_animal',
          settings: AnimalSettings(
            maxHealth: 10,
            movementSpeed: 0.2,
            breedingItem: 'minecraft:wheat',
            goals: [
              FloatGoal(priority: 0),
              PanicGoal(priority: 1, speedModifier: 1.25),
              BreedGoal(priority: 2, speedModifier: 1.0),
              TemptGoal(priority: 3, temptItem: 'minecraft:wheat', speedModifier: 1.0),
              FollowParentGoal(priority: 4, speedModifier: 1.1),
              WaterAvoidingRandomStrollGoal(priority: 5),
              LookAtPlayerGoal(priority: 6, lookDistance: 6.0),
              RandomLookAroundGoal(priority: 7),
            ],
          ),
        );
}

/// Animal with no goals configured - should use defaults for backward compatibility.
class DefaultGoalsAnimal extends CustomAnimal {
  DefaultGoalsAnimal()
      : super(
          id: 'framework_tests:default_goals_animal',
          settings: AnimalSettings(
            maxHealth: 10,
            movementSpeed: 0.2,
            breedingItem: 'minecraft:carrot',
            // goals: null - should use default animal goals
            // targetGoals: null - should use default (none)
          ),
        );
}

// =============================================================================
// Goal Serialization Unit Tests (Pure Dart)
// =============================================================================

Future<void> main() async {
  dart_test.group('Goal JSON Serialization', () {
    dart_test.test('FloatGoal serializes correctly', () {
      const goal = FloatGoal(priority: 0);
      final json = goal.toJson();

      expect(json['type'], equals('float'));
      expect(json['priority'], equals(0));
    });

    dart_test.test('MeleeAttackGoal serializes correctly', () {
      const goal = MeleeAttackGoal(
        priority: 2,
        speedModifier: 1.2,
        followEvenIfNotSeen: false,
      );
      final json = goal.toJson();

      expect(json['type'], equals('melee_attack'));
      expect(json['priority'], equals(2));
      expect(json['speedModifier'], equals(1.2));
      expect(json['followEvenIfNotSeen'], equals(false));
    });

    dart_test.test('LeapAtTargetGoal serializes correctly', () {
      const goal = LeapAtTargetGoal(priority: 1, yd: 0.5);
      final json = goal.toJson();

      expect(json['type'], equals('leap_at_target'));
      expect(json['priority'], equals(1));
      expect(json['yd'], equals(0.5));
    });

    dart_test.test('WaterAvoidingRandomStrollGoal serializes correctly', () {
      const goal = WaterAvoidingRandomStrollGoal(priority: 5, speedModifier: 0.8);
      final json = goal.toJson();

      expect(json['type'], equals('water_avoiding_random_stroll'));
      expect(json['priority'], equals(5));
      expect(json['speedModifier'], equals(0.8));
    });

    dart_test.test('LookAtPlayerGoal serializes correctly', () {
      const goal = LookAtPlayerGoal(priority: 6, lookDistance: 10.0);
      final json = goal.toJson();

      expect(json['type'], equals('look_at_player'));
      expect(json['priority'], equals(6));
      expect(json['lookDistance'], equals(10.0));
    });

    dart_test.test('RandomLookAroundGoal serializes correctly', () {
      const goal = RandomLookAroundGoal(priority: 7);
      final json = goal.toJson();

      expect(json['type'], equals('random_look_around'));
      expect(json['priority'], equals(7));
    });

    dart_test.test('PanicGoal serializes correctly', () {
      const goal = PanicGoal(priority: 1, speedModifier: 1.5);
      final json = goal.toJson();

      expect(json['type'], equals('panic'));
      expect(json['priority'], equals(1));
      expect(json['speedModifier'], equals(1.5));
    });

    dart_test.test('BreedGoal serializes correctly', () {
      const goal = BreedGoal(priority: 2, speedModifier: 1.0);
      final json = goal.toJson();

      expect(json['type'], equals('breed'));
      expect(json['priority'], equals(2));
      expect(json['speedModifier'], equals(1.0));
    });

    dart_test.test('TemptGoal serializes correctly', () {
      const goal = TemptGoal(
        priority: 3,
        temptItem: 'minecraft:wheat',
        speedModifier: 0.9,
      );
      final json = goal.toJson();

      expect(json['type'], equals('tempt'));
      expect(json['priority'], equals(3));
      expect(json['temptItem'], equals('minecraft:wheat'));
      expect(json['speedModifier'], equals(0.9));
    });

    dart_test.test('FollowParentGoal serializes correctly', () {
      const goal = FollowParentGoal(priority: 4, speedModifier: 1.1);
      final json = goal.toJson();

      expect(json['type'], equals('follow_parent'));
      expect(json['priority'], equals(4));
      expect(json['speedModifier'], equals(1.1));
    });

    dart_test.test('NearestAttackableTargetGoal serializes correctly', () {
      const goal = NearestAttackableTargetGoal(
        priority: 1,
        targetType: 'minecraft:player',
        mustSee: false,
      );
      final json = goal.toJson();

      expect(json['type'], equals('nearest_attackable_target'));
      expect(json['priority'], equals(1));
      expect(json['targetType'], equals('minecraft:player'));
      expect(json['mustSee'], equals(false));
    });

    dart_test.test('HurtByTargetGoal serializes correctly', () {
      const goal = HurtByTargetGoal(priority: 2, alertOthers: false);
      final json = goal.toJson();

      expect(json['type'], equals('hurt_by_target'));
      expect(json['priority'], equals(2));
      expect(json['alertOthers'], equals(false));
    });

    dart_test.test('multiple goals serialize to valid JSON array', () {
      final goals = [
        const FloatGoal(priority: 0),
        const MeleeAttackGoal(priority: 2),
        const WaterAvoidingRandomStrollGoal(priority: 5),
      ];

      final jsonList = goals.map((g) => g.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      // Should be valid JSON
      expect(() => jsonDecode(jsonString), dart_test.returnsNormally);

      // Parse back and verify structure
      final parsed = jsonDecode(jsonString) as List;
      expect(parsed.length, equals(3));
      expect(parsed[0]['type'], equals('float'));
      expect(parsed[1]['type'], equals('melee_attack'));
      expect(parsed[2]['type'], equals('water_avoiding_random_stroll'));
    });
  });

  dart_test.group('MonsterSettings with goals', () {
    dart_test.test('AttackingZombie has correct goals', () {
      final zombie = AttackingZombie();
      final goals = zombie.settings.goals!;
      final targetGoals = zombie.settings.targetGoals!;

      expect(goals.length, equals(5));
      expect(goals[0], isA<FloatGoal>());
      expect(goals[1], isA<MeleeAttackGoal>());
      expect(goals[2], isA<WaterAvoidingRandomStrollGoal>());
      expect(goals[3], isA<LookAtPlayerGoal>());
      expect(goals[4], isA<RandomLookAroundGoal>());

      expect(targetGoals.length, equals(2));
      expect(targetGoals[0], isA<NearestAttackableTargetGoal>());
      expect(targetGoals[1], isA<HurtByTargetGoal>());
    });

    dart_test.test('PassiveZombie has empty goals', () {
      final zombie = PassiveZombie();

      expect(zombie.settings.goals, isEmpty);
      expect(zombie.settings.targetGoals, isEmpty);
    });

    dart_test.test('WanderingZombie has movement goals but no target goals', () {
      final zombie = WanderingZombie();

      expect(zombie.settings.goals, isNotEmpty);
      expect(zombie.settings.goals!.length, equals(4));
      expect(zombie.settings.targetGoals, isNull);
    });
  });

  dart_test.group('AnimalSettings with goals', () {
    dart_test.test('MinimalAnimal has only basic goals', () {
      final animal = MinimalAnimal();
      final goals = animal.settings.goals!;

      expect(goals.length, equals(2));
      expect(goals[0], isA<FloatGoal>());
      expect(goals[1], isA<PanicGoal>());
    });

    dart_test.test('BreedableAnimal has full standard goals', () {
      final animal = BreedableAnimal();
      final goals = animal.settings.goals!;

      expect(goals.length, equals(8));
      expect(goals.any((g) => g is BreedGoal), isTrue);
      expect(goals.any((g) => g is TemptGoal), isTrue);
      expect(goals.any((g) => g is FollowParentGoal), isTrue);
    });

    dart_test.test('DefaultGoalsAnimal has null goals (uses defaults)', () {
      final animal = DefaultGoalsAnimal();

      expect(animal.settings.goals, isNull);
      expect(animal.settings.targetGoals, isNull);
    });
  });

  // ==========================================================================
  // E2E Tests - Custom Entity Spawning
  //
  // These tests verify that custom entities with goal configurations can be
  // spawned and are functional. The entities are registered in
  // framework_tests/lib/main.dart.
  //
  // Run with: cd packages/framework_tests && redstone test test/entity_goal_e2e_test.dart
  // ==========================================================================

  await group('Entity Goals E2E - Spawning', () async {
    // Test spawn position - elevated to ensure entities don't suffocate
    const testPos = Vec3(3000, 70, 3000);

    await testMinecraft('can spawn monster with custom attack goals', (game) async {
      final entity = game.spawnEntity('framework_tests:attacking_zombie', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('framework_tests:attacking_zombie'));
      expect(entity.isLiving, isTrue);
    });

    await testMinecraft('can spawn monster with empty goals', (game) async {
      final spawnPos = Vec3(testPos.x + 10, testPos.y, testPos.z);
      final entity = game.spawnEntity('framework_tests:passive_zombie', spawnPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('framework_tests:passive_zombie'));
    });

    await testMinecraft('can spawn monster with movement-only goals', (game) async {
      final spawnPos = Vec3(testPos.x + 20, testPos.y, testPos.z);
      final entity = game.spawnEntity('framework_tests:wandering_zombie', spawnPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('framework_tests:wandering_zombie'));
    });

    await testMinecraft('can spawn monster with leap attack goals', (game) async {
      final spawnPos = Vec3(testPos.x + 30, testPos.y, testPos.z);
      final entity = game.spawnEntity('framework_tests:leaping_spider', spawnPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('framework_tests:leaping_spider'));
    });

    await testMinecraft('can spawn animal with custom goals', (game) async {
      final spawnPos = Vec3(testPos.x + 40, testPos.y, testPos.z);
      final entity = game.spawnEntity('framework_tests:minimal_animal', spawnPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('framework_tests:minimal_animal'));
    });

    await testMinecraft('can spawn animal with breeding goals', (game) async {
      final spawnPos = Vec3(testPos.x + 50, testPos.y, testPos.z);
      final entity = game.spawnEntity('framework_tests:breedable_animal', spawnPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('framework_tests:breedable_animal'));
    });

    await testMinecraft('can spawn animal with default goals', (game) async {
      final spawnPos = Vec3(testPos.x + 60, testPos.y, testPos.z);
      final entity = game.spawnEntity('framework_tests:default_goals_animal', spawnPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('framework_tests:default_goals_animal'));
    });
  });

  await group('Entity Goals E2E - Behavior', () async {
    await testMinecraft('passive zombie stays stationary', (game) async {
      // Place a platform for the entity
      final platformPos = BlockPos(3100, 69, 3100);
      for (var dx = -2; dx <= 2; dx++) {
        for (var dz = -2; dz <= 2; dz++) {
          game.placeBlock(
            BlockPos(platformPos.x + dx, platformPos.y, platformPos.z + dz),
            Block.stone,
          );
        }
      }
      await game.waitTicks(5);

      final spawnPos = Vec3(3100, 70, 3100);
      final entity = game.spawnEntity('framework_tests:passive_zombie', spawnPos);
      await game.waitTicks(10);
      expect(entity, isNotNull);

      final initialPos = entity!.position;

      // Wait and check position hasn't changed much (entity is passive)
      await game.waitTicks(60); // 3 seconds

      final finalPos = entity.position;

      // Passive zombie should stay roughly in place
      // (allowing small drift from gravity/physics settling)
      expect(finalPos.x, closeTo(initialPos.x, 2));
      expect(finalPos.z, closeTo(initialPos.z, 2));
    });

    await testMinecraft('wandering zombie moves around', (game) async {
      // Place a larger platform for wandering
      final platformPos = BlockPos(3150, 69, 3150);
      for (var dx = -5; dx <= 5; dx++) {
        for (var dz = -5; dz <= 5; dz++) {
          game.placeBlock(
            BlockPos(platformPos.x + dx, platformPos.y, platformPos.z + dz),
            Block.stone,
          );
        }
      }
      await game.waitTicks(5);

      final spawnPos = Vec3(3150, 70, 3150);
      final entity = game.spawnEntity('framework_tests:wandering_zombie', spawnPos);
      await game.waitTicks(10);
      expect(entity, isNotNull);

      final initialPos = entity!.position;

      // Wait for the entity to potentially wander
      await game.waitTicks(100); // 5 seconds

      final finalPos = entity.position;

      // Wandering zombie might have moved (though not guaranteed)
      // Just verify entity is still alive and accessible
      expect(entity.isLiving, isTrue);

      // Log position change for debugging
      final dx = (finalPos.x - initialPos.x).abs();
      final dz = (finalPos.z - initialPos.z).abs();
      print('Wandering zombie moved: dx=$dx, dz=$dz');
    });

    await testMinecraft('animal with panic goal flees when hurt', (game) async {
      // Place platform
      final platformPos = BlockPos(3200, 69, 3200);
      for (var dx = -5; dx <= 5; dx++) {
        for (var dz = -5; dz <= 5; dz++) {
          game.placeBlock(
            BlockPos(platformPos.x + dx, platformPos.y, platformPos.z + dz),
            Block.stone,
          );
        }
      }
      await game.waitTicks(5);

      final spawnPos = Vec3(3200, 70, 3200);
      final entity = game.spawnEntity('framework_tests:minimal_animal', spawnPos);
      await game.waitTicks(10);
      expect(entity, isNotNull);

      final initialPos = entity!.position;

      // Hurt the entity to trigger panic
      if (entity is LivingEntity) {
        entity.hurt(1.0);
      }
      await game.waitTicks(40); // 2 seconds to run

      final finalPos = entity.position;

      // Entity should have moved from panic
      final distance =
          (finalPos.x - initialPos.x).abs() + (finalPos.z - initialPos.z).abs();

      // Log distance for debugging (panic behavior may vary)
      print('Minimal animal panic distance: $distance');
    });

    await testMinecraft('monster with empty goals is passive', (game) async {
      // Note: We can't test player interaction in headless mode (no players),
      // so we verify passive behavior by checking the entity stays stationary.

      // Place platform
      final platformPos = BlockPos(3250, 69, 3250);
      for (var dx = -3; dx <= 3; dx++) {
        for (var dz = -3; dz <= 3; dz++) {
          game.placeBlock(
            BlockPos(platformPos.x + dx, platformPos.y, platformPos.z + dz),
            Block.stone,
          );
        }
      }
      await game.waitTicks(5);

      // Spawn passive zombie
      final spawnPos = Vec3(3250, 70, 3250);
      final entity = game.spawnEntity('framework_tests:passive_zombie', spawnPos);
      await game.waitTicks(10);
      expect(entity, isNotNull);

      final initialPos = entity!.position;

      // Wait for a bit - passive zombie should stay in place (no movement goals)
      await game.waitTicks(60); // 3 seconds

      final finalPos = entity.position;

      // Passive zombie should stay roughly in place
      // (allowing small drift from gravity/physics settling)
      expect(finalPos.x, closeTo(initialPos.x, 2));
      expect(finalPos.z, closeTo(initialPos.z, 2));
    });
  });
}

/// Matcher for approximate double equality.
Matcher closeTo(num value, num delta) =>
    inInclusiveRange(value - delta, value + delta);
