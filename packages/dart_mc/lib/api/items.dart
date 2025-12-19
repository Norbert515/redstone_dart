/// Static constants for all vanilla Minecraft item IDs.
///
/// Use these instead of raw strings to avoid typos:
/// ```dart
/// Recipes.shaped(
///   'mymod:diamond_pickaxe_alt',
///   pattern: ['DDD', ' S ', ' S '],
///   keys: {
///     'D': Items.diamond,
///     'S': Items.stick,
///   },
///   result: Items.diamondPickaxe,
/// );
/// ```
library;

/// Provides type-safe static constants for all vanilla Minecraft item IDs.
///
/// This class contains constants for every item in Minecraft 1.21, organized
/// by category for easy reference. Use these constants instead of raw strings
/// to avoid typos and get IDE autocompletion.
class Items {
  Items._();

  // ===========================================================================
  // BUILDING BLOCKS - Stone Variants
  // ===========================================================================

  static const String stone = 'minecraft:stone';
  static const String granite = 'minecraft:granite';
  static const String polishedGranite = 'minecraft:polished_granite';
  static const String diorite = 'minecraft:diorite';
  static const String polishedDiorite = 'minecraft:polished_diorite';
  static const String andesite = 'minecraft:andesite';
  static const String polishedAndesite = 'minecraft:polished_andesite';
  static const String deepslate = 'minecraft:deepslate';
  static const String cobbledDeepslate = 'minecraft:cobbled_deepslate';
  static const String polishedDeepslate = 'minecraft:polished_deepslate';
  static const String calcite = 'minecraft:calcite';
  static const String tuff = 'minecraft:tuff';
  static const String polishedTuff = 'minecraft:polished_tuff';
  static const String tuffBricks = 'minecraft:tuff_bricks';
  static const String chiseledTuff = 'minecraft:chiseled_tuff';
  static const String chiseledTuffBricks = 'minecraft:chiseled_tuff_bricks';
  static const String dripstoneBlock = 'minecraft:dripstone_block';
  static const String pointedDripstone = 'minecraft:pointed_dripstone';

  // ===========================================================================
  // BUILDING BLOCKS - Dirt and Grass
  // ===========================================================================

  static const String grassBlock = 'minecraft:grass_block';
  static const String dirt = 'minecraft:dirt';
  static const String coarseDirt = 'minecraft:coarse_dirt';
  static const String rootedDirt = 'minecraft:rooted_dirt';
  static const String podzol = 'minecraft:podzol';
  static const String mycelium = 'minecraft:mycelium';
  static const String mud = 'minecraft:mud';
  static const String packedMud = 'minecraft:packed_mud';
  static const String mudBricks = 'minecraft:mud_bricks';
  static const String farmland = 'minecraft:farmland';
  static const String dirtPath = 'minecraft:dirt_path';

  // ===========================================================================
  // BUILDING BLOCKS - Sand and Gravel
  // ===========================================================================

  static const String sand = 'minecraft:sand';
  static const String redSand = 'minecraft:red_sand';
  static const String gravel = 'minecraft:gravel';
  static const String suspiciousSand = 'minecraft:suspicious_sand';
  static const String suspiciousGravel = 'minecraft:suspicious_gravel';
  static const String sandstone = 'minecraft:sandstone';
  static const String chiseledSandstone = 'minecraft:chiseled_sandstone';
  static const String cutSandstone = 'minecraft:cut_sandstone';
  static const String smoothSandstone = 'minecraft:smooth_sandstone';
  static const String redSandstone = 'minecraft:red_sandstone';
  static const String chiseledRedSandstone = 'minecraft:chiseled_red_sandstone';
  static const String cutRedSandstone = 'minecraft:cut_red_sandstone';
  static const String smoothRedSandstone = 'minecraft:smooth_red_sandstone';

  // ===========================================================================
  // BUILDING BLOCKS - Cobblestone and Bricks
  // ===========================================================================

  static const String cobblestone = 'minecraft:cobblestone';
  static const String mossyCobblestone = 'minecraft:mossy_cobblestone';
  static const String stoneBricks = 'minecraft:stone_bricks';
  static const String mossyStoneBricks = 'minecraft:mossy_stone_bricks';
  static const String crackedStoneBricks = 'minecraft:cracked_stone_bricks';
  static const String chiseledStoneBricks = 'minecraft:chiseled_stone_bricks';
  static const String bricks = 'minecraft:bricks';
  static const String deepslateBricks = 'minecraft:deepslate_bricks';
  static const String crackedDeepslateBricks =
      'minecraft:cracked_deepslate_bricks';
  static const String deepslateTiles = 'minecraft:deepslate_tiles';
  static const String crackedDeepslateTiles =
      'minecraft:cracked_deepslate_tiles';
  static const String chiseledDeepslate = 'minecraft:chiseled_deepslate';
  static const String reinforcedDeepslate = 'minecraft:reinforced_deepslate';

  // ===========================================================================
  // BUILDING BLOCKS - Prismarine
  // ===========================================================================

  static const String prismarine = 'minecraft:prismarine';
  static const String prismarineBricks = 'minecraft:prismarine_bricks';
  static const String darkPrismarine = 'minecraft:dark_prismarine';
  static const String seaLantern = 'minecraft:sea_lantern';

  // ===========================================================================
  // BUILDING BLOCKS - Nether Blocks
  // ===========================================================================

  static const String netherrack = 'minecraft:netherrack';
  static const String netherBricks = 'minecraft:nether_bricks';
  static const String crackedNetherBricks = 'minecraft:cracked_nether_bricks';
  static const String chiseledNetherBricks = 'minecraft:chiseled_nether_bricks';
  static const String redNetherBricks = 'minecraft:red_nether_bricks';
  static const String netherWartBlock = 'minecraft:nether_wart_block';
  static const String warpedWartBlock = 'minecraft:warped_wart_block';
  static const String soulSand = 'minecraft:soul_sand';
  static const String soulSoil = 'minecraft:soul_soil';
  static const String basalt = 'minecraft:basalt';
  static const String polishedBasalt = 'minecraft:polished_basalt';
  static const String smoothBasalt = 'minecraft:smooth_basalt';
  static const String blackstone = 'minecraft:blackstone';
  static const String polishedBlackstone = 'minecraft:polished_blackstone';
  static const String chiseledPolishedBlackstone =
      'minecraft:chiseled_polished_blackstone';
  static const String polishedBlackstoneBricks =
      'minecraft:polished_blackstone_bricks';
  static const String crackedPolishedBlackstoneBricks =
      'minecraft:cracked_polished_blackstone_bricks';
  static const String gildedBlackstone = 'minecraft:gilded_blackstone';
  static const String magmaBlock = 'minecraft:magma_block';
  static const String glowstone = 'minecraft:glowstone';

  // ===========================================================================
  // BUILDING BLOCKS - End Blocks
  // ===========================================================================

  static const String endStone = 'minecraft:end_stone';
  static const String endStoneBricks = 'minecraft:end_stone_bricks';
  static const String purpurBlock = 'minecraft:purpur_block';
  static const String purpurPillar = 'minecraft:purpur_pillar';

  // ===========================================================================
  // BUILDING BLOCKS - Copper
  // ===========================================================================

  static const String copperBlock = 'minecraft:copper_block';
  static const String exposedCopper = 'minecraft:exposed_copper';
  static const String weatheredCopper = 'minecraft:weathered_copper';
  static const String oxidizedCopper = 'minecraft:oxidized_copper';
  static const String cutCopper = 'minecraft:cut_copper';
  static const String exposedCutCopper = 'minecraft:exposed_cut_copper';
  static const String weatheredCutCopper = 'minecraft:weathered_cut_copper';
  static const String oxidizedCutCopper = 'minecraft:oxidized_cut_copper';
  static const String waxedCopperBlock = 'minecraft:waxed_copper_block';
  static const String waxedExposedCopper = 'minecraft:waxed_exposed_copper';
  static const String waxedWeatheredCopper = 'minecraft:waxed_weathered_copper';
  static const String waxedOxidizedCopper = 'minecraft:waxed_oxidized_copper';
  static const String waxedCutCopper = 'minecraft:waxed_cut_copper';
  static const String waxedExposedCutCopper =
      'minecraft:waxed_exposed_cut_copper';
  static const String waxedWeatheredCutCopper =
      'minecraft:waxed_weathered_cut_copper';
  static const String waxedOxidizedCutCopper =
      'minecraft:waxed_oxidized_cut_copper';
  static const String copperGrate = 'minecraft:copper_grate';
  static const String exposedCopperGrate = 'minecraft:exposed_copper_grate';
  static const String weatheredCopperGrate = 'minecraft:weathered_copper_grate';
  static const String oxidizedCopperGrate = 'minecraft:oxidized_copper_grate';
  static const String waxedCopperGrate = 'minecraft:waxed_copper_grate';
  static const String waxedExposedCopperGrate =
      'minecraft:waxed_exposed_copper_grate';
  static const String waxedWeatheredCopperGrate =
      'minecraft:waxed_weathered_copper_grate';
  static const String waxedOxidizedCopperGrate =
      'minecraft:waxed_oxidized_copper_grate';
  static const String chiseledCopper = 'minecraft:chiseled_copper';
  static const String exposedChiseledCopper =
      'minecraft:exposed_chiseled_copper';
  static const String weatheredChiseledCopper =
      'minecraft:weathered_chiseled_copper';
  static const String oxidizedChiseledCopper =
      'minecraft:oxidized_chiseled_copper';
  static const String waxedChiseledCopper = 'minecraft:waxed_chiseled_copper';
  static const String waxedExposedChiseledCopper =
      'minecraft:waxed_exposed_chiseled_copper';
  static const String waxedWeatheredChiseledCopper =
      'minecraft:waxed_weathered_chiseled_copper';
  static const String waxedOxidizedChiseledCopper =
      'minecraft:waxed_oxidized_chiseled_copper';
  static const String copperBulb = 'minecraft:copper_bulb';
  static const String exposedCopperBulb = 'minecraft:exposed_copper_bulb';
  static const String weatheredCopperBulb = 'minecraft:weathered_copper_bulb';
  static const String oxidizedCopperBulb = 'minecraft:oxidized_copper_bulb';
  static const String waxedCopperBulb = 'minecraft:waxed_copper_bulb';
  static const String waxedExposedCopperBulb =
      'minecraft:waxed_exposed_copper_bulb';
  static const String waxedWeatheredCopperBulb =
      'minecraft:waxed_weathered_copper_bulb';
  static const String waxedOxidizedCopperBulb =
      'minecraft:waxed_oxidized_copper_bulb';
  static const String copperDoor = 'minecraft:copper_door';
  static const String exposedCopperDoor = 'minecraft:exposed_copper_door';
  static const String weatheredCopperDoor = 'minecraft:weathered_copper_door';
  static const String oxidizedCopperDoor = 'minecraft:oxidized_copper_door';
  static const String waxedCopperDoor = 'minecraft:waxed_copper_door';
  static const String waxedExposedCopperDoor =
      'minecraft:waxed_exposed_copper_door';
  static const String waxedWeatheredCopperDoor =
      'minecraft:waxed_weathered_copper_door';
  static const String waxedOxidizedCopperDoor =
      'minecraft:waxed_oxidized_copper_door';
  static const String copperTrapdoor = 'minecraft:copper_trapdoor';
  static const String exposedCopperTrapdoor =
      'minecraft:exposed_copper_trapdoor';
  static const String weatheredCopperTrapdoor =
      'minecraft:weathered_copper_trapdoor';
  static const String oxidizedCopperTrapdoor =
      'minecraft:oxidized_copper_trapdoor';
  static const String waxedCopperTrapdoor = 'minecraft:waxed_copper_trapdoor';
  static const String waxedExposedCopperTrapdoor =
      'minecraft:waxed_exposed_copper_trapdoor';
  static const String waxedWeatheredCopperTrapdoor =
      'minecraft:waxed_weathered_copper_trapdoor';
  static const String waxedOxidizedCopperTrapdoor =
      'minecraft:waxed_oxidized_copper_trapdoor';
  static const String lightningRod = 'minecraft:lightning_rod';

  // ===========================================================================
  // BUILDING BLOCKS - Metal Blocks
  // ===========================================================================

  static const String ironBlock = 'minecraft:iron_block';
  static const String goldBlock = 'minecraft:gold_block';
  static const String diamondBlock = 'minecraft:diamond_block';
  static const String emeraldBlock = 'minecraft:emerald_block';
  static const String lapisBlock = 'minecraft:lapis_block';
  static const String netheriteBlock = 'minecraft:netherite_block';
  static const String coalBlock = 'minecraft:coal_block';
  static const String redstoneBlock = 'minecraft:redstone_block';
  static const String rawIronBlock = 'minecraft:raw_iron_block';
  static const String rawGoldBlock = 'minecraft:raw_gold_block';
  static const String rawCopperBlock = 'minecraft:raw_copper_block';
  static const String amethystBlock = 'minecraft:amethyst_block';
  static const String buddingAmethyst = 'minecraft:budding_amethyst';

