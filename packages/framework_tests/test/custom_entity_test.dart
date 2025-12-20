/// Custom entity API tests.
///
/// Tests for CustomProjectile, CustomMonster, CustomAnimal classes
/// and their respective settings.
import 'package:dart_mc/api/custom_entity.dart';
import 'package:test/test.dart';

// Test implementations of custom entity classes
class TestProjectile extends CustomProjectile {
  final List<String> hitEntityCalls = [];
  final List<String> hitBlockCalls = [];

  TestProjectile({
    String id = 'test:projectile',
    ProjectileSettings settings = const ProjectileSettings(),
  }) : super(id: id, settings: settings);

  @override
  void onHitEntity(int projectileId, int targetId) {
    hitEntityCalls.add('$projectileId->$targetId');
  }

  @override
  void onHitBlock(int projectileId, int x, int y, int z, String side) {
    hitBlockCalls.add('$projectileId@($x,$y,$z):$side');
  }
}

class TestMonster extends CustomMonster {
  TestMonster({
    String id = 'test:monster',
    MonsterSettings settings = const MonsterSettings(),
  }) : super(id: id, settings: settings);
}

class TestAnimal extends CustomAnimal {
  final List<String> breedCalls = [];

  TestAnimal({
    String id = 'test:animal',
    AnimalSettings settings = const AnimalSettings(),
  }) : super(id: id, settings: settings);

  @override
  void onBreed(int entityId, int partnerId, int babyId) {
    breedCalls.add('$entityId+$partnerId=$babyId');
  }
}

