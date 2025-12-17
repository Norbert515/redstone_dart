# Getting Started

## Prerequisites

- **Dart SDK** 3.0+ — [dart.dev/get-dart](https://dart.dev/get-dart)
- **Java** 21+ — [adoptium.net](https://adoptium.net/)
- **Minecraft Java Edition** license (you don't need it installed)

## Install

```bash
dart pub global activate redstone_cli
redstone doctor  # Verify setup
```

## Create a Mod

```bash
redstone create my_mod
cd my_mod
redstone run
```

::: tip First Run
First run downloads ~500MB of game files. Takes a few minutes once, then it's fast.
:::

## Hot Reload

While Minecraft is running:
1. Edit your code
2. Press `r` in the terminal
3. Changes appear instantly!

## Project Structure

```
my_mod/
├── lib/main.dart         # Your mod code
├── assets/textures/      # Your textures (16x16 PNGs)
└── pubspec.yaml
```

## Next Steps

- [CLI Reference](/guide/cli.html)
- [Creating Blocks](/guide/blocks.html)
- [Examples](/examples/)
