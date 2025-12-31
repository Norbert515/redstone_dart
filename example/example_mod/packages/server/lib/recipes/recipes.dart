import 'package:dart_mod_server/dart_mod_server.dart';

/// Registers all custom crafting recipes.
void registerRecipes() {
  // Shaped recipe: HelloBlock (diamond + redstone pattern)
  Recipes.shaped(
    'example_mod:hello_block',
    pattern: [
      'DRD',
      'RSR',
      'DRD',
    ],
    keys: {
      'D': 'minecraft:diamond',
      'R': 'minecraft:redstone',
      'S': 'minecraft:stone',
    },
    result: 'example_mod:hello_block',
  );

  // Shapeless recipe: DartItem from stick + diamond
  Recipes.shapeless(
    'example_mod:dart_item',
    ingredients: ['minecraft:stick', 'minecraft:diamond'],
    result: 'example_mod:dart_item',
    count: 4,
  );

  // Shaped recipe: Weather Control Block
  Recipes.shaped(
    'example_mod:weather_control',
    pattern: [
      'LGL',
      'GDG',
      'LGL',
    ],
    keys: {
      'L': 'minecraft:lapis_lazuli',
      'G': 'minecraft:gold_ingot',
      'D': 'minecraft:diamond',
    },
    result: 'example_mod:weather_control',
  );

  // Shaped recipe: Entity Radar Block
  Recipes.shaped(
    'example_mod:entity_radar',
    pattern: [
      'ERE',
      'RCR',
      'ERE',
    ],
    keys: {
      'E': 'minecraft:ender_pearl',
      'R': 'minecraft:redstone',
      'C': 'minecraft:compass',
    },
    result: 'example_mod:entity_radar',
  );

  // Shaped recipe: Effect Wand
  Recipes.shaped(
    'example_mod:effect_wand',
    pattern: [
      '  A',
      ' B ',
      'B  ',
    ],
    keys: {
      'A': 'minecraft:amethyst_shard',
      'B': 'minecraft:blaze_rod',
    },
    result: 'example_mod:effect_wand',
  );

  // Smelting recipe: Cook DartItem into emerald
  Recipes.smelting(
    'example_mod:smelt_dart_item',
    input: 'example_mod:dart_item',
    result: 'minecraft:emerald',
    experience: 1.0,
  );

  // Shaped recipe: Obsidian Stick (stick + 2 obsidian)
  Recipes.shaped(
    'example_mod:obsidian_stick',
    pattern: [
      'O',
      'O',
      'S',
    ],
    keys: {
      'O': 'minecraft:obsidian',
      'S': 'minecraft:stick',
    },
    result: 'example_mod:obsidian_stick',
    count: 1,
  );

  // Shaped recipe: Peer Schwert (obsidian stick + 2 obsidian)
  Recipes.shaped(
    'example_mod:peer_schwert',
    pattern: [
      'O',
      'O',
      'I',
    ],
    keys: {
      'O': 'minecraft:obsidian',
      'I': 'example_mod:obsidian_stick',
    },
    result: 'example_mod:peer_schwert',
    count: 1,
  );

  print('Recipes: Registered 8 custom recipes');
}
