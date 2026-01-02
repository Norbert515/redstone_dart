/// API for defining custom blocks in Dart.
library;

import '../types.dart';
import 'block_model.dart';
import 'block_settings.dart';

/// Base class for Dart-defined blocks.
///
/// Subclass this and override methods to define custom block behavior.
///
/// Example:
/// ```dart
/// class DiamondOreBlock extends CustomBlock {
///   DiamondOreBlock() : super(
///     id: 'mymod:diamond_ore',
///     settings: BlockSettings(hardness: 3.0, resistance: 3.0, requiresTool: true),
///   );
///
///   @override
///   ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
///     print('Player $playerId used diamond ore at ($x, $y, $z)');
///     return ActionResult.success;
///   }
/// }
/// ```
abstract class CustomBlock {
  /// The block identifier in format "namespace:path" (e.g., "mymod:custom_block").
  final String id;

  /// Block settings (hardness, resistance, etc.).
  final BlockSettings settings;

  /// Optional block model for texture configuration.
  final BlockModel? model;

  /// The item ID this block drops when mined (e.g., 'mymod:dart_item').
  /// If null, drops itself (as a BlockItem).
  final String? drops;

  /// Internal handler ID assigned during registration.
  int? _handlerId;

  CustomBlock({
    required this.id,
    required this.settings,
    this.model,
    this.drops,
  });

  /// Get the handler ID (only available after registration).
  int get handlerId {
    if (_handlerId == null) {
      throw StateError('Block not registered: $id');
    }
    return _handlerId!;
  }

  /// Check if this block has been registered.
  bool get isRegistered => _handlerId != null;

  /// Called when the block is broken by a player.
  ///
  /// Override to add custom break behavior.
  /// Return true to allow the break, false to cancel it.
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    return true; // Default: allow break
  }

  /// Called when a player right-clicks (uses) the block.
  ///
  /// Override to add custom interaction behavior.
  /// Return the appropriate [ActionResult].
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    return ActionResult.pass;
  }

  /// Called when an entity walks on top of the block.
  ///
  /// Override to add custom behavior (e.g., damage, effects).
  void onSteppedOn(int worldId, int x, int y, int z, int entityId) {
    // Default: no action
  }

  /// Called when an entity falls and lands on the block.
  ///
  /// Override to add custom fall behavior (e.g., reduce fall damage, bounce).
  void onFallenUpon(int worldId, int x, int y, int z, int entityId, double fallDistance) {
    // Default: no action
  }

  /// Called on random game ticks.
  ///
  /// Override to add random tick behavior (e.g., crop growth, spreading).
  /// Requires [BlockSettings.ticksRandomly] to be true.
  void randomTick(int worldId, int x, int y, int z) {
    // Default: no action
  }

  /// Called when the block is placed in the world.
  ///
  /// Override to add custom placement behavior.
  void onPlaced(int worldId, int x, int y, int z, int playerId) {
    // Default: no action
  }

  /// Called when the block is removed from the world.
  ///
  /// Override to add custom removal behavior (e.g., cleanup).
  void onRemoved(int worldId, int x, int y, int z) {
    // Default: no action
  }

  /// Called when an adjacent block changes.
  ///
  /// Override to react to neighbor changes (e.g., redstone).
  void neighborChanged(int worldId, int x, int y, int z, int neighborX, int neighborY, int neighborZ) {
    // Default: no action
  }

  /// Called when an entity is inside the block's collision box.
  ///
  /// Override to add effects on entities inside (e.g., cobweb slowdown, damage).
  void entityInside(int worldId, int x, int y, int z, int entityId) {
    // Default: no action
  }

  /// Internal: Set the handler ID after registration.
  void setHandlerId(int id) {
    _handlerId = id;
  }

  @override
  String toString() => 'CustomBlock($id, registered=$isRegistered)';
}
