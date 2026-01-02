// framework_tests - A Minecraft mod built with Redstone
//
// Tests for the onAttackEntity callback system, entity goal system,
// and custom goal system with Dart-defined AI behavior.

import 'package:dart_mod_server/dart_mod_server.dart';

// ===========================================================================
// Test Items - onAttackEntity callback testing
// ===========================================================================

/// Test sword that logs when onAttackEntity is called and spawns lightning.
class TestLightningSword extends CustomItem {
  static int attackCount = 0;

  TestLightningSword()
      : super(
          id: 'framework_tests:test_lightning_sword',
          settings: ItemSettings(
            maxStackSize: 1,
            maxDamage: 100,
          ),
          combat: CombatAttributes.sword(damage: 10.0),
          model: ItemModel.handheld(
            texture: 'assets/textures/item/test_sword.png',
          ),
        );

  @override
  bool onAttackEntity(int worldId, int attackerId, int targetId) {
    attackCount++;
    print('=== TEST: onAttackEntity CALLBACK FIRED ===');
    print('  attackCount: $attackCount');
    print('  worldId: $worldId');
    print('  attackerId: $attackerId');
    print('  targetId: $targetId');

    try {
      final target = Entity(targetId);
      final pos = target.position;
      print('  target position: $pos');

      final world = World.overworld;
      world.spawnLightning(pos);
      print('  Lightning spawned successfully!');
    } catch (e, st) {
      print('  ERROR: $e');
      print('  Stack: $st');
    }

    return true;
  }
}

/// Simple test sword that just logs (no lightning) to isolate issues.
class TestSimpleSword extends CustomItem {
  static int hitCount = 0;

  TestSimpleSword()
      : super(
          id: 'framework_tests:test_simple_sword',
          settings: ItemSettings(
            maxStackSize: 1,
            maxDamage: 100,
          ),
          combat: CombatAttributes.sword(damage: 5.0),
          model: ItemModel.handheld(
            texture: 'assets/textures/item/test_sword.png',
          ),
        );

  @override
  bool onAttackEntity(int worldId, int attackerId, int targetId) {
    hitCount++;
    print('=== TEST: TestSimpleSword.onAttackEntity ===');
    print('  hitCount: $hitCount');
    print('  worldId=$worldId, attackerId=$attackerId, targetId=$targetId');
    return true;
  }
}

// ===========================================================================
// Test Entities - Entity Goal System Testing
// ===========================================================================

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
              NearestAttackableTargetGoal(
                priority: 1,
                targetType: 'minecraft:player',
              ),
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
              NearestAttackableTargetGoal(
                priority: 1,
                targetType: 'minecraft:player',
              ),
              HurtByTargetGoal(priority: 2),
            ],
          ),
        );
}

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
              TemptGoal(
                priority: 3,
                temptItem: 'minecraft:wheat',
                speedModifier: 1.0,
              ),
              FollowParentGoal(priority: 4, speedModifier: 1.1),
              WaterAvoidingRandomStrollGoal(priority: 5),
              LookAtPlayerGoal(priority: 6, lookDistance: 6.0),
              RandomLookAroundGoal(priority: 7),
            ],
          ),
        );
}

/// Animal with no goals configured - should use defaults for backward compat.
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

// ===========================================================================
// Custom Goals - Dart-defined AI behavior
// ===========================================================================

/// A custom goal that makes the entity look at the nearest player.
/// Uses EntityActions to detect and look at players.
class LookAtNearestPlayerGoal extends CustomGoal {
  static int canUseCalls = 0;
  static int startCalls = 0;
  static int tickCalls = 0;
  static int stopCalls = 0;

  static void resetCounters() {
    canUseCalls = 0;
    startCalls = 0;
    tickCalls = 0;
    stopCalls = 0;
  }

  LookAtNearestPlayerGoal()
      : super(
          id: 'framework_tests:look_at_nearest_player',
          priority: 3,
          flags: {GoalFlag.look},
          requiresUpdateEveryTick: true,
        );

  @override
  bool canUse(int entityId) {
    canUseCalls++;
    return EntityActions.hasNearbyPlayer(entityId, radius: 16);
  }

  @override
  void start(int entityId) {
    startCalls++;
    print('LookAtNearestPlayerGoal: start called for entity $entityId');
  }

  @override
  void tick(int entityId) {
    tickCalls++;
    final playerId = EntityActions.getNearestPlayerId(entityId, radius: 16);
    if (playerId >= 0) {
      EntityActions.lookAtEntity(entityId, playerId);
    }
  }