Future<void> main() async {
  group('ProjectileSettings', () {
    test('has correct default values', () {
      const settings = ProjectileSettings();

      expect(settings.width, equals(0.25));
      expect(settings.height, equals(0.25));
      expect(settings.gravity, equals(0.03));
      expect(settings.noClip, isFalse);
    });

    test('baseType returns EntityBaseType.projectile', () {
      const settings = ProjectileSettings();
      expect(settings.baseType, equals(EntityBaseType.projectile));
    });

    test('inherits fixed values from EntitySettings', () {
      const settings = ProjectileSettings();

      // Projectiles have fixed health/speed/damage values
      expect(settings.maxHealth, equals(1));
      expect(settings.movementSpeed, equals(0));
      expect(settings.attackDamage, equals(0));
      expect(settings.spawnGroup, equals(SpawnGroup.misc));
    });

    test('can customize width, height, and gravity', () {
      const settings = ProjectileSettings(
        width: 0.5,
        height: 0.5,
        gravity: 0.01,
      );

      expect(settings.width, equals(0.5));
      expect(settings.height, equals(0.5));
      expect(settings.gravity, equals(0.01));
    });

    test('noClip can be set to true', () {
      const settings = ProjectileSettings(noClip: true);
      expect(settings.noClip, isTrue);
    });
  });

  group('MonsterSettings', () {
    test('has correct default values', () {
      const settings = MonsterSettings();

      expect(settings.width, equals(0.6));
      expect(settings.height, equals(1.95));
      expect(settings.maxHealth, equals(20));
      expect(settings.movementSpeed, equals(0.23));
      expect(settings.attackDamage, equals(3));
      expect(settings.burnsInDaylight, isFalse);
    });

    test('baseType returns EntityBaseType.monster', () {
      const settings = MonsterSettings();
      expect(settings.baseType, equals(EntityBaseType.monster));
    });

    test('spawnGroup defaults to SpawnGroup.monster', () {
      const settings = MonsterSettings();
      expect(settings.spawnGroup, equals(SpawnGroup.monster));
    });

    test('burnsInDaylight can be set to true', () {
      const settings = MonsterSettings(burnsInDaylight: true);
      expect(settings.burnsInDaylight, isTrue);
    });

    test('can customize all attributes', () {
      const settings = MonsterSettings(
        width: 0.8,
        height: 2.5,
        maxHealth: 50,
        movementSpeed: 0.3,
        attackDamage: 10,
        burnsInDaylight: true,
      );

      expect(settings.width, equals(0.8));
      expect(settings.height, equals(2.5));
      expect(settings.maxHealth, equals(50));
      expect(settings.movementSpeed, equals(0.3));
      expect(settings.attackDamage, equals(10));
      expect(settings.burnsInDaylight, isTrue);
    });
  });

  group('AnimalSettings', () {
    test('has correct default values', () {
      const settings = AnimalSettings();

      expect(settings.width, equals(0.9));
      expect(settings.height, equals(1.4));
      expect(settings.maxHealth, equals(10));
      expect(settings.movementSpeed, equals(0.2));
      expect(settings.attackDamage, equals(0));
      expect(settings.breedingItem, isNull);
    });

    test('baseType returns EntityBaseType.animal', () {
      const settings = AnimalSettings();
      expect(settings.baseType, equals(EntityBaseType.animal));
    });

    test('spawnGroup defaults to SpawnGroup.creature', () {
      const settings = AnimalSettings();
      expect(settings.spawnGroup, equals(SpawnGroup.creature));
    });

    test('breedingItem can be set', () {
      const settings = AnimalSettings(breedingItem: 'minecraft:wheat');
      expect(settings.breedingItem, equals('minecraft:wheat'));
    });

    test('can customize all attributes', () {
      const settings = AnimalSettings(
        width: 1.2,
        height: 1.8,
        maxHealth: 20,
        movementSpeed: 0.25,
        attackDamage: 0,
        breedingItem: 'minecraft:carrot',
      );

      expect(settings.width, equals(1.2));
      expect(settings.height, equals(1.8));
      expect(settings.maxHealth, equals(20));
      expect(settings.movementSpeed, equals(0.25));
      expect(settings.breedingItem, equals('minecraft:carrot'));
    });
  });

  group('CustomProjectile', () {
    test('can create a subclass', () {
      final projectile = TestProjectile();

      expect(projectile.id, equals('test:projectile'));
      expect(projectile, isA<CustomProjectile>());
      expect(projectile, isA<CustomEntity>());
    });

    test('settings getter returns ProjectileSettings', () {
      final projectile = TestProjectile(
        settings: const ProjectileSettings(width: 0.5, gravity: 0.05),
      );

      expect(projectile.settings, isA<ProjectileSettings>());
      expect(projectile.settings.width, equals(0.5));
      expect(projectile.settings.gravity, equals(0.05));
    });

    test('onHitEntity hook can be overridden', () {
      final projectile = TestProjectile();

      projectile.onHitEntity(1, 2);
      projectile.onHitEntity(3, 4);

      expect(projectile.hitEntityCalls, equals(['1->2', '3->4']));
    });

    test('onHitBlock hook can be overridden', () {
      final projectile = TestProjectile();

      projectile.onHitBlock(1, 100, 64, 200, 'north');
      projectile.onHitBlock(2, 50, 70, 100, 'up');

      expect(projectile.hitBlockCalls, equals([
        '1@(100,64,200):north',
        '2@(50,70,100):up',
      ]));
    });
  });

  group('CustomMonster', () {
    test('can create a subclass', () {
      final monster = TestMonster();

      expect(monster.id, equals('test:monster'));
      expect(monster, isA<CustomMonster>());
      expect(monster, isA<CustomEntity>());
    });

    test('settings getter returns MonsterSettings', () {
      final monster = TestMonster(
        settings: const MonsterSettings(burnsInDaylight: true, attackDamage: 5),
      );

      expect(monster.settings, isA<MonsterSettings>());
      expect(monster.settings.burnsInDaylight, isTrue);
      expect(monster.settings.attackDamage, equals(5));
    });

    test('inherits lifecycle hooks from CustomEntity', () {
      final monster = TestMonster();

      // Should be able to call these without error
      monster.onSpawn(1, 100);
      monster.onTick(1);
      monster.onDeath(1, 'player');
      expect(monster.onDamage(1, 'fall', 5.0), isTrue);
      monster.onAttack(1, 2);
      monster.onTargetAcquired(1, 3);
    });
  });

  group('CustomAnimal', () {
    test('can create a subclass', () {
      final animal = TestAnimal();

      expect(animal.id, equals('test:animal'));
      expect(animal, isA<CustomAnimal>());
      expect(animal, isA<CustomEntity>());
    });

    test('settings getter returns AnimalSettings', () {
      final animal = TestAnimal(
        settings: const AnimalSettings(breedingItem: 'minecraft:wheat'),
      );

      expect(animal.settings, isA<AnimalSettings>());
      expect(animal.settings.breedingItem, equals('minecraft:wheat'));
    });

    test('onBreed hook can be overridden', () {
      final animal = TestAnimal();

      animal.onBreed(1, 2, 3);
      animal.onBreed(4, 5, 6);

      expect(animal.breedCalls, equals(['1+2=3', '4+5=6']));
    });

    test('inherits lifecycle hooks from CustomEntity', () {
      final animal = TestAnimal();

      // Should be able to call these without error
      animal.onSpawn(1, 100);
      animal.onTick(1);
      animal.onDeath(1, 'player');
      expect(animal.onDamage(1, 'fall', 5.0), isTrue);
    });
  });

  group('EntityBaseType enum', () {
    test('has all expected values', () {
      expect(EntityBaseType.values, containsAll([
        EntityBaseType.pathfinderMob,
        EntityBaseType.monster,
        EntityBaseType.animal,
        EntityBaseType.projectile,
      ]));
    });

    test('values have correct indices', () {
      expect(EntityBaseType.pathfinderMob.index, equals(0));
      expect(EntityBaseType.monster.index, equals(1));
      expect(EntityBaseType.animal.index, equals(2));
      expect(EntityBaseType.projectile.index, equals(3));
    });
  });

  group('SpawnGroup enum', () {
    test('has all expected values', () {
      expect(SpawnGroup.values, containsAll([
        SpawnGroup.monster,
        SpawnGroup.creature,
        SpawnGroup.ambient,
        SpawnGroup.waterCreature,
        SpawnGroup.misc,
      ]));
    });
  });

  group('Entity type detection', () {
    test('CustomProjectile is correctly identified via runtime type', () {
      final CustomEntity projectile = TestProjectile();
      expect(projectile, isA<CustomProjectile>());
      expect(projectile, isNot(isA<CustomMonster>()));
      expect(projectile, isNot(isA<CustomAnimal>()));
    });

    test('CustomMonster is correctly identified via runtime type', () {
      final CustomEntity monster = TestMonster();
      expect(monster, isA<CustomMonster>());
      expect(monster, isNot(isA<CustomProjectile>()));
      expect(monster, isNot(isA<CustomAnimal>()));
    });

    test('CustomAnimal is correctly identified via runtime type', () {
      final CustomEntity animal = TestAnimal();
      expect(animal, isA<CustomAnimal>());
      expect(animal, isNot(isA<CustomProjectile>()));
      expect(animal, isNot(isA<CustomMonster>()));
    });
  });

  group('EntitySettings base class', () {
    test('has correct default values', () {
      const settings = EntitySettings();

      expect(settings.width, equals(0.6));
      expect(settings.height, equals(1.8));
      expect(settings.maxHealth, equals(20.0));
      expect(settings.movementSpeed, equals(0.25));
      expect(settings.attackDamage, equals(2.0));
      expect(settings.spawnGroup, equals(SpawnGroup.creature));
    });

    test('baseType returns EntityBaseType.pathfinderMob', () {
      const settings = EntitySettings();
      expect(settings.baseType, equals(EntityBaseType.pathfinderMob));
    });
  });

  group('CustomEntity base class', () {
    test('isRegistered returns false before registration', () {
      final projectile = TestProjectile();
      expect(projectile.isRegistered, isFalse);
    });

    test('handlerId throws before registration', () {
      final projectile = TestProjectile();
      expect(() => projectile.handlerId, throwsStateError);
    });

    test('setHandlerId sets the handler ID', () {
      final projectile = TestProjectile();
      projectile.setHandlerId(42);

      expect(projectile.isRegistered, isTrue);
      expect(projectile.handlerId, equals(42));
    });

    test('toString returns expected format', () {
      final projectile = TestProjectile();
      expect(projectile.toString(), equals('CustomEntity(test:projectile, registered=false)'));

      projectile.setHandlerId(1);
      expect(projectile.toString(), equals('CustomEntity(test:projectile, registered=true)'));
    });
  });
}
