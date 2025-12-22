import 'item_model.dart';

/// Combat attributes for weapon items.
///
/// These attributes affect how much damage the item deals when used as a weapon.
class CombatAttributes {
  /// Additional attack damage (added to base player damage of 1)
  final double attackDamage;

  /// Attack speed modifier (default player speed is 4.0, swords use -2.4)
  final double attackSpeed;

  /// Additional knockback applied on hit
  final double attackKnockback;

  const CombatAttributes({
    required this.attackDamage,
    this.attackSpeed = -2.4,
    this.attackKnockback = 0.0,
  });

  /// Creates combat attributes for a sword-like weapon.
  /// Swords have faster attack speed than axes.
  factory CombatAttributes.sword({
    required double damage,
    double speed = -2.4,
    double knockback = 0.0,
  }) {
    return CombatAttributes(
      attackDamage: damage,
      attackSpeed: speed,
      attackKnockback: knockback,
    );
  }

  /// Creates combat attributes for an axe-like weapon.
  /// Axes are slower but can deal more damage per hit.
  factory CombatAttributes.axe({
    required double damage,
    double speed = -3.0,
    double knockback = 0.0,
  }) {
    return CombatAttributes(
      attackDamage: damage,
      attackSpeed: speed,
      attackKnockback: knockback,
    );
  }
}

/// Settings for creating an item.
class ItemSettings {
  /// Maximum stack size (1-64, default 64)
  final int maxStackSize;

  /// Maximum durability (0 for non-damageable items)
  final int maxDamage;

  /// Whether the item survives fire/lava
  final bool fireResistant;

  /// Combat attributes for weapon items (optional)
  final CombatAttributes? combat;

  const ItemSettings({
    this.maxStackSize = 64,
    this.maxDamage = 0,
    this.fireResistant = false,
    this.combat,
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

  /// Called when the item is used to attack an entity (left-click hit).
  ///
  /// [worldId] - The world where the attack occurred
  /// [attackerId] - The entity ID of the attacker (usually the player)
  /// [targetId] - The entity ID of the entity that was hit
  ///
  /// Return true to indicate the attack was handled specially.
  bool onAttackEntity(int worldId, int attackerId, int targetId) {
    return false; // Not handled by default
  }
}
