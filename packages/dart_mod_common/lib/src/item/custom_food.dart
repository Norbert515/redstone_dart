/// Base class for custom food items.
library;

import 'custom_item.dart';
import 'food_settings.dart';
import 'item_model.dart';
import 'item_settings.dart';

/// Base class for custom food items.
///
/// Extend this to create custom food that restores hunger.
abstract class CustomFood extends CustomItem {
  /// The food settings
  final FoodSettings food;

  /// Optional item returned after eating (e.g., bowl for stew)
  final String? finishItem;

  CustomFood({
    required String id,
    required this.food,
    required ItemModel model,
    this.finishItem,
    int maxStackSize = 64,
  }) : super(
          id: id,
          settings: ItemSettings(maxStackSize: maxStackSize),
          model: model,
        );

  /// Override to add custom behavior when the food is eaten.
  /// Called after the food is consumed.
  void onEat(int worldId, int playerId) {}
}
