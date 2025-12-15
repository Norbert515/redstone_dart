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
- Minecraft 1.21.1

## Dependencies

### Dart Runtime Library (dart_dll)

The native bridge requires `libdart_dll` - a shared library that embeds the Dart VM. This is provided by [dart_shared_library](https://github.com/fuzzybinary/dart_shared_library).

**The library must be placed at:** `dart_mc_bridge/native/deps/dart_dll/`

```
dart_mc_bridge/native/deps/dart_dll/
├── include/
│   ├── dart_api.h
│   ├── dart_api_dl.h
│   ├── dart_dll.h
│   ├── dart_native_api.h
│   ├── dart_tools_api.h
│   └── isolate_setup.h
└── lib/
    └── libdart_dll.dylib  (or .so / .dll)
```

### Option 1: Download Pre-built (x64 only)

For **Windows x64**, **Linux x64**, or **macOS x64 (Intel)**, download from [GitHub Releases](https://github.com/fuzzybinary/dart_shared_library/releases):

```bash
# Example for macOS x64
curl -L https://github.com/fuzzybinary/dart_shared_library/releases/download/0.2.0/lib-macos.zip -o dart_dll.zip
unzip dart_dll.zip -d dart_mc_bridge/native/deps/dart_dll/
```

### Option 2: Download from CI (includes ARM)

The GitHub Actions CI builds universal macOS binaries (x64 + ARM). Download artifacts from:
https://github.com/fuzzybinary/dart_shared_library/actions

Look for the latest successful run and download the `lib-macos` artifact.

### Option 3: Build from Source (ARM / Custom)

Required for **macOS ARM (M1/M2/M3)** or if you need a specific Dart version.

#### Prerequisites

- git
- Dart SDK 3.0+
- CMake
- C++ build tools (Xcode on macOS, Visual Studio on Windows, gcc on Linux)
- ~15GB disk space
- ~30-60 minutes build time

#### Build Steps

```bash
# 1. Clone dart_shared_library
git clone https://github.com/fuzzybinary/dart_shared_library.git
cd dart_shared_library

# 2. Install build helper dependencies
cd scripts/build_helpers
dart pub get
cd ../..

# 3. Build Dart VM (downloads Dart SDK source, patches, and compiles)
#    This takes 30-60 minutes and requires ~15GB disk space
dart ./scripts/build_helpers/bin/build_dart.dart -v

# 4. Build the shared library with CMake
cmake -B .build .
cmake --build .build --config release

# 5. Copy to your project
mkdir -p /path/to/vide_mc/dart_mc_bridge/native/deps/dart_dll/{include,lib}
cp .build/src/libdart_dll.dylib /path/to/vide_mc/dart_mc_bridge/native/deps/dart_dll/lib/
cp src/dart_dll.h /path/to/vide_mc/dart_mc_bridge/native/deps/dart_dll/include/
cp dart-sdk/sdk/runtime/include/*.h /path/to/vide_mc/dart_mc_bridge/native/deps/dart_dll/include/
```

#### What the Build Does

1. Downloads Google's `depot_tools`
2. Clones the Dart SDK source (~5GB)
3. Patches Dart build files to create a statically linkable `libdart`
4. Compiles the Dart VM (this is the slow part)
5. Wraps it in `libdart_dll` shared library

#### Troubleshooting

**macOS ARM**: Make sure you're using native ARM tools, not Rosetta. Check with:
```bash
uname -m  # Should show "arm64"
```

**Linux - Unresolved externals**:
- Uninstall Flutter snap package if installed
- Put `depot_tools` at the front of your PATH

**Disk space**: The build requires ~15GB. Clean up with:
```bash
rm -rf dart-sdk/sdk/out  # Remove build artifacts
rm -rf depot_tools       # Remove if not needed elsewhere
```

### Dart Version Compatibility

The Dart VM is **fully embedded** in `libdart_dll` - users don't need Dart installed to run your mod. The embedded version depends on when the library was built:

| Release | Dart Version |
|---------|-------------|
| v0.2.0  | 3.8.2       |
| v0.1.0  | 3.5.x       |

Your Dart mod code should be compatible with the embedded version.
