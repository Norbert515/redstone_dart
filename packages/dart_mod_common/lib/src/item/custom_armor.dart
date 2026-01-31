/// Custom armor items for Dart Minecraft mods.
library;

import 'armor_material.dart';
import 'armor_type.dart';
import 'custom_item.dart';
import 'item_model.dart';
import 'item_settings.dart';

/// Base class for custom armor items.
///
/// Extend this class or use one of the convenience subclasses
/// ([CustomHelmet], [CustomChestplate], [CustomLeggings], [CustomBoots])
/// to create custom armor items.
///
/// Example:
/// ```dart
/// class RubyHelmet extends CustomHelmet {
///   RubyHelmet() : super(
///     id: 'mymod:ruby_helmet',
///     material: ArmorMaterial(
///       durability: 25,
///       protection: ArmorMaterial.makeProtection(2, 5, 6, 3),
///       enchantability: 12,
///       toughness: 1.0,
///       repairItem: 'mymod:ruby',
///     ),
///     model: ItemModel.generated(texture: 'assets/textures/item/ruby_helmet.png'),
///   );
///
///   @override
///   void onArmorTick(int worldId, int playerId) {
///     // Add special effects while wearing
///   }
/// }
/// ```
abstract class CustomArmor extends CustomItem {
  /// The armor material defining stats.
  final ArmorMaterial material;

  /// The armor slot type.
  final ArmorType armorType;

  CustomArmor({
    required String id,
    required this.material,
    required this.armorType,
    required ItemModel model,
  }) : super(
          id: id,
          settings: ItemSettings(
            maxStackSize: 1,
            maxDamage: material.getDurability(armorType),
          ),
          model: model,
        );

  /// Called every tick while the armor is equipped.
  ///
  /// Override this to add special effects when the armor is worn.
  /// For example, regeneration, fire resistance, or custom abilities.
  ///
  /// [worldId] is the ID of the world the player is in.
  /// [playerId] is the entity ID of the player wearing the armor.
  void onArmorTick(int worldId, int playerId) {}
}

/// Custom helmet item.
///
/// Convenience class for creating helmet items with [ArmorType.helmet].
class CustomHelmet extends CustomArmor {
  CustomHelmet({
    required super.id,
    required super.material,
    required super.model,
  }) : super(armorType: ArmorType.helmet);
}

/// Custom chestplate item.
///
/// Convenience class for creating chestplate items with [ArmorType.chestplate].
class CustomChestplate extends CustomArmor {
  CustomChestplate({
    required super.id,
    required super.material,
    required super.model,
  }) : super(armorType: ArmorType.chestplate);
}

/// Custom leggings item.
///
/// Convenience class for creating leggings items with [ArmorType.leggings].
class CustomLeggings extends CustomArmor {
  CustomLeggings({
    required super.id,
    required super.material,
    required super.model,
  }) : super(armorType: ArmorType.leggings);
}

/// Custom boots item.
///
/// Convenience class for creating boots items with [ArmorType.boots].
class CustomBoots extends CustomArmor {
  CustomBoots({
    required super.id,
    required super.material,
    required super.model,
  }) : super(armorType: ArmorType.boots);
}
