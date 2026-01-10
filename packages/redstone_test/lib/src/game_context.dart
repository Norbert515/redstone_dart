/// Game context for Minecraft tests.
///
/// Provides access to the game world and utilities for test execution.
library;

import 'dart:async';

import 'package:dart_mod_server/dart_mod_server.dart';

import 'test_binding.dart';

/// Context object providing access to the game during tests.
///
/// This is passed to [testMinecraft] callbacks and provides helper
/// methods for interacting with the Minecraft world.
class MinecraftGameContext {
  final MinecraftTestBinding _binding;

  /// Create a new game context from a binding.
  ///
  /// This is intended for internal use by [testMinecraft].
  /// Prefer using [MinecraftGameContext.create] for general use.
  MinecraftGameContext(this._binding);

  /// Create a game context for the current test.
  ///
  /// Ensures the binding is initialized and creates a context.
  factory MinecraftGameContext.create() {
    final binding = MinecraftTestBinding.ensureInitialized();
    return MinecraftGameContext(binding);
  }

  // ==========================================================================
  // World Access
  // ==========================================================================

  /// Access to the overworld dimension.
  World get world => World.overworld;

  /// Access to the nether dimension.
  World get nether => World.nether;

  /// Access to the end dimension.
  World get end => World.end;

  /// Access a specific world/dimension by ID.
  World getWorld(String dimensionId) => World(dimensionId);

  // ==========================================================================
  // Tick-Based Waiting
  // ==========================================================================

  /// Wait for a specified number of game ticks.
  ///
  /// Example:
  /// ```dart
  /// await game.waitTicks(20); // Wait 1 second (20 ticks)
  /// ```
  Future<void> waitTicks(int ticks) {
    if (ticks <= 0) return Future.value();

    final completer = Completer<void>();
    final targetTick = _binding.currentTick + ticks;
    _binding.registerTickCompleter(targetTick, completer);
    return completer.future;
  }

  /// Wait until a condition becomes true, or timeout after [maxTicks].
  ///
  /// Polls the condition every [pollInterval] ticks (default 1).
  /// Returns `true` if the condition was met, `false` if timed out.
  ///
  /// Example:
  /// ```dart
  /// final success = await game.waitUntil(
  ///   () => world.getBlock(pos) == Block.stone,
  ///   maxTicks: 100,
  /// );
  /// expect(success, isTrue);
  /// ```
  Future<bool> waitUntil(
    bool Function() condition, {
    int maxTicks = 100,
    int pollInterval = 1,
  }) async {
    var ticksWaited = 0;

    while (ticksWaited < maxTicks) {
      if (condition()) {
        return true;
      }
      await waitTicks(pollInterval);
      ticksWaited += pollInterval;
    }

    return condition(); // Final check
  }

  /// Wait until a condition becomes true, or throw if it doesn't within [maxTicks].
  ///
  /// Like [waitUntil] but throws a [TimeoutException] if the condition is not met.
  ///
  /// Example:
  /// ```dart
  /// await game.waitUntilOrThrow(
  ///   () => world.getBlock(pos) == Block.stone,
  ///   maxTicks: 100,
  ///   reason: 'Block should have changed to stone',
  /// );
  /// ```
  Future<void> waitUntilOrThrow(
    bool Function() condition, {
    int maxTicks = 100,
    int pollInterval = 1,
    String? reason,
  }) async {
    final success = await waitUntil(
      condition,
      maxTicks: maxTicks,
      pollInterval: pollInterval,
    );

    if (!success) {
      throw TimeoutException(
        reason ?? 'Condition not met within $maxTicks ticks',
        Duration(milliseconds: maxTicks * 50), // ~50ms per tick
      );
    }
  }

  // ==========================================================================
  // Block Helpers
  // ==========================================================================

  /// Place a block at the given position in the overworld.
  ///
  /// This is a convenience method for [world.setBlock].
  void placeBlock(BlockPos pos, Block block) {
    world.setBlock(pos, block);
  }

  /// Get the block at the given position in the overworld.
  ///
  /// This is a convenience method for [world.getBlock].
  Block getBlock(BlockPos pos) {
    return world.getBlock(pos);
  }

  /// Set a block in the specified world.
  void setBlock(World targetWorld, BlockPos pos, Block block) {
    targetWorld.setBlock(pos, block);
  }

  /// Get a block from the specified world.
  Block getBlockIn(World targetWorld, BlockPos pos) {
    return targetWorld.getBlock(pos);
  }

  /// Check if a position contains air in the overworld.
  bool isAir(BlockPos pos) {
    return world.isAir(pos);
  }

