# Dart-Minecraft Bridge Technical Specification

## Overview

This document specifies the architecture for embedding Dart into a Minecraft Fabric mod, enabling mod logic to be written in Dart with hot reload support during development.

**Core Value Proposition**: Write Minecraft mod logic in Dart, leveraging Dart's superior tooling, type system, and hot reload for rapid iteration.

---

## 1. Architecture Overview

### 1.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Minecraft JVM (Main Game Thread)                 │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                 Fabric Mod (Kotlin/Java)                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐    │   │
│  │  │ ProxyBlock  │  │ ProxyEntity │  │ EventDispatcher  │    │   │
│  │  └──────┬──────┘  └──────┬──────┘  └────────┬─────────┘    │   │
│  │         │                │                   │              │   │
│  │         └────────────────┼───────────────────┘              │   │
│  │                          │ JNI                              │   │
│  └──────────────────────────┼──────────────────────────────────┘   │
└─────────────────────────────┼───────────────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────────────┐
│              Native Bridge (C++ Shared Library)                     │
│  ┌──────────────────────────┴──────────────────────────────────┐   │
│  │                    JNI Interface Layer                       │   │
│  │  • Java_DartBridge_* functions                              │   │
│  │  • Type marshalling (jobject ↔ C structs)                   │   │
│  └──────────────────────────┬──────────────────────────────────┘   │
│  ┌──────────────────────────┴──────────────────────────────────┐   │
│  │                  Dart VM Host                                │   │
│  │  • Dart_Initialize / Dart_CreateIsolateGroup                │   │
│  │  • Kernel snapshot loading                                   │   │
│  │  • Hot reload orchestration                                  │   │
│  └──────────────────────────┬──────────────────────────────────┘   │
│  ┌──────────────────────────┴──────────────────────────────────┐   │
│  │               Callback Registry                              │   │
│  │  • Function pointer table (stable C ABI)                    │   │
│  │  • NativeCallable.isolateLocal endpoints                    │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ FFI (stable C ABI)
                              │
┌─────────────────────────────┼───────────────────────────────────────┐
│                    Dart VM (Same Thread)                            │
│  ┌──────────────────────────┴──────────────────────────────────┐   │
│  │                  dart:ffi Bindings                           │   │
│  │  • NativeCallable.isolateLocal handlers                     │   │
│  │  • Struct definitions for MC types                          │   │
│  └──────────────────────────┬──────────────────────────────────┘   │
│  ┌──────────────────────────┴──────────────────────────────────┐   │
│  │                  Mod Runtime Library                         │   │
│  │  • Event registration DSL                                    │   │
│  │  • Minecraft API wrappers                                    │   │
│  │  • Hot reload lifecycle                                      │   │
│  └──────────────────────────┬──────────────────────────────────┘   │
│  ┌──────────────────────────┴──────────────────────────────────┐   │
│  │                  User Mod Code                               │   │
│  │  • Event handlers                                            │   │
│  │  • Custom logic                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Threading Model

**Single-Thread Architecture**: All Dart code executes on the Minecraft main game thread.

```
Minecraft Main Thread
    │
    ├── Game tick starts
    │   ├── World updates
    │   ├── Entity updates
    │   └── Block updates ──► JNI ──► Native Bridge ──► Dart callback
    │                                                        │
    │   ◄────────────────────────────────────────────────────┘
    │                         (synchronous return)
    │
    └── Game tick ends
```

**Why This Works**:
1. Minecraft fires all mod events on the main server thread
2. JNI calls are synchronous by nature
3. `NativeCallable.isolateLocal` executes on the calling thread (which becomes the Dart mutator thread)
4. No thread synchronization needed between Java and Dart
5. Dart's event loop is not used—we drive execution from Java

**Constraints**:
- All Dart callbacks must be non-blocking
- Long-running operations would freeze the game
- Async Dart code (Future/Stream) cannot span across callback boundaries

### 1.3 Hot Reload Integration

```
┌─────────────────┐     File Watch      ┌──────────────────┐
│  Dart Source    │ ──────────────────► │  Dev Server      │
│  (lib/*.dart)   │                     │  (dart tool)     │
└─────────────────┘                     └────────┬─────────┘
                                                 │
                                         Incremental Kernel
                                                 │
                                                 ▼
┌─────────────────┐     Reload Signal   ┌──────────────────┐
│  Native Bridge  │ ◄────────────────── │  File/Socket     │
│                 │                     │  Watcher         │
└────────┬────────┘                     └──────────────────┘
         │
         │ Dart_ReloadSources()
         ▼
┌─────────────────┐
│  Dart Isolate   │
│  • Old handlers invalidated
│  • New handlers registered
│  • State preserved (if designed correctly)
└─────────────────┘
```

---

## 2. Native Bridge Layer (C++)

### 2.1 Dart VM Initialization

```cpp
// dart_bridge.h
#pragma once

#include <dart_api.h>
#include <dart_native_api.h>
#include <jni.h>

namespace dart_mc {

struct BridgeConfig {
    const char* kernel_snapshot_path;  // Path to compiled .dill
    const char* dart_sdk_path;         // Path to Dart SDK
    bool enable_hot_reload;
    const char* hot_reload_socket;     // Unix socket or TCP port
};

class DartBridge {
public:
    static DartBridge& instance();

    bool initialize(const BridgeConfig& config);
    void shutdown();

    bool reload_sources();

    // Callback management
    using BlockInteractCallback = int32_t (*)(
        int32_t world_id,
        int32_t x, int32_t y, int32_t z,
        int32_t player_id,
        int32_t hand  // 0=main, 1=off
    );

    void set_block_interact_callback(BlockInteractCallback cb);
    BlockInteractCallback get_block_interact_callback() const;

private:
    DartBridge() = default;

    Dart_Isolate isolate_ = nullptr;
    Dart_IsolateGroup isolate_group_ = nullptr;

    // Callback table
    BlockInteractCallback block_interact_cb_ = nullptr;
    // ... more callbacks
};

} // namespace dart_mc
```

