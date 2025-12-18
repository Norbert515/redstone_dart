/// Recipe API for registering custom Minecraft recipes.
///
/// This library provides a simple API for creating crafting, smelting,
/// and other types of recipes in Minecraft.
///
/// ## Example
///
/// ```dart
/// import 'package:dart_mc/api/api.dart';
///
/// void onModInit() {
///   // Shaped crafting recipe
///   Recipes.shaped(
///     'mymod:diamond_hammer',
///     pattern: [
///       'DDD',
///       ' S ',
///       ' S ',
///     ],
///     keys: {
///       'D': 'minecraft:diamond',
///       'S': 'minecraft:stick',
///     },
///     result: 'mymod:diamond_hammer',
///   );
///
///   // Shapeless recipe
///   Recipes.shapeless(
///     'mymod:combined_item',
///     ingredients: ['minecraft:diamond', 'minecraft:emerald'],
///     result: 'mymod:combined_item',
///   );
///
///   // Smelting recipe
///   Recipes.smelting(
///     'mymod:purified_iron',
///     input: 'minecraft:raw_iron',
///     result: 'mymod:purified_iron',
///     experience: 1.0,
///   );
/// }
/// ```
library;

import 'dart:convert';

import '../src/bridge.dart';
import '../src/jni/generic_bridge.dart';

/// Type of recipe.
enum RecipeType {
  /// Shaped crafting (3x3 grid with specific pattern).
  shaped,

  /// Shapeless crafting (ingredients in any arrangement).
  shapeless,

  /// Furnace smelting.
  smelting,

  /// Blast furnace smelting.
  blasting,

  /// Smoker cooking.
  smoking,

  /// Campfire cooking.
  campfire,

  /// Stonecutter recipe.
  stonecutting,

  /// Smithing table recipe.
  smithing,

  /// Smithing table transformation (1.20+).
  smithingTransform,
}

/// Registry for custom Minecraft recipes.
///
/// Recipes must be registered during mod initialization. The recipes are
/// added to Minecraft's recipe system and will appear in recipe viewers
/// like REI or JEI.
class Recipes {
  static final Map<String, _RecipeData> _recipes = {};
  static bool _initialized = false;

  Recipes._();

  /// Initialize the recipe registry if needed.
  static void _ensureInitialized() {
    if (_initialized) return;
    if (Bridge.isDatagenMode) {
      _initialized = true;
      return;
    }

    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/proxy/RecipeRegistry',
      'initialize',
      '()V',
    );