  // ===========================================================================
  // BUILDING BLOCKS - Glass
  // ===========================================================================

  static const String glass = 'minecraft:glass';
  static const String tintedGlass = 'minecraft:tinted_glass';
  static const String whiteStainedGlass = 'minecraft:white_stained_glass';
  static const String orangeStainedGlass = 'minecraft:orange_stained_glass';
  static const String magentaStainedGlass = 'minecraft:magenta_stained_glass';
  static const String lightBlueStainedGlass =
      'minecraft:light_blue_stained_glass';
  static const String yellowStainedGlass = 'minecraft:yellow_stained_glass';
  static const String limeStainedGlass = 'minecraft:lime_stained_glass';
  static const String pinkStainedGlass = 'minecraft:pink_stained_glass';
  static const String grayStainedGlass = 'minecraft:gray_stained_glass';
  static const String lightGrayStainedGlass =
      'minecraft:light_gray_stained_glass';
  static const String cyanStainedGlass = 'minecraft:cyan_stained_glass';
  static const String purpleStainedGlass = 'minecraft:purple_stained_glass';
  static const String blueStainedGlass = 'minecraft:blue_stained_glass';
  static const String brownStainedGlass = 'minecraft:brown_stained_glass';
  static const String greenStainedGlass = 'minecraft:green_stained_glass';
  static const String redStainedGlass = 'minecraft:red_stained_glass';
  static const String blackStainedGlass = 'minecraft:black_stained_glass';
  static const String glassPane = 'minecraft:glass_pane';
  static const String whiteStainedGlassPane =
      'minecraft:white_stained_glass_pane';
  static const String orangeStainedGlassPane =
      'minecraft:orange_stained_glass_pane';
  static const String magentaStainedGlassPane =
      'minecraft:magenta_stained_glass_pane';
  static const String lightBlueStainedGlassPane =
      'minecraft:light_blue_stained_glass_pane';
  static const String yellowStainedGlassPane =
      'minecraft:yellow_stained_glass_pane';
  static const String limeStainedGlassPane = 'minecraft:lime_stained_glass_pane';
  static const String pinkStainedGlassPane = 'minecraft:pink_stained_glass_pane';
  static const String grayStainedGlassPane = 'minecraft:gray_stained_glass_pane';
  static const String lightGrayStainedGlassPane =
      'minecraft:light_gray_stained_glass_pane';
  static const String cyanStainedGlassPane = 'minecraft:cyan_stained_glass_pane';
  static const String purpleStainedGlassPane =
      'minecraft:purple_stained_glass_pane';
  static const String blueStainedGlassPane = 'minecraft:blue_stained_glass_pane';
  static const String brownStainedGlassPane =
      'minecraft:brown_stained_glass_pane';
  static const String greenStainedGlassPane =
      'minecraft:green_stained_glass_pane';
  static const String redStainedGlassPane = 'minecraft:red_stained_glass_pane';
  static const String blackStainedGlassPane =
      'minecraft:black_stained_glass_pane';

  // ===========================================================================
  // BUILDING BLOCKS - Terracotta
  // ===========================================================================

  static const String terracotta = 'minecraft:terracotta';
  static const String whiteTerracotta = 'minecraft:white_terracotta';
  static const String orangeTerracotta = 'minecraft:orange_terracotta';
  static const String magentaTerracotta = 'minecraft:magenta_terracotta';
  static const String lightBlueTerracotta = 'minecraft:light_blue_terracotta';
  static const String yellowTerracotta = 'minecraft:yellow_terracotta';
  static const String limeTerracotta = 'minecraft:lime_terracotta';
  static const String pinkTerracotta = 'minecraft:pink_terracotta';
  static const String grayTerracotta = 'minecraft:gray_terracotta';
  static const String lightGrayTerracotta = 'minecraft:light_gray_terracotta';
  static const String cyanTerracotta = 'minecraft:cyan_terracotta';
  static const String purpleTerracotta = 'minecraft:purple_terracotta';
  static const String blueTerracotta = 'minecraft:blue_terracotta';
  static const String brownTerracotta = 'minecraft:brown_terracotta';
  static const String greenTerracotta = 'minecraft:green_terracotta';
  static const String redTerracotta = 'minecraft:red_terracotta';
  static const String blackTerracotta = 'minecraft:black_terracotta';

  // ===========================================================================
  // BUILDING BLOCKS - Glazed Terracotta
  // ===========================================================================

  static const String whiteGlazedTerracotta =
      'minecraft:white_glazed_terracotta';
  static const String orangeGlazedTerracotta =
      'minecraft:orange_glazed_terracotta';
  static const String magentaGlazedTerracotta =
      'minecraft:magenta_glazed_terracotta';
  static const String lightBlueGlazedTerracotta =
      'minecraft:light_blue_glazed_terracotta';
  static const String yellowGlazedTerracotta =
      'minecraft:yellow_glazed_terracotta';
  static const String limeGlazedTerracotta = 'minecraft:lime_glazed_terracotta';
  static const String pinkGlazedTerracotta = 'minecraft:pink_glazed_terracotta';
  static const String grayGlazedTerracotta = 'minecraft:gray_glazed_terracotta';
  static const String lightGrayGlazedTerracotta =
      'minecraft:light_gray_glazed_terracotta';
  static const String cyanGlazedTerracotta = 'minecraft:cyan_glazed_terracotta';
  static const String purpleGlazedTerracotta =
      'minecraft:purple_glazed_terracotta';
  static const String blueGlazedTerracotta = 'minecraft:blue_glazed_terracotta';
  static const String brownGlazedTerracotta =
      'minecraft:brown_glazed_terracotta';
  static const String greenGlazedTerracotta =
      'minecraft:green_glazed_terracotta';
  static const String redGlazedTerracotta = 'minecraft:red_glazed_terracotta';
  static const String blackGlazedTerracotta =
      'minecraft:black_glazed_terracotta';

  // ===========================================================================
  // BUILDING BLOCKS - Concrete
  // ===========================================================================

  static const String whiteConcrete = 'minecraft:white_concrete';
  static const String orangeConcrete = 'minecraft:orange_concrete';
  static const String magentaConcrete = 'minecraft:magenta_concrete';
  static const String lightBlueConcrete = 'minecraft:light_blue_concrete';
  static const String yellowConcrete = 'minecraft:yellow_concrete';
  static const String limeConcrete = 'minecraft:lime_concrete';
  static const String pinkConcrete = 'minecraft:pink_concrete';
  static const String grayConcrete = 'minecraft:gray_concrete';
  static const String lightGrayConcrete = 'minecraft:light_gray_concrete';
  static const String cyanConcrete = 'minecraft:cyan_concrete';
  static const String purpleConcrete = 'minecraft:purple_concrete';
  static const String blueConcrete = 'minecraft:blue_concrete';
  static const String brownConcrete = 'minecraft:brown_concrete';
  static const String greenConcrete = 'minecraft:green_concrete';
  static const String redConcrete = 'minecraft:red_concrete';
  static const String blackConcrete = 'minecraft:black_concrete';
  static const String whiteConcretePowder = 'minecraft:white_concrete_powder';
  static const String orangeConcretePowder = 'minecraft:orange_concrete_powder';
  static const String magentaConcretePowder =
      'minecraft:magenta_concrete_powder';
  static const String lightBlueConcretePowder =
      'minecraft:light_blue_concrete_powder';
  static const String yellowConcretePowder = 'minecraft:yellow_concrete_powder';
  static const String limeConcretePowder = 'minecraft:lime_concrete_powder';
  static const String pinkConcretePowder = 'minecraft:pink_concrete_powder';
  static const String grayConcretePowder = 'minecraft:gray_concrete_powder';
  static const String lightGrayConcretePowder =
      'minecraft:light_gray_concrete_powder';
  static const String cyanConcretePowder = 'minecraft:cyan_concrete_powder';
  static const String purpleConcretePowder = 'minecraft:purple_concrete_powder';
  static const String blueConcretePowder = 'minecraft:blue_concrete_powder';
  static const String brownConcretePowder = 'minecraft:brown_concrete_powder';
  static const String greenConcretePowder = 'minecraft:green_concrete_powder';
  static const String redConcretePowder = 'minecraft:red_concrete_powder';
  static const String blackConcretePowder = 'minecraft:black_concrete_powder';

  // ===========================================================================
  // BUILDING BLOCKS - Wool
  // ===========================================================================

  static const String whiteWool = 'minecraft:white_wool';
  static const String orangeWool = 'minecraft:orange_wool';
  static const String magentaWool = 'minecraft:magenta_wool';
  static const String lightBlueWool = 'minecraft:light_blue_wool';
  static const String yellowWool = 'minecraft:yellow_wool';
  static const String limeWool = 'minecraft:lime_wool';
  static const String pinkWool = 'minecraft:pink_wool';
  static const String grayWool = 'minecraft:gray_wool';
  static const String lightGrayWool = 'minecraft:light_gray_wool';
  static const String cyanWool = 'minecraft:cyan_wool';
  static const String purpleWool = 'minecraft:purple_wool';
  static const String blueWool = 'minecraft:blue_wool';
  static const String brownWool = 'minecraft:brown_wool';
  static const String greenWool = 'minecraft:green_wool';
  static const String redWool = 'minecraft:red_wool';
  static const String blackWool = 'minecraft:black_wool';

  // ===========================================================================
  // BUILDING BLOCKS - Carpet
  // ===========================================================================

  static const String whiteCarpet = 'minecraft:white_carpet';
  static const String orangeCarpet = 'minecraft:orange_carpet';
  static const String magentaCarpet = 'minecraft:magenta_carpet';
  static const String lightBlueCarpet = 'minecraft:light_blue_carpet';
  static const String yellowCarpet = 'minecraft:yellow_carpet';
  static const String limeCarpet = 'minecraft:lime_carpet';
  static const String pinkCarpet = 'minecraft:pink_carpet';
  static const String grayCarpet = 'minecraft:gray_carpet';
  static const String lightGrayCarpet = 'minecraft:light_gray_carpet';
  static const String cyanCarpet = 'minecraft:cyan_carpet';
  static const String purpleCarpet = 'minecraft:purple_carpet';
  static const String blueCarpet = 'minecraft:blue_carpet';
  static const String brownCarpet = 'minecraft:brown_carpet';
  static const String greenCarpet = 'minecraft:green_carpet';
  static const String redCarpet = 'minecraft:red_carpet';
  static const String blackCarpet = 'minecraft:black_carpet';
  static const String mossCarpet = 'minecraft:moss_carpet';

  // ===========================================================================
  // WOOD - Logs
  // ===========================================================================

  static const String oakLog = 'minecraft:oak_log';
  static const String spruceLog = 'minecraft:spruce_log';
  static const String birchLog = 'minecraft:birch_log';
  static const String jungleLog = 'minecraft:jungle_log';
  static const String acaciaLog = 'minecraft:acacia_log';
  static const String darkOakLog = 'minecraft:dark_oak_log';
  static const String mangroveLog = 'minecraft:mangrove_log';
  static const String cherryLog = 'minecraft:cherry_log';
  static const String paleOakLog = 'minecraft:pale_oak_log';
  static const String crimsonStem = 'minecraft:crimson_stem';
  static const String warpedStem = 'minecraft:warped_stem';
  static const String bambooBlock = 'minecraft:bamboo_block';

  // ===========================================================================
  // WOOD - Stripped Logs
  // ===========================================================================

  static const String strippedOakLog = 'minecraft:stripped_oak_log';
  static const String strippedSpruceLog = 'minecraft:stripped_spruce_log';
  static const String strippedBirchLog = 'minecraft:stripped_birch_log';
  static const String strippedJungleLog = 'minecraft:stripped_jungle_log';
  static const String strippedAcaciaLog = 'minecraft:stripped_acacia_log';
  static const String strippedDarkOakLog = 'minecraft:stripped_dark_oak_log';
  static const String strippedMangroveLog = 'minecraft:stripped_mangrove_log';
  static const String strippedCherryLog = 'minecraft:stripped_cherry_log';
  static const String strippedPaleOakLog = 'minecraft:stripped_pale_oak_log';
  static const String strippedCrimsonStem = 'minecraft:stripped_crimson_stem';
  static const String strippedWarpedStem = 'minecraft:stripped_warped_stem';
  static const String strippedBambooBlock = 'minecraft:stripped_bamboo_block';

  // ===========================================================================
  // WOOD - Wood (bark on all sides)
  // ===========================================================================

  static const String oakWood = 'minecraft:oak_wood';
  static const String spruceWood = 'minecraft:spruce_wood';
  static const String birchWood = 'minecraft:birch_wood';
  static const String jungleWood = 'minecraft:jungle_wood';
  static const String acaciaWood = 'minecraft:acacia_wood';
  static const String darkOakWood = 'minecraft:dark_oak_wood';
  static const String mangroveWood = 'minecraft:mangrove_wood';
  static const String cherryWood = 'minecraft:cherry_wood';
  static const String paleOakWood = 'minecraft:pale_oak_wood';
  static const String crimsonHyphae = 'minecraft:crimson_hyphae';
  static const String warpedHyphae = 'minecraft:warped_hyphae';