### 2.2 VM Lifecycle Implementation

```cpp
// dart_bridge.cpp
#include "dart_bridge.h"
#include <cstring>

namespace dart_mc {

// Dart VM callbacks
static Dart_Isolate create_isolate_callback(
    const char* script_uri,
    const char* main,
    const char* package_root,
    const char* package_config,
    Dart_IsolateFlags* flags,
    void* callback_data,
    char** error
) {
    // For our use case, we only create one isolate at startup
    *error = strdup("Additional isolate creation not supported");
    return nullptr;
}

static void isolate_shutdown_callback(void* isolate_group_data, void* isolate_data) {
    // Cleanup isolate-specific resources
}

static void isolate_cleanup_callback(void* isolate_group_data, void* isolate_data) {
    // Final cleanup
}

bool DartBridge::initialize(const BridgeConfig& config) {
    // 1. Initialize Dart VM
    char* init_error = nullptr;
    Dart_InitializeParams params = {};
    params.version = DART_INITIALIZE_PARAMS_CURRENT_VERSION;
    params.create_group = nullptr;  // We handle isolate creation manually
    params.shutdown_isolate = isolate_shutdown_callback;
    params.cleanup_isolate = isolate_cleanup_callback;

    if (!Dart_Initialize(&params)) {
        // Log error
        return false;
    }

    // 2. Load kernel snapshot
    // Read .dill file into memory
    uint8_t* kernel_buffer = nullptr;
    intptr_t kernel_size = 0;
    if (!load_file(config.kernel_snapshot_path, &kernel_buffer, &kernel_size)) {
        return false;
    }

    // 3. Create isolate from kernel
    Dart_IsolateFlags flags = {};
    flags.version = DART_FLAGS_CURRENT_VERSION;
    flags.enable_asserts = true;  // For development

    isolate_ = Dart_CreateIsolateGroupFromKernel(
        config.kernel_snapshot_path,  // script_uri
        "main",                        // name
        kernel_buffer,
        kernel_size,
        &flags,
        nullptr,  // isolate_group_data
        nullptr,  // isolate_data
        &init_error
    );

    if (isolate_ == nullptr) {
        // Log init_error
        free(init_error);
        return false;
    }

    // 4. Enter isolate and run initialization
    Dart_EnterIsolate(isolate_);
    Dart_EnterScope();

    // Load core libraries
    Dart_Handle root_lib = Dart_RootLibrary();
    if (Dart_IsError(root_lib)) {
        Dart_ExitScope();
        return false;
    }

    // Call Dart-side initialization
    Dart_Handle init_result = Dart_Invoke(
        root_lib,
        Dart_NewStringFromCString("_initializeBridge"),
        0,
        nullptr
    );

    if (Dart_IsError(init_result)) {
        // Log Dart_GetError(init_result)
        Dart_ExitScope();
        return false;
    }

    Dart_ExitScope();
    Dart_ExitIsolate();

    return true;
}

void DartBridge::shutdown() {
    if (isolate_ != nullptr) {
        Dart_EnterIsolate(isolate_);
        Dart_ShutdownIsolate();
        isolate_ = nullptr;
    }

    Dart_Cleanup();
}

bool DartBridge::reload_sources() {
    if (isolate_ == nullptr) return false;

    Dart_EnterIsolate(isolate_);
    Dart_EnterScope();

    // Notify Dart side that reload is starting
    Dart_Handle root_lib = Dart_RootLibrary();
    Dart_Invoke(root_lib, Dart_NewStringFromCString("_onBeforeReload"), 0, nullptr);

    // Perform the reload
    // Note: In practice, you'd use Dart_ReloadSources with the new kernel
    Dart_Handle reload_result = Dart_ReloadSources(
        // ... reload parameters
    );

    if (Dart_IsError(reload_result)) {
        // Log error, but don't crash—keep old code running
        Dart_ExitScope();
        Dart_ExitIsolate();
        return false;
    }

    // Notify Dart side that reload completed
    Dart_Invoke(root_lib, Dart_NewStringFromCString("_onAfterReload"), 0, nullptr);

    Dart_ExitScope();
    Dart_ExitIsolate();

    return true;
}

} // namespace dart_mc
```

### 2.3 JNI Interface

```cpp
// jni_interface.cpp
#include "dart_bridge.h"
#include <jni.h>

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_example_dartmc_DartBridge_nativeInitialize(
    JNIEnv* env,
    jclass clazz,
    jstring kernel_path,
    jstring sdk_path,
    jboolean enable_hot_reload
) {
    const char* kernel = env->GetStringUTFChars(kernel_path, nullptr);
    const char* sdk = env->GetStringUTFChars(sdk_path, nullptr);

    dart_mc::BridgeConfig config = {
        .kernel_snapshot_path = kernel,
        .dart_sdk_path = sdk,
        .enable_hot_reload = enable_hot_reload,
        .hot_reload_socket = "/tmp/dart_mc_reload.sock"
    };

    bool result = dart_mc::DartBridge::instance().initialize(config);

    env->ReleaseStringUTFChars(kernel_path, kernel);
    env->ReleaseStringUTFChars(sdk_path, sdk);

    return result ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_example_dartmc_DartBridge_nativeShutdown(JNIEnv* env, jclass clazz) {
    dart_mc::DartBridge::instance().shutdown();
}

JNIEXPORT jint JNICALL
Java_com_example_dartmc_DartBridge_nativeOnBlockInteract(
    JNIEnv* env,
    jclass clazz,
    jint world_id,
    jint x, jint y, jint z,
    jint player_id,
    jint hand
) {
    auto callback = dart_mc::DartBridge::instance().get_block_interact_callback();
    if (callback == nullptr) {
        return 0;  // PASS - let vanilla behavior continue
    }

    // This call goes directly into Dart code via the registered NativeCallable
    return callback(world_id, x, y, z, player_id, hand);
}

JNIEXPORT jboolean JNICALL
Java_com_example_dartmc_DartBridge_nativeReloadSources(JNIEnv* env, jclass clazz) {
    return dart_mc::DartBridge::instance().reload_sources() ? JNI_TRUE : JNI_FALSE;
}

} // extern "C"
```

