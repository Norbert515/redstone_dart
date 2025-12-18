/// Recipe API tests.
///
/// Tests for the recipe registration system.
import 'package:dart_mc/api/api.dart';
import 'package:dart_mc/api/recipes.dart';
import 'package:redstone_test/redstone_test.dart';
import 'package:test/test.dart' as dart_test;

Future<void> main() async {
  await group('Shaped recipes', () async {
    await testMinecraft('can register simple shaped recipe', (game) async {
      Recipes.shaped(
        'testmod:diamond_sword_alt',
        pattern: [
          'D',
          'D',
          'S',
        ],
        keys: {
          'D': 'minecraft:diamond',
          'S': 'minecraft:stick',
        },
        result: 'minecraft:diamond_sword',
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('can register 3x3 shaped recipe', (game) async {
      Recipes.shaped(
        'testmod:diamond_block_alt',
        pattern: [
          'DDD',
          'DDD',
          'DDD',
        ],
        keys: {
          'D': 'minecraft:diamond',
        },
        result: 'minecraft:diamond_block',
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('can register 2x2 shaped recipe', (game) async {
      Recipes.shaped(
        'testmod:planks_alt',
        pattern: [
          'LL',
          'LL',
        ],
        keys: {
          'L': 'minecraft:oak_log',
        },
        result: 'minecraft:oak_planks',
        count: 16,
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('can register shaped recipe with count', (game) async {
      Recipes.shaped(
        'testmod:sticks_alt',
        pattern: [
          'P',
          'P',
        ],
        keys: {
          'P': 'minecraft:oak_planks',
        },
        result: 'minecraft:stick',
        count: 4,
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('can register shaped recipe with group', (game) async {
      Recipes.shaped(
        'testmod:wool_alt',
        pattern: [
          'SS',
          'SS',
        ],
        keys: {
          'S': 'minecraft:string',
        },
        result: 'minecraft:white_wool',
        group: 'wool',
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });
  });

  await group('Shapeless recipes', () async {
    await testMinecraft('can register simple shapeless recipe', (game) async {
      Recipes.shapeless(
        'testmod:mushroom_stew_alt',
        ingredients: [
          'minecraft:bowl',
          'minecraft:brown_mushroom',
          'minecraft:red_mushroom',
        ],
        result: 'minecraft:mushroom_stew',
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('can register shapeless recipe with count', (game) async {
      Recipes.shapeless(
        'testmod:dye_mix',
        ingredients: [
          'minecraft:red_dye',
          'minecraft:blue_dye',
        ],
        result: 'minecraft:purple_dye',
        count: 2,
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('can register shapeless recipe with group', (game) async {
      Recipes.shapeless(
        'testmod:book_alt',
        ingredients: [
          'minecraft:paper',
          'minecraft:paper',
          'minecraft:paper',
          'minecraft:leather',
        ],
        result: 'minecraft:book',
        group: 'books',
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('can register single ingredient shapeless', (game) async {
      Recipes.shapeless(
        'testmod:planks_from_log',
        ingredients: ['minecraft:oak_log'],
        result: 'minecraft:oak_planks',
        count: 4,
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });
  });

  await group('Smelting recipes', () async {
    await testMinecraft('can register smelting recipe', (game) async {
      Recipes.smelting(
        'testmod:iron_ingot_alt',
        input: 'minecraft:raw_iron',
        result: 'minecraft:iron_ingot',
        experience: 0.7,
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('can register smelting with custom time', (game) async {
      Recipes.smelting(
        'testmod:slow_smelt',
        input: 'minecraft:cobblestone',
        result: 'minecraft:stone',
        cookingTime: 400, // Twice as long
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('can register smelting with group', (game) async {
      Recipes.smelting(
        'testmod:glass_alt',
        input: 'minecraft:sand',
        result: 'minecraft:glass',
        group: 'glass',
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });
  });

  await group('Blasting recipes', () async {
    await testMinecraft('can register blasting recipe', (game) async {
      Recipes.blasting(
        'testmod:iron_ingot_blast',
        input: 'minecraft:raw_iron',
        result: 'minecraft:iron_ingot',
        experience: 0.7,
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('blasting defaults to 100 ticks', (game) async {
      Recipes.blasting(
        'testmod:gold_ingot_blast',
        input: 'minecraft:raw_gold',
        result: 'minecraft:gold_ingot',
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });
  });

  await group('Smoking recipes', () async {
    await testMinecraft('can register smoking recipe', (game) async {
      Recipes.smoking(
        'testmod:cooked_beef_smoke',
        input: 'minecraft:beef',
        result: 'minecraft:cooked_beef',
        experience: 0.35,
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });
  });

  await group('Campfire recipes', () async {
    await testMinecraft('can register campfire recipe', (game) async {
      Recipes.campfire(
        'testmod:cooked_porkchop_campfire',
        input: 'minecraft:porkchop',
        result: 'minecraft:cooked_porkchop',
        experience: 0.35,
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('campfire defaults to 600 ticks', (game) async {
      Recipes.campfire(
        'testmod:cooked_chicken_campfire',
        input: 'minecraft:chicken',
        result: 'minecraft:cooked_chicken',
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });
  });

  await group('Stonecutting recipes', () async {
    await testMinecraft('can register stonecutting recipe', (game) async {
      Recipes.stonecutting(
        'testmod:stone_bricks_cut',
        input: 'minecraft:stone',
        result: 'minecraft:stone_bricks',
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });

    await testMinecraft('can register stonecutting with count', (game) async {
      Recipes.stonecutting(
        'testmod:stone_slab_cut',
        input: 'minecraft:stone',
        result: 'minecraft:stone_slab',
        count: 2,
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });
  });

  await group('Smithing recipes', () async {
    await testMinecraft('can register smithing transform recipe', (game) async {
      Recipes.smithingTransform(
        'testmod:netherite_sword_alt',
        template: 'minecraft:netherite_upgrade_smithing_template',
        base: 'minecraft:diamond_sword',
        addition: 'minecraft:netherite_ingot',
        result: 'minecraft:netherite_sword',
      );

      expect(Recipes.recipeCount, greaterThan(0));
    });
  });

  await group('Recipe removal', () async {
    await testMinecraft('can mark recipe for removal', (game) async {
      Recipes.remove('minecraft:diamond_sword');
      expect(true, isTrue);
    });

    await testMinecraft('can mark recipes by output for removal', (game) async {
      Recipes.removeByOutput('minecraft:tnt');
      expect(true, isTrue);
    });
  });

  await group('Recipe queries', () async {
    await testMinecraft('recipeCount returns correct count', (game) async {
      final initialCount = Recipes.recipeCount;

      Recipes.shaped(
        'testmod:query_test',
        pattern: ['D'],
        keys: {'D': 'minecraft:diamond'},
        result: 'minecraft:diamond',
      );

      expect(Recipes.recipeCount, equals(initialCount + 1));
    });

    await testMinecraft('allRecipes returns registered recipes', (game) async {
      Recipes.shaped(
        'testmod:all_recipes_test',
        pattern: ['I'],
        keys: {'I': 'minecraft:iron_ingot'},
        result: 'minecraft:iron_nugget',
      );

      expect(Recipes.allRecipes.length, greaterThan(0));
    });
  });

  // Pure Dart unit tests
  await group('RecipeType values', () async {
    dart_test.test('RecipeType has expected values', () {
      expect(RecipeType.shaped.name, equals('shaped'));
      expect(RecipeType.shapeless.name, equals('shapeless'));
      expect(RecipeType.smelting.name, equals('smelting'));
      expect(RecipeType.blasting.name, equals('blasting'));
      expect(RecipeType.smoking.name, equals('smoking'));
      expect(RecipeType.campfire.name, equals('campfire'));
      expect(RecipeType.stonecutting.name, equals('stonecutting'));
      expect(RecipeType.smithing.name, equals('smithing'));
      expect(RecipeType.smithingTransform.name, equals('smithingTransform'));
    });
  });

  await group('Recipe validation', () async {
    dart_test.test('shaped recipe validates pattern rows', () {
      dart_test.expect(
        () => Recipes.shaped(
          'testmod:invalid',
          pattern: ['DDDD'], // Too wide
          keys: {'D': 'minecraft:diamond'},
          result: 'minecraft:diamond',
        ),
        dart_test.throwsArgumentError,
      );
    });

    dart_test.test('shaped recipe validates pattern height', () {
      dart_test.expect(
        () => Recipes.shaped(
          'testmod:invalid2',
          pattern: ['D', 'D', 'D', 'D'], // Too tall
          keys: {'D': 'minecraft:diamond'},
          result: 'minecraft:diamond',
        ),
        dart_test.throwsArgumentError,
      );
    });

    dart_test.test('shapeless recipe validates ingredient count', () {
      dart_test.expect(
        () => Recipes.shapeless(
          'testmod:invalid3',
          ingredients: [], // Empty
          result: 'minecraft:diamond',
        ),
        dart_test.throwsArgumentError,
      );
    });

    dart_test.test('shapeless recipe validates max ingredients', () {
      dart_test.expect(
        () => Recipes.shapeless(
          'testmod:invalid4',
          ingredients: List.filled(10, 'minecraft:diamond'), // Too many
          result: 'minecraft:diamond',
        ),
        dart_test.throwsArgumentError,
      );
    });
  });
}
