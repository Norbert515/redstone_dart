import 'item_model.dart';

/// Settings for creating an item.
class ItemSettings {
  /// Maximum stack size (1-64, default 64)
  final int maxStackSize;

  /// Maximum durability (0 for non-damageable items)
  final int maxDamage;

  /// Whether the item survives fire/lava
  final bool fireResistant;

  const ItemSettings({
    this.maxStackSize = 64,
    this.maxDamage = 0,
    this.fireResistant = false,
  });
}

/// Action result for item interactions.
enum ItemActionResult {
  success,
  consumePartial,
  consume,
  fail,
  pass,
}

/// Base class for custom items defined in Dart.
///
/// Extend this class to create custom items with custom behavior.
///
/// Example:
/// ```dart
/// class DartItem extends CustomItem {
///   DartItem() : super(
///     id: 'mymod:dart_item',
///     settings: ItemSettings(maxStackSize: 64),
///     model: ItemModel.generated(texture: 'assets/textures/item/dart_item.png'),
///   );
/// }
/// ```
abstract class CustomItem {
  /// The item identifier (e.g., 'mymod:dart_item')
  final String id;

  /// Item settings (stack size, durability, etc.)
  final ItemSettings settings;

  /// Item model for rendering
  final ItemModel model;

  /// Internal handler ID assigned during registration
  int? _handlerId;

  CustomItem({
    required this.id,
    required this.settings,
    required this.model,
  });

  /// Whether this item has been registered
  bool get isRegistered => _handlerId != null;

  /// Get the handler ID (only valid after registration)
  int get handlerId {
    if (_handlerId == null) {
      throw StateError('Item not registered: $id');
    }
    return _handlerId!;
  }

  /// Set the handler ID (called by ItemRegistry)
  void setHandlerId(int id) {
    if (_handlerId != null) {
      throw StateError('Handler ID already set for item: ${this.id}');
    }
    _handlerId = id;
  }

  // ==========================================================================
  // Overridable callbacks
  // ==========================================================================

  /// Called when the item is used (right-click in air).
  ///
  /// Return [ItemActionResult.success] to consume the action,
  /// [ItemActionResult.pass] to allow other handlers.
  ItemActionResult onUse(int worldId, int playerId, int hand) {
    return ItemActionResult.pass;
  }

  /// Called when the item is used on a block (right-click on block).
  ItemActionResult onUseOnBlock(
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
    int hand,
  ) {
    return ItemActionResult.pass;
  }

  /// Called when the item is used on an entity (right-click on entity).
  ItemActionResult onUseOnEntity(
    int worldId,
    int entityId,
    int playerId,
    int hand,
  ) {
    return ItemActionResult.pass;
  }
}
