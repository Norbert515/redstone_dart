import 'package:dart_mod_server/dart_mod_server.dart';

/// Example item demonstrating data component modification.
///
/// This wand modifies the offhand item's data components when used:
/// - Sets a custom name
/// - Adds lore lines
/// - Adds enchantments
/// - Makes it unbreakable
class EnchantWand extends CustomItem {
  EnchantWand()
      : super(
          id: 'example_mod:enchant_wand',
          settings: const ItemSettings(maxStackSize: 1),
          model: ItemModel.generated(
            texture: 'assets/textures/item/dart_item.png', // Reuse existing texture
          ),
        );

  @override
  ItemActionResult onUse(int worldId, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player == null) return ItemActionResult.pass;

    // Get the offhand item (slot 40 in player inventory)
    const offhandSlot = 40;
    final offhandItem = player.inventory.getSlot(offhandSlot);

    if (offhandItem.isEmpty) {
      player.sendMessage('§c[Enchant Wand] §fHold an item in your offhand to enchant it!');
      return ItemActionResult.fail;
    }

    // Get a handle to the offhand item to modify its components
    try {
      final handle = player.inventory.getHandle(offhandSlot);
      try {
        // Set custom name with color
        handle.customName = '§d§lEnchanted ${offhandItem.item.id.split(':').last}';

        // Add lore lines
        handle.lore = [
          '§7Enchanted by the §5Enchant Wand',
          '§7This item has been blessed with',
          '§7magical properties!',
          '',
          '§8Crafted with Dart magic',
        ];

        // Add enchantments
        handle.enchantments = {
          'minecraft:unbreaking': 3,
          'minecraft:mending': 1,
        };

        // Make it unbreakable
        handle.isUnbreakable = true;

        player.sendMessage('§d[Enchant Wand] §fItem enchanted successfully!');
        player.sendMessage('§7Added: Custom name, lore, Unbreaking III, Mending, Unbreakable');

        // Visual effects
        final world = World.overworld;
        world.spawnParticles(
          Particles.enchant,
          player.precisePosition + const Vec3(0, 1, 0),
          count: 30,
          delta: Vec3(0.5, 0.5, 0.5),
        );
        world.playSound(player.precisePosition, Sounds.levelUp, volume: 0.8);
      } finally {
        handle.release();
      }
    } catch (e) {
      player.sendMessage('§c[Enchant Wand] §fFailed to enchant item: $e');
      return ItemActionResult.fail;
    }

    return ItemActionResult.success;
  }
}
