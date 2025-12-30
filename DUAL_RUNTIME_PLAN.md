# Dual Runtime Architecture Plan

## Overview

This plan describes the architecture change to run **two separate Dart runtimes**:
1. **Server Runtime** - Pure Dart VM (dart_dll) for game logic on Server thread
2. **Client Runtime** - Flutter Embedder for UI rendering on Render thread

This matches Minecraft's own client/server separation and solves the threading issues we encountered with FFI callbacks from different threads.

## Current Problem

With the Flutter-only approach:
- Flutter's Dart VM runs on the Render thread
- Server-side events (block interactions, entity AI, player join) fire on the Server thread
- Direct FFI callbacks from Server thread → Dart crash because Dart isolate is on Render thread
- The "merged thread" approach only merges Flutter's internal threads, not Minecraft's threads

## Proposed Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SINGLEPLAYER                              │
├─────────────────────────────┬───────────────────────────────────┤
│      Server Thread          │         Render Thread             │
│                             │                                   │
│   ┌─────────────────┐       │      ┌─────────────────┐         │
│   │   Dart VM       │       │      │ Flutter Engine  │         │
│   │   (dart_dll)    │       │      │                 │         │
│   │                 │       │      │                 │         │
│   │ dart_mod_server │       │      │ dart_mod_client │         │
│   │ dart_mod_common │       │      │ dart_mod_common │         │
│   └────────┬────────┘       │      └────────┬────────┘         │
│            │                │               │                   │
│   Dart_EnterIsolate()       │      Direct FFI (same thread)    │
│   (any thread safe)         │                                   │
│            │                │               │                   │
│   ┌────────▼────────┐       │      ┌────────▼────────┐         │
│   │  DartBridge     │◄──────┼──────►FlutterBridge    │         │
│   │  (Server)       │       │      │  (Client)       │         │
│   └─────────────────┘       │      └─────────────────┘         │
│            │                │               │                   │
│            └────────────────┼───────────────┘                   │
│                   Minecraft Packets                             │
│              (for client-server sync)                           │
└─────────────────────────────┴───────────────────────────────────┘
```

## Dart Package Structure

```
packages/
├── dart_mod_common/              # Shared between client & server
│   ├── lib/
│   │   ├── src/
│   │   │   ├── blocks/           # Block definitions (data only)
│   │   │   ├── items/            # Item definitions (data only)
│   │   │   ├── entities/         # Entity definitions (data only)
│   │   │   ├── registry/         # Registration APIs (interfaces)
│   │   │   ├── protocol/         # Packet definitions
│   │   │   └── utils/            # Shared utilities
│   │   └── dart_mod_common.dart  # Library export
│   └── pubspec.yaml              # No platform dependencies
│
├── dart_mod_server/              # Server-only (dart_dll runtime)
│   ├── lib/
│   │   ├── src/
│   │   │   ├── bridge.dart       # Server FFI bridge
│   │   │   ├── handlers/         # Block/item/entity handlers
│   │   │   ├── ai/               # Entity AI implementations
│   │   │   └── world/            # World manipulation APIs
│   │   └── dart_mod_server.dart  # Library export
│   └── pubspec.yaml              # depends on dart_mod_common
│
├── dart_mod_client/              # Client-only (Flutter runtime)
│   ├── lib/
│   │   ├── src/
│   │   │   ├── bridge.dart       # Client FFI bridge
│   │   │   ├── screens/          # Flutter UI screens
│   │   │   ├── widgets/          # Reusable widgets
│   │   │   └── rendering/        # Client-side effects
│   │   └── dart_mod_client.dart  # Library export
│   └── pubspec.yaml              # depends on dart_mod_common, flutter
│
├── dart_mc/                      # EXISTING - to be refactored
└── ...
```

## Native Bridge Structure

```
packages/native_mc_bridge/
├── deps/
│   ├── dart_dll/                 # Restored from before Flutter migration
│   │   ├── include/
│   │   │   ├── dart_dll.h
│   │   │   ├── dart_api.h
│   │   │   └── dart_api_dl.h
│   │   └── lib/
│   │       └── libdart_dll.dylib (or .so/.dll)
│   │
│   └── flutter_embedder/         # Keep existing Flutter embedder
│       ├── include/
│       │   └── flutter_embedder.h
│       └── lib/
│           └── FlutterEmbedder.framework
│
├── src/
│   ├── dart_bridge_server.cpp    # Server-side: dart_dll init, safe_enter/exit
│   ├── dart_bridge_server.h
│   ├── dart_bridge_client.cpp    # Client-side: Flutter embedder init
│   ├── dart_bridge_client.h
│   ├── callback_registry.h       # Shared callback types
│   ├── jni_interface.cpp         # JNI entry points (routes to server/client)
│   ├── generic_jni.cpp           # JNI utilities
│   └── object_registry.cpp       # Java object handle management
│
└── CMakeLists.txt                # Build both server and client bridges
```

## Java Bridge Structure

```
packages/java_mc_bridge/src/
├── main/java/com/redstone/        # Common + Server
│   ├── DartModLoader.java         # Common initializer
│   ├── DartBridgeServer.java      # Server-side JNI bridge (dart_dll)
│   ├── proxy/                     # Block/Item/Entity proxies (call server Dart)
│   └── network/                   # Packet definitions
│
└── client/java/com/redstone/      # Client-only
    ├── DartModClientLoader.java   # Client initializer
    ├── DartBridgeClient.java      # Client-side JNI bridge (Flutter)
    ├── flutter/                   # Flutter screen integration
    └── render/                    # Entity renderers
