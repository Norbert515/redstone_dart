import 'package:dart_mc/api/loot_tables.dart';

/// Registers all loot table modifications.
void registerLootTables() {
  // Zombies have 10% chance to drop DartItem
  LootTables.modify('minecraft:entities/zombie', (builder) {
    builder.addItem(
      'example_mod:dart_item',
      chance: 0.10,
      minCount: 1,
      maxCount: 1,
    );
  });

  // Skeletons have 5% chance to drop HelloBlock
  LootTables.modify('minecraft:entities/skeleton', (builder) {
    builder.addItem(
      'example_mod:hello_block',
      chance: 0.05,
      minCount: 1,
      maxCount: 1,
    );
  });

  // Creepers drop extra gunpowder with looting bonus
  LootTables.modify('minecraft:entities/creeper', (builder) {
    builder.addItemWithFunctions(
      'minecraft:gunpowder',
      [
        LootFunction.setCount(1, 2),
        LootFunction.lootingEnchant(min: 0, max: 2),
      ],
      chance: 0.5,
    );
  });

  // Endermen have rare chance to drop Effect Wand
  LootTables.modify('minecraft:entities/enderman', (builder) {
    builder.addItemWithCondition(
      'example_mod:effect_wand',
      LootCondition.randomChanceWithLooting(0.02, lootingMultiplier: 0.01),
    );
  });

  print('LootTables: Added 4 loot table modifications');
}
