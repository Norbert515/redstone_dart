# Dart-Minecraft Bridge

A bridge that allows writing Minecraft mod logic in Dart, with full interoperability between Dart, C++, and Java/Minecraft.

## Overview

This project enables defining custom Minecraft blocks entirely in Dart code. The Dart VM runs embedded within Minecraft, and block behaviors (break, use, etc.) are delegated from Java proxy classes to Dart handlers via JNI and FFI.

```
┌─────────────────┐     JNI      ┌─────────────────┐     FFI      ┌─────────────────┐
│   Minecraft     │◄────────────►│   C++ Bridge    │◄────────────►│    Dart VM      │
│   (Java/Fabric) │              │  (dart_mc_bridge)│              │   (dart_mod)    │
└─────────────────┘              └─────────────────┘              └─────────────────┘
```

## Project Structure

```
vide_mc/
├── myfirstmod/                    # Fabric mod (Java)
│   ├── src/main/java/com/example/
│   │   ├── dartbridge/
│   │   │   ├── DartBridge.java       # JNI interface to native library
│   │   │   ├── DartModLoader.java    # Fabric mod entry point
│   │   │   └── proxy/
│   │   │       ├── DartBlockProxy.java   # Block that delegates to Dart
│   │   │       └── ProxyRegistry.java    # Manages Dart-defined blocks
│   │   └── ...
│   └── run/
│       ├── mods/dart_mod/         # Dart mod package (copied here)
│       └── natives/               # Native library (copied here)
│
├── dart_mc_bridge/
│   ├── native/                    # C++ native bridge
│   │   ├── src/
│   │   │   ├── dart_bridge.cpp/h     # Dart VM lifecycle management
│   │   │   ├── jni_interface.cpp     # JNI bindings for Java
│   │   │   ├── generic_jni.cpp/h     # Dynamic JNI calls from Dart
│   │   │   ├── callback_registry.h   # Event callback storage
│   │   │   └── object_registry.h     # Java object handle management
│   │   └── build/                    # CMake build output
│   │
│   └── dart_mod/                  # Dart mod package
│       └── lib/
│           ├── dart_mod.dart         # Entry point
│           ├── api/
│           │   ├── custom_block.dart    # Base class for blocks
│           │   └── block_registry.dart  # Block registration
│           ├── src/
│           │   ├── bridge.dart          # FFI bindings
│           │   ├── events.dart          # Event handlers
│           │   └── jni/
│           │       ├── generic_bridge.dart  # Dynamic JNI from Dart
│           │       └── java_object.dart     # Java object wrapper
│           └── examples/
│               └── example_blocks.dart  # Example custom blocks
│
└── dart_shared_library/           # dart_dll (Dart VM embedding)
```

## Key Concepts

### Block Registration Flow

1. **Dart** calls `BlockRegistry.register(MyBlock())` during mod init
2. **Dart** → **C++** → **Java**: Creates proxy block via JNI
3. **Java** registers `DartBlockProxy` with Minecraft's registry
4. Handler ID links the Java proxy to the Dart `CustomBlock` instance

### Event Flow (e.g., block interaction)

1. Player right-clicks block in **Minecraft**
2. **Java** `DartBlockProxy.useWithoutItem()` is called
3. **Java** → **C++** via JNI: `onProxyBlockUse(handlerId, ...)`
4. **C++** → **Dart** via FFI callback: `BlockRegistry.dispatchBlockUse()`
5. **Dart** `CustomBlock.onUse()` executes your logic
6. Result propagates back: **Dart** → **C++** → **Java** → **Minecraft**

### Chat Messages (Dart → Minecraft)

```dart
Bridge.sendChatMessage(playerId, '§aHello from Dart!');
```

This flows: **Dart** → **C++** → **Java** → player's chat

## Quick Start

```bash
# Install just (command runner)
brew install just

# Build everything and run Minecraft
just run

# Or step by step:
just native          # Build C++ library
just native-install  # Copy to run directory
just dart-install    # Copy Dart mod
just mc              # Start Minecraft
```

## Creating Custom Blocks

```dart
// In dart_mod/lib/examples/my_block.dart
import '../api/custom_block.dart';
import '../src/bridge.dart';

class MyBlock extends CustomBlock {
  MyBlock() : super(
    id: 'mymod:my_block',
    settings: BlockSettings(hardness: 2.0, resistance: 6.0),
  );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    Bridge.sendChatMessage(playerId, '§bYou clicked my block!');
    return ActionResult.success;
  }

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    Bridge.sendChatMessage(playerId, '§eBlock broken!');
    return true; // Allow break (return false to cancel)
  }
}
```

Register in `dart_mod.dart`:
```dart
BlockRegistry.register(MyBlock());
```

## Hot Reload (Development)

The Dart VM service runs on `http://127.0.0.1:5858/`. You can:

1. Use `/darturl` command in-game to see the URL
2. Connect Dart DevTools for debugging
3. Trigger hot reload via VM Service protocol

Note: Hot reload updates block *behavior* but cannot add new blocks (Minecraft registry freezes at startup).

## In-Game Features

- **Join message**: Shows Dart support status and VM service URL
- **`/darturl` command**: Displays the Dart VM service URL
- **Chat integration**: Blocks can send colored messages to players

## Color Codes

Use Minecraft formatting codes in chat messages:
- `§a` green, `§b` aqua, `§c` red, `§d` pink, `§e` yellow
- `§f` white, `§7` gray, `§8` dark gray, `§0` black
- `§l` bold, `§o` italic, `§n` underline

## Requirements

- Java 21+
- Dart SDK 3.0+
- CMake 3.16+
- Fabric Loader 0.18+
- Minecraft 1.21.11