  // ===========================================================================
  // WOOD - Stripped Wood
  // ===========================================================================

  static const String strippedOakWood = 'minecraft:stripped_oak_wood';
  static const String strippedSpruceWood = 'minecraft:stripped_spruce_wood';
  static const String strippedBirchWood = 'minecraft:stripped_birch_wood';
  static const String strippedJungleWood = 'minecraft:stripped_jungle_wood';
  static const String strippedAcaciaWood = 'minecraft:stripped_acacia_wood';
  static const String strippedDarkOakWood = 'minecraft:stripped_dark_oak_wood';
  static const String strippedMangroveWood = 'minecraft:stripped_mangrove_wood';
  static const String strippedCherryWood = 'minecraft:stripped_cherry_wood';
  static const String strippedPaleOakWood = 'minecraft:stripped_pale_oak_wood';
  static const String strippedCrimsonHyphae =
      'minecraft:stripped_crimson_hyphae';
  static const String strippedWarpedHyphae = 'minecraft:stripped_warped_hyphae';

  // ===========================================================================
  // WOOD - Planks
  // ===========================================================================

  static const String oakPlanks = 'minecraft:oak_planks';
  static const String sprucePlanks = 'minecraft:spruce_planks';
  static const String birchPlanks = 'minecraft:birch_planks';
  static const String junglePlanks = 'minecraft:jungle_planks';
  static const String acaciaPlanks = 'minecraft:acacia_planks';
  static const String darkOakPlanks = 'minecraft:dark_oak_planks';
  static const String mangrovePlanks = 'minecraft:mangrove_planks';
  static const String cherryPlanks = 'minecraft:cherry_planks';
  static const String paleOakPlanks = 'minecraft:pale_oak_planks';
  static const String crimsonPlanks = 'minecraft:crimson_planks';
  static const String warpedPlanks = 'minecraft:warped_planks';
  static const String bambooPlanks = 'minecraft:bamboo_planks';
  static const String bambooMosaic = 'minecraft:bamboo_mosaic';

  // ===========================================================================
  // WOOD - Slabs
  // ===========================================================================

  static const String oakSlab = 'minecraft:oak_slab';
  static const String spruceSlab = 'minecraft:spruce_slab';
  static const String birchSlab = 'minecraft:birch_slab';
  static const String jungleSlab = 'minecraft:jungle_slab';
  static const String acaciaSlab = 'minecraft:acacia_slab';
  static const String darkOakSlab = 'minecraft:dark_oak_slab';
  static const String mangroveSlab = 'minecraft:mangrove_slab';
  static const String cherrySlab = 'minecraft:cherry_slab';
  static const String paleOakSlab = 'minecraft:pale_oak_slab';
  static const String crimsonSlab = 'minecraft:crimson_slab';
  static const String warpedSlab = 'minecraft:warped_slab';
  static const String bambooSlab = 'minecraft:bamboo_slab';
  static const String bambooMosaicSlab = 'minecraft:bamboo_mosaic_slab';

  // ===========================================================================
  // WOOD - Stairs
  // ===========================================================================

  static const String oakStairs = 'minecraft:oak_stairs';
  static const String spruceStairs = 'minecraft:spruce_stairs';
  static const String birchStairs = 'minecraft:birch_stairs';
  static const String jungleStairs = 'minecraft:jungle_stairs';
  static const String acaciaStairs = 'minecraft:acacia_stairs';
  static const String darkOakStairs = 'minecraft:dark_oak_stairs';
  static const String mangroveStairs = 'minecraft:mangrove_stairs';
  static const String cherryStairs = 'minecraft:cherry_stairs';
  static const String paleOakStairs = 'minecraft:pale_oak_stairs';
  static const String crimsonStairs = 'minecraft:crimson_stairs';
  static const String warpedStairs = 'minecraft:warped_stairs';
  static const String bambooStairs = 'minecraft:bamboo_stairs';
  static const String bambooMosaicStairs = 'minecraft:bamboo_mosaic_stairs';

  // ===========================================================================
  // WOOD - Fences
  // ===========================================================================

  static const String oakFence = 'minecraft:oak_fence';
  static const String spruceFence = 'minecraft:spruce_fence';
  static const String birchFence = 'minecraft:birch_fence';
  static const String jungleFence = 'minecraft:jungle_fence';
  static const String acaciaFence = 'minecraft:acacia_fence';
  static const String darkOakFence = 'minecraft:dark_oak_fence';
  static const String mangroveFence = 'minecraft:mangrove_fence';
  static const String cherryFence = 'minecraft:cherry_fence';
  static const String paleOakFence = 'minecraft:pale_oak_fence';
  static const String crimsonFence = 'minecraft:crimson_fence';
  static const String warpedFence = 'minecraft:warped_fence';
  static const String bambooFence = 'minecraft:bamboo_fence';
  static const String netherBrickFence = 'minecraft:nether_brick_fence';

  // ===========================================================================
  // WOOD - Fence Gates
  // ===========================================================================

  static const String oakFenceGate = 'minecraft:oak_fence_gate';
  static const String spruceFenceGate = 'minecraft:spruce_fence_gate';
  static const String birchFenceGate = 'minecraft:birch_fence_gate';
  static const String jungleFenceGate = 'minecraft:jungle_fence_gate';
  static const String acaciaFenceGate = 'minecraft:acacia_fence_gate';
  static const String darkOakFenceGate = 'minecraft:dark_oak_fence_gate';
  static const String mangroveFenceGate = 'minecraft:mangrove_fence_gate';
  static const String cherryFenceGate = 'minecraft:cherry_fence_gate';
  static const String paleOakFenceGate = 'minecraft:pale_oak_fence_gate';
  static const String crimsonFenceGate = 'minecraft:crimson_fence_gate';
  static const String warpedFenceGate = 'minecraft:warped_fence_gate';
  static const String bambooFenceGate = 'minecraft:bamboo_fence_gate';

  // ===========================================================================
  // WOOD - Doors
  // ===========================================================================

  static const String oakDoor = 'minecraft:oak_door';
  static const String spruceDoor = 'minecraft:spruce_door';
  static const String birchDoor = 'minecraft:birch_door';
  static const String jungleDoor = 'minecraft:jungle_door';
  static const String acaciaDoor = 'minecraft:acacia_door';
  static const String darkOakDoor = 'minecraft:dark_oak_door';
  static const String mangroveDoor = 'minecraft:mangrove_door';
  static const String cherryDoor = 'minecraft:cherry_door';
  static const String paleOakDoor = 'minecraft:pale_oak_door';
  static const String crimsonDoor = 'minecraft:crimson_door';
  static const String warpedDoor = 'minecraft:warped_door';
  static const String bambooDoor = 'minecraft:bamboo_door';
  static const String ironDoor = 'minecraft:iron_door';

  // ===========================================================================
  // WOOD - Trapdoors
  // ===========================================================================

  static const String oakTrapdoor = 'minecraft:oak_trapdoor';
  static const String spruceTrapdoor = 'minecraft:spruce_trapdoor';
  static const String birchTrapdoor = 'minecraft:birch_trapdoor';
  static const String jungleTrapdoor = 'minecraft:jungle_trapdoor';
  static const String acaciaTrapdoor = 'minecraft:acacia_trapdoor';
  static const String darkOakTrapdoor = 'minecraft:dark_oak_trapdoor';
  static const String mangroveTrapdoor = 'minecraft:mangrove_trapdoor';
  static const String cherryTrapdoor = 'minecraft:cherry_trapdoor';
  static const String paleOakTrapdoor = 'minecraft:pale_oak_trapdoor';
  static const String crimsonTrapdoor = 'minecraft:crimson_trapdoor';
  static const String warpedTrapdoor = 'minecraft:warped_trapdoor';
  static const String bambooTrapdoor = 'minecraft:bamboo_trapdoor';
  static const String ironTrapdoor = 'minecraft:iron_trapdoor';

  // ===========================================================================
  // WOOD - Pressure Plates
  // ===========================================================================

  static const String oakPressurePlate = 'minecraft:oak_pressure_plate';
  static const String sprucePressurePlate = 'minecraft:spruce_pressure_plate';
  static const String birchPressurePlate = 'minecraft:birch_pressure_plate';
  static const String junglePressurePlate = 'minecraft:jungle_pressure_plate';
  static const String acaciaPressurePlate = 'minecraft:acacia_pressure_plate';
  static const String darkOakPressurePlate = 'minecraft:dark_oak_pressure_plate';
  static const String mangrovePressurePlate =
      'minecraft:mangrove_pressure_plate';
  static const String cherryPressurePlate = 'minecraft:cherry_pressure_plate';
  static const String paleOakPressurePlate = 'minecraft:pale_oak_pressure_plate';
  static const String crimsonPressurePlate = 'minecraft:crimson_pressure_plate';
  static const String warpedPressurePlate = 'minecraft:warped_pressure_plate';
  static const String bambooPressurePlate = 'minecraft:bamboo_pressure_plate';
  static const String stonePressurePlate = 'minecraft:stone_pressure_plate';
  static const String polishedBlackstonePressurePlate =
      'minecraft:polished_blackstone_pressure_plate';
  static const String lightWeightedPressurePlate =
      'minecraft:light_weighted_pressure_plate';
  static const String heavyWeightedPressurePlate =
      'minecraft:heavy_weighted_pressure_plate';

  // ===========================================================================
  // WOOD - Buttons
  // ===========================================================================

  static const String oakButton = 'minecraft:oak_button';
  static const String spruceButton = 'minecraft:spruce_button';
  static const String birchButton = 'minecraft:birch_button';
  static const String jungleButton = 'minecraft:jungle_button';
  static const String acaciaButton = 'minecraft:acacia_button';
  static const String darkOakButton = 'minecraft:dark_oak_button';
  static const String mangroveButton = 'minecraft:mangrove_button';
  static const String cherryButton = 'minecraft:cherry_button';
  static const String paleOakButton = 'minecraft:pale_oak_button';
  static const String crimsonButton = 'minecraft:crimson_button';
  static const String warpedButton = 'minecraft:warped_button';
  static const String bambooButton = 'minecraft:bamboo_button';
  static const String stoneButton = 'minecraft:stone_button';
  static const String polishedBlackstoneButton =
      'minecraft:polished_blackstone_button';

  // ===========================================================================
  // WOOD - Signs
  // ===========================================================================

  static const String oakSign = 'minecraft:oak_sign';
  static const String spruceSign = 'minecraft:spruce_sign';
  static const String birchSign = 'minecraft:birch_sign';
  static const String jungleSign = 'minecraft:jungle_sign';
  static const String acaciaSign = 'minecraft:acacia_sign';
  static const String darkOakSign = 'minecraft:dark_oak_sign';
  static const String mangroveSign = 'minecraft:mangrove_sign';
  static const String cherrySign = 'minecraft:cherry_sign';
  static const String paleOakSign = 'minecraft:pale_oak_sign';
  static const String crimsonSign = 'minecraft:crimson_sign';
  static const String warpedSign = 'minecraft:warped_sign';
  static const String bambooSign = 'minecraft:bamboo_sign';

  // ===========================================================================
  // WOOD - Hanging Signs
  // ===========================================================================

  static const String oakHangingSign = 'minecraft:oak_hanging_sign';
  static const String spruceHangingSign = 'minecraft:spruce_hanging_sign';
  static const String birchHangingSign = 'minecraft:birch_hanging_sign';
  static const String jungleHangingSign = 'minecraft:jungle_hanging_sign';
  static const String acaciaHangingSign = 'minecraft:acacia_hanging_sign';
  static const String darkOakHangingSign = 'minecraft:dark_oak_hanging_sign';
  static const String mangroveHangingSign = 'minecraft:mangrove_hanging_sign';
  static const String cherryHangingSign = 'minecraft:cherry_hanging_sign';
  static const String paleOakHangingSign = 'minecraft:pale_oak_hanging_sign';
  static const String crimsonHangingSign = 'minecraft:crimson_hanging_sign';
  static const String warpedHangingSign = 'minecraft:warped_hanging_sign';
  static const String bambooHangingSign = 'minecraft:bamboo_hanging_sign';

  // ===========================================================================
  // WOOD - Boats
  // ===========================================================================

  static const String oakBoat = 'minecraft:oak_boat';
  static const String spruceBoat = 'minecraft:spruce_boat';
  static const String birchBoat = 'minecraft:birch_boat';
  static const String jungleBoat = 'minecraft:jungle_boat';
  static const String acaciaBoat = 'minecraft:acacia_boat';
  static const String darkOakBoat = 'minecraft:dark_oak_boat';
  static const String mangroveBoat = 'minecraft:mangrove_boat';
  static const String cherryBoat = 'minecraft:cherry_boat';
  static const String paleOakBoat = 'minecraft:pale_oak_boat';
  static const String bambooRaft = 'minecraft:bamboo_raft';
  static const String oakChestBoat = 'minecraft:oak_chest_boat';
  static const String spruceChestBoat = 'minecraft:spruce_chest_boat';
  static const String birchChestBoat = 'minecraft:birch_chest_boat';
  static const String jungleChestBoat = 'minecraft:jungle_chest_boat';
  static const String acaciaChestBoat = 'minecraft:acacia_chest_boat';
  static const String darkOakChestBoat = 'minecraft:dark_oak_chest_boat';
  static const String mangroveChestBoat = 'minecraft:mangrove_chest_boat';
  static const String cherryChestBoat = 'minecraft:cherry_chest_boat';
  static const String paleOakChestBoat = 'minecraft:pale_oak_chest_boat';
  static const String bambooChestRaft = 'minecraft:bamboo_chest_raft';