```

## Implementation Phases

### Phase 1: Restore dart_dll Dependencies

1. Restore `deps/dart_dll/` from git history (commit before 40abce7)
2. Update CMakeLists.txt to build with dart_dll again
3. Keep Flutter embedder deps alongside

**Files to restore:**
- `deps/dart_dll/include/dart_dll.h`
- `deps/dart_dll/include/dart_api.h`
- `deps/dart_dll/include/dart_api_dl.h`
- `deps/dart_dll/include/dart_native_api.h`
- `deps/dart_dll/include/dart_tools_api.h`
- `deps/dart_dll/lib/libdart_dll.dylib` (downloaded via CLI)

### Phase 2: Refactor Native Bridge

1. Split `dart_bridge.cpp` into:
   - `dart_bridge_server.cpp` - dart_dll initialization, safe_enter/exit pattern
   - `dart_bridge_client.cpp` - Flutter embedder initialization

2. Create separate initialization functions:
   - `dart_server_init(script_path)` - Initialize server Dart VM
   - `dart_client_init(flutter_assets_path, icu_path)` - Initialize Flutter

3. Route dispatch functions appropriately:
   - Server events → `dart_bridge_server` → safe_enter → Dart callback
   - Client events → `dart_bridge_client` → direct Flutter callback

### Phase 3: Create Dart Package Structure

1. Create `packages/dart_mod_common/`:
   - Move shared types from `dart_mc`
   - Define protocol/packet structures
   - Keep pure Dart (no FFI)

2. Create `packages/dart_mod_server/`:
   - Server FFI bridge
   - Block/item/entity handlers
   - AI logic

3. Create `packages/dart_mod_client/`:
   - Flutter FFI bridge
   - UI screens and widgets
   - Client-side rendering

4. Refactor `example/example_mod/`:
   - Split into server and client entry points
   - Server: `lib/server/main.dart`
   - Client: `lib/client/main.dart`

### Phase 4: Update Java Bridge

1. Rename/split `DartBridge.java`:
   - `DartBridgeServer.java` - Server-side native methods
   - Keep `DartBridgeClient.java` - Client-side native methods

2. Update initialization flow:
   - `DartModLoader.onInitialize()` → Initialize server Dart VM
   - `DartModClientLoader.onInitializeClient()` → Initialize Flutter

3. Route events correctly:
   - Server thread events → DartBridgeServer
   - Render thread events → DartBridgeClient

### Phase 5: Unified Hot Reload

1. Update CLI to track both VM service URLs:
   - Server Dart VM: port 5858 (or configurable)
   - Flutter VM: port 5859 (or configurable)

2. Single `redstone run` command:
   - Starts Minecraft
   - Connects to both VM services
   - File watcher triggers reload on both

3. Reload behavior:
   - Server code changes → Reload server Dart VM
   - Client code changes → Reload Flutter
   - Common code changes → Reload both

### Phase 6: Client-Server Sync (Packets)

1. Define packet protocol in `dart_mod_common`:
   ```dart
   abstract class ModPacket {
     void encode(ByteBuffer buffer);
     static ModPacket decode(ByteBuffer buffer);
   }
   ```

2. Register Fabric networking handlers in Java

3. Bridge packets to Dart:
   - Java receives packet → calls native → Dart handler
   - Dart sends packet → calls native → Java sends via Fabric networking

## Migration Path for Existing Mods

Existing mods using `dart_mc` will need to:

1. Split their code into server/client packages
2. Move UI code to client package (depends on flutter)
3. Move game logic to server package (no flutter dependency)
4. Update imports to use new package structure

We can provide a migration guide and potentially a codemod tool.

## Testing Strategy

1. **Unit tests**: Test common package logic
2. **Integration tests**: Test server Dart VM initialization
3. **E2E tests**: Existing headless tests (server-only)
4. **Visual tests**: Flutter UI tests (client-only)

## Timeline Estimate

- Phase 1: 1-2 hours (restore deps)
- Phase 2: 4-6 hours (native bridge refactor)
- Phase 3: 2-3 hours (Dart packages)
- Phase 4: 2-3 hours (Java bridge)
- Phase 5: 2-3 hours (hot reload)
- Phase 6: 4-6 hours (networking)

**Total: ~15-23 hours of implementation work**

## Open Questions

1. Should `dart_mod_common` have any FFI at all, or be 100% pure Dart?
   - Recommendation: Pure Dart for maximum portability

2. How to handle the example mod migration?
   - Recommendation: Create new example structure, keep old for reference

3. Should we support running server-only (no Flutter) for testing?
   - Recommendation: Yes, useful for CI and headless tests