  @override
  void stop(int entityId) {
    stopCalls++;
    print('LookAtNearestPlayerGoal: stop called for entity $entityId');
  }
}

/// A custom goal that makes the entity spin in circles.
/// Simple goal that doesn't depend on players or other entities.
class SpinInCirclesGoal extends CustomGoal {
  static int tickCalls = 0;
  static int startCalls = 0;
  static int stopCalls = 0;

  static void resetCounters() {
    tickCalls = 0;
    startCalls = 0;
    stopCalls = 0;
  }

  SpinInCirclesGoal()
      : super(
          id: 'framework_tests:spin_in_circles',
          priority: 5,
          flags: {GoalFlag.look},
          requiresUpdateEveryTick: true,
        );

  @override
  bool canUse(int entityId) {
    // Always active - entity should spin whenever no higher priority goal runs
    return true;
  }

  @override
  void start(int entityId) {
    startCalls++;
    print('SpinInCirclesGoal: start called for entity $entityId');
  }

  @override
  void tick(int entityId) {
    tickCalls++;
    // Get current position and look at a rotating point around it
    final pos = EntityActions.getPosition(entityId);
    if (pos.isNotEmpty) {
      // Create a rotating look target by using tick count
      final angle = (tickCalls * 0.1) % (2 * 3.14159);
      final lookX = pos[0] + 2 * _cos(angle);
      final lookZ = pos[2] + 2 * _sin(angle);
      EntityActions.lookAt(entityId, lookX, pos[1], lookZ);
    }
  }

  @override
  void stop(int entityId) {
    stopCalls++;
    print('SpinInCirclesGoal: stop called for entity $entityId');
  }
}

/// A custom chase goal that uses EntityActions to move toward the nearest player.
class ChasePlayerGoal extends CustomGoal {
  static int tickCalls = 0;
  static int canUseCalls = 0;

  static void resetCounters() {
    tickCalls = 0;
    canUseCalls = 0;
  }

  ChasePlayerGoal()
      : super(
          id: 'framework_tests:chase_player',
          priority: 2,
          flags: {GoalFlag.move, GoalFlag.look},
          requiresUpdateEveryTick: true,
        );

  @override
  bool canUse(int entityId) {
    canUseCalls++;
    return EntityActions.hasNearbyPlayer(entityId, radius: 24);
  }

  @override
  void tick(int entityId) {
    tickCalls++;
    final playerId = EntityActions.getNearestPlayerId(entityId, radius: 24);
    if (playerId >= 0) {
      // Look at and move toward the player
      EntityActions.lookAtEntity(entityId, playerId);

      // Get player position and move toward it
      final playerPos = EntityActions.getPosition(playerId);
      if (playerPos.isNotEmpty) {
        EntityActions.moveTo(
          entityId,
          playerPos[0],
          playerPos[1],
          playerPos[2],
          speed: 1.0,
        );
      }
    }
  }
}

// Simple trig helpers for SpinInCirclesGoal
double _cos(double x) {
  // Taylor series approximation for cos
  double result = 1.0;
  double term = 1.0;
  for (int i = 1; i <= 10; i++) {
    term *= -x * x / ((2 * i - 1) * (2 * i));
    result += term;
  }
  return result;
}

double _sin(double x) {
  // Taylor series approximation for sin
  double result = x;
  double term = x;
  for (int i = 1; i <= 10; i++) {
    term *= -x * x / ((2 * i) * (2 * i + 1));
    result += term;
  }
  return result;
}

// ===========================================================================
// Test Entities - Custom Goal Testing
// ===========================================================================

/// Monster with a simple spinning custom goal.
class SpinningZombie extends CustomMonster {
  SpinningZombie()
      : super(
          id: 'framework_tests:spinning_zombie',
          settings: MonsterSettings(
            maxHealth: 20,
            attackDamage: 3,
            movementSpeed: 0.25,
            goals: [
              FloatGoal(priority: 0),
              CustomGoalRef(
                priority: 5,
                goalId: 'framework_tests:spin_in_circles',
                flags: {GoalFlag.look},
              ),
            ],
            targetGoals: [], // No targeting - just spin
          ),
        );
}

/// Monster with a custom look-at-player goal.
class LookingZombie extends CustomMonster {
  LookingZombie()
      : super(
          id: 'framework_tests:looking_zombie',
          settings: MonsterSettings(
            maxHealth: 20,
            attackDamage: 3,
            movementSpeed: 0.25,
            goals: [
              FloatGoal(priority: 0),
              CustomGoalRef(
                priority: 3,
                goalId: 'framework_tests:look_at_nearest_player',
                flags: {GoalFlag.look},
              ),
              WaterAvoidingRandomStrollGoal(priority: 5),
            ],
            targetGoals: [], // No attacking - just looks
          ),
        );
}

