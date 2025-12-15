# Native MC Bridge

C++ native bridge for Redstone - connects Java (via JNI) to Dart (via FFI).

## Overview

This package contains the native C++ library that:

1. Embeds the Dart VM using `dart_dll`
2. Provides JNI bindings for Java to call into Dart
3. Manages Dart isolate lifecycle
4. Handles event dispatch between Java and Dart

## Architecture

```
┌─────────────────┐     JNI      ┌─────────────────┐     FFI      ┌─────────────────┐
│   Minecraft     │◄────────────►│   Native Bridge │◄────────────►│    Dart VM      │
│   (Java)        │              │   (C++)         │              │   (dart_dll)    │
└─────────────────┘              └─────────────────┘              └─────────────────┘
```

## Package Structure

```
native_mc_bridge/
├── src/
│   ├── dart_bridge.cpp/.h      # Dart VM lifecycle
│   ├── jni_interface.cpp       # JNI bindings
│   ├── generic_jni.cpp/.h      # Dynamic JNI calls from Dart
│   ├── callback_registry.h     # Event callback storage
│   └── object_registry.h       # Java object handle management
├── deps/
│   └── dart_dll/               # Dart VM shared library
│       ├── include/            # Headers
│       └── lib/                # libdart_dll.dylib/so/dll
├── build/                      # CMake build output
└── CMakeLists.txt
```

## Building

### Prerequisites

- CMake 3.21+
- C++17 compiler (clang, gcc, MSVC)
- JDK 21+ (for JNI headers)
- dart_dll library (in `deps/dart_dll/`)

### Build Commands

```bash
cd packages/native_mc_bridge
cmake -B build .
cmake --build build --config release
```

### Output

The build produces `dart_mc_bridge.dylib` (macOS), `dart_mc_bridge.dll` (Windows), or `libdart_mc_bridge.so` (Linux).

## Dependencies

### dart_dll

The Dart VM is embedded via [dart_shared_library](https://github.com/fuzzybinary/dart_shared_library).

For x64 platforms, download pre-built binaries from GitHub releases.
For ARM64 macOS, you'll need to build from source (see main README).

## Platform Support

| Platform | Status |
|----------|--------|
| macOS ARM64 (M1/M2/M3) | ✅ |
| macOS x64 | ✅ |
| Linux x64 | ✅ |
| Windows x64 | ✅ |
