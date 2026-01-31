/// Tests for advanced item types: Tools, Armor, and Food.
///
/// Tests for CustomTool, ToolMaterial, ToolType, CustomArmor, ArmorMaterial,
/// ArmorType, FoodSettings, StatusEffectInstance, and CustomFood.
import 'package:dart_mod_server/dart_mod_server.dart';
import 'package:test/test.dart';

// =============================================================================
// Test Implementations
// =============================================================================

/// Test sword implementation
class TestSword extends CustomSword {
  TestSword({
    required super.id,
    required super.material,
  }) : super(
          model: ItemModel.generated(texture: 'textures/item/test_sword.png'),
        );
}

/// Test pickaxe implementation
class TestPickaxe extends CustomPickaxe {
  TestPickaxe({
    required super.id,
    required super.material,
  }) : super(
          model: ItemModel.generated(texture: 'textures/item/test_pickaxe.png'),
        );
}

/// Test axe implementation
class TestAxe extends CustomAxe {
  TestAxe({
    required super.id,
    required super.material,
  }) : super(
          model: ItemModel.generated(texture: 'textures/item/test_axe.png'),
        );
}

/// Test shovel implementation
class TestShovel extends CustomShovel {
  TestShovel({
    required super.id,
    required super.material,
  }) : super(
          model: ItemModel.generated(texture: 'textures/item/test_shovel.png'),
        );
}

/// Test hoe implementation
class TestHoe extends CustomHoe {
  TestHoe({
    required super.id,
    required super.material,
  }) : super(
          model: ItemModel.generated(texture: 'textures/item/test_hoe.png'),
        );
}

/// Test helmet implementation
class TestHelmet extends CustomHelmet {
  TestHelmet({
    required super.id,
    required super.material,
  }) : super(
          model: ItemModel.generated(texture: 'textures/item/test_helmet.png'),
        );
}

/// Test chestplate implementation
class TestChestplate extends CustomChestplate {
  TestChestplate({
    required super.id,
    required super.material,
  }) : super(
          model: ItemModel.generated(
              texture: 'textures/item/test_chestplate.png'),
        );
}

/// Test leggings implementation
class TestLeggings extends CustomLeggings {
  TestLeggings({
    required super.id,
    required super.material,
  }) : super(
          model: ItemModel.generated(texture: 'textures/item/test_leggings.png'),
        );
}

/// Test boots implementation
class TestBoots extends CustomBoots {
  TestBoots({
    required super.id,
    required super.material,
  }) : super(
          model: ItemModel.generated(texture: 'textures/item/test_boots.png'),
        );
}

/// Test armor that tracks ticks
class TickingHelmet extends CustomHelmet {
  final List<String> ticks = [];

  TickingHelmet()
      : super(
          id: 'test:ticking_helmet',
          material: ArmorMaterial.iron,
          model: ItemModel.generated(texture: 'textures/item/ticking_helmet.png'),
        );

  @override
  void onArmorTick(int worldId, int playerId) {
    ticks.add('tick:$worldId:$playerId');
  }
}

/// Test food implementation
class TestFood extends CustomFood {
  TestFood({
    required String id,
    required super.food,
    super.finishItem,
    super.maxStackSize,
  }) : super(
          id: id,
          model: ItemModel.generated(texture: 'textures/item/test_food.png'),
        );
}

/// Test food that tracks eating
class TrackingFood extends CustomFood {
  final List<String> eatCalls = [];

  TrackingFood()
      : super(
          id: 'test:tracking_food',
          food: FoodSettings.apple,
          model: ItemModel.generated(texture: 'textures/item/tracking_food.png'),
        );

