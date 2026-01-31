/// Armor slot types for equipment.
library;

/// Armor slot types.
///
/// Each slot has a durability multiplier that is used to calculate the total
/// durability of armor items based on the material's base durability.
enum ArmorType {
  helmet(11, 'helmet'),
  chestplate(16, 'chestplate'),
  leggings(15, 'leggings'),
  boots(13, 'boots'),
  body(16, 'body'); // For animal armor (wolf, horse, etc.)

  /// Durability multiplier for this slot.
  ///
  /// Total durability = materialDurability * durabilityMultiplier.
  final int durabilityMultiplier;

  /// Name used for textures and IDs.
  final String name;

  const ArmorType(this.durabilityMultiplier, this.name);

  /// Calculate the total durability for a given material's base durability.
  int getDurability(int materialDurability) =>
      durabilityMultiplier * materialDurability;
}
