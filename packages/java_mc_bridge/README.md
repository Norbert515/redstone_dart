# Java MC Bridge

Java/Fabric bridge code for Redstone - enables Dart mods to run in Minecraft.

## Overview

This package contains the Java side of the Dart-Minecraft bridge:

- **DartBridge.java** - JNI interface to the native C++ library
- **DartModLoader.java** - Fabric mod entry point that initializes Dart
- **proxy/** - Proxy classes that delegate block/entity behavior to Dart

## Architecture

```
Minecraft (Java) ←→ JNI ←→ Native Bridge (C++) ←→ FFI ←→ Dart VM
```

## Package Structure

```
src/main/java/com/redstone/
├── DartBridge.java         # JNI bindings
├── DartModLoader.java      # Fabric entry point
├── DartContainerBlock.java # Container block support
├── DartContainerMenu.java  # Container UI support
├── ContainerDef.java       # Container definitions
├── DartSlot.java           # Inventory slot handling
└── proxy/
    ├── ProxyRegistry.java      # Block proxy management
    ├── DartBlockProxy.java     # Block that delegates to Dart
    ├── EntityProxyRegistry.java # Entity proxy management
    └── DartEntityProxy.java    # Entity that delegates to Dart
```

## Usage

This package is automatically copied to `.redstone/bridge/` when creating a Redstone project. The generated Fabric mod includes this as a source set.

## Development Setup (MC Source Access)

This package has a Fabric Loom setup for IDE navigation and MC source access:

```bash
# Generate decompiled Minecraft sources (run once)
./gradlew genSources

# Refresh your IDE after running this
```

Sources are cached in `.gradle/loom-cache/` (not checked into git).

**Note**: The project won't fully compile standalone because it references mod-specific classes (`com.example.*`). The Loom setup is for IDE navigation and code completion only.

## Building

This is Java source code - it gets compiled as part of the Fabric mod build process, not separately.