### 2.4 Callback Registration (C side)

```cpp
// callback_registry.cpp
#include "dart_bridge.h"

extern "C" {

// Called from Dart via FFI to register callbacks
void dart_mc_register_block_interact(dart_mc::DartBridge::BlockInteractCallback cb) {
    dart_mc::DartBridge::instance().set_block_interact_callback(cb);
}

void dart_mc_unregister_block_interact() {
    dart_mc::DartBridge::instance().set_block_interact_callback(nullptr);
}

// Add more registration functions for other event types...

} // extern "C"
```

### 2.5 Memory Management Strategy

**Principles**:
1. **No cross-boundary allocations**: Data passed between Java↔C++↔Dart is copied, not shared
2. **Stack allocation for small structs**: BlockPos, Vec3, etc. are passed by value
3. **Handles for complex objects**: Players, Worlds, Entities use integer IDs
4. **Dart GC handles Dart objects**: Native code never holds Dart object references across calls

```cpp
// Example: Converting Java BlockPos to C struct
struct NativeBlockPos {
    int32_t x, y, z;
};

NativeBlockPos java_to_native_blockpos(JNIEnv* env, jobject blockpos) {
    jclass cls = env->GetObjectClass(blockpos);
    jmethodID getX = env->GetMethodID(cls, "getX", "()I");
    jmethodID getY = env->GetMethodID(cls, "getY", "()I");
    jmethodID getZ = env->GetMethodID(cls, "getZ", "()I");

    return NativeBlockPos {
        .x = env->CallIntMethod(blockpos, getX),
        .y = env->CallIntMethod(blockpos, getY),
        .z = env->CallIntMethod(blockpos, getZ)
    };
}
```

### 2.6 Error Handling

```cpp
// Error handling strategy
enum class BridgeError {
    None = 0,
    DartException = 1,
    InvalidCallback = 2,
    IsolateNotReady = 3,
};

// Thread-local error state (safe since we're single-threaded)
thread_local BridgeError last_error = BridgeError::None;
thread_local char last_error_message[1024] = {0};

void set_bridge_error(BridgeError error, const char* message) {
    last_error = error;
    strncpy(last_error_message, message, sizeof(last_error_message) - 1);
}

// Dart callbacks should catch exceptions and report via this mechanism
extern "C" void dart_mc_report_error(const char* message) {
    set_bridge_error(BridgeError::DartException, message);
}
```

---

## 3. Dart Mod API

### 3.1 FFI Bindings

```dart
// lib/src/ffi/bindings.dart
import 'dart:ffi';

/// C struct definitions matching native bridge
final class NativeBlockPos extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
  @Int32()
  external int z;
}

/// Callback type definitions
typedef BlockInteractCallbackNative = Int32 Function(
  Int32 worldId,
  Int32 x, Int32 y, Int32 z,
  Int32 playerId,
  Int32 hand,
);
typedef BlockInteractCallback = int Function(
  int worldId,
  int x, int y, int z,
  int playerId,
  int hand,
);

/// Native function signatures for callback registration
typedef RegisterBlockInteractNative = Void Function(
  Pointer<NativeFunction<BlockInteractCallbackNative>> callback,
);
typedef RegisterBlockInteract = void Function(
  Pointer<NativeFunction<BlockInteractCallbackNative>> callback,
);

typedef UnregisterBlockInteractNative = Void Function();
typedef UnregisterBlockInteract = void Function();

/// Bridge bindings
class DartMcBindings {
  final DynamicLibrary _lib;

  late final RegisterBlockInteract registerBlockInteract;
  late final UnregisterBlockInteract unregisterBlockInteract;

  DartMcBindings(this._lib) {
    registerBlockInteract = _lib
        .lookup<NativeFunction<RegisterBlockInteractNative>>(
            'dart_mc_register_block_interact')
        .asFunction();

    unregisterBlockInteract = _lib
        .lookup<NativeFunction<UnregisterBlockInteractNative>>(
            'dart_mc_unregister_block_interact')
        .asFunction();
  }

  static DartMcBindings? _instance;

  static DartMcBindings get instance {
    if (_instance == null) {
      // Library is already loaded by the host process
      final lib = DynamicLibrary.process();
      _instance = DartMcBindings(lib);
    }
    return _instance!;
  }
}
```

### 3.2 Event Handler Registration