  /// Fill a region with a block.
  ///
  /// Fills all blocks in the rectangular region from [from] to [to] (inclusive).
  void fillBlocks(BlockPos from, BlockPos to, Block block) {
    final minX = from.x < to.x ? from.x : to.x;
    final maxX = from.x > to.x ? from.x : to.x;
    final minY = from.y < to.y ? from.y : to.y;
    final maxY = from.y > to.y ? from.y : to.y;
    final minZ = from.z < to.z ? from.z : to.z;
    final maxZ = from.z > to.z ? from.z : to.z;

    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        for (var z = minZ; z <= maxZ; z++) {
          world.setBlock(BlockPos(x, y, z), block);
        }
      }
    }
  }

  // ==========================================================================
  // Block Entity Helpers
  // ==========================================================================

  /// Get a block entity at the given position.
  ///
  /// [typeId] is the block entity type (e.g., 'mymod:my_chest').
  /// Returns null if no block entity of that type exists at this position.
  ///
  /// Example:
  /// ```dart
  /// final chest = game.getBlockEntity<MyChestEntity>(
  ///   pos,
  ///   'mymod:my_chest',
  /// );
  /// expect(chest?.container.progress.value, equals(0));
  /// ```
  T? getBlockEntity<T extends BlockEntity>(BlockPos pos, String typeId) {
    final handlerId = BlockEntityRegistry.getHandlerIdForType(typeId);
    if (handlerId == null) {
      print('[GameContext] getBlockEntity: No handler ID for typeId=$typeId');
      return null; // Type not registered
    }

    final blockPosHash = encodeBlockPos(pos);
    final result = BlockEntityRegistry.get(handlerId, blockPosHash);
    if (result == null) {
      print('[GameContext] getBlockEntity: No instance found at pos=$pos (hash=$blockPosHash) for handlerId=$handlerId');
    }
    return result as T?;
  }

  // ==========================================================================
  // Entity Helpers
  // ==========================================================================

  /// Spawn an entity at the given position.
  Entity? spawnEntity(String entityType, Vec3 position) {
    return Entities.spawn(world, entityType, position);
  }

  /// Get all entities within a radius of a position.
  List<Entity> getEntitiesInRadius(Vec3 center, double radius) {
    return Entities.getEntitiesInRadius(world, center, radius);
  }

  /// Get all players currently online.
  List<Player> get players => Players.getAllPlayers();

  // ==========================================================================
  // Time Control
  // ==========================================================================

  /// Set the time of day in the overworld.
  void setTimeOfDay(int time) {
    world.timeOfDay = time;
  }

  /// Set the weather in the overworld.
  void setWeather(Weather weather, {int durationTicks = 6000}) {
    world.setWeather(weather, durationTicks);
  }

  // ==========================================================================
  // Chunk Management
  // ==========================================================================

  /// Force-load the chunk containing a block position.
  ///
  /// This prevents the chunk from being unloaded by Minecraft's chunk
  /// management system. Useful for tests to ensure block entities
  /// aren't removed during chunk unloading.
  ///
  /// Example:
  /// ```dart
  /// game.forceLoadChunkAt(pos);
  /// game.placeBlock(pos, Block.myChest);
  /// await game.waitTicks(100);
  /// // Block entity will still exist even after many ticks
  /// ```
  bool forceLoadChunkAt(BlockPos pos, {String dimension = 'minecraft:overworld'}) {
    return ServerBridge.forceLoadChunkAtBlockPos(dimension, pos.x, pos.z);
  }

  /// Remove force-load from the chunk containing a block position.
  ///
  /// Call this after your test is done to allow normal chunk unloading.
  bool unforceLoadChunkAt(BlockPos pos, {String dimension = 'minecraft:overworld'}) {
    return ServerBridge.forceLoadChunkAtBlockPos(dimension, pos.x, pos.z, load: false);
  }

  /// Force-load a chunk by chunk coordinates.
  bool forceLoadChunk(int chunkX, int chunkZ, {String dimension = 'minecraft:overworld'}) {
    return ServerBridge.setChunkForceLoaded(dimension, chunkX, chunkZ, true);
  }

  /// Remove force-load from a chunk by chunk coordinates.
  bool unforceLoadChunk(int chunkX, int chunkZ, {String dimension = 'minecraft:overworld'}) {
    return ServerBridge.setChunkForceLoaded(dimension, chunkX, chunkZ, false);
  }

  // ==========================================================================
  // Test Utilities
  // ==========================================================================

  /// Get the current game tick.
  int get currentTick => _binding.currentTick;

  /// Get the game time in the overworld.
  int get gameTime => world.gameTime;
}
