/// Item settings for creating custom items.
library;

/// Settings for creating a custom item.
class ItemSettings {
  /// Maximum stack size (1-64, or higher for custom items).
  final int maxStackSize;

  /// Maximum durability (0 for items without durability).
  final int maxDamage;

  /// Whether the item survives fire/lava.
  final bool fireResistant;

  /// Attack damage when used as a weapon.
  final double attackDamage;

  /// Attack speed modifier.
  final double attackSpeed;

  /// Attack knockback modifier.
  final double attackKnockback;

  const ItemSettings({
    this.maxStackSize = 64,
    this.maxDamage = 0,
    this.fireResistant = false,
    this.attackDamage = 0.0,
    this.attackSpeed = 0.0,
    this.attackKnockback = 0.0,
  });
}