```dart
// lib/src/events/event_registry.dart
import 'dart:ffi';
import '../ffi/bindings.dart';

/// Action result for event handlers
enum ActionResult {
  /// Allow the default behavior
  pass(0),
  /// Consume the event, prevent default
  success(1),
  /// Consume the event, indicate failure
  fail(2);

  final int value;
  const ActionResult(this.value);
}

/// Event handler function types
typedef BlockInteractHandler = ActionResult Function(
  World world,
  BlockPos pos,
  Player player,
  Hand hand,
);

/// Manages event handler registration with native callbacks
class EventRegistry {
  static final EventRegistry instance = EventRegistry._();
  EventRegistry._();

  // Current registered handlers
  BlockInteractHandler? _blockInteractHandler;

  // Native callback pointers (must be kept alive!)
  NativeCallable<BlockInteractCallbackNative>? _blockInteractCallable;

  /// Register a block interaction handler
  void onBlockInteract(BlockInteractHandler handler) {
    // Clean up previous registration
    _unregisterBlockInteract();

    _blockInteractHandler = handler;

    // Create the native-callable wrapper
    _blockInteractCallable = NativeCallable<BlockInteractCallbackNative>.isolateLocal(
      _handleBlockInteract,
      exceptionalReturn: ActionResult.pass.value,
    );

    // Register with native bridge
    DartMcBindings.instance.registerBlockInteract(
      _blockInteractCallable!.nativeFunction,
    );
  }

  /// Internal handler that bridges to user code
  static int _handleBlockInteract(
    int worldId,
    int x, int y, int z,
    int playerId,
    int hand,
  ) {
    final handler = instance._blockInteractHandler;
    if (handler == null) return ActionResult.pass.value;

    try {
      final world = World.fromId(worldId);
      final pos = BlockPos(x, y, z);
      final player = Player.fromId(playerId);
      final handEnum = Hand.values[hand];

      final result = handler(world, pos, player, handEnum);
      return result.value;
    } catch (e, stack) {
      // Log error but don't crash the game
      print('Error in block interact handler: $e\n$stack');
      return ActionResult.pass.value;
    }
  }

  void _unregisterBlockInteract() {
    if (_blockInteractCallable != null) {
      DartMcBindings.instance.unregisterBlockInteract();
      _blockInteractCallable!.close();
      _blockInteractCallable = null;
      _blockInteractHandler = null;
    }
  }

  /// Called before hot reload to unregister all callbacks
  void prepareForReload() {
    _unregisterBlockInteract();
    // ... unregister other handlers
  }

  /// Called after hot reload to allow re-registration
  void afterReload() {
    // User code will re-register handlers via mod initialization
  }
}
```

### 3.3 Minecraft Type Bindings

```dart
// lib/src/minecraft/types.dart

/// Represents a position in the world
class BlockPos {
  final int x;
  final int y;
  final int z;

  const BlockPos(this.x, this.y, this.z);

  BlockPos offset(int dx, int dy, int dz) => BlockPos(x + dx, y + dy, z + dz);
  BlockPos get up => offset(0, 1, 0);
  BlockPos get down => offset(0, -1, 0);
  BlockPos get north => offset(0, 0, -1);
  BlockPos get south => offset(0, 0, 1);
  BlockPos get east => offset(1, 0, 0);
  BlockPos get west => offset(-1, 0, 0);

  @override
  String toString() => 'BlockPos($x, $y, $z)';

  @override
  bool operator ==(Object other) =>
      other is BlockPos && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// Player's hand
enum Hand { mainHand, offHand }

/// Represents a player (handle-based)
class Player {
  final int _id;

  Player.fromId(this._id);

  /// Get player's current position
  BlockPos get blockPos {
    // Call into native to get position
    return _nativeGetPlayerBlockPos(_id);
  }

  /// Send a chat message to the player
  void sendMessage(String message) {
    _nativeSendPlayerMessage(_id, message);
  }

  /// Get player's name
  String get name => _nativeGetPlayerName(_id);

  // ... more player methods
}

/// Represents a world (handle-based)
class World {
  final int _id;

  World.fromId(this._id);

  /// Get block at position
  Block getBlock(BlockPos pos) {
    return _nativeGetBlock(_id, pos.x, pos.y, pos.z);
  }

  /// Set block at position
  void setBlock(BlockPos pos, Block block) {
    _nativeSetBlock(_id, pos.x, pos.y, pos.z, block.id);
  }

  /// Spawn particles
  void spawnParticles(ParticleType type, double x, double y, double z, int count) {
    _nativeSpawnParticles(_id, type.id, x, y, z, count);
  }

  // ... more world methods
}

/// Represents a block type
class Block {
  final String id;  // e.g., "minecraft:stone"

  const Block(this.id);

  static const air = Block('minecraft:air');
  static const stone = Block('minecraft:stone');
  static const dirt = Block('minecraft:dirt');
  // ... common blocks
}
```

### 3.4 Mod Definition DSL

```dart
// lib/src/mod/mod.dart

/// Base class for Dart mods
abstract class DartMod {
  /// Unique mod identifier
  String get modId;

  /// Human-readable mod name
  String get name;

  /// Mod version
  String get version;

  /// Called when mod is first loaded
  void onInitialize();

  /// Called before hot reload (save state here)
  void onBeforeReload() {}

  /// Called after hot reload (restore state here)
  void onAfterReload() {}

  /// Called when mod is being unloaded
  void onShutdown() {}
}

/// Mod registry
class ModRegistry {
  static final ModRegistry instance = ModRegistry._();
  ModRegistry._();

  final List<DartMod> _mods = [];

  void register(DartMod mod) {
    _mods.add(mod);
    mod.onInitialize();
  }

  void prepareForReload() {
    for (final mod in _mods) {
      mod.onBeforeReload();
    }
    EventRegistry.instance.prepareForReload();
  }

  void afterReload() {
    EventRegistry.instance.afterReload();
    for (final mod in _mods) {
      mod.onAfterReload();
    }
  }

  void shutdown() {
    for (final mod in _mods) {
      mod.onShutdown();
    }
    _mods.clear();
  }
}
```

### 3.5 Example Mod

```dart
// example_mod/lib/main.dart
import 'package:dart_mc/dart_mc.dart';

class ExampleMod extends DartMod {
  @override
  String get modId => 'example_mod';

  @override
  String get name => 'Example Dart Mod';

  @override
  String get version => '1.0.0';

  // State that survives hot reload
  int _interactionCount = 0;

  @override
  void onInitialize() {
    print('$name initializing...');
    _registerHandlers();
  }

  void _registerHandlers() {
    EventRegistry.instance.onBlockInteract((world, pos, player, hand) {
      _interactionCount++;

      player.sendMessage(
        'You interacted with block at $pos (total: $_interactionCount)',
      );

      // If holding main hand, place a torch above
      if (hand == Hand.mainHand) {
        final block = world.getBlock(pos);
        if (block.id != 'minecraft:air') {
          world.setBlock(pos.up, const Block('minecraft:torch'));
          return ActionResult.success;
        }
      }

      return ActionResult.pass;
    });
  }

  @override
  void onBeforeReload() {
    // State is preserved in instance fields
    print('Preparing for reload, interaction count: $_interactionCount');
  }

  @override
  void onAfterReload() {
    // Re-register handlers with potentially updated code
    _registerHandlers();
    print('Reloaded! Interaction count preserved: $_interactionCount');
  }
}

// Entry point called by native bridge
void main() {
  ModRegistry.instance.register(ExampleMod());
}

// Bridge lifecycle hooks (called from C++)
void _initializeBridge() {
  print('Dart bridge initialized');
}

void _onBeforeReload() {
  ModRegistry.instance.prepareForReload();
}

void _onAfterReload() {
  ModRegistry.instance.afterReload();
}
```

