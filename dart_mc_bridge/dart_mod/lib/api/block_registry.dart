/// Registry for Dart-defined blocks.
library;

import 'custom_block.dart';
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
    final handlerId = GenericJniBridge.callStaticLongMethod(
      'com/redstone/proxy/ProxyRegistry',
      'createBlock',
      '(FFZ)J',
      [
        block.settings.hardness,
        block.settings.resistance,
        block.settings.requiresTool,
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

    print('BlockRegistry: Registered ${block.id} with handler ID $handlerId');
    return handlerId;
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
  static void freeze() {
    _frozen = true;
    print('BlockRegistry: Frozen with ${_blocks.length} blocks registered');
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
}
