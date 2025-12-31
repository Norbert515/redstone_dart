/// Game context for Minecraft client tests.
///
/// Provides access to client-specific features like screenshots,
/// camera positioning, and rendering verification.
library;

import 'dart:async';

import 'package:dart_mod_server/dart_mod_server.dart';

import 'client_test_binding.dart';

/// Context object providing access to client features during tests.
///
/// This is passed to [testMinecraftClient] callbacks and provides helper
/// methods for visual testing like taking screenshots.
class ClientGameContext {
  final ClientTestBinding _binding;

  /// Create a new client game context from a binding.
  ///
  /// This is intended for internal use by [testMinecraftClient].
  ClientGameContext(this._binding);

  /// Create a client game context for the current test.
  ///
  /// Ensures the binding is initialized and creates a context.
  factory ClientGameContext.create() {
    final binding = ClientTestBinding.ensureInitialized();
    return ClientGameContext(binding);
  }

  // ==========================================================================
  // Screenshot Methods
  // ==========================================================================

  /// Take a screenshot with the specified name.
  ///
  /// Returns the absolute path to the saved screenshot file.
  /// The file is saved in the Minecraft screenshots directory.
  ///
  /// Example:
  /// ```dart
  /// testMinecraftClient('entity renders correctly', (game) async {
  ///   // Position camera and spawn entity...
  ///   await game.waitTicks(5); // Wait for rendering to stabilize
  ///
  ///   final path = await game.takeScreenshot('entity_test');
  ///   print('Screenshot saved to: $path');
  /// });
  /// ```
  Future<String?> takeScreenshot(String name) async {
    // Wait a frame for any pending renders
    await waitTicks(1);

    final path = ClientBridge.takeScreenshot(name);

    // Wait for the screenshot to be written
    await waitTicks(2);

    return path;
  }

  // ==========================================================================
  // Camera Control
  // ==========================================================================

  /// Position the camera at the specified coordinates with optional rotation.
  ///
  /// [x], [y], [z] - The world coordinates to position the camera at.
  /// [yaw] - Horizontal rotation in degrees (0 = south, 90 = west, -90 = east).
  /// [pitch] - Vertical rotation in degrees (-90 = up, 0 = horizon, 90 = down).
  ///
  /// Example:
  /// ```dart
  /// // Position camera looking at an entity from above
  /// await game.positionCamera(100, 75, 200, yaw: 45, pitch: 45);
  /// ```
  Future<void> positionCamera(
    double x,
    double y,
    double z, {
    double yaw = 0,
    double pitch = 0,
  }) async {
    ClientBridge.positionCamera(x, y, z, yaw: yaw, pitch: pitch);
    await waitTicks(1); // Wait for position update
  }

  /// Position the camera at a block position with optional rotation.
  ///
  /// Convenience method that accepts a [BlockPos] instead of coordinates.
  Future<void> positionCameraAt(
    BlockPos pos, {
    double yaw = 0,
    double pitch = 0,
    double yOffset = 1.6, // Default eye height
  }) async {
    await positionCamera(
      pos.x.toDouble() + 0.5,
      pos.y.toDouble() + yOffset,
      pos.z.toDouble() + 0.5,
      yaw: yaw,
      pitch: pitch,
    );
  }

  /// Position the camera and look at a specific position.
  ///
  /// Places the camera at [cameraPos] and rotates it to look at [lookAt].
  ///
  /// Example:
  /// ```dart
  /// final entityPos = BlockPos(100, 64, 200);
  /// final cameraPos = BlockPos(105, 66, 205);
  /// await game.positionCameraLookingAt(cameraPos, lookAt: entityPos);
  /// ```
  Future<void> positionCameraLookingAt(
    BlockPos cameraPos, {
    required BlockPos lookAt,
    double yOffset = 1.6,
  }) async {
    // First move to position
    await positionCameraAt(cameraPos, yOffset: yOffset);

    // Then look at target
    ClientBridge.lookAt(
      lookAt.x.toDouble() + 0.5,
      lookAt.y.toDouble() + 0.5,
      lookAt.z.toDouble() + 0.5,
    );

    await waitTicks(1);
  }

  /// Make the camera look at a specific world position.
  ///
  /// Does not change the camera position, only the rotation.
  Future<void> lookAt(double x, double y, double z) async {
    ClientBridge.lookAt(x, y, z);
    await waitTicks(1);
  }

  // ==========================================================================
  // World Access (delegated to server-side functionality)
  // ==========================================================================

  /// Access to the overworld dimension.
  World get world => World.overworld;

  /// Access to the nether dimension.
  World get nether => World.nether;

  /// Access to the end dimension.
  World get end => World.end;

  // ==========================================================================
  // Tick-Based Waiting
  // ==========================================================================

  /// Wait for a specified number of client ticks.
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
        Duration(milliseconds: maxTicks * 50),
      );
    }
  }

  // ==========================================================================
  // Block Helpers (same as server context)
  // ==========================================================================

  /// Place a block at the given position in the overworld.
  void placeBlock(BlockPos pos, Block block) {
    world.setBlock(pos, block);
  }

  /// Get the block at the given position in the overworld.
  Block getBlock(BlockPos pos) {
    return world.getBlock(pos);
  }

  /// Check if a position contains air in the overworld.
  bool isAir(BlockPos pos) {
    return world.isAir(pos);
  }

  /// Fill a region with a block.
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

  // ==========================================================================
  // Window Information
  // ==========================================================================

  /// Get the window width in pixels.
  int get windowWidth => ClientBridge.getWindowWidth();

  /// Get the window height in pixels.
  int get windowHeight => ClientBridge.getWindowHeight();

  /// Get the screenshots directory path.
  String? get screenshotsDirectory => ClientBridge.getScreenshotsDirectory();

  // ==========================================================================
  // Test Utilities
  // ==========================================================================

  /// Get the current client tick.
  int get currentTick => _binding.currentTick;

  /// Check if the client is ready (world loaded, player present).
  bool get isClientReady => _binding.isClientReady;

  /// Wait for the client to be ready.
  Future<void> waitForClientReady() => _binding.waitForClientReady();
}