  // ===========================================================================
  // LEAVES
  // ===========================================================================

  static const String oakLeaves = 'minecraft:oak_leaves';
  static const String spruceLeaves = 'minecraft:spruce_leaves';
  static const String birchLeaves = 'minecraft:birch_leaves';
  static const String jungleLeaves = 'minecraft:jungle_leaves';
  static const String acaciaLeaves = 'minecraft:acacia_leaves';
  static const String darkOakLeaves = 'minecraft:dark_oak_leaves';
  static const String mangroveLeaves = 'minecraft:mangrove_leaves';
  static const String cherryLeaves = 'minecraft:cherry_leaves';
  static const String paleOakLeaves = 'minecraft:pale_oak_leaves';
  static const String azaleaLeaves = 'minecraft:azalea_leaves';
  static const String floweringAzaleaLeaves =
      'minecraft:flowering_azalea_leaves';

  // ===========================================================================
  // SAPLINGS
  // ===========================================================================

  static const String oakSapling = 'minecraft:oak_sapling';
  static const String spruceSapling = 'minecraft:spruce_sapling';
  static const String birchSapling = 'minecraft:birch_sapling';
  static const String jungleSapling = 'minecraft:jungle_sapling';
  static const String acaciaSapling = 'minecraft:acacia_sapling';
  static const String darkOakSapling = 'minecraft:dark_oak_sapling';
  static const String mangrovePropagule = 'minecraft:mangrove_propagule';
  static const String cherrySapling = 'minecraft:cherry_sapling';
  static const String paleOakSapling = 'minecraft:pale_oak_sapling';
  static const String azalea = 'minecraft:azalea';
  static const String floweringAzalea = 'minecraft:flowering_azalea';
  static const String bamboo = 'minecraft:bamboo';

  // ===========================================================================
  // ORES
  // ===========================================================================

  static const String coalOre = 'minecraft:coal_ore';
  static const String deepslateCoalOre = 'minecraft:deepslate_coal_ore';
  static const String ironOre = 'minecraft:iron_ore';
  static const String deepslateIronOre = 'minecraft:deepslate_iron_ore';
  static const String copperOre = 'minecraft:copper_ore';
  static const String deepslateCopperOre = 'minecraft:deepslate_copper_ore';
  static const String goldOre = 'minecraft:gold_ore';
  static const String deepslateGoldOre = 'minecraft:deepslate_gold_ore';
  static const String redstoneOre = 'minecraft:redstone_ore';
  static const String deepslateRedstoneOre = 'minecraft:deepslate_redstone_ore';
  static const String emeraldOre = 'minecraft:emerald_ore';
  static const String deepslateEmeraldOre = 'minecraft:deepslate_emerald_ore';
  static const String lapisOre = 'minecraft:lapis_ore';
  static const String deepslateLapisOre = 'minecraft:deepslate_lapis_ore';
  static const String diamondOre = 'minecraft:diamond_ore';
  static const String deepslateDiamondOre = 'minecraft:deepslate_diamond_ore';
  static const String netherGoldOre = 'minecraft:nether_gold_ore';
  static const String netherQuartzOre = 'minecraft:nether_quartz_ore';
  static const String ancientDebris = 'minecraft:ancient_debris';

  // ===========================================================================
  // TOOLS - Wooden
  // ===========================================================================

  static const String woodenSword = 'minecraft:wooden_sword';
  static const String woodenPickaxe = 'minecraft:wooden_pickaxe';
  static const String woodenAxe = 'minecraft:wooden_axe';
  static const String woodenShovel = 'minecraft:wooden_shovel';
  static const String woodenHoe = 'minecraft:wooden_hoe';

  // ===========================================================================
  // TOOLS - Stone
  // ===========================================================================

  static const String stoneSword = 'minecraft:stone_sword';
  static const String stonePickaxe = 'minecraft:stone_pickaxe';
  static const String stoneAxe = 'minecraft:stone_axe';
  static const String stoneShovel = 'minecraft:stone_shovel';
  static const String stoneHoe = 'minecraft:stone_hoe';

  // ===========================================================================
  // TOOLS - Iron
  // ===========================================================================

  static const String ironSword = 'minecraft:iron_sword';
  static const String ironPickaxe = 'minecraft:iron_pickaxe';
  static const String ironAxe = 'minecraft:iron_axe';
  static const String ironShovel = 'minecraft:iron_shovel';
  static const String ironHoe = 'minecraft:iron_hoe';

  // ===========================================================================
  // TOOLS - Golden
  // ===========================================================================

  static const String goldenSword = 'minecraft:golden_sword';
  static const String goldenPickaxe = 'minecraft:golden_pickaxe';
  static const String goldenAxe = 'minecraft:golden_axe';
  static const String goldenShovel = 'minecraft:golden_shovel';
  static const String goldenHoe = 'minecraft:golden_hoe';

  // ===========================================================================
  // TOOLS - Diamond
  // ===========================================================================

  static const String diamondSword = 'minecraft:diamond_sword';
  static const String diamondPickaxe = 'minecraft:diamond_pickaxe';
  static const String diamondAxe = 'minecraft:diamond_axe';
  static const String diamondShovel = 'minecraft:diamond_shovel';
  static const String diamondHoe = 'minecraft:diamond_hoe';

  // ===========================================================================
  // TOOLS - Netherite
  // ===========================================================================

  static const String netheriteSword = 'minecraft:netherite_sword';
  static const String netheritePickaxe = 'minecraft:netherite_pickaxe';
  static const String netheriteAxe = 'minecraft:netherite_axe';
  static const String netheriteShovel = 'minecraft:netherite_shovel';
  static const String netheriteHoe = 'minecraft:netherite_hoe';

  // ===========================================================================
  // TOOLS - Other
  // ===========================================================================

  static const String shears = 'minecraft:shears';
  static const String flintAndSteel = 'minecraft:flint_and_steel';
  static const String fishingRod = 'minecraft:fishing_rod';
  static const String carrotOnAStick = 'minecraft:carrot_on_a_stick';
  static const String warpedFungusOnAStick =
      'minecraft:warped_fungus_on_a_stick';
  static const String brush = 'minecraft:brush';
  static const String spyglass = 'minecraft:spyglass';
  static const String compass = 'minecraft:compass';
  static const String recoveryCompass = 'minecraft:recovery_compass';
  static const String clock = 'minecraft:clock';
  static const String lead = 'minecraft:lead';
  static const String nameTag = 'minecraft:name_tag';

  // ===========================================================================
  // ARMOR - Leather
  // ===========================================================================

  static const String leatherHelmet = 'minecraft:leather_helmet';
  static const String leatherChestplate = 'minecraft:leather_chestplate';
  static const String leatherLeggings = 'minecraft:leather_leggings';
  static const String leatherBoots = 'minecraft:leather_boots';

  // ===========================================================================
  // ARMOR - Chainmail
  // ===========================================================================

  static const String chainmailHelmet = 'minecraft:chainmail_helmet';
  static const String chainmailChestplate = 'minecraft:chainmail_chestplate';
  static const String chainmailLeggings = 'minecraft:chainmail_leggings';
  static const String chainmailBoots = 'minecraft:chainmail_boots';

  // ===========================================================================
  // ARMOR - Iron
  // ===========================================================================

  static const String ironHelmet = 'minecraft:iron_helmet';
  static const String ironChestplate = 'minecraft:iron_chestplate';
  static const String ironLeggings = 'minecraft:iron_leggings';
  static const String ironBoots = 'minecraft:iron_boots';

  // ===========================================================================
  // ARMOR - Golden
  // ===========================================================================

  static const String goldenHelmet = 'minecraft:golden_helmet';
  static const String goldenChestplate = 'minecraft:golden_chestplate';
  static const String goldenLeggings = 'minecraft:golden_leggings';
  static const String goldenBoots = 'minecraft:golden_boots';

  // ===========================================================================
  // ARMOR - Diamond
  // ===========================================================================

  static const String diamondHelmet = 'minecraft:diamond_helmet';
  static const String diamondChestplate = 'minecraft:diamond_chestplate';
  static const String diamondLeggings = 'minecraft:diamond_leggings';
  static const String diamondBoots = 'minecraft:diamond_boots';

  // ===========================================================================
  // ARMOR - Netherite
  // ===========================================================================

  static const String netheriteHelmet = 'minecraft:netherite_helmet';
  static const String netheriteChestplate = 'minecraft:netherite_chestplate';
  static const String netheriteLeggings = 'minecraft:netherite_leggings';
  static const String netheriteBoots = 'minecraft:netherite_boots';

  // ===========================================================================
  // ARMOR - Other
  // ===========================================================================

  static const String turtleHelmet = 'minecraft:turtle_helmet';
  static const String elytra = 'minecraft:elytra';
  static const String shield = 'minecraft:shield';
  static const String wolfArmor = 'minecraft:wolf_armor';

  // ===========================================================================
  // ARMOR TRIMS (Smithing Templates)
  // ===========================================================================

  static const String coastArmorTrimSmithingTemplate =
      'minecraft:coast_armor_trim_smithing_template';
  static const String duneArmorTrimSmithingTemplate =
      'minecraft:dune_armor_trim_smithing_template';
  static const String eyeArmorTrimSmithingTemplate =
      'minecraft:eye_armor_trim_smithing_template';
  static const String hostArmorTrimSmithingTemplate =
      'minecraft:host_armor_trim_smithing_template';
  static const String raisedArmorTrimSmithingTemplate =
      'minecraft:raiser_armor_trim_smithing_template';
  static const String ribArmorTrimSmithingTemplate =
      'minecraft:rib_armor_trim_smithing_template';
  static const String sentryArmorTrimSmithingTemplate =
      'minecraft:sentry_armor_trim_smithing_template';
  static const String shaperArmorTrimSmithingTemplate =
      'minecraft:shaper_armor_trim_smithing_template';
  static const String silenceArmorTrimSmithingTemplate =
      'minecraft:silence_armor_trim_smithing_template';
  static const String snoutArmorTrimSmithingTemplate =
      'minecraft:snout_armor_trim_smithing_template';
  static const String spireArmorTrimSmithingTemplate =
      'minecraft:spire_armor_trim_smithing_template';
  static const String tideArmorTrimSmithingTemplate =
      'minecraft:tide_armor_trim_smithing_template';
  static const String vexArmorTrimSmithingTemplate =
      'minecraft:vex_armor_trim_smithing_template';
  static const String wardArmorTrimSmithingTemplate =
      'minecraft:ward_armor_trim_smithing_template';
  static const String wayfinderArmorTrimSmithingTemplate =
      'minecraft:wayfinder_armor_trim_smithing_template';
  static const String wildArmorTrimSmithingTemplate =
      'minecraft:wild_armor_trim_smithing_template';
  static const String netheriteUpgradeSmithingTemplate =
      'minecraft:netherite_upgrade_smithing_template';
  static const String boltArmorTrimSmithingTemplate =
      'minecraft:bolt_armor_trim_smithing_template';
  static const String flowArmorTrimSmithingTemplate =
      'minecraft:flow_armor_trim_smithing_template';

  // ===========================================================================
  // COMBAT - Weapons
  // ===========================================================================

  static const String bow = 'minecraft:bow';
  static const String crossbow = 'minecraft:crossbow';
  static const String arrow = 'minecraft:arrow';
  static const String spectralArrow = 'minecraft:spectral_arrow';
  static const String tippedArrow = 'minecraft:tipped_arrow';
  static const String trident = 'minecraft:trident';
  static const String mace = 'minecraft:mace';
  static const String fireworkRocket = 'minecraft:firework_rocket';
  static const String fireworkStar = 'minecraft:firework_star';

  // ===========================================================================
  // FOOD - Raw Meat
  // ===========================================================================

  static const String beef = 'minecraft:beef';
  static const String porkchop = 'minecraft:porkchop';
  static const String mutton = 'minecraft:mutton';
  static const String chicken = 'minecraft:chicken';
  static const String rabbit = 'minecraft:rabbit';
  static const String cod = 'minecraft:cod';
  static const String salmon = 'minecraft:salmon';
  static const String tropicalFish = 'minecraft:tropical_fish';
  static const String pufferfish = 'minecraft:pufferfish';

  // ===========================================================================
  // FOOD - Cooked Meat
  // ===========================================================================

  static const String cookedBeef = 'minecraft:cooked_beef';
  static const String cookedPorkchop = 'minecraft:cooked_porkchop';
  static const String cookedMutton = 'minecraft:cooked_mutton';
  static const String cookedChicken = 'minecraft:cooked_chicken';
  static const String cookedRabbit = 'minecraft:cooked_rabbit';
  static const String cookedCod = 'minecraft:cooked_cod';
  static const String cookedSalmon = 'minecraft:cooked_salmon';

