# Research Report: Embedding the Dart VM in a Host Application

## Overview

Embedding the Dart VM allows native applications (C/C++, games, etc.) to use Dart as a scripting or logic language, similar to how Lua is commonly used. While possible, it requires building the Dart VM from source and understanding several complex APIs.

## Key Information

- **Current Version**: Dart 3.x (SDK must match kernel file format)
- **Platforms Supported**: Windows x64, Linux x64, macOS x64/ARM64
- **Official Docs**: [dart_api.h](https://github.com/dart-lang/sdk/blob/main/runtime/include/dart_api.h)
- **Key Examples**: [fuzzybinary/dart-embedding-example](https://github.com/fuzzybinary/dart-embedding-example), [dart_shared_library](https://github.com/fuzzybinary/dart_shared_library)

---

## 1. Dart VM Embedding APIs

### Core Header Files

The embedding API is defined in these headers from the Dart SDK:
- **`dart_api.h`** - Main embedding API with isolate management, handle types, and code execution
- **`dart_native_api.h`** - Native port communication and message passing
- **`dart_api_dl.h`** - Dynamic linking version for FFI usage

### Initialization Process

```cpp
// 1. Initialize VM with params
Dart_InitializeParams params;
Dart_InitializeParamsSetDefaults(&params);
char* error = Dart_Initialize(&params);

// 2. Create isolate from kernel binary (.dill file)
Dart_Isolate isolate = Dart_CreateIsolateGroupFromKernel(
    script_uri,
    name,
    kernel_buffer,
    kernel_size,
    flags,
    isolate_group_data,
    isolate_data,
    &error
);

// 3. Enter scope for handle management
Dart_EnterScope();

// 4. Execute Dart code
Dart_Handle result = Dart_Invoke(
    Dart_RootLibrary(),
    Dart_NewStringFromCString("main"),
    0, nullptr
);

// 5. Cleanup
Dart_ExitScope();
Dart_ShutdownIsolate();
Dart_Cleanup();
```

### Key API Functions

| Function | Purpose |
|----------|---------|
| `Dart_Initialize()` | Initialize the Dart VM |
| `Dart_CreateIsolateGroupFromKernel()` | Create isolate from .dill file |
| `Dart_EnterIsolate()` / `Dart_ExitIsolate()` | Thread-isolate binding |
| `Dart_EnterScope()` / `Dart_ExitScope()` | Handle scope management |
| `Dart_Invoke()` | Call a Dart function |
| `Dart_RunLoop()` | Run the message queue event loop |
| `Dart_HandleMessage()` | Process a single message |
| `Dart_ShutdownIsolate()` | Terminate an isolate |
| `Dart_Cleanup()` | Final VM cleanup |

### Handle Types

- **Local Handles**: Scoped, auto-collected when scope exits
- **Persistent Handles**: Survive across scopes, manually deleted via `Dart_DeletePersistentHandle()`

---

## 2. Building the Dart VM as a Shared Library

### The Challenge

Dart doesn't provide pre-built embedding libraries. The SDK's `libdart` is designed for extensions, not embedding. You must build from source.

### Build Process (dart_shared_library project)

```bash
# 1. Clone and setup
git clone https://github.com/aspect-build/aspect-workflows
depot_tools fetch dart

# 2. Apply patches to Dart SDK build files
dart run build_dart.dart

# 3. Build using GN/Ninja
gn gen out/Release --args='...'
ninja -C out/Release libdart

# 4. Result: libdart.so / libdart.dll / libdart.dylib
```

### Platform Support

| Platform | Status | Output |
|----------|--------|--------|
| Windows x64 | ✅ Supported | `dart.dll` |
| Linux x64 | ✅ Supported | `libdart.so` |
| macOS x64 | ✅ Supported | `libdart.dylib` |
| macOS ARM64 | ✅ Local build | `libdart.dylib` |
| Android/iOS | ⚠️ More complex | Via Flutter |

### Library Size and Dependencies

- Full library with JIT: ~30-50MB (estimated)
- Requires C++ runtime (MSVC, libstdc++, libc++)
- Service isolate and kernel isolate add overhead

### Library Configurations Available

1. **Full JIT** - Source/dill compilation, debugging, hot reload
2. **AOT-only** - Pre-compiled snapshots, smaller, no hot reload
3. **With/without kernel isolate** - For source compilation vs pre-compiled only

---

## 3. Communication Patterns

### Native Ports (Primary Mechanism)

Native ports allow bidirectional async communication between C/C++ and Dart:

**Dart Side:**
```dart
import 'dart:ffi';
import 'dart:isolate';

// Create receive port
final receivePort = ReceivePort();
receivePort.listen((message) {
  print('Received from native: $message');
});

// Pass native port to C++
final nativePort = receivePort.sendPort.nativePort;
_setNativePort(nativePort);
```

**C++ Side:**
```cpp
#include "dart_api_dl.h"

Dart_Port dart_port;

void SetNativePort(int64_t port) {
    dart_port = port;
}

void SendToDart(const char* message) {
    Dart_CObject obj;
    obj.type = Dart_CObject_kString;
    obj.value.as_string = message;
    Dart_PostCObject_DL(dart_port, &obj);  // Thread-safe!
}
```

### Dart_CObject Message Types

```cpp
typedef enum {
  Dart_CObject_kNull,
  Dart_CObject_kBool,
  Dart_CObject_kInt32,
  Dart_CObject_kInt64,
  Dart_CObject_kDouble,
  Dart_CObject_kString,
  Dart_CObject_kArray,
  Dart_CObject_kTypedData,
  Dart_CObject_kSendPort,
  Dart_CObject_kNativePointer,
  // ...
} Dart_CObject_Type;
```

### FFI Callbacks (Native to Dart)

```dart
// Dart: Define a callback
void myCallback(int value) {
  print('Called with: $value');
}

// Get native function pointer
final callbackPointer = Pointer.fromFunction<Void Function(Int32)>(myCallback);

// Pass to native code
_registerCallback(callbackPointer);
```

### Native Functions (Dart to Native)

```dart
@pragma('vm:external-name', 'NativeAdd')
external int add(int a, int b);
```

```cpp
// C++: Implement resolver
Dart_NativeFunction ResolveName(Dart_Handle name, int argc, bool* auto_setup) {
    const char* cname;
    Dart_StringToCString(name, &cname);
    if (strcmp(cname, "NativeAdd") == 0) return NativeAdd;
    return nullptr;
}

void NativeAdd(Dart_NativeArguments args) {
    int64_t a, b;
    Dart_GetNativeIntegerArgument(args, 0, &a);
    Dart_GetNativeIntegerArgument(args, 1, &b);
    Dart_SetIntegerReturnValue(args, a + b);
}
```

---

## 4. Hot Reload in Embedded Context

### Can It Work?

**Yes, with requirements:**

1. **JIT mode required** - AOT compilation doesn't support hot reload
2. **VM Service must be enabled** - `--enable-vm-service`
3. **Kernel isolate needed** - For recompiling source to kernel

### How It Works

Hot reload uses the VM Service Protocol's `reloadSources` RPC:

```dart
// Using vm_service package
final vmService = await vmServiceConnectUri('ws://127.0.0.1:8181/ws');
await vmService.reloadSources(isolateId);
```

### The hotreloader Package

For embedded contexts, the [hotreloader](https://pub.dev/packages/hotreloader) package can be adapted:

```dart
// Monitors source files and triggers reload
final reloader = await HotReloader.create(
  debounceInterval: Duration(milliseconds: 500),
  onAfterReload: (result) => print('Reload: ${result.status}'),
);
```

### Requirements for Embedded Hot Reload

1. Start with debugging enabled: `--enable-vm-service --disable-service-auth-codes`
2. Keep kernel isolate running for recompilation
3. Source files must be accessible at their original paths
4. Connect to VM service at `localhost:8181` (default)

### Limitations

- **Not for AOT** - Only works with JIT compilation
- **Main isolate only** - Spawned isolates don't get updates automatically
- **State preserved** - But some state (like closures capturing old code) may cause issues
- **Performance overhead** - Debugging/service infrastructure adds latency

---

## 5. Existing Projects and Examples

### Flutter Engine (Production Example)

Flutter is the largest example of Dart VM embedding:

**Architecture:**
- C++ engine embeds Dart VM
- `dart:ui` library provides Skia bindings
- 4 task runners: Platform, UI (Dart execution), Raster, IO
- Each FlutterEngine creates its own Dart isolate

**Key Insights:**
- Threading is embedder-managed, not VM-managed
- Multiple engines share one VM instance
- Communication via platform channels (MethodChannel)

**Reference:** [Flutter Engine Architecture](https://github.com/flutter/flutter/blob/master/docs/about/The-Engine-architecture.md)

### godot_dart (Game Engine)

[godot_dart](https://github.com/fuzzybinary/godot_dart) embeds Dart in Godot Engine:

**Features:**
- Uses custom dart_shared_library
- Hot reload integrated with Godot's file reload
- C++ bindings via godot-cpp
- Performance optimizations pending

**Lessons:**
- Hot reload can work in game context
- Vector/Math types need native variants for performance
- Memory management with RefCounted objects works

### JNI Integration (Android)

For Android/JVM platforms, use [jnigen](https://pub.dev/packages/jnigen):

```yaml
# pubspec.yaml
dependencies:
  jni: ^0.7.0
dev_dependencies:
  jnigen: ^0.7.0
```

**How it works:**
- Generates Dart bindings from Java/Kotlin code
- Uses JNI under the hood
- On Android, runs embedded in Android JVM
- On desktop, spawns JVM via `Jni.spawn()`

---

## 6. Isolate Model Considerations

### Thread-Isolate Relationship

- One mutator thread per isolate at a time
- OS thread can enter only one isolate at a time
- Isolate groups share heap and GC
- Helper threads (JIT, GC) are separate

### Message Passing

Isolates communicate only through ports:
- `SendPort` / `ReceivePort` in Dart
- `Dart_Port` / `Dart_PostCObject` from native
- Messages are copied, not shared

### Native Code Interop Challenges

Native code doesn't understand isolates:
- Platform-specific APIs may require main thread
- Callbacks from native threads need `NativeCallable.shared`
- Thread-pinned APIs (UI thread, @MainActor) require careful handling

---

## 7. Implementation Recommendations

### For a New Embedding Project

1. **Start with dart_shared_library** - Don't build VM from scratch
2. **Use kernel (.dill) files** - Not raw .dart source
3. **Implement native ports** - For bidirectional communication
4. **Consider hot reload from start** - Easier to add early than retrofit
5. **Test on target platforms early** - Platform quirks vary

### Minimal Viable Embedding

```cpp
// Simplified flow
int main() {
    // 1. Initialize
    Dart_InitializeParams params = {};
    Dart_InitializeParamsSetDefaults(&params);
    Dart_Initialize(&params);

    // 2. Load kernel
    uint8_t* kernel = ReadFile("app.dill", &kernel_size);

    // 3. Create isolate
    Dart_Isolate isolate = Dart_CreateIsolateGroupFromKernel(
        "file:///app.dill", "main", kernel, kernel_size,
        nullptr, nullptr, nullptr, &error);

    // 4. Run main()
    Dart_EnterScope();
    Dart_Invoke(Dart_RootLibrary(),
                Dart_NewStringFromCString("main"), 0, nullptr);
    Dart_ExitScope();

    // 5. Cleanup
    Dart_ShutdownIsolate();
    Dart_Cleanup();
}
```

---

## Summary

**Key Findings:**

1. **Embedding is possible but complex** - No official pre-built libraries; must build from source
2. **Use dart_shared_library** - Fuzzybinary's project handles build complexity
3. **Native ports are the communication backbone** - Thread-safe, async, bidirectional
4. **Hot reload works in embedded context** - Requires JIT mode and VM service
5. **Flutter engine is the reference implementation** - Study its architecture for patterns
6. **Isolate model impacts design** - Plan for message-passing architecture

**Resources:**
- [dart_api.h](https://github.com/dart-lang/sdk/blob/main/runtime/include/dart_api.h) - Core API
- [dart_shared_library](https://github.com/fuzzybinary/dart_shared_library) - Build Dart as shared lib
- [dart-embedding-example](https://github.com/fuzzybinary/dart-embedding-example) - C++ embedding example
- [godot_dart](https://github.com/fuzzybinary/godot_dart) - Game engine embedding
- [Dart VM Internals](https://mrale.ph/dartvm/) - Deep technical reference
- [hotreloader package](https://pub.dev/packages/hotreloader) - Hot reload implementation
- [Flutter Engine Architecture](https://github.com/flutter/flutter/blob/master/docs/about/The-Engine-architecture.md)