  @override
  void onEat(int worldId, int playerId) {
    eatCalls.add('eat:$worldId:$playerId');
  }
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ===========================================================================
  // ToolMaterial Tests
  // ===========================================================================
  group('ToolMaterial', () {
    test('wood material has correct values', () {
      expect(ToolMaterial.wood.durability, equals(59));
      expect(ToolMaterial.wood.miningSpeed, equals(2.0));
      expect(ToolMaterial.wood.attackDamageBonus, equals(0.0));
      expect(ToolMaterial.wood.enchantability, equals(15));
      expect(ToolMaterial.wood.repairItem, equals('minecraft:oak_planks'));
    });

    test('stone material has correct values', () {
      expect(ToolMaterial.stone.durability, equals(131));
      expect(ToolMaterial.stone.miningSpeed, equals(4.0));
      expect(ToolMaterial.stone.attackDamageBonus, equals(1.0));
      expect(ToolMaterial.stone.enchantability, equals(5));
    });

    test('copper material has correct values', () {
      expect(ToolMaterial.copper.durability, equals(190));
      expect(ToolMaterial.copper.miningSpeed, equals(5.0));
      expect(ToolMaterial.copper.attackDamageBonus, equals(1.0));
      expect(ToolMaterial.copper.enchantability, equals(13));
    });

    test('iron material has correct values', () {
      expect(ToolMaterial.iron.durability, equals(250));
      expect(ToolMaterial.iron.miningSpeed, equals(6.0));
      expect(ToolMaterial.iron.attackDamageBonus, equals(2.0));
      expect(ToolMaterial.iron.enchantability, equals(14));
    });

    test('diamond material has correct values', () {
      expect(ToolMaterial.diamond.durability, equals(1561));
      expect(ToolMaterial.diamond.miningSpeed, equals(8.0));
      expect(ToolMaterial.diamond.attackDamageBonus, equals(3.0));
      expect(ToolMaterial.diamond.enchantability, equals(10));
    });

    test('gold material has correct values', () {
      expect(ToolMaterial.gold.durability, equals(32));
      expect(ToolMaterial.gold.miningSpeed, equals(12.0));
      expect(ToolMaterial.gold.attackDamageBonus, equals(0.0));
      expect(ToolMaterial.gold.enchantability, equals(22));
    });

    test('netherite material has correct values', () {
      expect(ToolMaterial.netherite.durability, equals(2031));
      expect(ToolMaterial.netherite.miningSpeed, equals(9.0));
      expect(ToolMaterial.netherite.attackDamageBonus, equals(4.0));
      expect(ToolMaterial.netherite.enchantability, equals(15));
    });

    test('all built-in materials are defined', () {
      expect(ToolMaterial.wood, isNotNull);
      expect(ToolMaterial.stone, isNotNull);
      expect(ToolMaterial.copper, isNotNull);
      expect(ToolMaterial.iron, isNotNull);
      expect(ToolMaterial.diamond, isNotNull);
      expect(ToolMaterial.gold, isNotNull);
      expect(ToolMaterial.netherite, isNotNull);
    });

    test('can create custom material', () {
      const custom = ToolMaterial(
        durability: 500,
        miningSpeed: 10.0,
        attackDamageBonus: 5.0,
        enchantability: 20,
        repairItem: 'mymod:ruby',
      );
      expect(custom.durability, equals(500));
      expect(custom.miningSpeed, equals(10.0));
      expect(custom.attackDamageBonus, equals(5.0));
      expect(custom.enchantability, equals(20));
      expect(custom.repairItem, equals('mymod:ruby'));
    });

    test('custom material can omit repair item', () {
      const custom = ToolMaterial(
        durability: 100,
        miningSpeed: 5.0,
        attackDamageBonus: 2.0,
        enchantability: 10,
      );
      expect(custom.repairItem, isNull);
    });
  });

  // ===========================================================================
  // ToolType Tests
  // ===========================================================================
  group('ToolType', () {
    test('all tool types are defined', () {
      expect(
        ToolType.values,
        containsAll([
          ToolType.pickaxe,
          ToolType.axe,
          ToolType.shovel,
          ToolType.hoe,
          ToolType.sword,
        ]),
      );
    });

    test('has exactly 5 tool types', () {
      expect(ToolType.values, hasLength(5));
    });
  });