  // ===========================================================================
  // FOOD - Vegetables and Fruits
  // ===========================================================================

  static const String apple = 'minecraft:apple';
  static const String goldenApple = 'minecraft:golden_apple';
  static const String enchantedGoldenApple =
      'minecraft:enchanted_golden_apple';
  static const String carrot = 'minecraft:carrot';
  static const String goldenCarrot = 'minecraft:golden_carrot';
  static const String potato = 'minecraft:potato';
  static const String bakedPotato = 'minecraft:baked_potato';
  static const String poisonousPotato = 'minecraft:poisonous_potato';
  static const String beetroot = 'minecraft:beetroot';
  static const String melonSlice = 'minecraft:melon_slice';
  static const String sweetBerries = 'minecraft:sweet_berries';
  static const String glowBerries = 'minecraft:glow_berries';
  static const String chorusFruit = 'minecraft:chorus_fruit';

  // ===========================================================================
  // FOOD - Baked Goods and Other
  // ===========================================================================

  static const String bread = 'minecraft:bread';
  static const String cookie = 'minecraft:cookie';
  static const String cake = 'minecraft:cake';
  static const String pumpkinPie = 'minecraft:pumpkin_pie';
  static const String mushroomStew = 'minecraft:mushroom_stew';
  static const String beetrootSoup = 'minecraft:beetroot_soup';
  static const String rabbitStew = 'minecraft:rabbit_stew';
  static const String suspiciousStew = 'minecraft:suspicious_stew';
  static const String driedKelp = 'minecraft:dried_kelp';
  static const String honeyBottle = 'minecraft:honey_bottle';
  static const String rottenFlesh = 'minecraft:rotten_flesh';
  static const String spiderEye = 'minecraft:spider_eye';

  // ===========================================================================
  // MATERIALS - Ingots and Nuggets
  // ===========================================================================

  static const String ironIngot = 'minecraft:iron_ingot';
  static const String goldIngot = 'minecraft:gold_ingot';
  static const String copperIngot = 'minecraft:copper_ingot';
  static const String netheriteIngot = 'minecraft:netherite_ingot';
  static const String ironNugget = 'minecraft:iron_nugget';
  static const String goldNugget = 'minecraft:gold_nugget';

  // ===========================================================================
  // MATERIALS - Raw Ores
  // ===========================================================================

  static const String rawIron = 'minecraft:raw_iron';
  static const String rawGold = 'minecraft:raw_gold';
  static const String rawCopper = 'minecraft:raw_copper';

  // ===========================================================================
  // MATERIALS - Gems and Minerals
  // ===========================================================================

  static const String diamond = 'minecraft:diamond';
  static const String emerald = 'minecraft:emerald';
  static const String lapisLazuli = 'minecraft:lapis_lazuli';
  static const String quartz = 'minecraft:quartz';
  static const String amethystShard = 'minecraft:amethyst_shard';
  static const String netheriteScrap = 'minecraft:netherite_scrap';
  static const String coal = 'minecraft:coal';
  static const String charcoal = 'minecraft:charcoal';
  static const String redstone = 'minecraft:redstone';
  static const String glowstoneDust = 'minecraft:glowstone_dust';
  static const String prismarineShard = 'minecraft:prismarine_shard';
  static const String prismarineCrystals = 'minecraft:prismarine_crystals';

  // ===========================================================================
  // MATERIALS - Basic
  // ===========================================================================

  static const String stick = 'minecraft:stick';
  static const String bone = 'minecraft:bone';
  static const String boneMeal = 'minecraft:bone_meal';
  static const String leather = 'minecraft:leather';
  static const String rabbitHide = 'minecraft:rabbit_hide';
  static const String feather = 'minecraft:feather';
  static const String string = 'minecraft:string';
  static const String flint = 'minecraft:flint';
  static const String clay = 'minecraft:clay';
  static const String clayBall = 'minecraft:clay_ball';
  static const String brick = 'minecraft:brick';
  static const String netherBrick = 'minecraft:nether_brick';
  static const String paper = 'minecraft:paper';
  static const String book = 'minecraft:book';
  static const String slimeball = 'minecraft:slime_ball';
  static const String honeyBlock = 'minecraft:honey_block';
  static const String honeycomb = 'minecraft:honeycomb';
  static const String honeycombBlock = 'minecraft:honeycomb_block';
  static const String gunpowder = 'minecraft:gunpowder';
  static const String blazeRod = 'minecraft:blaze_rod';
  static const String blazePowder = 'minecraft:blaze_powder';
  static const String ghastTear = 'minecraft:ghast_tear';
  static const String magmaCream = 'minecraft:magma_cream';
  static const String enderPearl = 'minecraft:ender_pearl';
  static const String eyeOfEnder = 'minecraft:ender_eye';
  static const String netherStar = 'minecraft:nether_star';
  static const String shulkerShell = 'minecraft:shulker_shell';
  static const String scute = 'minecraft:turtle_scute';
  static const String phantomMembrane = 'minecraft:phantom_membrane';
  static const String echoShard = 'minecraft:echo_shard';
  static const String discFragment5 = 'minecraft:disc_fragment_5';
  static const String heartOfTheSea = 'minecraft:heart_of_the_sea';
  static const String nautilusShell = 'minecraft:nautilus_shell';
  static const String rabbitFoot = 'minecraft:rabbit_foot';
  static const String fermentedSpiderEye = 'minecraft:fermented_spider_eye';
  static const String dragonBreath = 'minecraft:dragon_breath';
  static const String breezRod = 'minecraft:breeze_rod';
  static const String heavyCore = 'minecraft:heavy_core';

  // ===========================================================================
  // DYES
  // ===========================================================================

  static const String whiteDye = 'minecraft:white_dye';
  static const String orangeDye = 'minecraft:orange_dye';
  static const String magentaDye = 'minecraft:magenta_dye';
  static const String lightBlueDye = 'minecraft:light_blue_dye';
  static const String yellowDye = 'minecraft:yellow_dye';
  static const String limeDye = 'minecraft:lime_dye';
  static const String pinkDye = 'minecraft:pink_dye';
  static const String grayDye = 'minecraft:gray_dye';
  static const String lightGrayDye = 'minecraft:light_gray_dye';
  static const String cyanDye = 'minecraft:cyan_dye';
  static const String purpleDye = 'minecraft:purple_dye';
  static const String blueDye = 'minecraft:blue_dye';
  static const String brownDye = 'minecraft:brown_dye';
  static const String greenDye = 'minecraft:green_dye';
  static const String redDye = 'minecraft:red_dye';
  static const String blackDye = 'minecraft:black_dye';
  static const String inkSac = 'minecraft:ink_sac';
  static const String glowInkSac = 'minecraft:glow_ink_sac';

  // ===========================================================================
  // SEEDS AND CROPS
  // ===========================================================================

  static const String wheatSeeds = 'minecraft:wheat_seeds';
  static const String wheat = 'minecraft:wheat';
  static const String beetrootSeeds = 'minecraft:beetroot_seeds';
  static const String melonSeeds = 'minecraft:melon_seeds';
  static const String pumpkinSeeds = 'minecraft:pumpkin_seeds';
  static const String torchflowerSeeds = 'minecraft:torchflower_seeds';
  static const String pitcherPod = 'minecraft:pitcher_pod';
  static const String netherWart = 'minecraft:nether_wart';
  static const String sugarCane = 'minecraft:sugar_cane';
  static const String sugar = 'minecraft:sugar';
  static const String kelp = 'minecraft:kelp';
  static const String cocoaBeans = 'minecraft:cocoa_beans';

  // ===========================================================================
  // REDSTONE COMPONENTS
  // ===========================================================================

  static const String redstoneTorch = 'minecraft:redstone_torch';
  static const String redstoneRepeater = 'minecraft:repeater';
  static const String redstoneComparator = 'minecraft:comparator';
  static const String lever = 'minecraft:lever';
  static const String tripwireHook = 'minecraft:tripwire_hook';
  static const String daylightDetector = 'minecraft:daylight_detector';
  static const String targetBlock = 'minecraft:target';
  static const String observer = 'minecraft:observer';
  static const String piston = 'minecraft:piston';
  static const String stickyPiston = 'minecraft:sticky_piston';
  static const String slimeBlock = 'minecraft:slime_block';
  static const String dispenser = 'minecraft:dispenser';
  static const String dropper = 'minecraft:dropper';
  static const String hopper = 'minecraft:hopper';
  static const String redstoneLamp = 'minecraft:redstone_lamp';
  static const String noteBlock = 'minecraft:note_block';
  static const String tnt = 'minecraft:tnt';
  static const String sculkSensor = 'minecraft:sculk_sensor';
  static const String calibratedSculkSensor =
      'minecraft:calibrated_sculk_sensor';
  static const String sculk = 'minecraft:sculk';
  static const String sculkVein = 'minecraft:sculk_vein';
  static const String sculkCatalyst = 'minecraft:sculk_catalyst';
  static const String sculkShrieker = 'minecraft:sculk_shrieker';
  static const String crafter = 'minecraft:crafter';

  // ===========================================================================
  // FUNCTIONAL BLOCKS
  // ===========================================================================

  static const String craftingTable = 'minecraft:crafting_table';
  static const String furnace = 'minecraft:furnace';
  static const String blastFurnace = 'minecraft:blast_furnace';
  static const String smoker = 'minecraft:smoker';
  static const String campfire = 'minecraft:campfire';
  static const String soulCampfire = 'minecraft:soul_campfire';
  static const String anvil = 'minecraft:anvil';
  static const String chippedAnvil = 'minecraft:chipped_anvil';
  static const String damagedAnvil = 'minecraft:damaged_anvil';
  static const String grindstone = 'minecraft:grindstone';
  static const String stonecutter = 'minecraft:stonecutter';
  static const String smithingTable = 'minecraft:smithing_table';
  static const String loom = 'minecraft:loom';
  static const String cartographyTable = 'minecraft:cartography_table';
  static const String fletchingTable = 'minecraft:fletching_table';
  static const String brewingStand = 'minecraft:brewing_stand';
  static const String cauldron = 'minecraft:cauldron';
  static const String composter = 'minecraft:composter';
  static const String enchantingTable = 'minecraft:enchanting_table';
  static const String bookshelf = 'minecraft:bookshelf';
  static const String chiseledBookshelf = 'minecraft:chiseled_bookshelf';
  static const String lectern = 'minecraft:lectern';
  static const String beacon = 'minecraft:beacon';
  static const String conduit = 'minecraft:conduit';
  static const String lodestone = 'minecraft:lodestone';
  static const String respawnAnchor = 'minecraft:respawn_anchor';
  static const String jukebox = 'minecraft:jukebox';
  static const String bell = 'minecraft:bell';
  static const String bed = 'minecraft:white_bed';
  static const String endCrystal = 'minecraft:end_crystal';

  // ===========================================================================
  // BEDS (All Colors)
  // ===========================================================================

  static const String whiteBed = 'minecraft:white_bed';
  static const String orangeBed = 'minecraft:orange_bed';
  static const String magentaBed = 'minecraft:magenta_bed';
  static const String lightBlueBed = 'minecraft:light_blue_bed';
  static const String yellowBed = 'minecraft:yellow_bed';
  static const String limeBed = 'minecraft:lime_bed';
  static const String pinkBed = 'minecraft:pink_bed';
  static const String grayBed = 'minecraft:gray_bed';
  static const String lightGrayBed = 'minecraft:light_gray_bed';
  static const String cyanBed = 'minecraft:cyan_bed';
  static const String purpleBed = 'minecraft:purple_bed';
  static const String blueBed = 'minecraft:blue_bed';
  static const String brownBed = 'minecraft:brown_bed';
  static const String greenBed = 'minecraft:green_bed';
  static const String redBed = 'minecraft:red_bed';
  static const String blackBed = 'minecraft:black_bed';

  // ===========================================================================
  // STORAGE
  // ===========================================================================

  static const String chest = 'minecraft:chest';
  static const String trappedChest = 'minecraft:trapped_chest';
  static const String enderChest = 'minecraft:ender_chest';
  static const String barrel = 'minecraft:barrel';
  static const String shulkerBox = 'minecraft:shulker_box';
  static const String whiteShulkerBox = 'minecraft:white_shulker_box';
  static const String orangeShulkerBox = 'minecraft:orange_shulker_box';
  static const String magentaShulkerBox = 'minecraft:magenta_shulker_box';
  static const String lightBlueShulkerBox = 'minecraft:light_blue_shulker_box';
  static const String yellowShulkerBox = 'minecraft:yellow_shulker_box';
  static const String limeShulkerBox = 'minecraft:lime_shulker_box';
  static const String pinkShulkerBox = 'minecraft:pink_shulker_box';
  static const String grayShulkerBox = 'minecraft:gray_shulker_box';
  static const String lightGrayShulkerBox = 'minecraft:light_gray_shulker_box';
  static const String cyanShulkerBox = 'minecraft:cyan_shulker_box';
  static const String purpleShulkerBox = 'minecraft:purple_shulker_box';
  static const String blueShulkerBox = 'minecraft:blue_shulker_box';
  static const String brownShulkerBox = 'minecraft:brown_shulker_box';
  static const String greenShulkerBox = 'minecraft:green_shulker_box';
  static const String redShulkerBox = 'minecraft:red_shulker_box';
  static const String blackShulkerBox = 'minecraft:black_shulker_box';
  static const String bundle = 'minecraft:bundle';

