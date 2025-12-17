---
home: true
heroImage: /logo.png
heroText: Redstone.Dart
tagline: Write Minecraft mods in Dart with hot reload
actions:
  - text: Get Started
    link: /guide/getting-started.html
    type: primary
  - text: Learn More
    link: /guide/
    type: secondary
features:
  - title: Hot Reload
    details: Change your code, press 'r', see changes in-game instantly. No more 30-second restart cycles.
  - title: Write in Dart
    details: Modern language, great tooling, null safety. If you know Flutter, you'll feel right at home.
  - title: DevTools Support
    details: Set breakpoints, inspect variables, profile performance—full Dart DevTools integration.
footer: MIT Licensed | Copyright © 2024 Redstone.Dart Contributors
---

## Quick Start

```bash
dart pub global activate redstone_cli
redstone create my_mod && cd my_mod
redstone run
```

## How It Works

Your Dart code defines behavior. Redstone creates proxy objects in Minecraft that call your code. When you hot reload, the proxies stay—but your code changes.

```dart
class HelloBlock extends CustomBlock {
  HelloBlock() : super(
    id: 'mymod:hello',
    settings: BlockSettings(hardness: 2.0),
  );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    // Change this, press 'r', see it immediately
    Players.getPlayer(playerId)?.sendMessage('§aHello from Dart!');
    return ActionResult.success;
  }
}
```