  // ===========================================================================
  // CustomTool Tests
  // ===========================================================================
  group('CustomTool', () {
    test('sword has maxStackSize 1', () {
      final sword = TestSword(id: 'test:sword', material: ToolMaterial.iron);
      expect(sword.settings.maxStackSize, equals(1));
    });

    test('all tools have maxStackSize 1', () {
      final sword = TestSword(id: 'test:sword', material: ToolMaterial.iron);
      final pickaxe =
          TestPickaxe(id: 'test:pickaxe', material: ToolMaterial.iron);
      final axe = TestAxe(id: 'test:axe', material: ToolMaterial.iron);
      final shovel = TestShovel(id: 'test:shovel', material: ToolMaterial.iron);
      final hoe = TestHoe(id: 'test:hoe', material: ToolMaterial.iron);

      expect(sword.settings.maxStackSize, equals(1));
      expect(pickaxe.settings.maxStackSize, equals(1));
      expect(axe.settings.maxStackSize, equals(1));
      expect(shovel.settings.maxStackSize, equals(1));
      expect(hoe.settings.maxStackSize, equals(1));
    });

    test('tool durability matches material durability', () {
      final ironSword =
          TestSword(id: 'test:iron_sword', material: ToolMaterial.iron);
      expect(ironSword.settings.maxDamage, equals(ToolMaterial.iron.durability));
      expect(ironSword.settings.maxDamage, equals(250));

      final diamondPickaxe =
          TestPickaxe(id: 'test:diamond_pickaxe', material: ToolMaterial.diamond);
      expect(
        diamondPickaxe.settings.maxDamage,
        equals(ToolMaterial.diamond.durability),
      );
      expect(diamondPickaxe.settings.maxDamage, equals(1561));
    });

    test('sword combat attributes are calculated correctly', () {
      // Diamond sword: base 3.0 + 3.0 bonus = 6.0 damage, speed -2.4
      final diamondSword =
          TestSword(id: 'test:diamond_sword', material: ToolMaterial.diamond);
      expect(diamondSword.combat, isNotNull);
      expect(diamondSword.combat!.attackDamage, equals(6.0));
      expect(diamondSword.combat!.attackSpeed, equals(-2.4));
      expect(diamondSword.combat!.attackKnockback, equals(0.0));
    });

    test('iron sword combat attributes', () {
      // Iron sword: base 3.0 + 2.0 bonus = 5.0 damage
      final ironSword =
          TestSword(id: 'test:iron_sword', material: ToolMaterial.iron);
      expect(ironSword.combat!.attackDamage, equals(5.0));
    });

    test('axe combat attributes are calculated correctly', () {
      // Diamond axe: base 5.0 + 3.0 bonus = 8.0 damage, speed -3.0
      final diamondAxe =
          TestAxe(id: 'test:diamond_axe', material: ToolMaterial.diamond);
      expect(diamondAxe.combat, isNotNull);
      expect(diamondAxe.combat!.attackDamage, equals(8.0));
      expect(diamondAxe.combat!.attackSpeed, equals(-3.0));
      expect(diamondAxe.combat!.attackKnockback, equals(0.0));
    });

    test('axe damage varies by material', () {
      // Wood axe: base 6.0 + 0.0 bonus = 6.0 damage, speed -3.2
      final woodAxe = TestAxe(id: 'test:wood_axe', material: ToolMaterial.wood);
      expect(woodAxe.combat!.attackDamage, equals(6.0));
      expect(woodAxe.combat!.attackSpeed, equals(-3.2));

      // Stone axe: base 7.0 + 1.0 bonus = 8.0 damage, speed -3.2
      final stoneAxe =
          TestAxe(id: 'test:stone_axe', material: ToolMaterial.stone);
      expect(stoneAxe.combat!.attackDamage, equals(8.0));
      expect(stoneAxe.combat!.attackSpeed, equals(-3.2));

      // Iron axe: base 6.0 + 2.0 bonus = 8.0 damage, speed -3.1
      final ironAxe = TestAxe(id: 'test:iron_axe', material: ToolMaterial.iron);
      expect(ironAxe.combat!.attackDamage, equals(8.0));
      expect(ironAxe.combat!.attackSpeed, equals(-3.1));

      // Gold axe: base 6.0 + 0.0 bonus = 6.0 damage, speed -3.0
      final goldAxe = TestAxe(id: 'test:gold_axe', material: ToolMaterial.gold);
      expect(goldAxe.combat!.attackDamage, equals(6.0));
      expect(goldAxe.combat!.attackSpeed, equals(-3.0));

      // Netherite axe: base 5.0 + 4.0 bonus = 9.0 damage, speed -3.0
      final netheriteAxe =
          TestAxe(id: 'test:netherite_axe', material: ToolMaterial.netherite);
      expect(netheriteAxe.combat!.attackDamage, equals(9.0));
      expect(netheriteAxe.combat!.attackSpeed, equals(-3.0));
    });

    test('pickaxe combat attributes are calculated correctly', () {
      // Diamond pickaxe: base 1.0 + 3.0 bonus = 4.0 damage, speed -2.8
      final diamondPickaxe =
          TestPickaxe(id: 'test:diamond_pickaxe', material: ToolMaterial.diamond);
      expect(diamondPickaxe.combat!.attackDamage, equals(4.0));
      expect(diamondPickaxe.combat!.attackSpeed, equals(-2.8));
    });

    test('shovel combat attributes are calculated correctly', () {
      // Diamond shovel: base 1.5 + 3.0 bonus = 4.5 damage, speed -3.0
      final diamondShovel =
          TestShovel(id: 'test:diamond_shovel', material: ToolMaterial.diamond);
      expect(diamondShovel.combat!.attackDamage, equals(4.5));
      expect(diamondShovel.combat!.attackSpeed, equals(-3.0));
    });

    test('hoe combat attributes have 0 damage and variable speed', () {
      // All hoes have 0.0 attack damage (MC uses negative base that cancels bonus)
      // Diamond hoe: 0.0 damage, speed 0.0
      final diamondHoe =
          TestHoe(id: 'test:diamond_hoe', material: ToolMaterial.diamond);
      expect(diamondHoe.combat!.attackDamage, equals(0.0));
      expect(diamondHoe.combat!.attackSpeed, equals(0.0));

      // Netherite hoe: 0.0 damage, speed 0.0
      final netheriteHoe =
          TestHoe(id: 'test:netherite_hoe', material: ToolMaterial.netherite);
      expect(netheriteHoe.combat!.attackDamage, equals(0.0));
      expect(netheriteHoe.combat!.attackSpeed, equals(0.0));

      // Iron hoe: 0.0 damage, speed -1.0
      final ironHoe = TestHoe(id: 'test:iron_hoe', material: ToolMaterial.iron);
      expect(ironHoe.combat!.attackDamage, equals(0.0));
      expect(ironHoe.combat!.attackSpeed, equals(-1.0));

      // Copper hoe: 0.0 damage, speed -2.0
      final copperHoe =
          TestHoe(id: 'test:copper_hoe', material: ToolMaterial.copper);
      expect(copperHoe.combat!.attackDamage, equals(0.0));
      expect(copperHoe.combat!.attackSpeed, equals(-2.0));

      // Stone hoe: 0.0 damage, speed -2.0
      final stoneHoe =
          TestHoe(id: 'test:stone_hoe', material: ToolMaterial.stone);
      expect(stoneHoe.combat!.attackDamage, equals(0.0));
      expect(stoneHoe.combat!.attackSpeed, equals(-2.0));

      // Wood hoe: 0.0 damage, speed -3.0
      final woodHoe = TestHoe(id: 'test:wood_hoe', material: ToolMaterial.wood);
      expect(woodHoe.combat!.attackDamage, equals(0.0));
      expect(woodHoe.combat!.attackSpeed, equals(-3.0));

      // Gold hoe: 0.0 damage, speed -3.0
      final goldHoe = TestHoe(id: 'test:gold_hoe', material: ToolMaterial.gold);
      expect(goldHoe.combat!.attackDamage, equals(0.0));
      expect(goldHoe.combat!.attackSpeed, equals(-3.0));
    });

    test('tool stores correct toolType', () {
      final sword = TestSword(id: 'test:sword', material: ToolMaterial.iron);
      final pickaxe =
          TestPickaxe(id: 'test:pickaxe', material: ToolMaterial.iron);
      final axe = TestAxe(id: 'test:axe', material: ToolMaterial.iron);
      final shovel = TestShovel(id: 'test:shovel', material: ToolMaterial.iron);
      final hoe = TestHoe(id: 'test:hoe', material: ToolMaterial.iron);

      expect(sword.toolType, equals(ToolType.sword));
      expect(pickaxe.toolType, equals(ToolType.pickaxe));
      expect(axe.toolType, equals(ToolType.axe));
      expect(shovel.toolType, equals(ToolType.shovel));
      expect(hoe.toolType, equals(ToolType.hoe));
    });

    test('tool stores correct material', () {
      final sword = TestSword(id: 'test:sword', material: ToolMaterial.diamond);
      expect(sword.material, same(ToolMaterial.diamond));
    });
  });

