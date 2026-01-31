/// Food settings for custom food items.
library;

import 'status_effect.dart';

/// Settings for food items.
///
/// Defines nutrition, saturation, and optional status effects.
class FoodSettings {
  /// Hunger points restored (0-20, each icon = 2 points)
  final int nutrition;

  /// Saturation modifier (affects how long you stay full)
  /// Actual saturation = nutrition * saturationModifier * 2
  final double saturationModifier;

  /// Whether the food can be eaten even when not hungry
  final bool alwaysEdible;

  /// Time to consume in seconds (default: 1.6)
  final double consumeSeconds;

  /// Status effects to apply when eaten
  final List<StatusEffectInstance> effects;

  const FoodSettings({
    required this.nutrition,
    required this.saturationModifier,
    this.alwaysEdible = false,
    this.consumeSeconds = 1.6,
    this.effects = const [],
  });

  /// Calculated saturation value
  double get saturation => nutrition * saturationModifier * 2;

  // Some common food presets

  /// Apple-like food (4 nutrition, 0.3 saturation)
  static const apple = FoodSettings(
    nutrition: 4,
    saturationModifier: 0.3,
  );

  /// Bread-like food (5 nutrition, 0.6 saturation)
  static const bread = FoodSettings(
    nutrition: 5,
    saturationModifier: 0.6,
  );

  /// Steak-like food (8 nutrition, 0.8 saturation)
  static const steak = FoodSettings(
    nutrition: 8,
    saturationModifier: 0.8,
  );

  /// Golden apple-like food (4 nutrition, 1.2 saturation, always edible)
  static const goldenApple = FoodSettings(
    nutrition: 4,
    saturationModifier: 1.2,
    alwaysEdible: true,
  );

  /// Create a stew-like food (with bowl return)
  static FoodSettings stew(int nutrition) {
    return FoodSettings(
      nutrition: nutrition,
      saturationModifier: 0.6,
    );
  }

  Map<String, dynamic> toJson() => {
        'nutrition': nutrition,
        'saturationModifier': saturationModifier,
        'alwaysEdible': alwaysEdible,
        'consumeSeconds': consumeSeconds,
        'effects': effects.map((e) => e.toJson()).toList(),
      };
}
