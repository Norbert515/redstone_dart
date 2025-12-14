# Dart-Minecraft Bridge

A bridge that allows writing Minecraft mod logic in Dart, running inside a Fabric mod.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Minecraft (JVM)                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Fabric Mod (Java)                     │   │
│  │       DartModLoader.java       DartBridge.java          │   │
│  └───────────────────────────┬─────────────────────────────┘   │
│                              │ JNI                              │
│  ┌───────────────────────────▼─────────────────────────────┐   │
│  │               Native Bridge (C++)                        │   │
│  │  dart_bridge.cpp  jni_interface.cpp  callback_registry.h│   │
│  └───────────────────────────┬─────────────────────────────┘   │
│                              │ Dart API                         │
│  ┌───────────────────────────▼─────────────────────────────┐   │
│  │                    Dart VM                               │   │
│  │  dart_mod.dart  events.dart  bridge.dart                │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
dart_mc_bridge/
├── native/                 # C++ native bridge
│   ├── CMakeLists.txt     # CMake build configuration
│   ├── src/
│   │   ├── dart_bridge.h      # Public API header
│   │   ├── dart_bridge.cpp    # Dart VM management
│   │   ├── jni_interface.cpp  # JNI bindings for Java
│   │   └── callback_registry.h # Thread-safe callback storage
│   └── include/           # External headers (dart_api_dl.h)
├── dart_mod/              # Dart mod code
│   ├── pubspec.yaml       # Dart package definition
│   ├── lib/
│   │   ├── dart_mod.dart  # Main entry point
│   │   ├── src/
│   │   │   ├── bridge.dart    # FFI bindings
│   │   │   ├── events.dart    # Event registration
│   │   │   └── types.dart     # Common types
│   │   └── api/
│   │       ├── block.dart     # Block API
│   │       ├── player.dart    # Player API
│   │       └── world.dart     # World API
│   └── bin/
│       └── compile.dart   # Compilation script
├── build.gradle.kts       # Build orchestration
└── README.md              # This file

myfirstmod/                # Java Fabric mod (separate project)
└── src/main/java/com/example/dartbridge/
    ├── DartBridge.java        # JNI interface
    └── DartModLoader.java     # Mod initializer
```

## Prerequisites

- **Dart SDK** 3.0 or higher
- **CMake** 3.16 or higher
- **JDK** 17+ (for JNI headers)
- **C++ Compiler** with C++17 support

## Building

### Quick Start

```bash
# Build everything
./gradlew buildAll

# Or step by step:
./gradlew dartPubGet    # Install Dart dependencies
./gradlew dartCompile   # Compile Dart to kernel
./gradlew cmakeBuild    # Build native library
```

### Native Library

```bash
cd native
mkdir build && cd build
cmake ..
cmake --build .
```

The output will be `libdart_mc_bridge.dylib` (macOS), `libdart_mc_bridge.so` (Linux), or `dart_mc_bridge.dll` (Windows).

### Dart Mod

```bash
cd dart_mod
dart pub get
dart compile kernel lib/dart_mod.dart -o ../build/dart_mod.dill
```

## Usage

### 1. Install the Native Library

Copy the built native library to a location in your Java library path, or set `java.library.path` to include its directory.

### 2. Install the Kernel File

Copy `build/dart_mod.dill` to your Minecraft `mods/` directory.

### 3. Add to Fabric Mod

Add the Java files from `myfirstmod/src/main/java/com/example/dartbridge/` to your Fabric mod and register `DartModLoader` as an entrypoint in `fabric.mod.json`:

```json
{
  "entrypoints": {
    "main": [
      "com.example.dartbridge.DartModLoader"
    ]
  }
}
```

The Java implementation includes:
- `DartBridge.java` - JNI interface to the native Dart bridge, handles library loading and event dispatch
- `DartModLoader.java` - Fabric mod initializer that loads the Dart VM and forwards Minecraft events

### 4. Write Dart Mod Logic

Edit `dart_mod/lib/dart_mod.dart` to add your mod logic:

```dart
void main() {
  print('My Dart Mod loaded!');

  Events.onBlockBreak((x, y, z, playerId) {
    print('Block broken at ($x, $y, $z)');
    // Return EventResult.cancel to prevent breaking
    return EventResult.allow;
  });
}
```

## Event API

### Block Break Event

Called when a player breaks a block. Return `EventResult.allow` to allow the break, `EventResult.cancel` to prevent it.

```dart
Events.onBlockBreak((x, y, z, playerId) {
  // Your logic here
  return EventResult.allow;
});
```

### Block Interact Event

Called when a player right-clicks a block.

```dart
Events.onBlockInteract((x, y, z, playerId, hand) {
  // hand: 0 = main hand, 1 = off hand
  return EventResult.allow;
});
```

### Tick Event

Called every game tick (20 times per second).

```dart
Events.onTick((tick) {
  if (tick % 20 == 0) {
    print('One second passed!');
  }
});
```

## TODO

- [ ] Integrate actual Dart VM embedding (currently stubbed)
- [ ] Add more event types (entity events, chat, etc.)
- [ ] Add world manipulation API (get/set blocks)
- [ ] Add player manipulation API (teleport, send messages)
- [ ] Hot reload support for development
- [ ] Configuration file for kernel path
- [ ] Example mods

## License

MIT License