---

## 4. Fabric Mod Layer (Kotlin)

### 4.1 Main Mod Class

```kotlin
// src/main/kotlin/com/example/dartmc/DartMcMod.kt
package com.example.dartmc

import net.fabricmc.api.ModInitializer
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents
import net.fabricmc.fabric.api.event.player.UseBlockCallback
import net.minecraft.util.ActionResult
import org.slf4j.LoggerFactory
import java.nio.file.Path

class DartMcMod : ModInitializer {
    private val logger = LoggerFactory.getLogger("dart-mc")

    override fun onInitialize() {
        logger.info("Initializing Dart-MC bridge...")

        // Load native library
        val libPath = findNativeLibrary()
        System.load(libPath.toString())

        // Find Dart kernel snapshot
        val kernelPath = findKernelSnapshot()
        val sdkPath = findDartSdk()

        // Initialize Dart VM
        val success = DartBridge.initialize(
            kernelPath.toString(),
            sdkPath.toString(),
            enableHotReload = isDevelopmentMode()
        )

        if (!success) {
            logger.error("Failed to initialize Dart bridge!")
            return
        }

        logger.info("Dart bridge initialized successfully")

        // Register event proxies
        registerEventProxies()

        // Setup hot reload watcher in dev mode
        if (isDevelopmentMode()) {
            HotReloadWatcher.start(kernelPath.parent)
        }

        // Cleanup on shutdown
        ServerLifecycleEvents.SERVER_STOPPING.register { _ ->
            DartBridge.shutdown()
        }
    }

    private fun registerEventProxies() {
        // Block interaction
        UseBlockCallback.EVENT.register { player, world, hand, hitResult ->
            val result = DartBridge.onBlockInteract(
                WorldRegistry.getId(world),
                hitResult.blockPos.x,
                hitResult.blockPos.y,
                hitResult.blockPos.z,
                PlayerRegistry.getId(player),
                hand.ordinal
            )

            when (result) {
                1 -> ActionResult.SUCCESS
                2 -> ActionResult.FAIL
                else -> ActionResult.PASS
            }
        }

        // ... register more event proxies
    }

    private fun findNativeLibrary(): Path {
        // Platform-specific library name
        val libName = when {
            System.getProperty("os.name").lowercase().contains("win") -> "dart_mc_bridge.dll"
            System.getProperty("os.name").lowercase().contains("mac") -> "libdart_mc_bridge.dylib"
            else -> "libdart_mc_bridge.so"
        }

        // Look in mod's native directory
        return Path.of("mods/dart-mc/native/$libName")
    }

    private fun findKernelSnapshot(): Path {
        return Path.of("mods/dart-mc/dart/app.dill")
    }

    private fun findDartSdk(): Path {
        // Could be bundled or use system Dart
        return Path.of(System.getenv("DART_SDK") ?: "/usr/lib/dart")
    }

    private fun isDevelopmentMode(): Boolean {
        return System.getenv("DART_MC_DEV") == "1"
    }
}
```

### 4.2 JNI Bridge Interface

```kotlin
// src/main/kotlin/com/example/dartmc/DartBridge.kt
package com.example.dartmc

object DartBridge {
    @JvmStatic
    external fun nativeInitialize(
        kernelPath: String,
        sdkPath: String,
        enableHotReload: Boolean
    ): Boolean

    @JvmStatic
    external fun nativeShutdown()

    @JvmStatic
    external fun nativeOnBlockInteract(
        worldId: Int,
        x: Int, y: Int, z: Int,
        playerId: Int,
        hand: Int
    ): Int

    @JvmStatic
    external fun nativeReloadSources(): Boolean

    fun initialize(kernelPath: String, sdkPath: String, enableHotReload: Boolean): Boolean {
        return nativeInitialize(kernelPath, sdkPath, enableHotReload)
    }

    fun shutdown() {
        nativeShutdown()
    }

    fun onBlockInteract(worldId: Int, x: Int, y: Int, z: Int, playerId: Int, hand: Int): Int {
        return nativeOnBlockInteract(worldId, x, y, z, playerId, hand)
    }

    fun reloadSources(): Boolean {
        return nativeReloadSources()
    }
}
```

### 4.3 Object Registries (Handle System)

```kotlin
// src/main/kotlin/com/example/dartmc/registry/WorldRegistry.kt
package com.example.dartmc.registry

import net.minecraft.world.World
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/**
 * Maps World instances to integer IDs for cross-boundary references.
 * IDs are stable for the lifetime of the world.
 */
object WorldRegistry {
    private val worldToId = ConcurrentHashMap<World, Int>()
    private val idToWorld = ConcurrentHashMap<Int, World>()
    private val nextId = AtomicInteger(1)

    fun getId(world: World): Int {
        return worldToId.computeIfAbsent(world) { w ->
            val id = nextId.getAndIncrement()
            idToWorld[id] = w
            id
        }
    }

    fun getWorld(id: Int): World? = idToWorld[id]

    fun remove(world: World) {
        worldToId.remove(world)?.let { id ->
            idToWorld.remove(id)
        }
    }
}

// Similar registries for Player, Entity, etc.
```

### 4.4 Hot Reload Watcher