  // ===========================================================================
  // BUCKETS
  // ===========================================================================

  static const String bucket = 'minecraft:bucket';
  static const String waterBucket = 'minecraft:water_bucket';
  static const String lavaBucket = 'minecraft:lava_bucket';
  static const String milkBucket = 'minecraft:milk_bucket';
  static const String powderSnowBucket = 'minecraft:powder_snow_bucket';
  static const String codBucket = 'minecraft:cod_bucket';
  static const String salmonBucket = 'minecraft:salmon_bucket';
  static const String tropicalFishBucket = 'minecraft:tropical_fish_bucket';
  static const String pufferfishBucket = 'minecraft:pufferfish_bucket';
  static const String axolotlBucket = 'minecraft:axolotl_bucket';
  static const String tadpoleBucket = 'minecraft:tadpole_bucket';

  // ===========================================================================
  // MINECARTS
  // ===========================================================================

  static const String minecart = 'minecraft:minecart';
  static const String chestMinecart = 'minecraft:chest_minecart';
  static const String furnaceMinecart = 'minecraft:furnace_minecart';
  static const String hopperMinecart = 'minecraft:hopper_minecart';
  static const String tntMinecart = 'minecraft:tnt_minecart';
  static const String commandBlockMinecart =
      'minecraft:command_block_minecart';

  // ===========================================================================
  // RAILS
  // ===========================================================================

  static const String rail = 'minecraft:rail';
  static const String poweredRail = 'minecraft:powered_rail';
  static const String detectorRail = 'minecraft:detector_rail';
  static const String activatorRail = 'minecraft:activator_rail';

  // ===========================================================================
  // DECORATIONS
  // ===========================================================================

  static const String torch = 'minecraft:torch';
  static const String soulTorch = 'minecraft:soul_torch';
  static const String lantern = 'minecraft:lantern';
  static const String soulLantern = 'minecraft:soul_lantern';
  static const String candle = 'minecraft:candle';
  static const String whiteCandle = 'minecraft:white_candle';
  static const String orangeCandle = 'minecraft:orange_candle';
  static const String magentaCandle = 'minecraft:magenta_candle';
  static const String lightBlueCandle = 'minecraft:light_blue_candle';
  static const String yellowCandle = 'minecraft:yellow_candle';
  static const String limeCandle = 'minecraft:lime_candle';
  static const String pinkCandle = 'minecraft:pink_candle';
  static const String grayCandle = 'minecraft:gray_candle';
  static const String lightGrayCandle = 'minecraft:light_gray_candle';
  static const String cyanCandle = 'minecraft:cyan_candle';
  static const String purpleCandle = 'minecraft:purple_candle';
  static const String blueCandle = 'minecraft:blue_candle';
  static const String brownCandle = 'minecraft:brown_candle';
  static const String greenCandle = 'minecraft:green_candle';
  static const String redCandle = 'minecraft:red_candle';
  static const String blackCandle = 'minecraft:black_candle';
  static const String endRod = 'minecraft:end_rod';
  static const String chain = 'minecraft:chain';
  static const String ladder = 'minecraft:ladder';
  static const String scaffolding = 'minecraft:scaffolding';
  static const String itemFrame = 'minecraft:item_frame';
  static const String glowItemFrame = 'minecraft:glow_item_frame';
  static const String painting = 'minecraft:painting';
  static const String armorStand = 'minecraft:armor_stand';
  static const String flowerPot = 'minecraft:flower_pot';

  // ===========================================================================
  // FLOWERS
  // ===========================================================================

  static const String dandelion = 'minecraft:dandelion';
  static const String poppy = 'minecraft:poppy';
  static const String blueOrchid = 'minecraft:blue_orchid';
  static const String allium = 'minecraft:allium';
  static const String azureBluet = 'minecraft:azure_bluet';
  static const String redTulip = 'minecraft:red_tulip';
  static const String orangeTulip = 'minecraft:orange_tulip';
  static const String whiteTulip = 'minecraft:white_tulip';
  static const String pinkTulip = 'minecraft:pink_tulip';
  static const String oxeyeDaisy = 'minecraft:oxeye_daisy';
  static const String cornflower = 'minecraft:cornflower';
  static const String lilyOfTheValley = 'minecraft:lily_of_the_valley';
  static const String witherRose = 'minecraft:wither_rose';
  static const String torchflower = 'minecraft:torchflower';
  static const String pinkPetals = 'minecraft:pink_petals';
  static const String sunflower = 'minecraft:sunflower';
  static const String lilac = 'minecraft:lilac';
  static const String roseBush = 'minecraft:rose_bush';
  static const String peony = 'minecraft:peony';
  static const String pitcher = 'minecraft:pitcher_plant';

  // ===========================================================================
  // MUSHROOMS AND FUNGI
  // ===========================================================================

  static const String brownMushroom = 'minecraft:brown_mushroom';
  static const String redMushroom = 'minecraft:red_mushroom';
  static const String brownMushroomBlock = 'minecraft:brown_mushroom_block';
  static const String redMushroomBlock = 'minecraft:red_mushroom_block';
  static const String mushroomStem = 'minecraft:mushroom_stem';
  static const String crimsonFungus = 'minecraft:crimson_fungus';
  static const String warpedFungus = 'minecraft:warped_fungus';
  static const String crimsonRoots = 'minecraft:crimson_roots';
  static const String warpedRoots = 'minecraft:warped_roots';
  static const String netherSprouts = 'minecraft:nether_sprouts';
  static const String weepingVines = 'minecraft:weeping_vines';
  static const String twistingVines = 'minecraft:twisting_vines';
  static const String shroomlight = 'minecraft:shroomlight';

  // ===========================================================================
  // PLANTS AND VEGETATION
  // ===========================================================================

  static const String grass = 'minecraft:short_grass';
  static const String tallGrass = 'minecraft:tall_grass';
  static const String fern = 'minecraft:fern';
  static const String largeFern = 'minecraft:large_fern';
  static const String deadBush = 'minecraft:dead_bush';
  static const String seagrass = 'minecraft:seagrass';
  static const String seaPickle = 'minecraft:sea_pickle';
  static const String vine = 'minecraft:vine';
  static const String lilyPad = 'minecraft:lily_pad';
  static const String mossBlock = 'minecraft:moss_block';
  static const String hangingRoots = 'minecraft:hanging_roots';
  static const String sporeBlossom = 'minecraft:spore_blossom';
  static const String cactus = 'minecraft:cactus';
  static const String hayBlock = 'minecraft:hay_block';
  static const String pumpkin = 'minecraft:pumpkin';
  static const String carvedPumpkin = 'minecraft:carved_pumpkin';
  static const String jackOLantern = 'minecraft:jack_o_lantern';
  static const String melon = 'minecraft:melon';
  static const String driedKelpBlock = 'minecraft:dried_kelp_block';
  static const String cobweb = 'minecraft:cobweb';
  static const String glowLichen = 'minecraft:glow_lichen';
  static const String bigDripleaf = 'minecraft:big_dripleaf';
  static const String smallDripleaf = 'minecraft:small_dripleaf';

  // ===========================================================================
  // CORALS
  // ===========================================================================

  static const String tubeCoralBlock = 'minecraft:tube_coral_block';
  static const String brainCoralBlock = 'minecraft:brain_coral_block';
  static const String bubbleCoralBlock = 'minecraft:bubble_coral_block';
  static const String fireCoralBlock = 'minecraft:fire_coral_block';
  static const String hornCoralBlock = 'minecraft:horn_coral_block';
  static const String tubeCoral = 'minecraft:tube_coral';
  static const String brainCoral = 'minecraft:brain_coral';
  static const String bubbleCoral = 'minecraft:bubble_coral';
  static const String fireCoral = 'minecraft:fire_coral';
  static const String hornCoral = 'minecraft:horn_coral';
  static const String tubeCoralFan = 'minecraft:tube_coral_fan';
  static const String brainCoralFan = 'minecraft:brain_coral_fan';
  static const String bubbleCoralFan = 'minecraft:bubble_coral_fan';
  static const String fireCoralFan = 'minecraft:fire_coral_fan';
  static const String hornCoralFan = 'minecraft:horn_coral_fan';
  static const String deadTubeCoralBlock = 'minecraft:dead_tube_coral_block';
  static const String deadBrainCoralBlock = 'minecraft:dead_brain_coral_block';
  static const String deadBubbleCoralBlock =
      'minecraft:dead_bubble_coral_block';
  static const String deadFireCoralBlock = 'minecraft:dead_fire_coral_block';
  static const String deadHornCoralBlock = 'minecraft:dead_horn_coral_block';

  // ===========================================================================
  // SKULLS AND HEADS
  // ===========================================================================

  static const String skeletonSkull = 'minecraft:skeleton_skull';
  static const String witherSkeletonSkull = 'minecraft:wither_skeleton_skull';
  static const String zombieHead = 'minecraft:zombie_head';
  static const String playerHead = 'minecraft:player_head';
  static const String creeperHead = 'minecraft:creeper_head';
  static const String dragonHead = 'minecraft:dragon_head';
  static const String piglinHead = 'minecraft:piglin_head';

  // ===========================================================================
  // BANNERS
  // ===========================================================================

  static const String whiteBanner = 'minecraft:white_banner';
  static const String orangeBanner = 'minecraft:orange_banner';
  static const String magentaBanner = 'minecraft:magenta_banner';
  static const String lightBlueBanner = 'minecraft:light_blue_banner';
  static const String yellowBanner = 'minecraft:yellow_banner';
  static const String limeBanner = 'minecraft:lime_banner';
  static const String pinkBanner = 'minecraft:pink_banner';
  static const String grayBanner = 'minecraft:gray_banner';
  static const String lightGrayBanner = 'minecraft:light_gray_banner';
  static const String cyanBanner = 'minecraft:cyan_banner';
  static const String purpleBanner = 'minecraft:purple_banner';
  static const String blueBanner = 'minecraft:blue_banner';
  static const String brownBanner = 'minecraft:brown_banner';
  static const String greenBanner = 'minecraft:green_banner';
  static const String redBanner = 'minecraft:red_banner';
  static const String blackBanner = 'minecraft:black_banner';
  static const String ominousBanner = 'minecraft:ominous_banner';

  // ===========================================================================
  // POTIONS AND BREWING
  // ===========================================================================

  static const String potion = 'minecraft:potion';
  static const String splashPotion = 'minecraft:splash_potion';
  static const String lingeringPotion = 'minecraft:lingering_potion';
  static const String glassBottle = 'minecraft:glass_bottle';
  static const String experienceBottle = 'minecraft:experience_bottle';

  // ===========================================================================
  // ENCHANTING AND BOOKS
  // ===========================================================================

  static const String enchantedBook = 'minecraft:enchanted_book';
  static const String writableBook = 'minecraft:writable_book';
  static const String writtenBook = 'minecraft:written_book';
  static const String knowledgeBook = 'minecraft:knowledge_book';

  // ===========================================================================
  // MAPS
  // ===========================================================================

  static const String map = 'minecraft:map';
  static const String filledMap = 'minecraft:filled_map';
  static const String explorerMap = 'minecraft:filled_map';

  // ===========================================================================
  // POTTERY SHERDS
  // ===========================================================================

  static const String anglerPotterySherd = 'minecraft:angler_pottery_sherd';
  static const String archerPotterySherd = 'minecraft:archer_pottery_sherd';
  static const String armsBothUpPotterySherd =
      'minecraft:arms_up_pottery_sherd';
  static const String bladePotterySherd = 'minecraft:blade_pottery_sherd';
  static const String brewerPotterySherd = 'minecraft:brewer_pottery_sherd';
  static const String burnPotterySherd = 'minecraft:burn_pottery_sherd';
  static const String dangerPotterySherd = 'minecraft:danger_pottery_sherd';
  static const String explorerPotterySherd = 'minecraft:explorer_pottery_sherd';
  static const String friendPotterySherd = 'minecraft:friend_pottery_sherd';
  static const String heartPotterySherd = 'minecraft:heart_pottery_sherd';
  static const String heartbreakPotterySherd =
      'minecraft:heartbreak_pottery_sherd';
  static const String howlPotterySherd = 'minecraft:howl_pottery_sherd';
  static const String minerPotterySherd = 'minecraft:miner_pottery_sherd';
  static const String mournerPotterySherd = 'minecraft:mourner_pottery_sherd';
  static const String plentyPotterySherd = 'minecraft:plenty_pottery_sherd';
  static const String prizePotterySherd = 'minecraft:prize_pottery_sherd';
  static const String sheafPotterySherd = 'minecraft:sheaf_pottery_sherd';
  static const String shelterPotterySherd = 'minecraft:shelter_pottery_sherd';
  static const String skullPotterySherd = 'minecraft:skull_pottery_sherd';
  static const String snortPotterySherd = 'minecraft:snort_pottery_sherd';
  static const String flowPotterySherd = 'minecraft:flow_pottery_sherd';
  static const String gustPotterySherd = 'minecraft:gust_pottery_sherd';
  static const String scrapePotterySherd = 'minecraft:scrape_pottery_sherd';

