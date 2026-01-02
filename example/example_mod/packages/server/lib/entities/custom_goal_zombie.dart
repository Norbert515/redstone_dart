import 'package:dart_mod_server/dart_mod_server.dart';

// ============================================================================
// Custom Goals - Define AI behavior entirely in Dart!
// ============================================================================

/// A custom goal that makes the entity spin in circles while looking around.
class SpinGoal extends CustomGoal {
  // Track rotation per entity
  static final Map<int, double> _rotations = {};

  SpinGoal()
      : super(
          id: 'example_mod:spin',
          priority: 1,
          flags: {GoalFlag.look},
        );

  @override
  bool canUse(int entityId) => true; // Always active

  @override
  void start(int entityId) {
    _rotations[entityId] = 0.0;
    print('[SpinGoal] Started spinning for entity $entityId');
  }

  @override
  void tick(int entityId) {
    final pos = EntityActions.getPosition(entityId);
    final rotation = (_rotations[entityId] ?? 0.0) + 0.1;
    _rotations[entityId] = rotation;

    // Look in a circle around the entity
    final lookX = pos[0] + _cos(rotation) * 5;
    final lookZ = pos[2] + _sin(rotation) * 5;
    EntityActions.lookAt(entityId, lookX, pos[1], lookZ);
  }

  @override
  void stop(int entityId) {
    _rotations.remove(entityId);
    print('[SpinGoal] Stopped spinning for entity $entityId');
  }

  // Simple trig using Taylor series
  double _cos(double x) {
    x = x % (2 * 3.14159);
    return 1 - (x * x) / 2 + (x * x * x * x) / 24;
  }

  double _sin(double x) {
    x = x % (2 * 3.14159);
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }
}

/// A custom goal that chases the nearest player aggressively.
class AggressiveChaseGoal extends CustomGoal {
  AggressiveChaseGoal()
      : super(
          id: 'example_mod:aggressive_chase',
          priority: 2,
          flags: {GoalFlag.move, GoalFlag.look},
        );

  @override
  bool canUse(int entityId) {
    return EntityActions.hasNearbyPlayer(entityId, radius: 32);
  }

  @override
  void start(int entityId) {
    print('[AggressiveChaseGoal] Starting chase for entity $entityId');
  }

  @override
  void tick(int entityId) {
    final playerId = EntityActions.getNearestPlayerId(entityId, radius: 32);
    if (playerId >= 0) {
      // Look at and move towards player
      EntityActions.lookAtEntity(entityId, playerId);

      final playerPos = EntityActions.getPosition(playerId);
      EntityActions.moveTo(
        entityId,
        playerPos[0],
        playerPos[1],
        playerPos[2],
        speed: 2.5, // Fast!
      );
    }
  }

  @override
  void stop(int entityId) {
    EntityActions.stopMoving(entityId);
    print('[AggressiveChaseGoal] Stopped chase for entity $entityId');
  }
}

// ============================================================================
// Custom Goal Zombie - Uses Dart-defined AI
// ============================================================================

/// A zombie with custom AI defined entirely in Dart.
///
/// This zombie:
/// - Spins in circles when no player is nearby
/// - Aggressively chases players when they get close
class CustomGoalZombie extends CustomMonster {
  CustomGoalZombie()
      : super(
          id: 'example_mod:custom_goal_zombie',
          settings: MonsterSettings(
            maxHealth: 25,
            attackDamage: 5,
            movementSpeed: 0.3,
            burnsInDaylight: false, // This one doesn't burn!
            model: EntityModel.humanoid(
              texture: 'textures/entity/dart_zombie.png',
            ),
            goals: [
              FloatGoal(priority: 0),
              // Custom Dart-defined goals!
              CustomGoalRef(priority: 1, goalId: 'example_mod:spin'),
              CustomGoalRef(priority: 2, goalId: 'example_mod:aggressive_chase'),
              MeleeAttackGoal(priority: 3, speedModifier: 1.2),
            ],
            targetGoals: [
              HurtByTargetGoal(priority: 1),
              NearestAttackableTargetGoal(priority: 2, targetType: 'player'),
            ],
          ),
        );

  @override
  void onSpawn(int entityId, int worldId) {
    print('[CustomGoalZombie] Spawned with CUSTOM DART AI! Entity: $entityId');
  }

  @override
  void onAttack(int entityId, int targetId) {
    print('[CustomGoalZombie] Custom AI zombie attacking target: $targetId');
  }
}

/// Register all custom goals. Call this during mod initialization.
void registerCustomGoals() {
  CustomGoalRegistry.register(SpinGoal());
  CustomGoalRegistry.register(AggressiveChaseGoal());
  print('Custom goals registered!');
}
