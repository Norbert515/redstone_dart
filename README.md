<p align="center">
  <img src="packages/docs/public/screenshots/redstone_logo.png" alt="Redstone.Dart" width="500"/>
  <br/><br/>
  <strong>Write Minecraft mods in Dart with hot reload</strong>
</p>

> **Warning**
> This project is highly experimental and under active development. APIs are likely to change significantly between versions. Use at your own risk and expect breaking changes.

<p align="center">
  <img src="packages/docs/public/screenshots/main.png" alt="Minecraft running with Dart support" width="600"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Minecraft-1.21.1-62B47A?style=flat-square&logo=minecraft" alt="Minecraft 1.21.1"/>
  <img src="https://img.shields.io/badge/Dart-3.0+-0175C2?style=flat-square&logo=dart" alt="Dart 3.0+"/>
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License MIT"/>
  <br/><br/>
  <a href="https://docs.redstone-dart.dev/docs">Docs</a> · <a href="https://docs.redstone-dart.dev/docs/getting-started">Get Started</a> · <a href="https://github.com/Norbert515/redstone_dart/tree/main/example">Examples</a>
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
# Clone the repository
git clone https://github.com/Norbert515/redstone_dart.git
cd redstone_dart/packages/redstone_cli

# Install the CLI globally
dart pub global activate --source path .

# Create a new mod (from any directory)
cd ~/my_projects
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

📖 **[Read the full documentation →](https://docs.redstone-dart.dev/docs)**

- [Getting Started](https://docs.redstone-dart.dev/docs/getting-started)
- [CLI Reference](https://docs.redstone-dart.dev/docs/cli)
- [Creating Blocks](https://docs.redstone-dart.dev/docs/blocks)
- [Creating Items](https://docs.redstone-dart.dev/docs/items)

## Platform Support

| Platform | Status |
|----------|--------|
| macOS (ARM64 & x64) | ✅ |
| Linux x64 | ✅ |
| Windows x64 | ✅ |

### 🪟 Windows Notes

The custom Flutter engine is not yet available on Windows, which means **Dual Mode** is currently unsupported. 

To run your mod successfully on Windows, you must edit your `redstone.yaml` to retain **only** the `redstone_mod` configuration block. Remove any flutter or dual mode related configuration, otherwise the runner will fail.

## License

[MIT License](LICENSE)

---

<p align="center">
  <a href="https://github.com/Norbert515/redstone_dart/issues">Report Bug</a> •
  <a href="https://github.com/Norbert515/redstone_dart/issues">Request Feature</a>
</p>