  // ===========================================================================
  // DECORATED POTS AND ARCHAEOLOGY
  // ===========================================================================

  static const String decoratedPot = 'minecraft:decorated_pot';
  static const String brickItem = 'minecraft:brick';

  // ===========================================================================
  // MUSIC DISCS
  // ===========================================================================

  static const String musicDisc11 = 'minecraft:music_disc_11';
  static const String musicDisc13 = 'minecraft:music_disc_13';
  static const String musicDisc5 = 'minecraft:music_disc_5';
  static const String musicDiscBlocks = 'minecraft:music_disc_blocks';
  static const String musicDiscCat = 'minecraft:music_disc_cat';
  static const String musicDiscChirp = 'minecraft:music_disc_chirp';
  static const String musicDiscCreator = 'minecraft:music_disc_creator';
  static const String musicDiscCreatorMusicBox =
      'minecraft:music_disc_creator_music_box';
  static const String musicDiscFar = 'minecraft:music_disc_far';
  static const String musicDiscMall = 'minecraft:music_disc_mall';
  static const String musicDiscMellohi = 'minecraft:music_disc_mellohi';
  static const String musicDiscOtherside = 'minecraft:music_disc_otherside';
  static const String musicDiscPigstep = 'minecraft:music_disc_pigstep';
  static const String musicDiscPrecipice = 'minecraft:music_disc_precipice';
  static const String musicDiscRelic = 'minecraft:music_disc_relic';
  static const String musicDiscStal = 'minecraft:music_disc_stal';
  static const String musicDiscStrad = 'minecraft:music_disc_strad';
  static const String musicDiscWait = 'minecraft:music_disc_wait';
  static const String musicDiscWard = 'minecraft:music_disc_ward';

  // ===========================================================================
  // SPAWN EGGS
  // ===========================================================================

  static const String allaySpawnEgg = 'minecraft:allay_spawn_egg';
  static const String armadilloSpawnEgg = 'minecraft:armadillo_spawn_egg';
  static const String axolotlSpawnEgg = 'minecraft:axolotl_spawn_egg';
  static const String batSpawnEgg = 'minecraft:bat_spawn_egg';
  static const String beeSpawnEgg = 'minecraft:bee_spawn_egg';
  static const String blazeSpawnEgg = 'minecraft:blaze_spawn_egg';
  static const String boggedSpawnEgg = 'minecraft:bogged_spawn_egg';
  static const String breezeSpawnEgg = 'minecraft:breeze_spawn_egg';
  static const String camelSpawnEgg = 'minecraft:camel_spawn_egg';
  static const String catSpawnEgg = 'minecraft:cat_spawn_egg';
  static const String caveSpiderSpawnEgg = 'minecraft:cave_spider_spawn_egg';
  static const String chickenSpawnEgg = 'minecraft:chicken_spawn_egg';
  static const String codSpawnEgg = 'minecraft:cod_spawn_egg';
  static const String cowSpawnEgg = 'minecraft:cow_spawn_egg';
  static const String creeperSpawnEgg = 'minecraft:creeper_spawn_egg';
  static const String dolphinSpawnEgg = 'minecraft:dolphin_spawn_egg';
  static const String donkeySpawnEgg = 'minecraft:donkey_spawn_egg';
  static const String drownedSpawnEgg = 'minecraft:drowned_spawn_egg';
  static const String elderGuardianSpawnEgg =
      'minecraft:elder_guardian_spawn_egg';
  static const String endermanSpawnEgg = 'minecraft:enderman_spawn_egg';
  static const String endermiteSpawnEgg = 'minecraft:endermite_spawn_egg';
  static const String evokerSpawnEgg = 'minecraft:evoker_spawn_egg';
  static const String foxSpawnEgg = 'minecraft:fox_spawn_egg';
  static const String frogSpawnEgg = 'minecraft:frog_spawn_egg';
  static const String ghastSpawnEgg = 'minecraft:ghast_spawn_egg';
  static const String glowSquidSpawnEgg = 'minecraft:glow_squid_spawn_egg';
  static const String goatSpawnEgg = 'minecraft:goat_spawn_egg';
  static const String guardianSpawnEgg = 'minecraft:guardian_spawn_egg';
  static const String hoglinSpawnEgg = 'minecraft:hoglin_spawn_egg';
  static const String horseSpawnEgg = 'minecraft:horse_spawn_egg';
  static const String huskSpawnEgg = 'minecraft:husk_spawn_egg';
  static const String ironGolemSpawnEgg = 'minecraft:iron_golem_spawn_egg';
  static const String llamaSpawnEgg = 'minecraft:llama_spawn_egg';
  static const String magmaCubeSpawnEgg = 'minecraft:magma_cube_spawn_egg';
  static const String mooshroomSpawnEgg = 'minecraft:mooshroom_spawn_egg';
  static const String muleSpawnEgg = 'minecraft:mule_spawn_egg';
  static const String ocelotSpawnEgg = 'minecraft:ocelot_spawn_egg';
  static const String pandaSpawnEgg = 'minecraft:panda_spawn_egg';
  static const String parrotSpawnEgg = 'minecraft:parrot_spawn_egg';
  static const String phantomSpawnEgg = 'minecraft:phantom_spawn_egg';
  static const String pigSpawnEgg = 'minecraft:pig_spawn_egg';
  static const String piglinSpawnEgg = 'minecraft:piglin_spawn_egg';
  static const String piglinBruteSpawnEgg = 'minecraft:piglin_brute_spawn_egg';
  static const String pillagerSpawnEgg = 'minecraft:pillager_spawn_egg';
  static const String polarBearSpawnEgg = 'minecraft:polar_bear_spawn_egg';
  static const String pufferfishSpawnEgg = 'minecraft:pufferfish_spawn_egg';
  static const String rabbitSpawnEgg = 'minecraft:rabbit_spawn_egg';
  static const String ravagerSpawnEgg = 'minecraft:ravager_spawn_egg';
  static const String salmonSpawnEgg = 'minecraft:salmon_spawn_egg';
  static const String sheepSpawnEgg = 'minecraft:sheep_spawn_egg';
  static const String shulkerSpawnEgg = 'minecraft:shulker_spawn_egg';
  static const String silverfishSpawnEgg = 'minecraft:silverfish_spawn_egg';
  static const String skeletonSpawnEgg = 'minecraft:skeleton_spawn_egg';
  static const String skeletonHorseSpawnEgg =
      'minecraft:skeleton_horse_spawn_egg';
  static const String slimeSpawnEgg = 'minecraft:slime_spawn_egg';
  static const String snifferSpawnEgg = 'minecraft:sniffer_spawn_egg';
  static const String snowGolemSpawnEgg = 'minecraft:snow_golem_spawn_egg';
  static const String spiderSpawnEgg = 'minecraft:spider_spawn_egg';
  static const String squidSpawnEgg = 'minecraft:squid_spawn_egg';
  static const String straySpawnEgg = 'minecraft:stray_spawn_egg';
  static const String striderSpawnEgg = 'minecraft:strider_spawn_egg';
  static const String tadpoleSpawnEgg = 'minecraft:tadpole_spawn_egg';
  static const String traderLlamaSpawnEgg = 'minecraft:trader_llama_spawn_egg';
  static const String tropicalFishSpawnEgg =
      'minecraft:tropical_fish_spawn_egg';
  static const String turtleSpawnEgg = 'minecraft:turtle_spawn_egg';
  static const String vexSpawnEgg = 'minecraft:vex_spawn_egg';
  static const String villagerSpawnEgg = 'minecraft:villager_spawn_egg';
  static const String vindicatorSpawnEgg = 'minecraft:vindicator_spawn_egg';
  static const String wanderingTraderSpawnEgg =
      'minecraft:wandering_trader_spawn_egg';
  static const String wardenSpawnEgg = 'minecraft:warden_spawn_egg';
  static const String witchSpawnEgg = 'minecraft:witch_spawn_egg';
  static const String witherSkeletonSpawnEgg =
      'minecraft:wither_skeleton_spawn_egg';
  static const String wolfSpawnEgg = 'minecraft:wolf_spawn_egg';
  static const String zoglinSpawnEgg = 'minecraft:zoglin_spawn_egg';
  static const String zombieSpawnEgg = 'minecraft:zombie_spawn_egg';
  static const String zombieHorseSpawnEgg = 'minecraft:zombie_horse_spawn_egg';
  static const String zombieVillagerSpawnEgg =
      'minecraft:zombie_villager_spawn_egg';
  static const String zombifiedPiglinSpawnEgg =
      'minecraft:zombified_piglin_spawn_egg';

  // ===========================================================================
  // MISCELLANEOUS BLOCKS
  // ===========================================================================

  static const String bedrock = 'minecraft:bedrock';
  static const String obsidian = 'minecraft:obsidian';
  static const String cryingObsidian = 'minecraft:crying_obsidian';
  static const String ice = 'minecraft:ice';
  static const String packedIce = 'minecraft:packed_ice';
  static const String blueIce = 'minecraft:blue_ice';
  static const String frostedIce = 'minecraft:frosted_ice';
  static const String snowBlock = 'minecraft:snow_block';
  static const String snow = 'minecraft:snow';
  static const String snowball = 'minecraft:snowball';
  static const String powderSnow = 'minecraft:powder_snow';
  static const String sponge = 'minecraft:sponge';
  static const String wetSponge = 'minecraft:wet_sponge';
  static const String boneBlock = 'minecraft:bone_block';
  static const String egg = 'minecraft:egg';
  static const String turtleEgg = 'minecraft:turtle_egg';
  static const String frogspawn = 'minecraft:frogspawn';
  static const String snifferEgg = 'minecraft:sniffer_egg';
  static const String infectedStone = 'minecraft:infested_stone';
  static const String infectedCobblestone = 'minecraft:infested_cobblestone';
  static const String infectedStoneBricks = 'minecraft:infested_stone_bricks';
  static const String infectedMossyStoneBricks =
      'minecraft:infested_mossy_stone_bricks';
  static const String infectedCrackedStoneBricks =
      'minecraft:infested_cracked_stone_bricks';
  static const String infectedChiseledStoneBricks =
      'minecraft:infested_chiseled_stone_bricks';
  static const String infectedDeepslate = 'minecraft:infested_deepslate';
  static const String spawner = 'minecraft:spawner';
  static const String trialSpawner = 'minecraft:trial_spawner';
  static const String vault = 'minecraft:vault';

  // ===========================================================================
  // SLABS - Stone
  // ===========================================================================

  static const String stoneSlab = 'minecraft:stone_slab';
  static const String smoothStoneSlab = 'minecraft:smooth_stone_slab';
  static const String cobblestoneSlab = 'minecraft:cobblestone_slab';
  static const String mossyCobblestoneSlab = 'minecraft:mossy_cobblestone_slab';
  static const String stoneBrickSlab = 'minecraft:stone_brick_slab';
  static const String mossyStoneBrickSlab = 'minecraft:mossy_stone_brick_slab';
  static const String graniteSlab = 'minecraft:granite_slab';
  static const String polishedGraniteSlab = 'minecraft:polished_granite_slab';
  static const String dioriteSlab = 'minecraft:diorite_slab';
  static const String polishedDioriteSlab = 'minecraft:polished_diorite_slab';
  static const String andesiteSlab = 'minecraft:andesite_slab';
  static const String polishedAndesiteSlab = 'minecraft:polished_andesite_slab';
  static const String cobbledDeepslateSlab = 'minecraft:cobbled_deepslate_slab';
  static const String polishedDeepslateSlab =
      'minecraft:polished_deepslate_slab';
  static const String deepslateBrickSlab = 'minecraft:deepslate_brick_slab';
  static const String deepslateTileSlab = 'minecraft:deepslate_tile_slab';
  static const String brickSlab = 'minecraft:brick_slab';
  static const String sandstoneSlab = 'minecraft:sandstone_slab';
  static const String smoothSandstoneSlab = 'minecraft:smooth_sandstone_slab';
  static const String cutSandstoneSlab = 'minecraft:cut_sandstone_slab';
  static const String redSandstoneSlab = 'minecraft:red_sandstone_slab';
  static const String smoothRedSandstoneSlab =
      'minecraft:smooth_red_sandstone_slab';
  static const String cutRedSandstoneSlab = 'minecraft:cut_red_sandstone_slab';
  static const String prismarineSlab = 'minecraft:prismarine_slab';
  static const String prismarineBrickSlab = 'minecraft:prismarine_brick_slab';
  static const String darkPrismarineSlab = 'minecraft:dark_prismarine_slab';
  static const String netherBrickSlab = 'minecraft:nether_brick_slab';
  static const String redNetherBrickSlab = 'minecraft:red_nether_brick_slab';
  static const String blackstoneSlab = 'minecraft:blackstone_slab';
  static const String polishedBlackstoneSlab =
      'minecraft:polished_blackstone_slab';
  static const String polishedBlackstoneBrickSlab =
      'minecraft:polished_blackstone_brick_slab';
  static const String endStoneBrickSlab = 'minecraft:end_stone_brick_slab';
  static const String purpurSlab = 'minecraft:purpur_slab';
  static const String quartzSlab = 'minecraft:quartz_slab';
  static const String smoothQuartzSlab = 'minecraft:smooth_quartz_slab';
  static const String cutCopperSlab = 'minecraft:cut_copper_slab';
  static const String exposedCutCopperSlab = 'minecraft:exposed_cut_copper_slab';
  static const String weatheredCutCopperSlab =
      'minecraft:weathered_cut_copper_slab';
  static const String oxidizedCutCopperSlab =
      'minecraft:oxidized_cut_copper_slab';
  static const String waxedCutCopperSlab = 'minecraft:waxed_cut_copper_slab';
  static const String waxedExposedCutCopperSlab =
      'minecraft:waxed_exposed_cut_copper_slab';
  static const String waxedWeatheredCutCopperSlab =
      'minecraft:waxed_weathered_cut_copper_slab';
  static const String waxedOxidizedCutCopperSlab =
      'minecraft:waxed_oxidized_cut_copper_slab';
  static const String mudBrickSlab = 'minecraft:mud_brick_slab';
  static const String tuffSlab = 'minecraft:tuff_slab';
  static const String polishedTuffSlab = 'minecraft:polished_tuff_slab';
  static const String tuffBrickSlab = 'minecraft:tuff_brick_slab';

