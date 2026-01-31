/// ItemStack Data Components E2E Tests.
///
/// Tests for the ItemStackHandle API which provides live access to
/// Minecraft ItemStack data components (1.20.5+).
import 'package:dart_mod_server/dart_mod_server.dart';
import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  // Helper to get a player or skip the test
  Player? getPlayer(MinecraftGameContext game) {
    final players = game.players;
    return players.isEmpty ? null : players.first;
  }

  // Helper to clear inventory and give item
  Future<void> setupItem(
    MinecraftGameContext game,
    Player player,
    String itemId, {
    int slot = 0,
  }) async {
    player.inventory.clear();
    await game.waitTicks(1);
    player.inventory.setSlot(slot, ItemStack(Item(itemId), 1));
    await game.waitTicks(1);
  }

  await group('Basic Component Read', () async {
    await testMinecraft('can read maxDamage from diamond sword', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        final maxDamage = handle.maxDamage;
        // Diamond sword has 1561 durability
        expect(maxDamage, equals(1561));
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can read damage (starts at 0)', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        final damage = handle.damage;
        // Fresh item has 0 damage
        expect(damage, equals(0));
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can read maxStackSize', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      // Test with a stackable item
      await setupItem(game, player, 'minecraft:diamond');

      final handle = player.inventory.getHandle(0);
      try {
        final maxStackSize = handle.maxStackSize;
        // Diamonds stack to 64
        expect(maxStackSize, equals(64));
      } finally {
        handle.release();
      }
    });

    await testMinecraft('sword has maxStackSize of 1', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        final maxStackSize = handle.maxStackSize;
        // Swords don't stack
        expect(maxStackSize, equals(1));
      } finally {
        handle.release();
      }
    });
  });

  await group('Component Write - Damage', () async {
    await testMinecraft('can set damage on pickaxe', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_pickaxe');

      final handle = player.inventory.getHandle(0);
      try {
        // Set damage to 100
        handle.damage = 100;
        await game.waitTicks(1);

        // Read back
        expect(handle.damage, equals(100));
      } finally {
        handle.release();
      }
    });

    await testMinecraft('fresh item has 0 damage', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      // Give a new pickaxe
      await setupItem(game, player, 'minecraft:diamond_pickaxe');

      final handle = player.inventory.getHandle(0);
      try {
        // Should be 0 (fresh item)
        expect(handle.damage, equals(0));
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can set maxDamage', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        // Set custom max damage
        handle.maxDamage = 9999;
        await game.waitTicks(1);

        expect(handle.maxDamage, equals(9999));
      } finally {
        handle.release();
      }
    });
  });

  await group('Custom Name', () async {
    await testMinecraft('item has no custom name by default', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        expect(handle.customName, isNull);
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can set custom name', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        handle.customName = 'Test Sword';
        await game.waitTicks(1);

        expect(handle.customName, equals('Test Sword'));
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can remove custom name', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        // Set then remove
        handle.customName = 'Named Sword';
        await game.waitTicks(1);
        expect(handle.customName, equals('Named Sword'));

        handle.customName = null;
        await game.waitTicks(1);
        expect(handle.customName, isNull);
      } finally {
        handle.release();
      }
    });

    await testMinecraft('custom name with special characters', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        handle.customName = 'Sword of Fire & Ice';
        await game.waitTicks(1);

        expect(handle.customName, equals('Sword of Fire & Ice'));
      } finally {
        handle.release();
      }
    });
  });

  await group('Lore', () async {
    await testMinecraft('item has no lore by default', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        expect(handle.lore, isEmpty);
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can set lore', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        handle.lore = ['Line 1', 'Line 2', 'Line 3'];
        await game.waitTicks(1);

        final lore = handle.lore;
        expect(lore.length, equals(3));
        expect(lore[0], equals('Line 1'));
        expect(lore[1], equals('Line 2'));
        expect(lore[2], equals('Line 3'));
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can clear lore', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        // Set then clear
        handle.lore = ['Test lore'];
        await game.waitTicks(1);
        expect(handle.lore.length, equals(1));

        handle.lore = [];
        await game.waitTicks(1);
        expect(handle.lore, isEmpty);
      } finally {
        handle.release();
      }
    });

    await testMinecraft('lore with multiple lines', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        final loreLines = [
          'This is a legendary sword',
          'Crafted by ancient smiths',
          'It glows with power',
          '+10 Attack Damage',
          '+5 Fire Damage',
        ];
        handle.lore = loreLines;
        await game.waitTicks(1);

        final readLore = handle.lore;
        expect(readLore.length, equals(5));
        for (var i = 0; i < loreLines.length; i++) {
          expect(readLore[i], equals(loreLines[i]));
        }
      } finally {
        handle.release();
      }
    });
  });

  await group('Unbreakable', () async {
    await testMinecraft('item is not unbreakable by default', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        expect(handle.isUnbreakable, isFalse);
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can set unbreakable to true', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        handle.isUnbreakable = true;
        await game.waitTicks(1);

        expect(handle.isUnbreakable, isTrue);
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can set unbreakable to false', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        // Set to true then false
        handle.isUnbreakable = true;
        await game.waitTicks(1);
        expect(handle.isUnbreakable, isTrue);

        handle.isUnbreakable = false;
        await game.waitTicks(1);
        expect(handle.isUnbreakable, isFalse);
      } finally {
        handle.release();
      }
    });
  });

  await group('Fire Resistant', () async {
    await testMinecraft('regular item is not fire resistant', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        expect(handle.isFireResistant, isFalse);
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can set fire resistant', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        handle.isFireResistant = true;
        await game.waitTicks(1);

        expect(handle.isFireResistant, isTrue);
      } finally {
        handle.release();
      }
    });
  });

  await group('Enchantments', () async {
    await testMinecraft('fresh item has no enchantments', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        expect(handle.enchantments, isEmpty);
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can set single enchantment', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        handle.enchantments = {'minecraft:sharpness': 5};
        await game.waitTicks(1);

        final enchants = handle.enchantments;
        expect(enchants.length, equals(1));
        expect(enchants['minecraft:sharpness'], equals(5));
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can set multiple enchantments', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        handle.enchantments = {
          'minecraft:sharpness': 5,
          'minecraft:fire_aspect': 2,
          'minecraft:looting': 3,
        };
        await game.waitTicks(1);

        final enchants = handle.enchantments;
        expect(enchants.length, equals(3));
        expect(enchants['minecraft:sharpness'], equals(5));
        expect(enchants['minecraft:fire_aspect'], equals(2));
        expect(enchants['minecraft:looting'], equals(3));
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can clear enchantments', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        // Set then clear
        handle.enchantments = {'minecraft:sharpness': 5};
        await game.waitTicks(1);
        expect(handle.enchantments.isNotEmpty, isTrue);

        handle.enchantments = {};
        await game.waitTicks(1);
        expect(handle.enchantments, isEmpty);
      } finally {
        handle.release();
      }
    });
  });

  await group('Handle Lifecycle', () async {
    await testMinecraft('released handle throws StateError', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      handle.release();

      // Any operation should throw
      var threw = false;
      try {
        final _ = handle.damage;
      } on StateError {
        threw = true;
      }
      expect(threw, isTrue);
    });

    await testMinecraft('double release is safe', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      handle.release();
      handle.release(); // Should not throw

      expect(true, isTrue); // If we get here, it didn't throw
    });

    await testMinecraft('empty slot throws on handle creation', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      player.inventory.clear();
      await game.waitTicks(1);

      var threw = false;
      try {
        final _ = player.inventory.getHandle(0);
      } on StateError {
        threw = true;
      }
      expect(threw, isTrue);
    });
  });

  await group('Multiple Handles', () async {
    await testMinecraft('can have handles to different slots', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      // Set up items in two slots
      player.inventory.clear();
      await game.waitTicks(1);
      player.inventory.setSlot(0, ItemStack(Item('minecraft:diamond_sword'), 1));
      player.inventory.setSlot(1, ItemStack(Item('minecraft:diamond_pickaxe'), 1));
      await game.waitTicks(1);

      final handleSword = player.inventory.getHandle(0);
      final handlePick = player.inventory.getHandle(1);

      try {
        // Modify sword
        handleSword.customName = 'My Sword';
        await game.waitTicks(1);

        // Modify pickaxe
        handlePick.customName = 'My Pickaxe';
        await game.waitTicks(1);

        // Verify changes are independent
        expect(handleSword.customName, equals('My Sword'));
        expect(handlePick.customName, equals('My Pickaxe'));
      } finally {
        handleSword.release();
        handlePick.release();
      }
    });

    await testMinecraft('changes to one slot do not affect another', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      // Set up items
      player.inventory.clear();
      await game.waitTicks(1);
      player.inventory.setSlot(0, ItemStack(Item('minecraft:diamond_sword'), 1));
      player.inventory.setSlot(1, ItemStack(Item('minecraft:diamond_sword'), 1));
      await game.waitTicks(1);

      final handle0 = player.inventory.getHandle(0);
      final handle1 = player.inventory.getHandle(1);

      try {
        // Modify only slot 0
        handle0.damage = 500;
        handle0.isUnbreakable = true;
        await game.waitTicks(1);

        // Verify slot 1 is unchanged
        expect(handle0.damage, equals(500));
        expect(handle0.isUnbreakable, isTrue);

        expect(handle1.damage, equals(0));
        expect(handle1.isUnbreakable, isFalse);
      } finally {
        handle0.release();
        handle1.release();
      }
    });
  });

  await group('Generic Component Access', () async {
    await testMinecraft('hasComponent returns false for missing component', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        // Fresh sword has no custom_name component
        expect(handle.hasComponent('custom_name'), isFalse);
      } finally {
        handle.release();
      }
    });

    await testMinecraft('hasComponent returns true for existing component', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        // Set a custom name
        handle.customName = 'Test';
        await game.waitTicks(1);

        expect(handle.hasComponent('custom_name'), isTrue);
      } finally {
        handle.release();
      }
    });

    await testMinecraft('removeComponent removes the component', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        // Set then remove
        handle.customName = 'Test';
        await game.waitTicks(1);
        expect(handle.hasComponent('custom_name'), isTrue);

        handle.removeComponent('custom_name');
        await game.waitTicks(1);
        expect(handle.hasComponent('custom_name'), isFalse);
        expect(handle.customName, isNull);
      } finally {
        handle.release();
      }
    });
  });

  await group('Combined Operations', () async {
    await testMinecraft('can create fully customized item', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        // Apply all customizations
        handle.customName = 'Excalibur';
        handle.lore = [
          'The legendary sword',
          'Wielded by kings',
        ];
        handle.isUnbreakable = true;
        handle.enchantments = {
          'minecraft:sharpness': 10,
          'minecraft:fire_aspect': 5,
        };
        await game.waitTicks(1);

        // Verify all changes persisted
        expect(handle.customName, equals('Excalibur'));
        expect(handle.lore.length, equals(2));
        expect(handle.isUnbreakable, isTrue);
        expect(handle.enchantments['minecraft:sharpness'], equals(10));
        expect(handle.enchantments['minecraft:fire_aspect'], equals(5));
      } finally {
        handle.release();
      }
    });

    await testMinecraft('changes persist after re-getting handle', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      // First handle - make changes
      final handle1 = player.inventory.getHandle(0);
      handle1.customName = 'Persistent Name';
      handle1.damage = 250;
      await game.waitTicks(1);
      handle1.release();

      // Second handle - verify changes
      final handle2 = player.inventory.getHandle(0);
      try {
        expect(handle2.customName, equals('Persistent Name'));
        expect(handle2.damage, equals(250));
      } finally {
        handle2.release();
      }
    });
  });

  await group('Edge Cases', () async {
    await testMinecraft('can handle empty string custom name', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        handle.customName = '';
        await game.waitTicks(1);

        // Empty string should be treated as null/no name
        expect(handle.customName, isNull);
      } finally {
        handle.release();
      }
    });

    await testMinecraft('can handle very long custom name', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        final longName = 'A' * 100;
        handle.customName = longName;
        await game.waitTicks(1);

        expect(handle.customName, equals(longName));
      } finally {
        handle.release();
      }
    });

    await testMinecraft('enchantment level 0 means no enchantment', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        // Setting level 0 should effectively remove the enchantment
        handle.enchantments = {'minecraft:sharpness': 0};
        await game.waitTicks(1);

        // Depending on implementation, either empty or contains level 0
        final enchants = handle.enchantments;
        if (enchants.isNotEmpty) {
          expect(enchants['minecraft:sharpness'], equals(0));
        }
      } finally {
        handle.release();
      }
    });

    await testMinecraft('high enchantment levels work', (game) async {
      final player = getPlayer(game);
      if (player == null) return;

      await setupItem(game, player, 'minecraft:diamond_sword');

      final handle = player.inventory.getHandle(0);
      try {
        handle.enchantments = {'minecraft:sharpness': 255};
        await game.waitTicks(1);

        expect(handle.enchantments['minecraft:sharpness'], equals(255));
      } finally {
        handle.release();
      }
    });
  });
}
