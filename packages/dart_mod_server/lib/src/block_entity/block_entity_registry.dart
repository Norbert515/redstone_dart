/// Registry for Dart-defined block entity instances.
///
/// This registry manages block entity type registration and instance lifecycle,
/// routing callbacks from the native bridge to the correct block entity instances.
library;

import 'package:dart_mod_common/dart_mod_common.dart';

import '../bridge.dart';

/// Factory function for creating block entity instances.
typedef BlockEntityFactory = BlockEntity Function();

/// Registry for block entity types and instances.
///
/// Handles:
/// - Registering block entity types with their factory functions
/// - Creating block entity instances when blocks are placed
/// - Routing callbacks to the correct instances
/// - Cleaning up instances when blocks are removed
///
/// ## Example
///
/// ```dart
/// // Register a block entity type for a block
/// final handlerId = BlockEntityRegistry.registerType(
///   'mymod:my_furnace',
///   () => MyFurnace(),
///   inventorySize: 3,
///   containerTitle: 'My Furnace',
/// );
///
/// // Create an instance at a position
/// final instance = BlockEntityRegistry.createAt(handlerId, blockPosHash);
///
/// // Get an existing instance
/// final existing = BlockEntityRegistry.get(handlerId, blockPosHash);
///
/// // Remove an instance
/// BlockEntityRegistry.remove(handlerId, blockPosHash);
/// ```
class BlockEntityRegistry {
  /// Map of handler ID -> (position hash -> instance)
  static final Map<int, Map<int, BlockEntity>> _instances = {};

  /// Map of handler ID -> factory function
  static final Map<int, BlockEntityFactory> _factories = {};

  /// Map of block entity type ID (string) -> handler ID
  static final Map<String, int> _typeToHandler = {};

  BlockEntityRegistry._(); // Private constructor - all static

  /// Register a block entity type for a specific block and get a handler ID.
  ///
  /// This queues the registration with the native bridge so that when the
  /// block is registered with Java/Fabric, it will be created with block entity support.
  ///
  /// Parameters:
  /// - [blockId]: The block ID this block entity is for (e.g., 'mymod:my_furnace')
  /// - [factory]: Factory function to create new instances
  /// - [inventorySize]: Number of inventory slots (default 0 for no inventory)
  /// - [containerTitle]: Display title for the container UI
  /// - [ticks]: Whether this block entity should receive tick callbacks
  ///
  /// Returns the assigned handler ID.
  static int registerType(
    String blockId,
    BlockEntityFactory factory, {
    int inventorySize = 0,
    String containerTitle = '',
    bool ticks = true,
  }) {
    // Queue the registration with the native bridge
    final handlerId = ServerBridge.queueBlockEntityRegistration(
      blockId: blockId,
      inventorySize: inventorySize,
      containerTitle: containerTitle,
      ticks: ticks,
    );

    _factories[handlerId] = factory;
    _instances[handlerId] = {};
    _typeToHandler[blockId] = handlerId;

    print('BlockEntityRegistry: Registered $blockId with handler ID $handlerId');
    return handlerId;
  }

  /// Register a block entity type using the settings from the factory instance.
  ///
  /// This is a convenience method that extracts block ID and settings from
  /// a temporary instance created by the factory.
  ///
  /// Returns the assigned handler ID.
  static int registerTypeFromFactory(BlockEntityFactory factory) {
    // Create a temporary instance to get the settings
    final tempInstance = factory();
    final blockId = tempInstance.id;

    // Determine inventory size and container title from settings
    int inventorySize = 0;
    String containerTitle = blockId;

    if (tempInstance.settings is ProcessingSettings) {
      final ps = tempInstance.settings as ProcessingSettings;
      inventorySize = ps.slots.totalSlots;
      containerTitle = blockId.split(':').last.replaceAll('_', ' ');
      // Capitalize first letter of each word
      containerTitle = containerTitle.split(' ')
          .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
          .join(' ');
    }

    return registerType(
      blockId,
      factory,
      inventorySize: inventorySize,
      containerTitle: containerTitle,
      ticks: true,
    );
  }

  /// Get the handler ID for a block entity type ID.
  static int? getHandlerIdForType(String typeId) => _typeToHandler[typeId];

  /// Create a new block entity instance at a position.
  ///
  /// If an instance already exists at this position, it is replaced.
  static BlockEntity createAt(int handlerId, int blockPosHash) {
    final factory = _factories[handlerId];
    if (factory == null) {
      throw StateError('Unknown handler ID: $handlerId');
    }

    final instance = factory();
    instance.handlerId = handlerId;
    instance.blockPosHash = blockPosHash;

    _instances[handlerId] ??= {};
    _instances[handlerId]![blockPosHash] = instance;

    return instance;
  }

  /// Get an existing block entity instance.
  ///
  /// Returns null if no instance exists at this position.
  static BlockEntity? get(int handlerId, int blockPosHash) {
    return _instances[handlerId]?[blockPosHash];
  }

  /// Get or create a block entity instance.
  ///
  /// If no instance exists, creates one using the registered factory.
  static BlockEntity getOrCreate(int handlerId, int blockPosHash) {
    var instance = get(handlerId, blockPosHash);
    if (instance == null) {
      instance = createAt(handlerId, blockPosHash);
    }
    return instance;
  }

  /// Remove a block entity instance.
  ///
  /// Called when the block is broken or replaced.
  static void remove(int handlerId, int blockPosHash) {
    _instances[handlerId]?.remove(blockPosHash);
  }

  /// Get all instances of a block entity type.
  static Iterable<BlockEntity> getAllOfType(int handlerId) {
    return _instances[handlerId]?.values ?? [];
  }

  /// Get the total number of active block entity instances.
  static int get instanceCount {
    var count = 0;
    for (final typeInstances in _instances.values) {
      count += typeInstances.length;
    }
    return count;
  }

  /// Clear all instances (for testing or world unload).
  static void clearAll() {
    for (final typeInstances in _instances.values) {
      typeInstances.clear();
    }
  }
}