/// Monster with a custom chase goal.
class ChasingZombie extends CustomMonster {
  ChasingZombie()
      : super(
          id: 'framework_tests:chasing_zombie',
          settings: MonsterSettings(
            maxHealth: 20,
            attackDamage: 3,
            movementSpeed: 0.3,
            goals: [
              FloatGoal(priority: 0),
              CustomGoalRef(
                priority: 2,
                goalId: 'framework_tests:chase_player',
                flags: {GoalFlag.move, GoalFlag.look},
              ),
              WaterAvoidingRandomStrollGoal(priority: 6),
            ],
            targetGoals: [],
          ),
        );
}

/// Monster with mixed vanilla and custom goals.
class MixedGoalZombie extends CustomMonster {
  MixedGoalZombie()
      : super(
          id: 'framework_tests:mixed_goal_zombie',
          settings: MonsterSettings(
            maxHealth: 20,
            attackDamage: 3,
            movementSpeed: 0.25,
            goals: [
              FloatGoal(priority: 0),
              // Vanilla melee attack (will use target from targetGoals)
              MeleeAttackGoal(priority: 2, speedModifier: 1.0),
              // Custom spinning when not attacking
              CustomGoalRef(
                priority: 4,
                goalId: 'framework_tests:spin_in_circles',
                flags: {GoalFlag.look},
              ),
              WaterAvoidingRandomStrollGoal(priority: 6),
            ],
            targetGoals: [
              HurtByTargetGoal(priority: 1), // Fight back when hit
            ],
          ),
        );
}

// ===========================================================================
// Test Block
// ===========================================================================

class HelloBlock extends CustomBlock {
  HelloBlock()
      : super(
          id: 'framework_tests:hello_block',
          settings: BlockSettings(
            hardness: 1.0,
            resistance: 1.0,
            requiresTool: false,
          ),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player != null) {
      player.sendMessage('Hello from Framework Tests!');
      player.sendMessage('TestSimpleSword hits: ${TestSimpleSword.hitCount}');
      player.sendMessage('TestLightningSword hits: ${TestLightningSword.attackCount}');
    }
    return ActionResult.success;
  }
}

// ===========================================================================
// Main entry point
// ===========================================================================

void main() {
  print('=== Framework Tests - onAttackEntity Testing ===');

  // Initialize the native bridge
  Bridge.initialize();

  // Register proxy handlers
  Events.registerProxyBlockHandlers();
  Events.registerProxyItemHandlers();
  print('Proxy handlers registered (blocks + items)');

  // Register test items BEFORE blocks
  print('Registering test items...');
  ItemRegistry.register(TestSimpleSword());
  ItemRegistry.register(TestLightningSword());
  ItemRegistry.freeze();
  print('Items registered: ${ItemRegistry.itemCount}');

  // Register test blocks
  BlockRegistry.register(HelloBlock());
  BlockRegistry.freeze();
  print('Blocks registered: ${BlockRegistry.blockCount}');

  // Register custom goals BEFORE entities that use them
  print('Registering custom goals...');
  CustomGoalRegistry.register(LookAtNearestPlayerGoal());
  CustomGoalRegistry.register(SpinInCirclesGoal());
  CustomGoalRegistry.register(ChasePlayerGoal());
  print('Custom goals registered: ${CustomGoalRegistry.registeredIds.length}');

  // Register test entities for goal system testing
  print('Registering test entities...');
  EntityRegistry.register(AttackingZombie());
  EntityRegistry.register(PassiveZombie());
  EntityRegistry.register(WanderingZombie());
  EntityRegistry.register(LeapingSpider());
  EntityRegistry.register(MinimalAnimal());
  EntityRegistry.register(BreedableAnimal());
  EntityRegistry.register(DefaultGoalsAnimal());
  // Custom goal test entities
  EntityRegistry.register(SpinningZombie());
  EntityRegistry.register(LookingZombie());
  EntityRegistry.register(ChasingZombie());
  EntityRegistry.register(MixedGoalZombie());
  EntityRegistry.freeze();
  print('Entities registered: ${EntityRegistry.entityCount}');

  // Log when we're ready
  print('=== Framework Tests Ready ===');
  print('Test items:');
  print('  /give @p framework_tests:test_simple_sword');
  print('  /give @p framework_tests:test_lightning_sword');
  print('Hit any mob with these swords to test onAttackEntity callback.');
}
