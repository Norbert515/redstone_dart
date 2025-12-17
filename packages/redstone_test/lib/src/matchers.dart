/// Minecraft-specific matchers for test assertions.
///
/// These matchers make it easy to write expressive assertions about
/// blocks, entities, positions, and other game state.
library;

import 'package:dart_mc/dart_mc.dart';
import 'package:matcher/matcher.dart';

// =============================================================================
// Custom expect function (zone-independent)
// =============================================================================

/// A simple expect function that works outside of test zones.
///
/// Unlike package:test's expect, this doesn't require being run inside
/// a test zone, making it suitable for running inside Minecraft.
void expect(dynamic actual, Matcher matcher, {String? reason}) {
  final matchState = <dynamic, dynamic>{};
  if (!matcher.matches(actual, matchState)) {
    final description = StringDescription();
    description.add('Expected: ');
    matcher.describe(description);
    description.add('\n  Actual: ');
    description.addDescriptionOf(actual);
    description.add('\n');

    final mismatch = StringDescription();
    matcher.describeMismatch(actual, mismatch, matchState, false);
    if (mismatch.length > 0) {
      description.add('   Which: $mismatch\n');
    }

    if (reason != null) {
      description.add('  Reason: $reason\n');
    }

    throw TestFailure(description.toString());
  }
}

/// Exception thrown when an expect() assertion fails.
class TestFailure implements Exception {
  final String message;
  TestFailure(this.message);

  @override
  String toString() => message;
}

// =============================================================================
// Throws Matcher (zone-independent)
// =============================================================================

/// Matches if the function throws an exception matching [matcher].
///
/// Unlike package:matcher's throwsA, this doesn't depend on test zones.
Matcher throwsA(Matcher matcher) => _ThrowsMatcher(matcher);

class _ThrowsMatcher extends Matcher {
  final Matcher _matcher;

  _ThrowsMatcher(this._matcher);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! Function) {
      return false;
    }

    try {
      // Call the function - it should throw
      (item as dynamic Function())();
      // If we get here, nothing was thrown
      matchState['threw'] = false;
      return false;
    } catch (e, st) {
      matchState['threw'] = true;
      matchState['exception'] = e;
      matchState['stackTrace'] = st;
      if (_matcher.matches(e, matchState)) {
        return true;
      }
      matchState['innerMismatch'] = true;
      return false;
    }
  }

  @override
  Description describe(Description description) {
    return description.add('throws ').addDescriptionOf(_matcher);
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! Function) {
      return mismatchDescription.add('is not a Function');
    }

    if (matchState['threw'] == false) {
      return mismatchDescription.add('did not throw');
    }

    if (matchState['innerMismatch'] == true) {
      mismatchDescription.add('threw ');
      _matcher.describeMismatch(
        matchState['exception'],
        mismatchDescription,
        matchState,
        verbose,
      );
      return mismatchDescription;
    }

    return mismatchDescription;
  }
}

// =============================================================================
// Block Matchers
// =============================================================================

/// Matches a [Block] by its ID or against another [Block].
///
/// Can be used with either a [Block] instance or a [String] block ID:
/// ```dart
/// expect(block, isBlock(Block.stone));
/// expect(block, isBlock('minecraft:stone'));
/// ```
Matcher isBlock(Object expected) {
  if (expected is Block) {
    return _BlockMatcher(expected.id);
  } else if (expected is String) {
    return _BlockMatcher(expected);
  } else {
    throw ArgumentError(
      'isBlock() expects a Block or String, got ${expected.runtimeType}',
    );
  }
}

class _BlockMatcher extends Matcher {
  final String expectedId;

  _BlockMatcher(this.expectedId);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is Block) {
      return item.id == expectedId;
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add('Block with ID "$expectedId"');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is Block) {
      return mismatchDescription.add('has ID "${item.id}"');
    }
    return mismatchDescription.add('is not a Block (${item.runtimeType})');
  }
}

/// Matches the air block.
///
/// ```dart
/// expect(world.getBlock(pos), isAir);
/// ```
const Matcher isAirBlock = _AirBlockMatcher();

class _AirBlockMatcher extends Matcher {
  const _AirBlockMatcher();

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is Block) {
      return item.id == 'minecraft:air';
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add('is air block');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is Block) {
      return mismatchDescription.add('is ${item.id}');
    }
    return mismatchDescription.add('is not a Block (${item.runtimeType})');
  }
}

/// Matches any block that is NOT air.
///
/// ```dart
/// expect(world.getBlock(pos), isNotAir);
/// ```
const Matcher isNotAirBlock = _NotAirBlockMatcher();

class _NotAirBlockMatcher extends Matcher {
  const _NotAirBlockMatcher();

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is Block) {
      return item.id != 'minecraft:air';
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add('is not air block');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is Block) {
      return mismatchDescription.add('is air');
    }
    return mismatchDescription.add('is not a Block (${item.runtimeType})');
  }
}

// =============================================================================
// Position Matchers
// =============================================================================

/// Matches a [BlockPos] against expected coordinates.
///
/// ```dart
/// expect(entity.position.toBlockPos(), isAt(BlockPos(10, 64, 10)));
/// expect(blockPos, isAt(10, 64, 10));
/// ```
Matcher isAt(Object x, [int? y, int? z]) {
  if (x is BlockPos) {
    return _BlockPosMatcher(x);
  } else if (x is int && y != null && z != null) {
    return _BlockPosMatcher(BlockPos(x, y, z));
  } else {
    throw ArgumentError(
      'isAt() expects a BlockPos or three int coordinates',
    );
  }
}

