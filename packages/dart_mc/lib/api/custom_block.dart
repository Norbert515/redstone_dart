/// API for defining custom blocks in Dart.
library;

/// Result of a block interaction.
enum ActionResult {
  success, // 0 - Interaction succeeded, arm swings
  consumePartial, // 1
  consume, // 2 - Interaction succeeded, no arm swing
  pass, // 3 - No interaction, try other handlers
  fail, // 4 - Interaction failed
}

/// Settings for creating a block.
class BlockSettings {
  final double hardness;
  final double resistance;
  final bool requiresTool;

  const BlockSettings({
    this.hardness = 1.0,
    this.resistance = 1.0,
    this.requiresTool = false,
  });
}

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

  /// Internal handler ID assigned during registration.
  int? _handlerId;

  CustomBlock({
    required this.id,
    required this.settings,
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

  // Future: Add more overridable methods
  // void onSteppedOn(int worldId, int x, int y, int z, int entityId) {}
  // void onLandedUpon(int worldId, int x, int y, int z, int entityId, double fallDistance) {}
  // void randomTick(int worldId, int x, int y, int z) {}

  /// Internal: Set the handler ID after registration.
  void setHandlerId(int id) {
    _handlerId = id;
  }

  @override
  String toString() => 'CustomBlock($id, registered=$isRegistered)';
}
