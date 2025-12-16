/// Registry for Dart-defined blocks.
library;

import 'dart:convert';
import 'dart:io';

import 'custom_block.dart';
import '../src/bridge.dart';
import '../src/jni/generic_bridge.dart';

/// Registry for Dart-defined blocks.
///
/// All blocks must be registered during mod initialization (before Minecraft's
/// registry freezes). Attempting to register blocks after initialization will fail.
///
/// Example:
/// ```dart
/// void onModInit() {
///   BlockRegistry.register(DiamondOreBlock());
///   BlockRegistry.register(CopperOreBlock());
///   // ... register all your blocks
/// }
/// ```
class BlockRegistry {
  static final Map<int, CustomBlock> _blocks = {};
  static bool _frozen = false;

  BlockRegistry._(); // Private constructor - all static

  /// Register a custom block.
  ///
  /// Must be called during mod initialization, before the registry freezes.
  /// Throws [StateError] if called after initialization.
  ///
  /// Returns the handler ID assigned to this block.
  static int register(CustomBlock block) {
    if (_frozen) {
      throw StateError(
        'Cannot register blocks after initialization. '
        'Block: ${block.id}',
      );
    }

    if (block.isRegistered) {
      throw StateError('Block already registered: ${block.id}');
    }

    // Parse the identifier
    final parts = block.id.split(':');
    if (parts.length != 2) {
      throw ArgumentError(
        'Invalid block ID format. Expected "namespace:path", got: ${block.id}',
      );
    }
    final namespace = parts[0];
    final path = parts[1];

    // Create the proxy block in Java
    // JNI signature: (FFZ I DDD ZZZ Z)J
    // float hardness, float resistance, boolean requiresTool,
    // int luminance, double slipperiness, double velocityMultiplier, double jumpVelocityMultiplier,
    // boolean ticksRandomly, boolean collidable, boolean replaceable, boolean burnable
    // returns long
    final handlerId = GenericJniBridge.callStaticLongMethod(
      'com/redstone/proxy/ProxyRegistry',
      'createBlock',
      '(FFZIDDDZZZ Z)J'.replaceAll(' ', ''),
      [
        block.settings.hardness,
        block.settings.resistance,
        block.settings.requiresTool,
        block.settings.luminance,
        block.settings.slipperiness,
        block.settings.velocityMultiplier,
        block.settings.jumpVelocityMultiplier,
        block.settings.ticksRandomly,
        block.settings.collidable,
        block.settings.replaceable,
        block.settings.burnable,
      ],
    );

    if (handlerId == 0) {
      throw StateError('Failed to create proxy block for: ${block.id}');
    }

    // Register with Minecraft's registry
    final success = GenericJniBridge.callStaticBoolMethod(
      'com/redstone/proxy/ProxyRegistry',
      'registerBlock',
      '(JLjava/lang/String;Ljava/lang/String;)Z',
      [handlerId, namespace, path],
    );

    if (!success) {
      throw StateError('Failed to register block with Minecraft: ${block.id}');
    }

    // Store the block and set its handler ID
    block.setHandlerId(handlerId);
    _blocks[handlerId] = block;

    // Write manifest after each registration
    _writeManifest();

    print('BlockRegistry: Registered ${block.id} with handler ID $handlerId');
    return handlerId;
  }

  /// Write the block manifest to `.redstone/manifest.json`.
  ///
  /// This file is read by the CLI to generate Minecraft resource files.
  static void _writeManifest() {
    final blocks = <Map<String, dynamic>>[];

    for (final block in _blocks.values) {
      final blockEntry = <String, dynamic>{
        'id': block.id,
      };

      // Only include model if present
      if (block.model != null) {
        blockEntry['model'] = block.model!.toJson();
      }

      // Include drops if specified
      if (block.drops != null) {
        blockEntry['drops'] = block.drops;
      }

      blocks.add(blockEntry);
    }

    // Read existing manifest to preserve items
    Map<String, dynamic> manifest = {};
    final manifestFile = File('.redstone/manifest.json');
    if (manifestFile.existsSync()) {
      try {
        manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parse errors
      }
    }

    manifest['blocks'] = blocks;

    // Create .redstone directory if it doesn't exist
    final redstoneDir = Directory('.redstone');
    if (!redstoneDir.existsSync()) {
      redstoneDir.createSync(recursive: true);
    }

    // Write manifest with pretty formatting
    final encoder = JsonEncoder.withIndent('  ');
    manifestFile.writeAsStringSync(encoder.convert(manifest));

    print('BlockRegistry: Wrote manifest with ${blocks.length} blocks');
  }

