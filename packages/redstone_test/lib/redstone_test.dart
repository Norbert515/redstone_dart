/// Testing library for Minecraft mods built with dart_mc.
///
/// This library extends `package:test` with Minecraft-specific functionality,
/// similar to how `flutter_test` extends `package:test` for Flutter.
///
/// ## Getting Started
///
/// ```dart
/// import 'package:redstone_test/redstone_test.dart';
///
/// void main() {
///   testMinecraft('placing a block changes the world', (game) async {
///     final pos = BlockPos(0, 64, 0);
///
///     game.placeBlock(pos, Block.stone);
///
///     expect(game.getBlock(pos), isBlock(Block.stone));
///   });
///
///   testMinecraft('waiting for game ticks', (game) async {
///     // Wait for 20 ticks (1 second)
///     await game.waitTicks(20);
///
///     // Wait until a condition is met
///     await game.waitUntil(() => game.getBlock(pos) == Block.air);
///   });
/// }
/// ```
///
/// ## Test Functions
///
/// - [testMinecraft] - Define a Minecraft test (wraps package:test's test())
///
/// Since [testMinecraft] wraps the standard [test] function, you can use
/// regular `setUp`, `tearDown`, `group`, etc. from `package:test`:
///
/// ```dart
/// import 'package:test/test.dart';
/// import 'package:redstone_test/redstone_test.dart';
///
/// void main() {
///   late BlockPos testArea;
///
///   setUp(() {
///     testArea = BlockPos(0, 64, 0);
///   });
///
///   tearDown(() {
///     // Clean up test area if needed
///   });
///
///   group('Block operations', () {
///     testMinecraft('can place blocks', (game) async {
///       game.placeBlock(testArea, Block.stone);
///       expect(game.getBlock(testArea), isBlock(Block.stone));
///     });
///   });
/// }
/// ```
///
/// ## Matchers
///
/// Minecraft-specific matchers for expressive assertions:
///
/// - [isBlock] - Match a block by type
/// - [isAirBlock] - Match the air block
/// - [isNotAirBlock] - Match any non-air block
/// - [isAt] - Match a position
/// - [isNearVec3] - Match a Vec3 within tolerance
/// - [hasHealth] - Match entity health
/// - [hasEntityType] - Match entity type
/// - [isDeadEntity] - Match a dead entity
/// - [isAliveEntity] - Match a living entity
/// - [hasGameMode] - Match player game mode
library redstone_test;

// Test function and result tracking
export 'src/minecraft_test.dart' show testMinecraft, group, testResults, TestResults;

// Test events for structured output
export 'src/test_event.dart'
    show
        testEventPrefix,
        TestEvent,
        SuiteStartEvent,
        SuiteEndEvent,
        GroupStartEvent,
        GroupEndEvent,
        TestStartEvent,
        TestPassEvent,
        TestFailEvent,
        TestSkipEvent,
        DoneEvent,
        emitEvent;

// Game context
export 'src/game_context.dart' show MinecraftGameContext;

// Test binding
export 'src/test_binding.dart' show MinecraftTestBinding;

// Programmatic runner
export 'src/programmatic_runner.dart'
    show runTestsProgrammatically, TestRunResult, TestFilterConfig, parseFilterArgs;

// Matchers and expect
export 'src/matchers.dart'
    show
        // Our custom expect (works outside test zones)
        expect,
        TestFailure,
        // Our custom throwsA (works outside test zones)
        throwsA,
        // Minecraft-specific matchers
        isBlock,
        isAirBlock,
        isNotAirBlock,
        isAt,
        isNearVec3,
        hasHealth,
        hasEntityType,
        isDeadEntity,
        isAliveEntity,
        hasGameMode;

// Re-export dart_mc types needed for testing
export 'package:dart_mc/dart_mc.dart'
    show
        // Core types
        Block,
        BlockPos,
        BlockState,
        Vec3,
        Direction,
        Hand,
        EventResult,
        // World
        World,
        Weather,
        SoundCategory,
        ExplosionMode,
        Difficulty,
        Sounds,
        Particles,
        // Entities
        Entity,
        LivingEntity,
        MobEntity,
        Entities,
        StatusEffect,
        AABB,
        // Players
        Player,
        Players,
        PlayerInfo,
        GameMode,
        // Events
        Events;

// Re-export common matchers from package:matcher (zone-independent)
export 'package:matcher/matcher.dart'
    show
        // Common matchers
        equals,
        isTrue,
        isFalse,
        isNull,
        isNotNull,
        isA,
        greaterThan,
        lessThan,
        greaterThanOrEqualTo,
        lessThanOrEqualTo,
        inInclusiveRange,
        inExclusiveRange,
        inOpenClosedRange,
        inClosedOpenRange,
        contains,
        containsAll,
        containsAllInOrder,
        isEmpty,
        isNotEmpty,
        hasLength,
        everyElement,
        anyElement,
        // Matcher utilities
        Matcher,
        isNot,
        allOf,
        anyOf,
        StringDescription;
