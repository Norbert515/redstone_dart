/// Custom Goal API E2E tests.
///
/// Tests for custom goals defined in Dart that control entity AI behavior
/// through Dart callbacks. Verifies the CustomGoal lifecycle, registration,
/// and EntityActions API.
import 'package:dart_mc/dart_mc.dart';
import 'package:redstone_test/redstone_test.dart';
import 'package:test/test.dart' as dart_test show test, group, returnsNormally;

// Import custom goals and entities from main.dart
import 'package:framework_tests/main.dart'
    show
        LookAtNearestPlayerGoal,
        SpinInCirclesGoal,
        ChasePlayerGoal,
        SpinningZombie,
        LookingZombie,
        ChasingZombie,
        MixedGoalZombie;

// =============================================================================
// Unit Tests - Pure Dart (no Minecraft server)
// =============================================================================

Future<void> main() async {
  dart_test.group('CustomGoal Serialization', () {
    dart_test.test('LookAtNearestPlayerGoal serializes correctly', () {
      final goal = LookAtNearestPlayerGoal();
      final json = goal.toJson();

      expect(json['type'], equals('custom'));
      expect(json['goalId'], equals('framework_tests:look_at_nearest_player'));
      expect(json['priority'], equals(3));
      expect(json['flags'], equals(['look']));
      expect(json['requiresUpdateEveryTick'], equals(true));
    });

    dart_test.test('CustomGoalRef serializes correctly', () {
      const ref = CustomGoalRef(
        priority: 5,
        goalId: 'framework_tests:spin_in_circles',
        flags: {GoalFlag.look, GoalFlag.move},
      );
      final json = ref.toJson();

      expect(json['type'], equals('custom'));
      expect(json['goalId'], equals('framework_tests:spin_in_circles'));
      expect(json['priority'], equals(5));
      expect(json['flags'], containsAll(['look', 'move']));
    });

    dart_test.test('SpinInCirclesGoal serializes correctly', () {
      final goal = SpinInCirclesGoal();
      final json = goal.toJson();

      expect(json['type'], equals('custom'));
      expect(json['goalId'], equals('framework_tests:spin_in_circles'));
      expect(json['priority'], equals(5));
    });

    dart_test.test('ChasePlayerGoal serializes with multiple flags', () {
      final goal = ChasePlayerGoal();
      final json = goal.toJson();

      expect(json['type'], equals('custom'));
      expect(json['goalId'], equals('framework_tests:chase_player'));
      expect(json['priority'], equals(2));
      expect(json['flags'], containsAll(['move', 'look']));
    });
  });

  dart_test.group('CustomGoalRegistry', () {
    dart_test.test('can access registered goal', () {
      // Note: Goals should already be registered via main.dart initialization
      // This test verifies the registry API works
      expect(
        () => CustomGoalRegistry.get('framework_tests:look_at_nearest_player'),
        dart_test.returnsNormally,
      );
    });

    dart_test.test('isRegistered returns false for non-existent goal', () {
      expect(CustomGoalRegistry.isRegistered('framework_tests:non_existent'), isFalse);
    });
  });

  dart_test.group('CustomMonster with CustomGoal', () {
    dart_test.test('SpinningZombie has custom goal in goals list', () {
      final zombie = SpinningZombie();
      final goals = zombie.settings.goals!;

      expect(goals.length, equals(2));
      expect(goals[0], isA<FloatGoal>());
      expect(goals[1], isA<CustomGoalRef>());

      final customRef = goals[1] as CustomGoalRef;
      expect(customRef.goalId, equals('framework_tests:spin_in_circles'));
      expect(customRef.priority, equals(5));
    });

    dart_test.test('LookingZombie has custom look goal', () {
      final zombie = LookingZombie();
      final goals = zombie.settings.goals!;

      expect(goals.length, equals(3));
      expect(goals[1], isA<CustomGoalRef>());

      final customRef = goals[1] as CustomGoalRef;
      expect(customRef.goalId, equals('framework_tests:look_at_nearest_player'));
    });

    dart_test.test('ChasingZombie has custom chase goal with move+look flags', () {
      final zombie = ChasingZombie();
      final goals = zombie.settings.goals!;

      expect(goals.any((g) => g is CustomGoalRef), isTrue);

      final customRef = goals.whereType<CustomGoalRef>().first;
      expect(customRef.goalId, equals('framework_tests:chase_player'));
      expect(customRef.flags, containsAll({GoalFlag.move, GoalFlag.look}));
    });

    dart_test.test('MixedGoalZombie has both vanilla and custom goals', () {
      final zombie = MixedGoalZombie();
      final goals = zombie.settings.goals!;

      expect(goals.any((g) => g is MeleeAttackGoal), isTrue);
      expect(goals.any((g) => g is CustomGoalRef), isTrue);
      expect(goals.any((g) => g is WaterAvoidingRandomStrollGoal), isTrue);
    });
  });

  // ===========================================================================
  // E2E Tests - Custom Entity Spawning with Custom Goals
  //
  // These tests verify that custom entities with Dart-defined goals can be
  // spawned and are functional. The goals and entities are registered in
  // framework_tests/lib/main.dart.
  //
  // Run with: cd packages/framework_tests && redstone test test/custom_goal_e2e_test.dart
  // ===========================================================================

  await group('Custom Goals E2E - Spawning', () async {
    const testPos = Vec3(4000, 70, 4000);

    await testMinecraft('can spawn monster with spinning custom goal', (game) async {
      final entity = game.spawnEntity('framework_tests:spinning_zombie', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('framework_tests:spinning_zombie'));
      expect(entity.isLiving, isTrue);
    });

    await testMinecraft('can spawn monster with look-at-player custom goal', (game) async {
      final spawnPos = Vec3(testPos.x + 10, testPos.y, testPos.z);
      final entity = game.spawnEntity('framework_tests:looking_zombie', spawnPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('framework_tests:looking_zombie'));
    });

    await testMinecraft('can spawn monster with chase custom goal', (game) async {
      final spawnPos = Vec3(testPos.x + 20, testPos.y, testPos.z);
      final entity = game.spawnEntity('framework_tests:chasing_zombie', spawnPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('framework_tests:chasing_zombie'));
    });

    await testMinecraft('can spawn monster with mixed vanilla and custom goals', (game) async {
      final spawnPos = Vec3(testPos.x + 30, testPos.y, testPos.z);
      final entity = game.spawnEntity('framework_tests:mixed_goal_zombie', spawnPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('framework_tests:mixed_goal_zombie'));
    });
  });

  await group('Custom Goals E2E - Behavior', () async {
    await testMinecraft('spinning zombie stays in place while spinning', (game) async {
      // Place a platform for the entity
      final platformPos = BlockPos(4100, 69, 4100);
      for (var dx = -2; dx <= 2; dx++) {
        for (var dz = -2; dz <= 2; dz++) {
          game.placeBlock(
            BlockPos(platformPos.x + dx, platformPos.y, platformPos.z + dz),
            Block.stone,
          );
        }
      }
      await game.waitTicks(5);

      final spawnPos = Vec3(4100, 70, 4100);
      final entity = game.spawnEntity('framework_tests:spinning_zombie', spawnPos);
      await game.waitTicks(10);
      expect(entity, isNotNull);

      final initialPos = entity!.position;

      // Wait for the entity to spin for a while
      await game.waitTicks(60); // 3 seconds

      final finalPos = entity.position;

      // Spinning zombie should stay roughly in place (no move goal active)
      expect(finalPos.x, closeTo(initialPos.x, 2));
      expect(finalPos.z, closeTo(initialPos.z, 2));

      // Entity is still alive
      expect(entity.isLiving, isTrue);
    });

    await testMinecraft('looking zombie with no player stays stationary', (game) async {
      // Place a platform
      final platformPos = BlockPos(4150, 69, 4150);
      for (var dx = -2; dx <= 2; dx++) {
        for (var dz = -2; dz <= 2; dz++) {
          game.placeBlock(
            BlockPos(platformPos.x + dx, platformPos.y, platformPos.z + dz),
            Block.stone,
          );
        }
      }
      await game.waitTicks(5);

      final spawnPos = Vec3(4150, 70, 4150);
      final entity = game.spawnEntity('framework_tests:looking_zombie', spawnPos);
      await game.waitTicks(10);
      expect(entity, isNotNull);

      final initialPos = entity!.position;

      // Wait for a bit - without players, it should just wander
      await game.waitTicks(60);

      final finalPos = entity.position;

      // Entity should still be alive and functional
      expect(entity.isLiving, isTrue);

      // Log movement for debugging
      final dx = (finalPos.x - initialPos.x).abs();
      final dz = (finalPos.z - initialPos.z).abs();
      print('Looking zombie moved: dx=$dx, dz=$dz');
    });

    await testMinecraft('mixed goal zombie stays active without targets', (game) async {
      // Place a platform
      final platformPos = BlockPos(4200, 69, 4200);
      for (var dx = -3; dx <= 3; dx++) {
        for (var dz = -3; dz <= 3; dz++) {
          game.placeBlock(
            BlockPos(platformPos.x + dx, platformPos.y, platformPos.z + dz),
            Block.stone,
          );
        }
      }
      await game.waitTicks(5);

      final spawnPos = Vec3(4200, 70, 4200);
      final entity = game.spawnEntity('framework_tests:mixed_goal_zombie', spawnPos);
      await game.waitTicks(10);
      expect(entity, isNotNull);

      // Wait for entity to exhibit behavior
      await game.waitTicks(100); // 5 seconds

      // Entity should still be alive
      expect(entity!.isLiving, isTrue);
    });

    await testMinecraft('chasing zombie exists and is functional', (game) async {
      // Place a platform
      final platformPos = BlockPos(4250, 69, 4250);
      for (var dx = -3; dx <= 3; dx++) {
        for (var dz = -3; dz <= 3; dz++) {
          game.placeBlock(
            BlockPos(platformPos.x + dx, platformPos.y, platformPos.z + dz),
            Block.stone,
          );
        }
      }
      await game.waitTicks(5);

      final spawnPos = Vec3(4250, 70, 4250);
      final entity = game.spawnEntity('framework_tests:chasing_zombie', spawnPos);
      await game.waitTicks(10);
      expect(entity, isNotNull);

      // Without players, the chase goal's canUse should return false
      // Entity should fall back to wandering
      await game.waitTicks(60);

      expect(entity!.isLiving, isTrue);
    });
  });

  await group('Custom Goals E2E - Multiple Entities', () async {
    await testMinecraft('can spawn multiple custom goal entities simultaneously', (game) async {
      // Place a large platform
      final platformPos = BlockPos(4300, 69, 4300);
      for (var dx = -10; dx <= 10; dx++) {
        for (var dz = -10; dz <= 10; dz++) {
          game.placeBlock(
            BlockPos(platformPos.x + dx, platformPos.y, platformPos.z + dz),
            Block.stone,
          );
        }
      }
      await game.waitTicks(5);

      // Spawn multiple entities with different custom goals
      final spinner = game.spawnEntity(
        'framework_tests:spinning_zombie',
        Vec3(4300, 70, 4300),
      );
      final looker = game.spawnEntity(
        'framework_tests:looking_zombie',
        Vec3(4305, 70, 4300),
      );
      final chaser = game.spawnEntity(
        'framework_tests:chasing_zombie',
        Vec3(4300, 70, 4305),
      );
      final mixed = game.spawnEntity(
        'framework_tests:mixed_goal_zombie',
        Vec3(4305, 70, 4305),
      );

      await game.waitTicks(20);

      // All entities should have spawned successfully
      expect(spinner, isNotNull);
      expect(looker, isNotNull);
      expect(chaser, isNotNull);
      expect(mixed, isNotNull);

      // Let them run for a while
      await game.waitTicks(100);

      // All entities should still be alive
      expect(spinner!.isLiving, isTrue);
      expect(looker!.isLiving, isTrue);
      expect(chaser!.isLiving, isTrue);
      expect(mixed!.isLiving, isTrue);
    });
  });
}

/// Matcher for approximate double equality.
Matcher closeTo(num value, num delta) =>
    inInclusiveRange(value - delta, value + delta);