  // ===========================================================================
  // ArmorType Tests
  // ===========================================================================
  group('ArmorType', () {
    test('all armor types are defined', () {
      expect(ArmorType.values, contains(ArmorType.helmet));
      expect(ArmorType.values, contains(ArmorType.chestplate));
      expect(ArmorType.values, contains(ArmorType.leggings));
      expect(ArmorType.values, contains(ArmorType.boots));
      expect(ArmorType.values, contains(ArmorType.body));
    });

    test('armor types have correct durability multipliers', () {
      expect(ArmorType.helmet.durabilityMultiplier, equals(11));
      expect(ArmorType.chestplate.durabilityMultiplier, equals(16));
      expect(ArmorType.leggings.durabilityMultiplier, equals(15));
      expect(ArmorType.boots.durabilityMultiplier, equals(13));
      expect(ArmorType.body.durabilityMultiplier, equals(16));
    });

    test('armor types have correct names', () {
      expect(ArmorType.helmet.name, equals('helmet'));
      expect(ArmorType.chestplate.name, equals('chestplate'));
      expect(ArmorType.leggings.name, equals('leggings'));
      expect(ArmorType.boots.name, equals('boots'));
      expect(ArmorType.body.name, equals('body'));
    });

    test('getDurability calculates correctly', () {
      // Iron has durability 15
      expect(ArmorType.helmet.getDurability(15), equals(15 * 11)); // 165
      expect(ArmorType.chestplate.getDurability(15), equals(15 * 16)); // 240
      expect(ArmorType.leggings.getDurability(15), equals(15 * 15)); // 225
      expect(ArmorType.boots.getDurability(15), equals(15 * 13)); // 195

      // Diamond has durability 33
      expect(ArmorType.helmet.getDurability(33), equals(33 * 11)); // 363
      expect(ArmorType.chestplate.getDurability(33), equals(33 * 16)); // 528
    });
  });