```kotlin
// src/main/kotlin/com/example/dartmc/HotReloadWatcher.kt
package com.example.dartmc

import org.slf4j.LoggerFactory
import java.nio.file.*

object HotReloadWatcher {
    private val logger = LoggerFactory.getLogger("dart-mc-hotreload")
    private var watchThread: Thread? = null

    fun start(dartDir: Path) {
        watchThread = Thread({
            val watchService = FileSystems.getDefault().newWatchService()
            dartDir.register(watchService, StandardWatchEventKinds.ENTRY_MODIFY)

            logger.info("Hot reload watcher started for $dartDir")

            while (!Thread.currentThread().isInterrupted) {
                val key = watchService.take()

                for (event in key.pollEvents()) {
                    val path = event.context() as? Path ?: continue

                    if (path.toString().endsWith(".dill")) {
                        logger.info("Detected kernel change, triggering hot reload...")

                        // Small delay to ensure file is fully written
                        Thread.sleep(100)

                        val success = DartBridge.reloadSources()
                        if (success) {
                            logger.info("Hot reload successful!")
                        } else {
                            logger.warn("Hot reload failed, keeping previous state")
                        }
                    }
                }

                key.reset()
            }
        }, "DartMC-HotReload")

        watchThread?.isDaemon = true
        watchThread?.start()
    }

    fun stop() {
        watchThread?.interrupt()
        watchThread = null
    }
}
```

---

## 5. Build System

### 5.1 Project Structure

```
dart-mc/
├── fabric-mod/                    # Kotlin/Java Fabric mod
│   ├── build.gradle.kts
│   ├── src/main/kotlin/
│   └── src/main/resources/
│       └── fabric.mod.json
│
├── native-bridge/                 # C++ native library
│   ├── CMakeLists.txt
│   ├── src/
│   │   ├── dart_bridge.cpp
│   │   ├── dart_bridge.h
│   │   └── jni_interface.cpp
│   └── include/
│
├── dart-runtime/                  # Dart mod runtime library
│   ├── pubspec.yaml
│   └── lib/
│       ├── dart_mc.dart
│       └── src/
│
├── example-mod/                   # Example Dart mod
│   ├── pubspec.yaml
│   └── lib/
│       └── main.dart
│
├── scripts/
│   ├── build-all.sh
│   ├── build-native.sh
│   └── compile-dart.sh
│
└── README.md
```

### 5.2 Gradle Build (Fabric Mod)

```kotlin
// fabric-mod/build.gradle.kts
plugins {
    kotlin("jvm") version "1.9.22"
    id("fabric-loom") version "1.5-SNAPSHOT"
}

version = "1.0.0"
group = "com.example"

repositories {
    mavenCentral()
}

dependencies {
    minecraft("com.mojang:minecraft:1.20.4")
    mappings("net.fabricmc:yarn:1.20.4+build.3:v2")
    modImplementation("net.fabricmc:fabric-loader:0.15.6")
    modImplementation("net.fabricmc.fabric-api:fabric-api:0.95.4+1.20.4")
    modImplementation("net.fabricmc:fabric-language-kotlin:1.10.17+kotlin.1.9.22")
}

tasks.processResources {
    inputs.property("version", project.version)

    filesMatching("fabric.mod.json") {
        expand("version" to project.version)
    }
}

// Copy native libraries to output
tasks.register<Copy>("copyNativeLibs") {
    from("../native-bridge/build/lib")
    into("build/libs/native")
}

// Copy Dart kernel to output
tasks.register<Copy>("copyDartKernel") {
    from("../example-mod/build/app.dill")
    into("build/libs/dart")
}

tasks.named("build") {
    dependsOn("copyNativeLibs", "copyDartKernel")
}
```

### 5.3 CMake Build (Native Bridge)

```cmake
# native-bridge/CMakeLists.txt
cmake_minimum_required(VERSION 3.16)
project(dart_mc_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find JNI
find_package(JNI REQUIRED)

# Dart SDK path (from environment or parameter)
set(DART_SDK "$ENV{DART_SDK}" CACHE PATH "Path to Dart SDK")
if(NOT DART_SDK)
    message(FATAL_ERROR "DART_SDK not set. Please set DART_SDK environment variable.")
endif()

# Include directories
include_directories(
    ${JNI_INCLUDE_DIRS}
    ${DART_SDK}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Link directories
link_directories(
    ${DART_SDK}/bin
)

# Source files
set(SOURCES
    src/dart_bridge.cpp
    src/jni_interface.cpp
    src/callback_registry.cpp
)

# Create shared library
add_library(dart_mc_bridge SHARED ${SOURCES})

# Link libraries
if(WIN32)
    target_link_libraries(dart_mc_bridge dart)
elseif(APPLE)
    target_link_libraries(dart_mc_bridge
        "-framework CoreFoundation"
        ${DART_SDK}/bin/libdart.dylib
    )
else()
    target_link_libraries(dart_mc_bridge dart pthread dl)
endif()

# Output directory
set_target_properties(dart_mc_bridge PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
)
```

### 5.4 Dart Compilation Script

```bash
#!/bin/bash
# scripts/compile-dart.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

RUNTIME_DIR="$PROJECT_ROOT/dart-runtime"
MOD_DIR="$PROJECT_ROOT/example-mod"
OUTPUT_DIR="$MOD_DIR/build"

mkdir -p "$OUTPUT_DIR"

# Get dependencies
cd "$RUNTIME_DIR"
dart pub get

cd "$MOD_DIR"
dart pub get

# Compile to kernel snapshot
echo "Compiling Dart mod to kernel..."
dart compile kernel \
    lib/main.dart \
    -o "$OUTPUT_DIR/app.dill"

echo "Kernel snapshot created at $OUTPUT_DIR/app.dill"

# For development: start incremental compiler
if [ "$1" == "--watch" ]; then
    echo "Starting incremental compilation watch..."
    # Use dart development compiler for incremental builds
    dart run build_runner watch --output "$OUTPUT_DIR"
fi
```

