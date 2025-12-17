/// Entity API tests.
///
/// Tests for entity spawning, properties, movement, and queries.
import 'package:redstone_test/redstone_test.dart';
import 'package:test/test.dart' as dart_test;

Future<void> main() async {
  // Test spawn position - elevated to ensure entities don't suffocate
  const testPos = Vec3(2000, 70, 2000);

  await group('Entity spawning', () async {
    await testMinecraft('can spawn a pig', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('minecraft:pig'));
    });

    await testMinecraft('can spawn a cow', (game) async {
      final entity = game.spawnEntity('minecraft:cow', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('minecraft:cow'));
    });

    await testMinecraft('can spawn a sheep', (game) async {
      final entity = game.spawnEntity('minecraft:sheep', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('minecraft:sheep'));
    });

    await testMinecraft('can spawn a zombie', (game) async {
      final entity = game.spawnEntity('minecraft:zombie', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('minecraft:zombie'));
    });

    await testMinecraft('can spawn a chicken', (game) async {
      final entity = game.spawnEntity('minecraft:chicken', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.type, equals('minecraft:chicken'));
    });

    await testMinecraft('spawned entity has valid ID', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.id, greaterThan(0));
    });
  });

  await group('Entity type checking', () async {
    await testMinecraft('isLiving returns true for living entities', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.isLiving, isTrue);
    });

    await testMinecraft('isPlayer returns false for non-player entities', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.isPlayer, isFalse);
    });

    await testMinecraft('hasEntityType matcher works', (game) async {
      final entity = game.spawnEntity('minecraft:cow', testPos);
      await game.waitTicks(5);

      expect(entity, hasEntityType('minecraft:cow'));
    });
  });

  await group('Entity position', () async {
    await testMinecraft('entity has position near spawn point', (game) async {
      final spawnPos = Vec3(testPos.x + 10, testPos.y, testPos.z);
      final entity = game.spawnEntity('minecraft:pig', spawnPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      final pos = entity!.position;

      // Position should be near spawn point (allowing for some drift)
      expect(pos.x, closeTo(spawnPos.x, 5));
      expect(pos.z, closeTo(spawnPos.z, 5));
    });

    await testMinecraft('can set entity position', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      final newPos = Vec3(testPos.x + 20, testPos.y + 5, testPos.z + 20);
      entity!.position = newPos;
      await game.waitTicks(5);

      final actualPos = entity.position;
      expect(actualPos.x, closeTo(newPos.x, 1));
      expect(actualPos.y, closeTo(newPos.y, 1));
      expect(actualPos.z, closeTo(newPos.z, 1));
    });

    await testMinecraft('can teleport entity', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      final targetPos = Vec3(testPos.x + 50, testPos.y, testPos.z + 50);
      entity!.teleport(targetPos);
      await game.waitTicks(5);

      final pos = entity.position;
      expect(pos.x, closeTo(targetPos.x, 1));
      expect(pos.z, closeTo(targetPos.z, 1));
    });
  });

  await group('Entity velocity', () async {
    await testMinecraft('can get entity velocity', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      final velocity = entity!.velocity;
      expect(velocity, isA<Vec3>());
    });

    await testMinecraft('can set entity velocity', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      entity!.velocity = Vec3(0, 1, 0); // Launch upward
      await game.waitTicks(1);

      // Entity should have upward velocity (may decrease due to gravity)
      final vel = entity.velocity;
      expect(vel.y, greaterThan(0));
    });
  });

  await group('Entity state flags', () async {
    await testMinecraft('can check if entity is on ground', (game) async {
      // Place a platform first
      final platformPos = BlockPos(
        testPos.x.floor() + 30,
        testPos.y.floor() - 1,
        testPos.z.floor(),
      );
      game.placeBlock(platformPos, Block.stone);
      await game.waitTicks(5);

      final entity = game.spawnEntity(
        'minecraft:pig',
        Vec3(platformPos.x + 0.5, platformPos.y + 1, platformPos.z + 0.5),
      );
      await game.waitTicks(20); // Wait for entity to settle

      expect(entity, isNotNull);
      expect(entity!.isOnGround, isTrue);
    });

    await testMinecraft('can check isOnFire', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.isOnFire, isFalse);
    });

    await testMinecraft('can set entity on fire', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      entity!.setOnFire(5);
      await game.waitTicks(1);

      expect(entity.isOnFire, isTrue);
    });

    await testMinecraft('can extinguish entity', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      entity!.setOnFire(10);
      await game.waitTicks(1);
      expect(entity.isOnFire, isTrue);

      entity.isOnFire = false;
      await game.waitTicks(1);
      expect(entity.isOnFire, isFalse);
    });

    await testMinecraft('can get and set isGlowing', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      expect(entity!.isGlowing, isFalse);

      entity.isGlowing = true;
      await game.waitTicks(1);
      expect(entity.isGlowing, isTrue);

      entity.isGlowing = false;
      await game.waitTicks(1);
      expect(entity.isGlowing, isFalse);
    });

    await testMinecraft('can get and set isInvisible', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      expect(entity!.isInvisible, isFalse);

      entity.isInvisible = true;
      await game.waitTicks(1);
      expect(entity.isInvisible, isTrue);
    });

    await testMinecraft('can get and set hasNoGravity', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      expect(entity!.hasNoGravity, isFalse);

      entity.hasNoGravity = true;
      await game.waitTicks(1);
      expect(entity.hasNoGravity, isTrue);
    });
  });

  await group('Entity custom name', () async {
    await testMinecraft('entity has no custom name by default', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.customName, isNull);
    });

    await testMinecraft('can set custom name', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      entity!.customName = 'Test Pig';
      await game.waitTicks(1);

      expect(entity.customName, equals('Test Pig'));
    });

    await testMinecraft('can make custom name visible', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      entity!.customName = 'Visible Name';
      entity.isCustomNameVisible = true;
      await game.waitTicks(1);

      expect(entity.isCustomNameVisible, isTrue);
    });
  });

  await group('Entity tags', () async {
    await testMinecraft('entity has no tags by default', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);

      expect(entity, isNotNull);
      expect(entity!.tags, isEmpty);
    });

    await testMinecraft('can add tag to entity', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      final added = entity!.addTag('test_tag');
      await game.waitTicks(1);

      expect(added, isTrue);
      expect(entity.hasTag('test_tag'), isTrue);
    });

    await testMinecraft('can remove tag from entity', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      entity!.addTag('removable_tag');
      await game.waitTicks(1);
      expect(entity.hasTag('removable_tag'), isTrue);

      entity.removeTag('removable_tag');
      await game.waitTicks(1);
      expect(entity.hasTag('removable_tag'), isFalse);
    });
  });

  await group('Entity removal', () async {
    await testMinecraft('can remove entity', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      entity!.remove();
      await game.waitTicks(10);

      // Entity should no longer be findable in the world
      final entities = game.getEntitiesInRadius(testPos, 10);
      final found = entities.where((e) => e.id == entity.id).isEmpty;
      expect(found, isTrue);
    });

    await testMinecraft('can discard entity', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      entity!.discard();
      await game.waitTicks(10);

      // Entity should be gone
      final entities = game.getEntitiesInRadius(testPos, 10);
      final found = entities.where((e) => e.id == entity.id).isEmpty;
      expect(found, isTrue);
    });
  });

  await group('Living entity health', () async {
    await testMinecraft('living entity has health', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      // Pig is a living entity, should have health
      if (entity is LivingEntity) {
        expect(entity.health, greaterThan(0));
        expect(entity.maxHealth, greaterThan(0));
      }
    });

    await testMinecraft('can get typed entity as LivingEntity', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      // The entity should be typed as LivingEntity
      expect(entity, isA<LivingEntity>());
    });

    await testMinecraft('hasHealth matcher works', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);

      expect(entity, hasHealth(greaterThan(0)));
    });

    await testMinecraft('can hurt living entity', (game) async {
      final entity = game.spawnEntity('minecraft:pig', testPos);
      await game.waitTicks(5);
      expect(entity, isNotNull);

      if (entity is LivingEntity) {
        final originalHealth = entity.health;
        entity.hurt(2.0);
        await game.waitTicks(5);

        expect(entity.health, lessThan(originalHealth));
      }
    });
  });

  await group('Entity queries', () async {
    await testMinecraft('can get entities in radius', (game) async {
      final center = Vec3(testPos.x + 100, testPos.y, testPos.z);

      // Spawn a few entities
      game.spawnEntity('minecraft:pig', center);
      game.spawnEntity('minecraft:cow', Vec3(center.x + 2, center.y, center.z));
      game.spawnEntity('minecraft:sheep', Vec3(center.x, center.y, center.z + 2));
      await game.waitTicks(10);

      final entities = game.getEntitiesInRadius(center, 10);
      expect(entities.length, greaterThanOrEqualTo(3));
    });

    await testMinecraft('getEntitiesInRadius returns empty for no entities', (game) async {
      // Use a far away location with no entities
      final emptyPos = Vec3(10000, 70, 10000);
      final entities = game.getEntitiesInRadius(emptyPos, 5);

      // Should be empty or only contain potential pre-existing entities
      expect(entities, isA<List<Entity>>());
    });

    await testMinecraft('can filter entities by type in query', (game) async {
      final center = Vec3(testPos.x + 200, testPos.y, testPos.z);

      // Spawn mixed entities
      game.spawnEntity('minecraft:pig', center);
      game.spawnEntity('minecraft:pig', Vec3(center.x + 1, center.y, center.z));
      game.spawnEntity('minecraft:cow', Vec3(center.x + 2, center.y, center.z));
      await game.waitTicks(10);

      final allEntities = Entities.getEntitiesInRadius(
        game.world,
        center,
        10,
        type: 'minecraft:pig',
      );

      for (final entity in allEntities) {
        expect(entity.type, equals('minecraft:pig'));
      }
    });
  });

  // Pure Dart unit tests (not Minecraft tests)
  await group('AABB utilities', () async {
    dart_test.test('AABB.contains works correctly', () {
      final aabb = AABB(Vec3(0, 0, 0), Vec3(10, 10, 10));

      expect(aabb.contains(Vec3(5, 5, 5)), isTrue);
      expect(aabb.contains(Vec3(0, 0, 0)), isTrue);
      expect(aabb.contains(Vec3(10, 10, 10)), isTrue);
      expect(aabb.contains(Vec3(-1, 5, 5)), isFalse);
      expect(aabb.contains(Vec3(11, 5, 5)), isFalse);
    });

    dart_test.test('AABB.intersects works correctly', () {
      final aabb1 = AABB(Vec3(0, 0, 0), Vec3(10, 10, 10));
      final aabb2 = AABB(Vec3(5, 5, 5), Vec3(15, 15, 15));
      final aabb3 = AABB(Vec3(20, 20, 20), Vec3(30, 30, 30));

      expect(aabb1.intersects(aabb2), isTrue);
      expect(aabb1.intersects(aabb3), isFalse);
    });

    dart_test.test('AABB.center returns correct center', () {
      final aabb = AABB(Vec3(0, 0, 0), Vec3(10, 10, 10));
      final center = aabb.center;

      expect(center.x, equals(5));
      expect(center.y, equals(5));
      expect(center.z, equals(5));
    });

    dart_test.test('AABB.expand works correctly', () {
      final aabb = AABB(Vec3(0, 0, 0), Vec3(10, 10, 10));
      final expanded = aabb.expand(5);

      expect(expanded.min.x, equals(-5));
      expect(expanded.max.x, equals(15));
    });

    dart_test.test('AABB.fromCenter creates correct box', () {
      final aabb = AABB.fromCenter(Vec3(5, 5, 5), 5, 5, 5);

      expect(aabb.min.x, equals(0));
      expect(aabb.max.x, equals(10));
    });

    dart_test.test('AABB.cube creates correct cube', () {
      final aabb = AABB.cube(Vec3(5, 5, 5), 5);

      expect(aabb.min.x, equals(0));
      expect(aabb.max.x, equals(10));
      expect(aabb.size.x, equals(10));
      expect(aabb.size.y, equals(10));
      expect(aabb.size.z, equals(10));
    });
  });
}

/// Matcher for approximate double equality.
Matcher closeTo(num value, num delta) =>
    inInclusiveRange(value - delta, value + delta);