  // ===========================================================================
  // ArmorMaterial Tests
  // ===========================================================================
  group('ArmorMaterial', () {
    test('iron armor has correct protection values', () {
      expect(ArmorMaterial.iron.getProtection(ArmorType.helmet), equals(2));
      expect(ArmorMaterial.iron.getProtection(ArmorType.chestplate), equals(6));
      expect(ArmorMaterial.iron.getProtection(ArmorType.leggings), equals(5));
      expect(ArmorMaterial.iron.getProtection(ArmorType.boots), equals(2));
    });

    test('diamond armor has correct protection values', () {
      expect(ArmorMaterial.diamond.getProtection(ArmorType.helmet), equals(3));
      expect(
          ArmorMaterial.diamond.getProtection(ArmorType.chestplate), equals(8));
      expect(
          ArmorMaterial.diamond.getProtection(ArmorType.leggings), equals(6));
      expect(ArmorMaterial.diamond.getProtection(ArmorType.boots), equals(3));
    });

    test('netherite has knockback resistance', () {
      expect(ArmorMaterial.netherite.knockbackResistance, equals(0.1));
    });

    test('most materials have no knockback resistance', () {
      expect(ArmorMaterial.iron.knockbackResistance, equals(0.0));
      expect(ArmorMaterial.diamond.knockbackResistance, equals(0.0));
      expect(ArmorMaterial.leather.knockbackResistance, equals(0.0));
    });

    test('diamond has toughness', () {
      expect(ArmorMaterial.diamond.toughness, equals(2.0));
    });

    test('netherite has higher toughness than diamond', () {
      expect(ArmorMaterial.netherite.toughness, equals(3.0));
      expect(ArmorMaterial.netherite.toughness,
          greaterThan(ArmorMaterial.diamond.toughness));
    });

    test('most materials have no toughness', () {
      expect(ArmorMaterial.iron.toughness, equals(0.0));
      expect(ArmorMaterial.leather.toughness, equals(0.0));
      expect(ArmorMaterial.chainmail.toughness, equals(0.0));
    });

    test('getDurability calculates correctly for iron', () {
      // Iron durability is 15
      expect(ArmorMaterial.iron.getDurability(ArmorType.helmet),
          equals(15 * 11)); // 165
      expect(ArmorMaterial.iron.getDurability(ArmorType.chestplate),
          equals(15 * 16)); // 240
      expect(ArmorMaterial.iron.getDurability(ArmorType.leggings),
          equals(15 * 15)); // 225
      expect(ArmorMaterial.iron.getDurability(ArmorType.boots),
          equals(15 * 13)); // 195
    });

    test('getDurability calculates correctly for diamond', () {
      // Diamond durability is 33
      expect(ArmorMaterial.diamond.getDurability(ArmorType.helmet),
          equals(33 * 11));
      expect(ArmorMaterial.diamond.getDurability(ArmorType.chestplate),
          equals(33 * 16));
      expect(ArmorMaterial.diamond.getDurability(ArmorType.leggings),
          equals(33 * 15));
      expect(ArmorMaterial.diamond.getDurability(ArmorType.boots),
          equals(33 * 13));
    });

    test('all built-in materials are defined', () {
      expect(ArmorMaterial.leather, isNotNull);
      expect(ArmorMaterial.chainmail, isNotNull);
      expect(ArmorMaterial.iron, isNotNull);
      expect(ArmorMaterial.gold, isNotNull);
      expect(ArmorMaterial.diamond, isNotNull);
      expect(ArmorMaterial.netherite, isNotNull);
      expect(ArmorMaterial.turtleScute, isNotNull);
      expect(ArmorMaterial.copper, isNotNull);
      expect(ArmorMaterial.armadilloScute, isNotNull);
    });

    test('armadilloScute material has correct values', () {
      expect(ArmorMaterial.armadilloScute.durability, equals(4));
      expect(ArmorMaterial.armadilloScute.enchantability, equals(10));
      expect(ArmorMaterial.armadilloScute.toughness, equals(0.0));
      expect(ArmorMaterial.armadilloScute.knockbackResistance, equals(0.0));
      expect(ArmorMaterial.armadilloScute.repairItem,
          equals('minecraft:armadillo_scute'));
      // Protection values: boots=3, leggings=6, chestplate=8, helmet=3, body=11
      expect(ArmorMaterial.armadilloScute.getProtection(ArmorType.boots),
          equals(3));
      expect(ArmorMaterial.armadilloScute.getProtection(ArmorType.leggings),
          equals(6));
      expect(ArmorMaterial.armadilloScute.getProtection(ArmorType.chestplate),
          equals(8));
      expect(ArmorMaterial.armadilloScute.getProtection(ArmorType.helmet),
          equals(3));
      expect(ArmorMaterial.armadilloScute.getProtection(ArmorType.body),
          equals(11));
    });

    test('makeProtection helper creates correct map', () {
      final protection = ArmorMaterial.makeProtection(1, 2, 3, 4, 5);
      expect(protection[ArmorType.boots], equals(1));
      expect(protection[ArmorType.leggings], equals(2));
      expect(protection[ArmorType.chestplate], equals(3));
      expect(protection[ArmorType.helmet], equals(4));
      expect(protection[ArmorType.body], equals(5));
    });

    test('can create custom material', () {
      final custom = ArmorMaterial(
        durability: 20,
        protection: ArmorMaterial.makeProtection(2, 5, 6, 2),
        enchantability: 12,
        toughness: 1.0,
        knockbackResistance: 0.05,
        repairItem: 'mymod:custom_ingot',
      );
      expect(custom.durability, equals(20));
      expect(custom.enchantability, equals(12));
      expect(custom.toughness, equals(1.0));
      expect(custom.knockbackResistance, equals(0.05));
      expect(custom.repairItem, equals('mymod:custom_ingot'));
    });
  });

