# Flutter Cache Architecture

Redstone manages a global cache at `~/.redstone/` to store Flutter SDK artifacts with matching SDK hashes. This document explains the cache structure, why it exists, and how it prevents version mismatch errors.

## The Problem: SDK Hash Mismatches

Flutter's Dart VM and compiler tools embed an **SDK hash** - a unique identifier for a specific build of the Dart SDK. When you compile Dart code to a kernel binary, the SDK hash is embedded in the output. At runtime, the Flutter engine (FlutterEmbedder) verifies this hash matches its own.

**The issue**: Redstone uses a **custom-built Flutter engine** to run Dart code inside Minecraft. Our custom engine has a different SDK hash than official Flutter releases from Google. If we use Google's `flutter build` command with our custom embedder, we get:

```
[ERROR] Can't load Kernel binary: Invalid kernel binary format version
```

This happens because:
- Official Flutter SDK artifacts have hash: `8e711d05` (example)
- Our custom engine build has hash: `df5701473c` (example)
- **All components must match**, or the kernel won't load

## The Solution: Versioned Global Cache

We cache all artifacts from our custom engine build in `~/.redstone/`, ensuring they all have the same SDK hash.

## Cache Structure

```
~/.redstone/
└── versions/
    └── 3.40.0-1.0.pre-379-362d8f1e/     # <flutter-version>-<engine-hash>
        │
        ├── flutter/                      # Symlink to engine Flutter SDK
        │   └── bin/
        │       └── flutter               # Used for `flutter build bundle`
        │
        ├── embedder/                     # The Flutter runtime engine
        │   └── FlutterEmbedder.framework/   (macOS)
        │   └── libflutter_engine.so         (Linux)
        │   └── flutter_engine.dll           (Windows)
        │
        └── engine/                       # Compilation artifacts
            ├── flutter_patched_sdk/
            │   └── platform_strong.dill  # Platform libraries
            │
            ├── dart-sdk/
            │   └── bin/
            │       ├── dartaotruntime    # Runs frontend_server
            │       └── snapshots/
            │           └── frontend_server_aot.dart.snapshot
            │
            ├── isolate_snapshot.bin      # VM startup snapshots
            ├── vm_isolate_snapshot.bin
            └── icudtl.dat                # Unicode data
```

## Component Details

### `flutter/` - Flutter SDK Symlink

**Type**: Symlink to `engine_build/monorepo/flutter/`

**Purpose**: Provides the `flutter` command for asset bundling (`flutter build bundle`). This generates FontManifest.json, AssetManifest.bin, and other assets.

**Note**: The `flutter build bundle` command also produces snapshot files, but these have the wrong SDK hash (from Google's CDN). We replace them afterward.

### `embedder/FlutterEmbedder.framework` - Flutter Engine

**Type**: Framework/shared library (133MB for custom debug build)

**Purpose**: The Flutter engine that:
- Loads and executes Dart kernel binaries
- Provides the Dart VM runtime
- Handles rendering, input, and platform channels

**SDK Hash**: This is the **source of truth**. All other artifacts must match this hash.

**Source**: Built from `engine_build/monorepo/flutter/engine/` and copied from `packages/native_mc_bridge/FlutterEmbedder.framework`

### `engine/flutter_patched_sdk/platform_strong.dill` - Platform SDK

**Type**: Dart kernel binary (~10MB)

**Purpose**: Contains the core Dart and Flutter libraries (dart:core, dart:async, package:flutter, etc.) in kernel format. Used by the frontend_server when compiling your mod code.

**SDK Hash**: Must match FlutterEmbedder

**Source**: `engine/src/out/mac_debug_unopt_arm64/flutter_patched_sdk/`

### `engine/dart-sdk/` - Dart Compilation Tools

**Contents**:
- `bin/dartaotruntime` - Runs AOT-compiled Dart snapshots
- `bin/snapshots/frontend_server_aot.dart.snapshot` - The Dart-to-kernel compiler

**Purpose**: These tools compile your Dart mod code into a kernel binary that the FlutterEmbedder can execute.

**SDK Hash**: Must match FlutterEmbedder

**Source**: `engine/src/out/mac_debug_unopt_arm64/dart-sdk/`

### `engine/isolate_snapshot.bin` & `vm_isolate_snapshot.bin` - VM Snapshots

**Type**: Binary VM state snapshots

**Purpose**: Pre-initialized Dart VM state for faster startup. Contains pre-compiled versions of core libraries.

**SDK Hash**: Must match FlutterEmbedder (embedded in snapshot header)

**Source**: `engine/src/out/mac_debug_unopt_arm64/gen/flutter/lib/snapshot/`

### `engine/icudtl.dat` - ICU Data

**Type**: Binary data file (~10MB)

**Purpose**: International Components for Unicode (ICU) data. Used for text rendering, date/time formatting, and internationalization.

**SDK Hash**: N/A (no hash verification)

## Version Naming Convention

Format: `<flutter-version>-<short-engine-hash>`

Example: `3.40.0-1.0.pre-379-362d8f1e`

- `3.40.0-1.0.pre-379` - Flutter framework version
- `362d8f1e` - First 8 chars of engine commit hash

This allows multiple redstone versions to coexist, each with their own compatible artifacts.

## How Artifacts Are Cached

When `FlutterSdk.ensureAvailable()` is called:

1. **Check if fully cached**: If all artifacts exist, return immediately
2. **Cache Flutter SDK**: Create symlink to `engine_build/monorepo/flutter/`
3. **Cache embedder**: Copy `FlutterEmbedder.framework` from `packages/native_mc_bridge/`
4. **Cache engine artifacts**: Copy from `engine/src/out/mac_debug_unopt_arm64/`:
   - `flutter_patched_sdk/` directory
   - `dart-sdk/` directory
   - `gen/flutter/lib/snapshot/isolate_snapshot.bin`
   - `gen/flutter/lib/snapshot/vm_isolate_snapshot.bin`
   - `icudtl.dat`

## Runtime Flow

When running `redstone run`:

1. **Ensure cache**: `FlutterSdk.ensureAvailable()` populates the cache if needed
2. **Bundle assets**: Run `flutter build bundle` using cached Flutter SDK
3. **Fix snapshots**: Replace Google's snapshot files with our cached versions
4. **Compile kernel**: Use cached `frontend_server` with cached `platform_strong.dill`
5. **Copy to natives**: Copy `FlutterEmbedder.framework` from cache to project's `natives/` folder
6. **Run Minecraft**: The dylib loads embedder from `natives/` via `@loader_path`

## Troubleshooting SDK Hash Mismatches

If you see "Invalid kernel binary format version":

1. **Check cache exists**: `ls ~/.redstone/versions/`
2. **Verify hashes match**:
   ```bash
   # Check kernel hash (bytes 8-17)
   hexdump -C .redstone/flutter_assets/kernel_blob.bin | head -1

   # Check embedder hash
   strings natives/FlutterEmbedder.framework/Versions/A/FlutterEmbedder | grep -E "^[a-f0-9]{10}$"
   ```
3. **Clear cache and rebuild**:
   ```bash
   rm -rf ~/.redstone/versions/
   redstone run
   ```

## Related Files

- `packages/redstone_cli/lib/src/flutter/flutter_cache.dart` - Cache management
- `packages/redstone_cli/lib/src/flutter/flutter_sdk.dart` - SDK path resolution
- `packages/redstone_cli/lib/src/commands/run_command.dart` - Runtime flow
- `packages/native_mc_bridge/CMakeLists.txt` - Native library RPATH configuration
