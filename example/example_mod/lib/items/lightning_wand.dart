import 'package:dart_mc/dart_mc.dart';

/// Wand that summons lightning where you click
class LightningWand extends CustomItem {
  LightningWand()
      : super(
          id: 'example_mod:lightning_wand',
          settings: const ItemSettings(maxStackSize: 1),
          model: ItemModel.handheld(
              texture: 'assets/textures/item/lightning_wand.png'),
        );

  @override
  ItemActionResult onUseOnBlock(
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
    int hand,
  ) {
    final player = Players.getPlayer(playerId);
    if (player != null) {
      World.overworld.spawnLightning(Vec3(x.toDouble(), y.toDouble(), z.toDouble()));
      player.sendMessage('\u00A7e\u26A1 Lightning strikes!');
    }
    return ItemActionResult.success;
  }
}