  /// Get a block by its handler ID.
  ///
  /// Returns null if no block is registered with that ID.
  static CustomBlock? getBlock(int handlerId) {
    return _blocks[handlerId];
  }

  /// Get all registered blocks.
  static Iterable<CustomBlock> get allBlocks => _blocks.values;

  /// Get the number of registered blocks.
  static int get blockCount => _blocks.length;

  /// Freeze the registry (called internally after mod initialization).
  ///
  /// After this is called, no more blocks can be registered.
  /// In datagen mode, this also exits the process after writing the manifest.
  static void freeze() {
    _frozen = true;
    print('BlockRegistry: Frozen with ${_blocks.length} blocks registered');

    // In datagen mode, exit cleanly after registration is complete
    // The manifest has been written, so the CLI can now generate assets
    if (Bridge.isDatagenMode) {
      print('BlockRegistry: Datagen mode complete, exiting...');
      exit(0);
    }
  }

  /// Check if the registry is frozen.
  static bool get isFrozen => _frozen;

  // ==========================================================================
  // Internal dispatch methods - called from native code
  // ==========================================================================

  /// Dispatch a block break event to the appropriate handler.
  /// Called from native code via callback.
  /// Returns true to allow break, false to cancel.
  static bool dispatchBlockBreak(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
  ) {
    final block = _blocks[handlerId];
    if (block != null) {
      return block.onBreak(worldId, x, y, z, playerId);
    }
    return true; // Default: allow break
  }

  /// Dispatch a block use event to the appropriate handler.
  /// Called from native code via callback.
  /// Returns the ActionResult ordinal.
  static int dispatchBlockUse(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
    int hand,
  ) {
    final block = _blocks[handlerId];
    if (block != null) {
      final result = block.onUse(worldId, x, y, z, playerId, hand);
      return result.index;
    }
    return ActionResult.pass.index;
  }

  /// Dispatch a stepped on event to the appropriate handler.
  /// Called from native code via callback.
  static void dispatchSteppedOn(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int entityId,
  ) {
    final block = _blocks[handlerId];
    block?.onSteppedOn(worldId, x, y, z, entityId);
  }

  /// Dispatch a fallen upon event to the appropriate handler.
  /// Called from native code via callback.
  static void dispatchFallenUpon(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int entityId,
    double fallDistance,
  ) {
    final block = _blocks[handlerId];
    block?.onFallenUpon(worldId, x, y, z, entityId, fallDistance);
  }

  /// Dispatch a random tick event to the appropriate handler.
  /// Called from native code via callback.
  static void dispatchRandomTick(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
  ) {
    final block = _blocks[handlerId];
    block?.randomTick(worldId, x, y, z);
  }

  /// Dispatch a block placed event to the appropriate handler.
  /// Called from native code via callback.
  static void dispatchPlaced(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
  ) {
    final block = _blocks[handlerId];
    block?.onPlaced(worldId, x, y, z, playerId);
  }

  /// Dispatch a block removed event to the appropriate handler.
  /// Called from native code via callback.
  static void dispatchRemoved(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
  ) {
    final block = _blocks[handlerId];
    block?.onRemoved(worldId, x, y, z);
  }

  /// Dispatch a neighbor changed event to the appropriate handler.
  /// Called from native code via callback.
  static void dispatchNeighborChanged(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int neighborX,
    int neighborY,
    int neighborZ,
  ) {
    final block = _blocks[handlerId];
    block?.neighborChanged(worldId, x, y, z, neighborX, neighborY, neighborZ);
  }

  /// Dispatch an entity inside event to the appropriate handler.
  /// Called from native code via callback.
  static void dispatchEntityInside(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int entityId,
  ) {
    final block = _blocks[handlerId];
    block?.entityInside(worldId, x, y, z, entityId);
  }
}