### 5.5 Full Build Script

```bash
#!/bin/bash
# scripts/build-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Building Dart-MC Bridge ==="

# 1. Build native library
echo "Building native bridge..."
cd "$PROJECT_ROOT/native-bridge"
mkdir -p build
cd build
cmake ..
cmake --build . --config Release

# 2. Compile Dart code
echo "Compiling Dart mod..."
"$SCRIPT_DIR/compile-dart.sh"

# 3. Build Fabric mod
echo "Building Fabric mod..."
cd "$PROJECT_ROOT/fabric-mod"
./gradlew build

# 4. Package everything
echo "Packaging..."
OUTPUT="$PROJECT_ROOT/dist"
mkdir -p "$OUTPUT"

cp "$PROJECT_ROOT/fabric-mod/build/libs/"*.jar "$OUTPUT/"
mkdir -p "$OUTPUT/dart-mc/native"
mkdir -p "$OUTPUT/dart-mc/dart"

# Copy native library (platform-specific)
if [[ "$OSTYPE" == "darwin"* ]]; then
    cp "$PROJECT_ROOT/native-bridge/build/lib/libdart_mc_bridge.dylib" "$OUTPUT/dart-mc/native/"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    cp "$PROJECT_ROOT/native-bridge/build/lib/dart_mc_bridge.dll" "$OUTPUT/dart-mc/native/"
else
    cp "$PROJECT_ROOT/native-bridge/build/lib/libdart_mc_bridge.so" "$OUTPUT/dart-mc/native/"
fi

cp "$PROJECT_ROOT/example-mod/build/app.dill" "$OUTPUT/dart-mc/dart/"

echo "=== Build complete! ==="
echo "Output in: $OUTPUT"
```

---

## 6. Development Workflow

### 6.1 Hot Reload Flow

```
Developer edits Dart code
         │
         ▼
┌─────────────────────────────────────┐
│ File watcher detects .dart change   │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ Incremental kernel compiler runs    │
│ (dart compile kernel --incremental) │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ New .dill file written              │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ HotReloadWatcher detects .dill      │
│ change and calls DartBridge.reload  │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ Native bridge calls Dart lifecycle: │
│ 1. _onBeforeReload()                │
│ 2. Dart_ReloadSources()             │
│ 3. _onAfterReload()                 │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ Mod re-registers event handlers     │
│ with updated code                   │
└────────────────┬────────────────────┘
                 │
                 ▼
     New code active in game!
     (State preserved via mod fields)
```

### 6.2 IDE Setup (VS Code)

**.vscode/launch.json**:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to Dart in Minecraft",
      "type": "dart",
      "request": "attach",
      "vmServiceUri": "${env:DART_VM_SERVICE_URI}",
      "cwd": "${workspaceFolder}/example-mod"
    }
  ]
}
```

**.vscode/tasks.json**:
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Build All",
      "type": "shell",
      "command": "./scripts/build-all.sh",
      "group": "build"
    },
    {
      "label": "Watch Dart",
      "type": "shell",
      "command": "./scripts/compile-dart.sh --watch",
      "isBackground": true,
      "problemMatcher": {
        "pattern": {
          "regexp": "^(.*):(\\d+):(\\d+): (.*)$",
          "file": 1,
          "line": 2,
          "column": 3,
          "message": 4
        },
        "background": {
          "activeOnStart": true,
          "beginsPattern": "^Compiling",
          "endsPattern": "^Kernel snapshot created"
        }
      }
    }
  ]
}
```

### 6.3 Development Commands

```bash
# First time setup
./scripts/build-all.sh

# Start Minecraft with mod
cd fabric-mod
./gradlew runServer

# In another terminal: watch Dart changes
DART_MC_DEV=1 ./scripts/compile-dart.sh --watch

# Connect debugger (optional)
# VM service URI is printed when Minecraft starts with DART_MC_DEV=1
```

---

## 7. Implementation Phases

### Phase 1: Proof of Concept (Dart Prints in MC)

**Goal**: Verify the basic architecture works.

**Tasks**:
1. Create minimal Fabric mod that loads native library
2. Implement Dart VM initialization in C++
3. Create simple Dart program that prints "Hello from Dart!"
4. Verify print output appears in MC console

**Success Criteria**: "Hello from Dart!" appears in Minecraft server console on startup.

**Estimated Complexity**: Low

---

### Phase 2: Bidirectional Callbacks

**Goal**: Establish reliable Dart↔Java communication.

**Tasks**:
1. Implement `NativeCallable.isolateLocal` callback registration
2. Create block interaction event proxy
3. Implement handle system for World/Player references
4. Add native functions for World.setBlock, Player.sendMessage
5. Create example: clicking a block sends chat message

**Success Criteria**:
- Right-clicking a block triggers Dart callback
- Dart code can send message to player
- No crashes or memory leaks after 100 interactions

**Estimated Complexity**: Medium

---

### Phase 3: Hot Reload Integration

**Goal**: Enable code changes without restarting Minecraft.

**Tasks**:
1. Implement hot reload lifecycle hooks in Dart
2. Create file watcher in Kotlin for .dill changes
3. Implement `Dart_ReloadSources` integration
4. Handle callback re-registration after reload
5. Test state preservation across reloads

**Success Criteria**:
- Change Dart code → save → see changes in-game within 2 seconds
- Counter variable preserves value across reloads
- No crashes during rapid reload cycles

**Estimated Complexity**: High

---

### Phase 4: Full Minecraft API Bindings

**Goal**: Comprehensive API for mod development.

**Tasks**:
1. Implement all common event types (see Section 8)
2. Create block/item/entity access APIs
3. Add world manipulation functions
4. Implement particle and sound effects
5. Create scheduler for delayed/repeated tasks
6. Add configuration file support
7. Write comprehensive documentation

**Success Criteria**:
- Can implement a non-trivial mod entirely in Dart
- All documented APIs work reliably
- Performance is comparable to Java mods

