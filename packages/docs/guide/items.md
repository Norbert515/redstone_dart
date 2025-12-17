# Items

Items work similarly to blocks—you define behavior in Dart, and a proxy item is created in Java.

## Items vs Blocks

The key difference: blocks exist in the world at coordinates, items exist in inventories and hands. This affects the callbacks you get:

- **Blocks** get `onUse(worldId, x, y, z, playerId, hand)` — you know where the block is
- **Items** get `onUse(player, world, hand)` — the item is in the player's hand, not at a fixed location

## Creating an Item

```dart
class MagicWand extends CustomItem {
  MagicWand() : super(
    id: 'mymod:magic_wand',
    settings: ItemSettings(maxCount: 1, rarity: Rarity.epic),
    model: ItemModel.handheld(texture: 'assets/textures/item/wand.png'),
  );

  @override
  ActionResult onUse(Player player, World world, int hand) {
    player.sendMessage('§dMagic!');
    return ActionResult.success;
  }
}
```

## Item Settings

```dart
ItemSettings(
  maxCount: 64,           // Stack size (tools usually 1)
  maxDamage: 500,         // Durability (0 = unbreakable)
  rarity: Rarity.epic,    // Affects name color
  fireResistant: true,    // Survives lava
)
```

Rarity affects the item name color in the inventory:
- `common` — White
- `uncommon` — Yellow
- `rare` — Aqua
- `epic` — Light purple

## Registration Order Matters

If your blocks drop custom items, register items **before** blocks:

```dart
void main() {
  Bridge.initialize();
  Events.registerProxyBlockHandlers();

  // Items first!
  ItemRegistry.register(MagicGem());
  ItemRegistry.freeze();

  // Then blocks that reference them
  BlockRegistry.register(GemOre()); // drops: 'mymod:magic_gem'
  BlockRegistry.freeze();
}
```

Why? When the block is registered, it references the item by ID. That item needs to already exist in the registry.

## Item Callbacks

### onUse — Right-Click in Air

Called when the player right-clicks while holding the item (not targeting a block):

```dart
@override
ActionResult onUse(Player player, World world, int hand) {
  // Do something magical
  return ActionResult.success;
}
```

### onUseOnBlock — Right-Click on Block

Called when targeting a specific block:

```dart
@override
ActionResult onUseOnBlock(Player player, World world, int x, int y, int z, int hand) {
  // Place something, transform the block, etc.
  world.setBlock(x, y + 1, z, 'minecraft:torch');
  return ActionResult.success;
}
```

## Item Models

Two main styles:

```dart
// Flat item (gems, materials, food)
ItemModel.generated(texture: 'assets/textures/item/gem.png')

// Handheld (tools, weapons, sticks)
ItemModel.handheld(texture: 'assets/textures/item/wand.png')
```

The difference is how the item rotates in the player's hand.

## Example: Lightning Wand

A wand that spawns lightning where you look:

```dart
class LightningWand extends CustomItem {
  LightningWand() : super(
    id: 'mymod:lightning_wand',
    settings: ItemSettings(maxCount: 1, rarity: Rarity.epic),
  );

  @override
  ActionResult onUse(Player player, World world, int hand) {
    // Raycast to find where player is looking
    final target = player.raycast(maxDistance: 50);

    if (target != null) {
      world.spawnLightning(target.x, target.y, target.z);
      player.sendMessage('§e⚡ Strike!');
    }

    return ActionResult.success;
  }
}
```
