<p align="center">
  <img src="packages/docs/public/screenshots/redstone_logo.png" alt="Redstone.Dart" width="500"/>
  <br/><br/>
  <strong>Write Minecraft mods in Dart with hot reload</strong>
</p>

<p align="center">
  <img src="packages/docs/public/screenshots/main.png" alt="Minecraft running with Dart support" width="600"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Minecraft-1.21.1-62B47A?style=flat-square&logo=minecraft" alt="Minecraft 1.21.1"/>
  <img src="https://img.shields.io/badge/Dart-3.0+-0175C2?style=flat-square&logo=dart" alt="Dart 3.0+"/>
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License MIT"/>
  <br/><br/>
  <a href="https://redstone-dart.dev/guide/">Docs</a> · <a href="https://redstone-dart.dev/guide/getting-started.html">Get Started</a> · <a href="https://redstone-dart.dev/examples/">Examples</a>
</p>

---

Redstone.Dart lets you write Minecraft mods in Dart instead of Java. Get instant feedback with hot reload — see your changes in-game without restarting Minecraft.

```dart
class MagicBlock extends CustomBlock {
  MagicBlock() : super(
    id: 'mymod:magic_block',
    settings: BlockSettings(hardness: 4.0, luminance: 15),
  );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    Players.getPlayer(playerId)?.sendMessage('§aHello from Dart!');
    return ActionResult.success;
  }
}
```

## Quick Start

```bash
# Install the CLI
dart pub global activate redstone_cli

# Create a new mod
redstone create my_mod
cd my_mod

# Run with hot reload
redstone run
```

Press `r` to hot reload your changes instantly.

## Requirements

- **Dart SDK** 3.0+
- **Java** 21+
- **Minecraft Java Edition** license ([EULA](https://www.minecraft.net/en-us/eula))

No Minecraft installation needed — Redstone downloads everything automatically on first run.

## Features

- **Hot Reload** — See changes in < 1 second
- **Custom Blocks** — Full lifecycle callbacks
- **Custom Items** — Behaviors and interactions
- **World API** — Place blocks, spawn entities, play sounds
- **Player API** — Messages, titles, teleport, inventory
- **Events** — Tick, block break, player join, and more
- **DevTools** — Full Dart debugging support

## Documentation

📖 **[Read the full documentation →](https://redstone-dart.dev)**

- [Getting Started](https://redstone-dart.dev/guide/getting-started.html)
- [CLI Reference](https://redstone-dart.dev/guide/cli.html)
- [Creating Blocks](https://redstone-dart.dev/guide/blocks.html)
- [Creating Items](https://redstone-dart.dev/guide/items.html)
- [API Reference](https://redstone-dart.dev/api/)

## Platform Support

| Platform | Status |
|----------|--------|
| macOS (ARM64 & x64) | ✅ |
| Linux x64 | ✅ |
| Windows x64 | ✅ |

## License

[MIT License](LICENSE)

---

<p align="center">
  <a href="https://github.com/user/redstone-dart/issues">Report Bug</a> •
  <a href="https://github.com/user/redstone-dart/issues">Request Feature</a>
</p>