**Estimated Complexity**: High

---

## 8. API Reference

### 8.1 Core Callback Signatures (C ABI)

```c
// Block events
typedef int32_t (*block_interact_callback)(
    int32_t world_id,
    int32_t x, int32_t y, int32_t z,
    int32_t player_id,
    int32_t hand
);

typedef void (*block_break_callback)(
    int32_t world_id,
    int32_t x, int32_t y, int32_t z,
    int32_t player_id
);

typedef void (*block_place_callback)(
    int32_t world_id,
    int32_t x, int32_t y, int32_t z,
    int32_t player_id,
    int32_t block_state_id
);

// Entity events
typedef void (*entity_spawn_callback)(
    int32_t world_id,
    int32_t entity_id,
    int32_t entity_type_id,
    double x, double y, double z
);

typedef void (*entity_damage_callback)(
    int32_t world_id,
    int32_t entity_id,
    int32_t source_type,
    int32_t attacker_id,  // 0 if none
    float amount
);

typedef void (*entity_death_callback)(
    int32_t world_id,
    int32_t entity_id,
    int32_t killer_id  // 0 if none
);

// Player events
typedef void (*player_join_callback)(int32_t player_id);
typedef void (*player_leave_callback)(int32_t player_id);
typedef int32_t (*player_chat_callback)(
    int32_t player_id,
    const char* message
);

// World events
typedef void (*world_tick_callback)(int32_t world_id);

// Server events
typedef void (*server_start_callback)(void);
typedef void (*server_stop_callback)(void);
```

### 8.2 Minecraft Event Types (Dart)

```dart
/// Event types and their Dart handler signatures

// Block Events
typedef BlockInteractHandler = ActionResult Function(
  World world, BlockPos pos, Player player, Hand hand);

typedef BlockBreakHandler = void Function(
  World world, BlockPos pos, Player player);

typedef BlockPlaceHandler = void Function(
  World world, BlockPos pos, Player player, Block block);

// Entity Events
typedef EntitySpawnHandler = void Function(
  World world, Entity entity, Vec3 position);

typedef EntityDamageHandler = void Function(
  World world, Entity entity, DamageSource source, double amount);

typedef EntityDeathHandler = void Function(
  World world, Entity entity, Entity? killer);

// Player Events
typedef PlayerJoinHandler = void Function(Player player);
typedef PlayerLeaveHandler = void Function(Player player);
typedef PlayerChatHandler = ActionResult Function(
  Player player, String message);

// World Events
typedef WorldTickHandler = void Function(World world);

// Server Events
typedef ServerStartHandler = void Function();
typedef ServerStopHandler = void Function();
```

### 8.3 Return Value Conventions

| Return Value | Meaning |
|-------------|---------|
| `0` / `ActionResult.pass` | Allow default behavior to continue |
| `1` / `ActionResult.success` | Event handled, prevent default, indicate success |
| `2` / `ActionResult.fail` | Event handled, prevent default, indicate failure |

### 8.4 Native Functions (Dart → Java/MC)

```dart
// World operations
external Block _nativeGetBlock(int worldId, int x, int y, int z);
external void _nativeSetBlock(int worldId, int x, int y, int z, String blockId);
external void _nativeSpawnParticles(
    int worldId, String particleId, double x, double y, double z, int count);
external void _nativePlaySound(
    int worldId, String soundId, double x, double y, double z,
    double volume, double pitch);

// Player operations
external String _nativeGetPlayerName(int playerId);
external BlockPos _nativeGetPlayerBlockPos(int playerId);
external Vec3 _nativeGetPlayerPos(int playerId);
external void _nativeSendPlayerMessage(int playerId, String message);
external void _nativeTeleportPlayer(int playerId, double x, double y, double z);
external ItemStack _nativeGetPlayerHeldItem(int playerId, int hand);

// Entity operations
external Vec3 _nativeGetEntityPos(int entityId);
external void _nativeSetEntityVelocity(int entityId, double x, double y, double z);
external void _nativeDamageEntity(int entityId, double amount, String sourceType);
external void _nativeRemoveEntity(int entityId);

// Server operations
external void _nativeBroadcastMessage(String message);
external List<int> _nativeGetOnlinePlayers();
external void _nativeRunCommand(String command);
```

---

## Appendix A: Error Codes

| Code | Name | Description |
|------|------|-------------|
| 0 | Success | Operation completed successfully |
| 1 | DartException | Dart code threw an unhandled exception |
| 2 | InvalidCallback | Callback pointer was null or invalid |
| 3 | IsolateNotReady | Dart isolate not initialized |
| 4 | VMInitFailed | Failed to initialize Dart VM |
| 5 | KernelLoadFailed | Failed to load kernel snapshot |
| 6 | ReloadFailed | Hot reload failed |

---

## Appendix B: Platform-Specific Notes

### Windows
- Native library: `dart_mc_bridge.dll`
- Requires Visual C++ Redistributable
- Use `LoadLibraryW` for Unicode paths

### macOS
- Native library: `libdart_mc_bridge.dylib`
- May need code signing for distribution
- Use `@rpath` for library loading

### Linux
- Native library: `libdart_mc_bridge.so`
- Set `LD_LIBRARY_PATH` or use `rpath`
- Ensure glibc compatibility

---

## Appendix C: Future Considerations

### Potential Enhancements
1. **Multi-isolate support**: Run mods in separate isolates for fault isolation
2. **Async task queue**: For long-running operations that shouldn't block game tick
3. **Dart DevTools integration**: Full debugging and profiling support
4. **Pre-compiled snapshots**: AOT compilation for production performance
5. **Mod sandboxing**: Restrict API access for untrusted mods

### Known Limitations
1. No direct Minecraft class reflection from Dart
2. Cannot create new block/item types (only proxy existing ones)
3. Hot reload requires careful state management
4. Single-threaded limits parallelism
