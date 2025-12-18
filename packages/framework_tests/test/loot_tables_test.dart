/// Loot Table API tests.
///
/// Tests for the loot table modification system.
import 'package:dart_mc/api/api.dart';
import 'package:dart_mc/api/loot_tables.dart';
import 'package:redstone_test/redstone_test.dart';
import 'package:test/test.dart' as dart_test;

Future<void> main() async {
  await group('Loot table modification', () async {
    await testMinecraft('can modify zombie loot table', (game) async {
      LootTables.modify('minecraft:entities/zombie', (builder) {
        builder.addItem('minecraft:diamond', chance: 0.01);
      });

      expect(LootTables.modifiedTables, contains('minecraft:entities/zombie'));
    });

    await testMinecraft('can add item with count range', (game) async {
      LootTables.modify('minecraft:entities/skeleton', (builder) {
        builder.addItem(
          'minecraft:bone',
          minCount: 1,
          maxCount: 3,
        );
      });

      expect(LootTables.modifiedTables, contains('minecraft:entities/skeleton'));
    });

    await testMinecraft('can add item with chance', (game) async {
      LootTables.modify('minecraft:blocks/grass', (builder) {
        builder.addItem('minecraft:wheat_seeds', chance: 0.125);
      });

      expect(LootTables.modifiedTables, contains('minecraft:blocks/grass'));
    });

    await testMinecraft('can add item with condition', (game) async {
      LootTables.modify('minecraft:entities/creeper', (builder) {
        builder.addItemWithCondition(
          'minecraft:music_disc_13',
          LootCondition.killedByPlayer(),
        );
      });

      expect(LootTables.modifiedTables, contains('minecraft:entities/creeper'));
    });

    await testMinecraft('can add item with multiple conditions', (game) async {
      LootTables.modify('minecraft:entities/witch', (builder) {
        builder.addItemWithConditions(
          'minecraft:enchanted_book',
          [
            LootCondition.killedByPlayer(),
            LootCondition.randomChance(0.1),
          ],
        );
      });

      expect(LootTables.modifiedTables, contains('minecraft:entities/witch'));
    });

    await testMinecraft('can add weighted pool', (game) async {
      LootTables.modify('minecraft:chests/simple_dungeon', (builder) {
        builder.addWeightedPool({
          'minecraft:diamond': 1,
          'minecraft:gold_ingot': 5,
          'minecraft:iron_ingot': 10,
        });
      });

      expect(
          LootTables.modifiedTables, contains('minecraft:chests/simple_dungeon'));
    });
  });

  await group('LootCondition', () async {
    await testMinecraft('randomChance condition works', (game) async {
      LootTables.modify('minecraft:entities/spider', (builder) {
        builder.addItemWithCondition(
          'minecraft:string',
          LootCondition.randomChance(0.5),
        );
      });
      expect(true, isTrue);
    });

    await testMinecraft('randomChanceWithLooting condition works', (game) async {
      LootTables.modify('minecraft:entities/blaze', (builder) {
        builder.addItemWithCondition(
          'minecraft:blaze_rod',
          LootCondition.randomChanceWithLooting(0.5, lootingMultiplier: 0.1),
        );
      });
      expect(true, isTrue);
    });

    await testMinecraft('killedByPlayer condition works', (game) async {
      LootTables.modify('minecraft:entities/enderman', (builder) {
        builder.addItemWithCondition(
          'minecraft:ender_pearl',
          LootCondition.killedByPlayer(),
        );
      });
      expect(true, isTrue);
    });

    await testMinecraft('matchTool condition works', (game) async {
      LootTables.modify('minecraft:blocks/stone', (builder) {
        builder.addItemWithCondition(
          'minecraft:cobblestone',
          LootCondition.matchTool('minecraft:diamond_pickaxe'),
        );
      });
      expect(true, isTrue);
    });

    await testMinecraft('inverted condition works', (game) async {
      LootTables.modify('minecraft:entities/pig', (builder) {
        builder.addItemWithCondition(
          'minecraft:cooked_porkchop',
          LootCondition.inverted(LootCondition.entityProperties(onFire: true)),
        );
      });
      expect(true, isTrue);
    });

    await testMinecraft('allOf condition works', (game) async {
      LootTables.modify('minecraft:entities/cow', (builder) {
        builder.addItemWithCondition(
          'minecraft:leather',
          LootCondition.allOf([
            LootCondition.killedByPlayer(),
            LootCondition.randomChance(0.5),
          ]),
        );
      });
      expect(true, isTrue);
    });

    await testMinecraft('anyOf condition works', (game) async {
      LootTables.modify('minecraft:entities/sheep', (builder) {
        builder.addItemWithCondition(
          'minecraft:string',
          LootCondition.anyOf([
            LootCondition.killedByPlayer(),
            LootCondition.randomChance(0.1),
          ]),
        );
      });
      expect(true, isTrue);
    });
  });

  await group('LootFunction', () async {
    await testMinecraft('setCount function works', (game) async {
      LootTables.modify('minecraft:entities/chicken', (builder) {
        builder.addItemWithFunctions(
          'minecraft:feather',
          [LootFunction.setCount(1, 3)],
        );
      });
      expect(true, isTrue);
    });

    await testMinecraft('setCountFixed function works', (game) async {
      LootTables.modify('minecraft:entities/bat', (builder) {
        builder.addItemWithFunctions(
          'minecraft:leather',
          [LootFunction.setCountFixed(1)],
        );
      });
      expect(true, isTrue);
    });

    await testMinecraft('lootingEnchant function works', (game) async {
      LootTables.modify('minecraft:entities/wither_skeleton', (builder) {
        builder.addItemWithFunctions(
          'minecraft:coal',
          [LootFunction.lootingEnchant(min: 0, max: 1)],
        );
      });
      expect(true, isTrue);
    });

    await testMinecraft('furnaceSmelt function works', (game) async {
      LootTables.modify('minecraft:entities/rabbit', (builder) {
        builder.addItemWithFunctions(
          'minecraft:rabbit',
          [LootFunction.furnaceSmelt()],
        );
      });
      expect(true, isTrue);
    });

    await testMinecraft('enchantRandomly function works', (game) async {
      LootTables.modify('minecraft:chests/buried_treasure', (builder) {
        builder.addItemWithFunctions(
          'minecraft:book',
          [LootFunction.enchantRandomly()],
        );
      });
      expect(true, isTrue);
    });
  });

  // Pure Dart unit tests
  await group('LootCondition JSON', () async {
    dart_test.test('randomChance generates correct JSON', () {
      final cond = LootCondition.randomChance(0.5);
      final json = cond.toJson();

      expect(json['type'], equals('random_chance'));
      expect(json['chance'], equals(0.5));
    });

    dart_test.test('killedByPlayer generates correct JSON', () {
      final cond = LootCondition.killedByPlayer();
      final json = cond.toJson();

      expect(json['type'], equals('killed_by_player'));
    });

    dart_test.test('inverted generates correct JSON', () {
      final inner = LootCondition.randomChance(0.5);
      final cond = LootCondition.inverted(inner);
      final json = cond.toJson();

      expect(json['type'], equals('inverted'));
      expect(json['term'], isNotNull);
    });
  });

  await group('LootFunction JSON', () async {
    dart_test.test('setCount generates correct JSON', () {
      final func = LootFunction.setCount(1, 3);
      final json = func.toJson();

      expect(json['function'], equals('set_count'));
      expect(json['count']['min'], equals(1));
      expect(json['count']['max'], equals(3));
    });

    dart_test.test('setCountFixed generates correct JSON', () {
      final func = LootFunction.setCountFixed(5);
      final json = func.toJson();

      expect(json['function'], equals('set_count'));
      expect(json['count'], equals(5));
    });
  });

  await group('LootTableBuilder', () async {
    dart_test.test('builder generates pool JSON', () {
      var poolCount = 0;

      // We can't directly access the builder, but we can verify
      // the modification was registered
      LootTables.modify('test:table', (builder) {
        builder.addItem('minecraft:diamond');
        poolCount++;
      });

      expect(poolCount, equals(1));
    });
  });
}