  // ===========================================================================
  // CustomArmor Tests
  // ===========================================================================
  group('CustomArmor', () {
    test('armor has maxStackSize 1', () {
      final helmet =
          TestHelmet(id: 'test:helmet', material: ArmorMaterial.iron);
      expect(helmet.settings.maxStackSize, equals(1));
    });

    test('all armor pieces have maxStackSize 1', () {
      final helmet =
          TestHelmet(id: 'test:helmet', material: ArmorMaterial.iron);
      final chestplate =
          TestChestplate(id: 'test:chestplate', material: ArmorMaterial.iron);
      final leggings =
          TestLeggings(id: 'test:leggings', material: ArmorMaterial.iron);
      final boots = TestBoots(id: 'test:boots', material: ArmorMaterial.iron);

      expect(helmet.settings.maxStackSize, equals(1));
      expect(chestplate.settings.maxStackSize, equals(1));
      expect(leggings.settings.maxStackSize, equals(1));
      expect(boots.settings.maxStackSize, equals(1));
    });

    test('armor durability is slot-specific', () {
      final helmet =
          TestHelmet(id: 'test:helmet', material: ArmorMaterial.iron);
      final chestplate =
          TestChestplate(id: 'test:chestplate', material: ArmorMaterial.iron);
      final leggings =
          TestLeggings(id: 'test:leggings', material: ArmorMaterial.iron);
      final boots = TestBoots(id: 'test:boots', material: ArmorMaterial.iron);

      // Iron durability is 15
      expect(helmet.settings.maxDamage, equals(15 * 11)); // 165
      expect(chestplate.settings.maxDamage, equals(15 * 16)); // 240
      expect(leggings.settings.maxDamage, equals(15 * 15)); // 225
      expect(boots.settings.maxDamage, equals(15 * 13)); // 195

      // All different
      expect(helmet.settings.maxDamage,
          isNot(equals(chestplate.settings.maxDamage)));
      expect(chestplate.settings.maxDamage,
          isNot(equals(leggings.settings.maxDamage)));
      expect(leggings.settings.maxDamage,
          isNot(equals(boots.settings.maxDamage)));
    });

    test('armor stores correct armorType', () {
      final helmet =
          TestHelmet(id: 'test:helmet', material: ArmorMaterial.iron);
      final chestplate =
          TestChestplate(id: 'test:chestplate', material: ArmorMaterial.iron);
      final leggings =
          TestLeggings(id: 'test:leggings', material: ArmorMaterial.iron);
      final boots = TestBoots(id: 'test:boots', material: ArmorMaterial.iron);

      expect(helmet.armorType, equals(ArmorType.helmet));
      expect(chestplate.armorType, equals(ArmorType.chestplate));
      expect(leggings.armorType, equals(ArmorType.leggings));
      expect(boots.armorType, equals(ArmorType.boots));
    });

    test('armor stores correct material', () {
      final helmet =
          TestHelmet(id: 'test:helmet', material: ArmorMaterial.diamond);
      expect(helmet.material, same(ArmorMaterial.diamond));
    });

    test('onArmorTick is callable', () {
      final helmet = TickingHelmet();

      // Should not throw
      helmet.onArmorTick(0, 123);
      helmet.onArmorTick(1, 456);

      expect(helmet.ticks, hasLength(2));
      expect(helmet.ticks[0], equals('tick:0:123'));
      expect(helmet.ticks[1], equals('tick:1:456'));
    });

    test('default onArmorTick does nothing', () {
      final helmet =
          TestHelmet(id: 'test:helmet', material: ArmorMaterial.iron);

      // Should not throw
      helmet.onArmorTick(0, 1);
    });
  });