class _BlockPosMatcher extends Matcher {
  final BlockPos expected;

  _BlockPosMatcher(this.expected);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is BlockPos) {
      return item.x == expected.x &&
          item.y == expected.y &&
          item.z == expected.z;
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add('at position (${expected.x}, ${expected.y}, ${expected.z})');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is BlockPos) {
      return mismatchDescription.add(
        'is at (${item.x}, ${item.y}, ${item.z})',
      );
    }
    return mismatchDescription.add('is not a BlockPos (${item.runtimeType})');
  }
}

/// Matches a [Vec3] within a tolerance.
///
/// ```dart
/// expect(entity.position, isNearVec3(Vec3(10.5, 64.0, 10.5)));
/// expect(entity.position, isNearVec3(Vec3(10.5, 64.0, 10.5), tolerance: 0.1));
/// ```
Matcher isNearVec3(Vec3 expected, {double tolerance = 0.01}) {
  return _Vec3Matcher(expected, tolerance);
}

class _Vec3Matcher extends Matcher {
  final Vec3 expected;
  final double tolerance;

  _Vec3Matcher(this.expected, this.tolerance);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is Vec3) {
      return (item.x - expected.x).abs() <= tolerance &&
          (item.y - expected.y).abs() <= tolerance &&
          (item.z - expected.z).abs() <= tolerance;
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add(
      'near position (${expected.x}, ${expected.y}, ${expected.z}) '
      'within $tolerance',
    );
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is Vec3) {
      final distance = item.distanceTo(expected);
      return mismatchDescription.add(
        'is at (${item.x}, ${item.y}, ${item.z}), '
        'distance $distance',
      );
    }
    return mismatchDescription.add('is not a Vec3 (${item.runtimeType})');
  }
}

// =============================================================================
// Entity Matchers
// =============================================================================

/// Matches an entity's health against a [Matcher].
///
/// ```dart
/// expect(entity, hasHealth(greaterThan(10)));
/// expect(entity, hasHealth(equals(20)));
/// expect(entity, hasHealth(lessThanOrEqualTo(5)));
/// ```
Matcher hasHealth(Matcher healthMatcher) {
  return _HealthMatcher(healthMatcher);
}

class _HealthMatcher extends Matcher {
  final Matcher healthMatcher;

  _HealthMatcher(this.healthMatcher);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is LivingEntity) {
      final health = item.health;
      return healthMatcher.matches(health, matchState);
    }
    if (item is Player) {
      final health = item.health;
      return healthMatcher.matches(health, matchState);
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add('has health that ').addDescriptionOf(healthMatcher);
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is LivingEntity) {
      return mismatchDescription.add('has health ${item.health}');
    }
    if (item is Player) {
      return mismatchDescription.add('has health ${item.health}');
    }
    return mismatchDescription.add(
      'is not a LivingEntity or Player (${item.runtimeType})',
    );
  }
}

/// Matches an entity's type.
///
/// ```dart
/// expect(entity, hasEntityType('minecraft:zombie'));
/// ```
Matcher hasEntityType(String expectedType) {
  return _EntityTypeMatcher(expectedType);
}

class _EntityTypeMatcher extends Matcher {
  final String expectedType;

  _EntityTypeMatcher(this.expectedType);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is Entity) {
      return item.type == expectedType;
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add('has entity type "$expectedType"');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is Entity) {
      return mismatchDescription.add('has type "${item.type}"');
    }
    return mismatchDescription.add('is not an Entity (${item.runtimeType})');
  }
}

/// Matches a dead entity.
///
/// ```dart
/// expect(entity, isDead);
/// ```
const Matcher isDeadEntity = _DeadEntityMatcher();

class _DeadEntityMatcher extends Matcher {
  const _DeadEntityMatcher();

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is LivingEntity) {
      return item.isDead;
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add('is dead');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is LivingEntity) {
      return mismatchDescription.add('is alive with ${item.health} health');
    }
    return mismatchDescription.add(
      'is not a LivingEntity (${item.runtimeType})',
    );
  }
}

/// Matches a living (not dead) entity.
///
/// ```dart
/// expect(entity, isAlive);
/// ```
const Matcher isAliveEntity = _AliveEntityMatcher();

class _AliveEntityMatcher extends Matcher {
  const _AliveEntityMatcher();

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is LivingEntity) {
      return !item.isDead;
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add('is alive');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is LivingEntity) {
      return mismatchDescription.add('is dead');
    }
    return mismatchDescription.add(
      'is not a LivingEntity (${item.runtimeType})',
    );
  }
}

// =============================================================================
// Player Matchers
// =============================================================================

/// Matches a player's game mode.
///
/// ```dart
/// expect(player, hasGameMode(GameMode.creative));
/// ```
Matcher hasGameMode(GameMode expectedMode) {
  return _GameModeMatcher(expectedMode);
}

class _GameModeMatcher extends Matcher {
  final GameMode expectedMode;

  _GameModeMatcher(this.expectedMode);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is Player) {
      return item.gameMode == expectedMode;
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add('has game mode ${expectedMode.name}');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is Player) {
      return mismatchDescription.add('has game mode ${item.gameMode.name}');
    }
    return mismatchDescription.add('is not a Player (${item.runtimeType})');
  }
}