    _initialized = true;
  }

  /// Register a shaped crafting recipe.
  ///
  /// [id] is the recipe identifier (e.g., 'mymod:diamond_hammer').
  /// [pattern] is a list of 1-3 strings defining the crafting grid pattern.
  ///   Each character is a key that maps to an ingredient.
  /// [keys] maps pattern characters to item IDs.
  /// [result] is the output item ID.
  /// [count] is the number of items produced.
  /// [group] is an optional group for recipe book organization.
  static void shaped(
    String id, {
    required List<String> pattern,
    required Map<String, String> keys,
    required String result,
    int count = 1,
    String? group,
  }) {
    // Validate before initializing JNI
    if (pattern.isEmpty || pattern.length > 3) {
      throw ArgumentError('Pattern must have 1-3 rows');
    }
    for (final row in pattern) {
      if (row.length > 3) {
        throw ArgumentError('Pattern rows must have at most 3 characters');
      }
    }

    _ensureInitialized();

    final recipeData = _RecipeData(
      id: id,
      type: RecipeType.shaped,
      data: {
        'pattern': pattern,
        'keys': keys,
        'result': result,
        'count': count,
        if (group != null) 'group': group,
      },
    );

    _recipes[id] = recipeData;
    _registerRecipe(recipeData);

    print('Recipes: Registered shaped recipe $id');  // TEMP: disabled to debug hang
  }

  /// Register a shapeless crafting recipe.
  ///
  /// [id] is the recipe identifier.
  /// [ingredients] is a list of item IDs required (order doesn't matter).
  /// [result] is the output item ID.
  /// [count] is the number of items produced.
  /// [group] is an optional group for recipe book organization.
  static void shapeless(
    String id, {
    required List<String> ingredients,
    required String result,
    int count = 1,
    String? group,
  }) {
    // Validate before initializing JNI
    if (ingredients.isEmpty || ingredients.length > 9) {
      throw ArgumentError('Shapeless recipes must have 1-9 ingredients');
    }

    _ensureInitialized();

    final recipeData = _RecipeData(
      id: id,
      type: RecipeType.shapeless,
      data: {
        'ingredients': ingredients,
        'result': result,
        'count': count,
        if (group != null) 'group': group,
      },
    );

    _recipes[id] = recipeData;
    _registerRecipe(recipeData);

    print('Recipes: Registered shapeless recipe $id');  // TEMP: disabled
  }

  /// Register a furnace smelting recipe.
  ///
  /// [id] is the recipe identifier.
  /// [input] is the item ID to smelt.
  /// [result] is the output item ID.
  /// [experience] is XP given per smelt.
  /// [cookingTime] is the time in ticks (200 = 10 seconds default).
  /// [group] is an optional group for recipe book organization.
  static void smelting(
    String id, {
    required String input,
    required String result,
    double experience = 0.0,
    int cookingTime = 200,
    String? group,
  }) {
    _cookingRecipe(
      id,
      type: RecipeType.smelting,
      input: input,
      result: result,
      experience: experience,
      cookingTime: cookingTime,
      group: group,
    );

    print('Recipes: Registered smelting recipe $id');
  }

  /// Register a blast furnace recipe.
  ///
  /// Blast furnace recipes cook twice as fast as regular smelting (100 ticks default).
  static void blasting(
    String id, {
    required String input,
    required String result,
    double experience = 0.0,
    int cookingTime = 100,
    String? group,
  }) {
    _cookingRecipe(
      id,
      type: RecipeType.blasting,
      input: input,
      result: result,
      experience: experience,
      cookingTime: cookingTime,
      group: group,
    );

    print('Recipes: Registered blasting recipe $id');
  }

  /// Register a smoker cooking recipe.
  ///
  /// Smoker recipes cook twice as fast as regular smelting (100 ticks default).
  static void smoking(
    String id, {
    required String input,
    required String result,
    double experience = 0.0,
    int cookingTime = 100,
    String? group,
  }) {
    _cookingRecipe(
      id,
      type: RecipeType.smoking,
      input: input,
      result: result,
      experience: experience,
      cookingTime: cookingTime,
      group: group,
    );

    print('Recipes: Registered smoking recipe $id');
  }

  /// Register a campfire cooking recipe.
  ///
  /// Campfire recipes take longer (600 ticks = 30 seconds default).
  static void campfire(
    String id, {
    required String input,
    required String result,
    double experience = 0.0,
    int cookingTime = 600,
    String? group,
  }) {
    _cookingRecipe(
      id,
      type: RecipeType.campfire,
      input: input,
      result: result,
      experience: experience,
      cookingTime: cookingTime,
      group: group,
    );

    print('Recipes: Registered campfire recipe $id');
  }

  /// Internal method for cooking recipes.
  static void _cookingRecipe(
    String id, {
    required RecipeType type,
    required String input,
    required String result,
    required double experience,
    required int cookingTime,
    String? group,
  }) {
    _ensureInitialized();

    final recipeData = _RecipeData(
      id: id,
      type: type,
      data: {
        'input': input,
        'result': result,
        'experience': experience,
        'cookingTime': cookingTime,
        if (group != null) 'group': group,
      },
    );

    _recipes[id] = recipeData;
    _registerRecipe(recipeData);
  }

  /// Register a stonecutting recipe.
  ///
  /// [id] is the recipe identifier.
  /// [input] is the item ID to cut.
  /// [result] is the output item ID.
  /// [count] is the number of items produced.
  static void stonecutting(
    String id, {
    required String input,
    required String result,
    int count = 1,
  }) {
    _ensureInitialized();

    final recipeData = _RecipeData(
      id: id,
      type: RecipeType.stonecutting,
      data: {
        'input': input,
        'result': result,
        'count': count,
      },
    );

    _recipes[id] = recipeData;
    _registerRecipe(recipeData);

    print('Recipes: Registered stonecutting recipe $id');
  }

  /// Register a legacy smithing recipe (pre-1.20 style).
  ///
  /// [id] is the recipe identifier.
  /// [base] is the item to upgrade.
  /// [addition] is the item to add (e.g., netherite ingot).
  /// [result] is the output item ID.
  @Deprecated('Use smithingTransform for Minecraft 1.20+')
  static void smithing(
    String id, {
    required String base,
    required String addition,
    required String result,
  }) {
    _ensureInitialized();

    final recipeData = _RecipeData(
      id: id,
      type: RecipeType.smithing,
      data: {
        'base': base,
        'addition': addition,
        'result': result,
      },
    );

    _recipes[id] = recipeData;
    _registerRecipe(recipeData);

    print('Recipes: Registered smithing recipe $id');
  }

  /// Register a smithing transformation recipe (1.20+ style).
  ///
  /// [id] is the recipe identifier.
  /// [template] is the smithing template item.
  /// [base] is the item to upgrade.
  /// [addition] is the item to add (e.g., netherite ingot).
  /// [result] is the output item ID.
  static void smithingTransform(
    String id, {
    required String template,
    required String base,
    required String addition,
    required String result,
  }) {
    _ensureInitialized();

    final recipeData = _RecipeData(
      id: id,
      type: RecipeType.smithingTransform,
      data: {
        'template': template,
        'base': base,
        'addition': addition,
        'result': result,
      },
    );

    _recipes[id] = recipeData;
    _registerRecipe(recipeData);

    print('Recipes: Registered smithing transform recipe $id');
  }

  /// Remove a vanilla or mod recipe by ID.
  ///
  /// [recipeId] is the full recipe identifier (e.g., 'minecraft:diamond_sword').
  static void remove(String recipeId) {
    _ensureInitialized();

    if (!Bridge.isDatagenMode) {
      GenericJniBridge.callStaticBoolMethod(
        'com/redstone/proxy/RecipeRegistry',
        'removeRecipe',
        '(Ljava/lang/String;)Z',
        [recipeId],
      );
    }

    print('Recipes: Removed recipe $recipeId');
  }

  /// Remove all recipes that produce a specific item.
  ///
  /// [itemId] is the output item ID (e.g., 'minecraft:diamond_sword').
  static void removeByOutput(String itemId) {
    _ensureInitialized();

    if (!Bridge.isDatagenMode) {
      GenericJniBridge.callStaticIntMethod(
        'com/redstone/proxy/RecipeRegistry',
        'removeRecipesByOutput',
        '(Ljava/lang/String;)I',
        [itemId],
      );
    }

    print('Recipes: Removed recipes producing $itemId');
  }

  /// Register a recipe with the Java side.
  static void _registerRecipe(_RecipeData recipe) {
    if (Bridge.isDatagenMode) return;

    final dataJson = jsonEncode(recipe.data);

    GenericJniBridge.callStaticBoolMethod(
      'com/redstone/proxy/RecipeRegistry',
      'registerRecipe',
      '(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Z',
      [recipe.id, recipe.type.name, dataJson],
    );
  }

  /// Get a registered recipe by ID.
  static _RecipeData? getRecipe(String id) => _recipes[id];

  /// Get all registered recipes.
  static Iterable<_RecipeData> get allRecipes => _recipes.values;

  /// Get the number of registered recipes.
  static int get recipeCount => _recipes.length;
}

/// Internal class to store recipe data.
class _RecipeData {
  final String id;
  final RecipeType type;
  final Map<String, dynamic> data;

  _RecipeData({
    required this.id,
    required this.type,
    required this.data,
  });
}