  // ===========================================================================
  // StatusEffectInstance Tests
  // ===========================================================================
  group('StatusEffectInstance', () {
    test('factory constructors create correct effects', () {
      final regen = StatusEffectInstance.regeneration(duration: 100);
      expect(regen.effect, equals('minecraft:regeneration'));
      expect(regen.duration, equals(100));
      expect(regen.amplifier, equals(0));
    });

    test('speed effect factory', () {
      final speed = StatusEffectInstance.speed(duration: 200);
      expect(speed.effect, equals('minecraft:speed'));
      expect(speed.duration, equals(200));
      expect(speed.amplifier, equals(0));
    });

    test('poison effect factory', () {
      final poison = StatusEffectInstance.poison(duration: 60);
      expect(poison.effect, equals('minecraft:poison'));
      expect(poison.duration, equals(60));
    });

    test('hunger effect factory', () {
      final hunger = StatusEffectInstance.hunger(duration: 40);
      expect(hunger.effect, equals('minecraft:hunger'));
      expect(hunger.duration, equals(40));
    });

    test('nausea effect factory', () {
      final nausea = StatusEffectInstance.nausea(duration: 100);
      expect(nausea.effect, equals('minecraft:nausea'));
      expect(nausea.duration, equals(100));
    });

    test('absorption effect factory', () {
      final absorption = StatusEffectInstance.absorption(duration: 200);
      expect(absorption.effect, equals('minecraft:absorption'));
      expect(absorption.duration, equals(200));
    });

    test('resistance effect factory', () {
      final resistance = StatusEffectInstance.resistance(duration: 150);
      expect(resistance.effect, equals('minecraft:resistance'));
      expect(resistance.duration, equals(150));
    });

    test('fire resistance effect factory', () {
      final fireRes = StatusEffectInstance.fireResistance(duration: 300);
      expect(fireRes.effect, equals('minecraft:fire_resistance'));
      expect(fireRes.duration, equals(300));
    });

    test('can set custom amplifier', () {
      final speed = StatusEffectInstance.speed(duration: 200, amplifier: 2);
      expect(speed.amplifier, equals(2));
    });

    test('default amplifier is 0', () {
      final regen = StatusEffectInstance.regeneration(duration: 100);
      expect(regen.amplifier, equals(0));
    });

    test('default showParticles is true', () {
      final effect = StatusEffectInstance.speed(duration: 100);
      expect(effect.showParticles, isTrue);
    });

    test('default showIcon is true', () {
      final effect = StatusEffectInstance.speed(duration: 100);
      expect(effect.showIcon, isTrue);
    });

    test('can customize showParticles and showIcon', () {
      const effect = StatusEffectInstance(
        effect: 'minecraft:invisibility',
        duration: 100,
        showParticles: false,
        showIcon: false,
      );
      expect(effect.showParticles, isFalse);
      expect(effect.showIcon, isFalse);
    });

    test('toJson serializes correctly', () {
      final poison = StatusEffectInstance.poison(duration: 60, amplifier: 1);
      final json = poison.toJson();

      expect(json['effect'], equals('minecraft:poison'));
      expect(json['duration'], equals(60));
      expect(json['amplifier'], equals(1));
      expect(json['showParticles'], isTrue);
      expect(json['showIcon'], isTrue);
    });

    test('toJson includes all fields', () {
      const effect = StatusEffectInstance(
        effect: 'minecraft:speed',
        duration: 200,
        amplifier: 2,
        showParticles: false,
        showIcon: true,
      );
      final json = effect.toJson();

      expect(json.keys, containsAll([
        'effect',
        'duration',
        'amplifier',
        'showParticles',
        'showIcon',
      ]));
      expect(json['showParticles'], isFalse);
    });
  });

