/// Custom tool classes for creating pickaxes, axes, shovels, hoes, and swords.
library;

import 'custom_item.dart';
import 'item_model.dart';
import 'item_settings.dart';
import 'tool_material.dart';

/// Base class for custom tool items.
///
/// Extend this to create custom pickaxes, axes, shovels, hoes, or swords.
/// For convenience, use the specific subclasses like [CustomSword],
/// [CustomPickaxe], etc.
///
/// Example:
/// ```dart
/// class RubySword extends CustomSword {
///   RubySword() : super(
///     id: 'mymod:ruby_sword',
///     material: ToolMaterial.diamond, // or custom material
///     model: ItemModel.generated(texture: 'assets/textures/item/ruby_sword.png'),
///   );
/// }
/// ```
abstract class CustomTool extends CustomItem {
  /// The tool material
  final ToolMaterial material;

  /// The tool type
  final ToolType toolType;

  CustomTool({
    required String id,
    required this.material,
    required this.toolType,
    required ItemModel model,
    CombatAttributes? combat,
  }) : super(
          id: id,
          settings: ItemSettings(
            maxStackSize: 1,
            maxDamage: material.durability,
          ),
          model: model,
          combat: combat ?? _defaultCombat(toolType, material),
        );

  static CombatAttributes _defaultCombat(ToolType type, ToolMaterial material) {
    // Default attack damage and speeds from Minecraft
    switch (type) {
      case ToolType.sword:
        // Swords: base 3.0 + material bonus, speed -2.4
        return CombatAttributes.sword(
          damage: 3.0 + material.attackDamageBonus,
        );
      case ToolType.axe:
        // Axes: base damage and speed vary by material
        final (baseDamage, attackSpeed) = _axeValues(material);
        return CombatAttributes(
          attackDamage: baseDamage + material.attackDamageBonus,
          attackSpeed: attackSpeed,
        );
      case ToolType.pickaxe:
        // Pickaxes: base 1.0 + material bonus, speed -2.8
        return CombatAttributes(
          attackDamage: 1.0 + material.attackDamageBonus,
          attackSpeed: -2.8,
        );
      case ToolType.shovel:
        // Shovels: base 1.5 + material bonus, speed -3.0
        return CombatAttributes(
          attackDamage: 1.5 + material.attackDamageBonus,
          attackSpeed: -3.0,
        );
      case ToolType.hoe:
        // Hoes: 0 damage (MC uses negative base that cancels bonus), speed varies
        return CombatAttributes(
          attackDamage: 0.0,
          attackSpeed: _hoeSpeed(material),
        );
    }
  }

  // Axe base damage and attack speed per material
  static (double, double) _axeValues(ToolMaterial material) {
    return switch (material) {
      ToolMaterial.wood => (6.0, -3.2),
      ToolMaterial.stone => (7.0, -3.2),
      ToolMaterial.copper => (7.0, -3.2),
      ToolMaterial.iron => (6.0, -3.1),
      ToolMaterial.gold => (6.0, -3.0),
      ToolMaterial.diamond => (5.0, -3.0),
      ToolMaterial.netherite => (5.0, -3.0),
      _ => (6.0, -3.0), // Default for custom materials
    };
  }

  // Hoe attack speed per material
  static double _hoeSpeed(ToolMaterial material) {
    return switch (material) {
      ToolMaterial.netherite || ToolMaterial.diamond => 0.0,
      ToolMaterial.iron => -1.0,
      ToolMaterial.copper || ToolMaterial.stone => -2.0,
      _ => -3.0, // wood, gold, custom materials
    };
  }
}

/// A custom sword item.
///
/// Swords have high attack speed and moderate damage.
/// They are effective against cobwebs and certain blocks.
class CustomSword extends CustomTool {
  CustomSword({
    required super.id,
    required super.material,
    required super.model,
    super.combat,
  }) : super(toolType: ToolType.sword);
}

/// A custom pickaxe item.
///
/// Pickaxes mine stone-type blocks efficiently.
class CustomPickaxe extends CustomTool {
  CustomPickaxe({
    required super.id,
    required super.material,
    required super.model,
    super.combat,
  }) : super(toolType: ToolType.pickaxe);
}

/// A custom axe item.
///
/// Axes mine wood-type blocks efficiently and deal high damage.
class CustomAxe extends CustomTool {
  CustomAxe({
    required super.id,
    required super.material,
    required super.model,
    super.combat,
  }) : super(toolType: ToolType.axe);
}

/// A custom shovel item.
///
/// Shovels mine dirt, sand, gravel, and similar blocks efficiently.
class CustomShovel extends CustomTool {
  CustomShovel({
    required super.id,
    required super.material,
    required super.model,
    super.combat,
  }) : super(toolType: ToolType.shovel);
}

/// A custom hoe item.
///
/// Hoes are used to till farmland and mine certain blocks.
class CustomHoe extends CustomTool {
  CustomHoe({
    required super.id,
    required super.material,
    required super.model,
    super.combat,
  }) : super(toolType: ToolType.hoe);
}