  // ===========================================================================
  // STAIRS - Stone
  // ===========================================================================

  static const String stoneStairs = 'minecraft:stone_stairs';
  static const String cobblestoneStairs = 'minecraft:cobblestone_stairs';
  static const String mossyCobblestoneStairs =
      'minecraft:mossy_cobblestone_stairs';
  static const String stoneBrickStairs = 'minecraft:stone_brick_stairs';
  static const String mossyStoneBrickStairs =
      'minecraft:mossy_stone_brick_stairs';
  static const String graniteStairs = 'minecraft:granite_stairs';
  static const String polishedGraniteStairs =
      'minecraft:polished_granite_stairs';
  static const String dioriteStairs = 'minecraft:diorite_stairs';
  static const String polishedDioriteStairs =
      'minecraft:polished_diorite_stairs';
  static const String andesiteStairs = 'minecraft:andesite_stairs';
  static const String polishedAndesiteStairs =
      'minecraft:polished_andesite_stairs';
  static const String cobbledDeepslateStairs =
      'minecraft:cobbled_deepslate_stairs';
  static const String polishedDeepslateStairs =
      'minecraft:polished_deepslate_stairs';
  static const String deepslateBrickStairs = 'minecraft:deepslate_brick_stairs';
  static const String deepslateTileStairs = 'minecraft:deepslate_tile_stairs';
  static const String brickStairs = 'minecraft:brick_stairs';
  static const String sandstoneStairs = 'minecraft:sandstone_stairs';
  static const String smoothSandstoneStairs =
      'minecraft:smooth_sandstone_stairs';
  static const String redSandstoneStairs = 'minecraft:red_sandstone_stairs';
  static const String smoothRedSandstoneStairs =
      'minecraft:smooth_red_sandstone_stairs';
  static const String prismarineStairs = 'minecraft:prismarine_stairs';
  static const String prismarineBrickStairs =
      'minecraft:prismarine_brick_stairs';
  static const String darkPrismarineStairs = 'minecraft:dark_prismarine_stairs';
  static const String netherBrickStairs = 'minecraft:nether_brick_stairs';
  static const String redNetherBrickStairs = 'minecraft:red_nether_brick_stairs';
  static const String blackstoneStairs = 'minecraft:blackstone_stairs';
  static const String polishedBlackstoneStairs =
      'minecraft:polished_blackstone_stairs';
  static const String polishedBlackstoneBrickStairs =
      'minecraft:polished_blackstone_brick_stairs';
  static const String endStoneBrickStairs = 'minecraft:end_stone_brick_stairs';
  static const String purpurStairs = 'minecraft:purpur_stairs';
  static const String quartzStairs = 'minecraft:quartz_stairs';
  static const String smoothQuartzStairs = 'minecraft:smooth_quartz_stairs';
  static const String cutCopperStairs = 'minecraft:cut_copper_stairs';
  static const String exposedCutCopperStairs =
      'minecraft:exposed_cut_copper_stairs';
  static const String weatheredCutCopperStairs =
      'minecraft:weathered_cut_copper_stairs';
  static const String oxidizedCutCopperStairs =
      'minecraft:oxidized_cut_copper_stairs';
  static const String waxedCutCopperStairs = 'minecraft:waxed_cut_copper_stairs';
  static const String waxedExposedCutCopperStairs =
      'minecraft:waxed_exposed_cut_copper_stairs';
  static const String waxedWeatheredCutCopperStairs =
      'minecraft:waxed_weathered_cut_copper_stairs';
  static const String waxedOxidizedCutCopperStairs =
      'minecraft:waxed_oxidized_cut_copper_stairs';
  static const String mudBrickStairs = 'minecraft:mud_brick_stairs';
  static const String tuffStairs = 'minecraft:tuff_stairs';
  static const String polishedTuffStairs = 'minecraft:polished_tuff_stairs';
  static const String tuffBrickStairs = 'minecraft:tuff_brick_stairs';

  // ===========================================================================
  // WALLS
  // ===========================================================================

  static const String cobblestoneWall = 'minecraft:cobblestone_wall';
  static const String mossyCobblestoneWall = 'minecraft:mossy_cobblestone_wall';
  static const String stoneBrickWall = 'minecraft:stone_brick_wall';
  static const String mossyStoneBrickWall = 'minecraft:mossy_stone_brick_wall';
  static const String graniteWall = 'minecraft:granite_wall';
  static const String dioriteWall = 'minecraft:diorite_wall';
  static const String andesiteWall = 'minecraft:andesite_wall';
  static const String cobbledDeepslateWall = 'minecraft:cobbled_deepslate_wall';
  static const String polishedDeepslateWall =
      'minecraft:polished_deepslate_wall';
  static const String deepslateBrickWall = 'minecraft:deepslate_brick_wall';
  static const String deepslateTileWall = 'minecraft:deepslate_tile_wall';
  static const String brickWall = 'minecraft:brick_wall';
  static const String sandstoneWall = 'minecraft:sandstone_wall';
  static const String redSandstoneWall = 'minecraft:red_sandstone_wall';
  static const String prismarineWall = 'minecraft:prismarine_wall';
  static const String netherBrickWall = 'minecraft:nether_brick_wall';
  static const String redNetherBrickWall = 'minecraft:red_nether_brick_wall';
  static const String blackstoneWall = 'minecraft:blackstone_wall';
  static const String polishedBlackstoneWall =
      'minecraft:polished_blackstone_wall';
  static const String polishedBlackstoneBrickWall =
      'minecraft:polished_blackstone_brick_wall';
  static const String endStoneBrickWall = 'minecraft:end_stone_brick_wall';
  static const String mudBrickWall = 'minecraft:mud_brick_wall';
  static const String tuffWall = 'minecraft:tuff_wall';
  static const String polishedTuffWall = 'minecraft:polished_tuff_wall';
  static const String tuffBrickWall = 'minecraft:tuff_brick_wall';

  // ===========================================================================
  // QUARTZ
  // ===========================================================================

  static const String quartzBlock = 'minecraft:quartz_block';
  static const String smoothQuartz = 'minecraft:smooth_quartz';
  static const String chiseledQuartzBlock = 'minecraft:chiseled_quartz_block';
  static const String quartzPillar = 'minecraft:quartz_pillar';
  static const String quartzBricks = 'minecraft:quartz_bricks';

  // ===========================================================================
  // IRON BARS AND CHAINS
  // ===========================================================================

  static const String ironBars = 'minecraft:iron_bars';

  // ===========================================================================
  // TRIAL CHAMBERS (1.21)
  // ===========================================================================

  static const String trialKey = 'minecraft:trial_key';
  static const String ominousTrialKey = 'minecraft:ominous_trial_key';
  static const String ominousBottle = 'minecraft:ominous_bottle';
  static const String windCharge = 'minecraft:wind_charge';

  // ===========================================================================
  // SADDLES AND HORSE ARMOR
  // ===========================================================================

  static const String saddle = 'minecraft:saddle';
  static const String leatherHorseArmor = 'minecraft:leather_horse_armor';
  static const String ironHorseArmor = 'minecraft:iron_horse_armor';
  static const String goldenHorseArmor = 'minecraft:golden_horse_armor';
  static const String diamondHorseArmor = 'minecraft:diamond_horse_armor';

  // ===========================================================================
  // MISCELLANEOUS ITEMS
  // ===========================================================================

  static const String totemOfUndying = 'minecraft:totem_of_undying';
  static const String goatHorn = 'minecraft:goat_horn';
  static const String debugStick = 'minecraft:debug_stick';
  static const String commandBlock = 'minecraft:command_block';
  static const String chainCommandBlock = 'minecraft:chain_command_block';
  static const String repeatingCommandBlock =
      'minecraft:repeating_command_block';
  static const String structureBlock = 'minecraft:structure_block';
  static const String structureVoid = 'minecraft:structure_void';
  static const String jigsaw = 'minecraft:jigsaw';
  static const String barrier = 'minecraft:barrier';
  static const String light = 'minecraft:light';

  // ===========================================================================
  // PORTAL BLOCKS
  // ===========================================================================

  static const String endPortalFrame = 'minecraft:end_portal_frame';

  // ===========================================================================
  // AMETHYST
  // ===========================================================================

  static const String smallAmethystBud = 'minecraft:small_amethyst_bud';
  static const String mediumAmethystBud = 'minecraft:medium_amethyst_bud';
  static const String largeAmethystBud = 'minecraft:large_amethyst_bud';
  static const String amethystCluster = 'minecraft:amethyst_cluster';

  // ===========================================================================
  // BANNER PATTERNS
  // ===========================================================================

  static const String flowerBannerPattern = 'minecraft:flower_banner_pattern';
  static const String creeperBannerPattern = 'minecraft:creeper_banner_pattern';
  static const String skullBannerPattern = 'minecraft:skull_banner_pattern';
  static const String mojangBannerPattern = 'minecraft:mojang_banner_pattern';
  static const String globeBannerPattern = 'minecraft:globe_banner_pattern';
  static const String piglinBannerPattern = 'minecraft:piglin_banner_pattern';
  static const String flowBannerPattern = 'minecraft:flow_banner_pattern';
  static const String gustBannerPattern = 'minecraft:gust_banner_pattern';

  // ===========================================================================
  // GOAT HORNS (VARIANTS)
  // ===========================================================================

  // Note: Goat horns use NBT data for variants, the base item is 'goat_horn'
  // The variants are: ponder, sing, seek, feel, admire, call, yearn, dream

  // ===========================================================================
  // PAINTING VARIANTS (1.21)
  // ===========================================================================

  // Note: Paintings use NBT data for variants, the base item is 'painting'

  // ===========================================================================
  // COMMAND BLOCKS
  // ===========================================================================

  static const String commandBlockMinecartItem =
      'minecraft:command_block_minecart';

  // ===========================================================================
  // FROGLIGHT VARIANTS
  // ===========================================================================

  static const String ochresFroglight = 'minecraft:ochre_froglight';
  static const String verdantFroglight = 'minecraft:verdant_froglight';
  static const String pearlescentFroglight = 'minecraft:pearlescent_froglight';

  // ===========================================================================
  // UTILITY BLOCKS
  // ===========================================================================

  static const String sporeBlossomItem = 'minecraft:spore_blossom';
  static const String decoratedPotItem = 'minecraft:decorated_pot';

  // ===========================================================================
  // Additional Pale Garden blocks (1.21.4)
  // ===========================================================================

  static const String paleMossBlock = 'minecraft:pale_moss_block';
  static const String paleMossCarpet = 'minecraft:pale_moss_carpet';
  static const String paleHangingMoss = 'minecraft:pale_hanging_moss';
  static const String creakingHeart = 'minecraft:creaking_heart';
  static const String resinClump = 'minecraft:resin_clump';
  static const String resinBlock = 'minecraft:resin_block';
  static const String resinBricks = 'minecraft:resin_bricks';
  static const String resinBrickStairs = 'minecraft:resin_brick_stairs';
  static const String resinBrickSlab = 'minecraft:resin_brick_slab';
  static const String resinBrickWall = 'minecraft:resin_brick_wall';
  static const String chiseledResinBricks = 'minecraft:chiseled_resin_bricks';
  static const String openEyeblossom = 'minecraft:open_eyeblossom';
  static const String closedEyeblossom = 'minecraft:closed_eyeblossom';
  static const String creakingSpawnEgg = 'minecraft:creaking_spawn_egg';
}