  // ===========================================================================
  // FoodSettings Tests
  // ===========================================================================
  group('FoodSettings', () {
    test('saturation is calculated correctly', () {
      // saturation = nutrition * saturationModifier * 2
      const food = FoodSettings(nutrition: 4, saturationModifier: 0.3);
      expect(food.saturation, equals(4 * 0.3 * 2)); // 2.4
    });

    test('steak saturation calculation', () {
      // Steak: 8 nutrition, 0.8 saturation modifier
      // saturation = 8 * 0.8 * 2 = 12.8
      expect(FoodSettings.steak.saturation, equals(12.8));
    });

    test('preset foods have correct nutrition values', () {
      expect(FoodSettings.apple.nutrition, equals(4));
      expect(FoodSettings.bread.nutrition, equals(5));
      expect(FoodSettings.steak.nutrition, equals(8));
      expect(FoodSettings.goldenApple.nutrition, equals(4));
    });

    test('preset foods have correct saturation modifiers', () {
      expect(FoodSettings.apple.saturationModifier, equals(0.3));
      expect(FoodSettings.bread.saturationModifier, equals(0.6));
      expect(FoodSettings.steak.saturationModifier, equals(0.8));
      expect(FoodSettings.goldenApple.saturationModifier, equals(1.2));
    });

    test('goldenApple is alwaysEdible', () {
      expect(FoodSettings.goldenApple.alwaysEdible, isTrue);
    });

    test('regular foods are not alwaysEdible', () {
      expect(FoodSettings.apple.alwaysEdible, isFalse);
      expect(FoodSettings.bread.alwaysEdible, isFalse);
      expect(FoodSettings.steak.alwaysEdible, isFalse);
    });

    test('default consumeSeconds is 1.6', () {
      const food = FoodSettings(nutrition: 1, saturationModifier: 0.1);
      expect(food.consumeSeconds, equals(1.6));
    });

    test('preset foods have default consumeSeconds', () {
      expect(FoodSettings.apple.consumeSeconds, equals(1.6));
      expect(FoodSettings.steak.consumeSeconds, equals(1.6));
    });

    test('can customize consumeSeconds', () {
      const food = FoodSettings(
        nutrition: 4,
        saturationModifier: 0.3,
        consumeSeconds: 0.8, // Fast food
      );
      expect(food.consumeSeconds, equals(0.8));
    });

    test('default effects list is empty', () {
      const food = FoodSettings(nutrition: 4, saturationModifier: 0.3);
      expect(food.effects, isEmpty);
    });

    test('can add status effects', () {
      final food = FoodSettings(
        nutrition: 4,
        saturationModifier: 0.3,
        effects: [
          StatusEffectInstance.regeneration(duration: 100),
          StatusEffectInstance.absorption(duration: 200, amplifier: 1),
        ],
      );
      expect(food.effects, hasLength(2));
      expect(food.effects[0].effect, equals('minecraft:regeneration'));
      expect(food.effects[1].effect, equals('minecraft:absorption'));
    });

    test('stew factory creates correct settings', () {
      final stew = FoodSettings.stew(6);
      expect(stew.nutrition, equals(6));
      expect(stew.saturationModifier, equals(0.6));
    });

    test('toJson serializes correctly', () {
      const food = FoodSettings(
        nutrition: 4,
        saturationModifier: 0.3,
        alwaysEdible: true,
        consumeSeconds: 2.0,
      );
      final json = food.toJson();

      expect(json['nutrition'], equals(4));
      expect(json['saturationModifier'], equals(0.3));
      expect(json['alwaysEdible'], isTrue);
      expect(json['consumeSeconds'], equals(2.0));
      expect(json['effects'], isEmpty);
    });

    test('toJson includes effects', () {
      final food = FoodSettings(
        nutrition: 4,
        saturationModifier: 1.2,
        effects: [
          StatusEffectInstance.regeneration(duration: 100),
        ],
      );
      final json = food.toJson();

      expect(json['effects'], hasLength(1));
      expect((json['effects'] as List)[0]['effect'],
          equals('minecraft:regeneration'));
    });
  });

  // ===========================================================================
  // CustomFood Tests
  // ===========================================================================
  group('CustomFood', () {
    test('food has correct default maxStackSize', () {
      final food = TestFood(
        id: 'test:food',
        food: FoodSettings.apple,
      );
      expect(food.settings.maxStackSize, equals(64));
    });

    test('can customize maxStackSize', () {
      final food = TestFood(
        id: 'test:food',
        food: FoodSettings.apple,
        maxStackSize: 16,
      );
      expect(food.settings.maxStackSize, equals(16));
    });

    test('food has no durability (maxDamage = 0)', () {
      final food = TestFood(
        id: 'test:food',
        food: FoodSettings.apple,
      );
      expect(food.settings.maxDamage, equals(0));
    });

    test('food stores food settings', () {
      final food = TestFood(
        id: 'test:food',
        food: FoodSettings.steak,
      );
      expect(food.food, same(FoodSettings.steak));
    });

    test('can set finishItem for stews', () {
      final stew = TestFood(
        id: 'test:stew',
        food: FoodSettings.stew(6),
        finishItem: 'minecraft:bowl',
        maxStackSize: 1,
      );
      expect(stew.finishItem, equals('minecraft:bowl'));
    });

    test('finishItem is null by default', () {
      final food = TestFood(
        id: 'test:food',
        food: FoodSettings.apple,
      );
      expect(food.finishItem, isNull);
    });

    test('onEat callback is callable', () {
      final food = TrackingFood();

      // Should not throw
      food.onEat(0, 123);
      food.onEat(1, 456);

      expect(food.eatCalls, hasLength(2));
      expect(food.eatCalls[0], equals('eat:0:123'));
      expect(food.eatCalls[1], equals('eat:1:456'));
    });

    test('default onEat does nothing', () {
      final food = TestFood(
        id: 'test:food',
        food: FoodSettings.apple,
      );

      // Should not throw
      food.onEat(0, 1);
    });
  });
}
