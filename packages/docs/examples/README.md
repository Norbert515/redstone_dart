# Examples

## Hello Block

A block that sends a message when clicked.

```dart
class HelloBlock extends CustomBlock {
  HelloBlock() : super(
    id: 'mymod:hello_block',
    settings: BlockSettings(hardness: 2.0),
  );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    Players.getPlayer(playerId)?.sendMessage('§aHello!');
    return ActionResult.success;
  }
}
```

## Magic Wand

An item that spawns lightning.

```dart
class LightningWand extends CustomItem {
  LightningWand() : super(
    id: 'mymod:lightning_wand',
    settings: ItemSettings(maxCount: 1, rarity: Rarity.epic),
  );

  @override
  ActionResult onUse(Player player, World world, int hand) {
    final target = player.raycast(maxDistance: 50);
    if (target != null) {
      world.spawnLightning(target.x, target.y, target.z);
    }
    return ActionResult.success;
  }
}
```

## Teleporter

A block that teleports players when stepped on.

```dart
class TeleporterBlock extends CustomBlock {
  TeleporterBlock() : super(
    id: 'mymod:teleporter',
    settings: BlockSettings(hardness: 2.0, luminance: 10),
  );

  @override
  void onSteppedOn(int worldId, int x, int y, int z, int entityId) {
    final player = Players.getPlayer(entityId);
    player?.teleport(x.toDouble(), y + 50.0, z.toDouble());
    player?.sendMessage('§dWhoosh!');
  }
}
```

## More

See `example/example_mod/` in the repo for a complete mod.
