# Redstone.dart Implementation Plan

> "The Flutter for Minecraft" - A CLI tool for building Minecraft mods in Dart

## Overview

Redstone is a CLI tool that enables developers to write Minecraft mods in Dart, following Flutter's UX patterns. Users run `redstone create my_mod` and get a working project they can immediately run with `redstone run`.

## Project Structure

### Generated Project (`redstone create my_mod`)

```
my_mod/
├── lib/
│   └── main.dart                 # User's Dart mod code
├── assets/
│   └── textures/                 # User's custom textures
├── pubspec.yaml                  # Dart deps + redstone config
├── README.md
│
├── minecraft/                    # Fabric mod (user-editable)
│   ├── src/main/
│   │   ├── java/com/example/mymod/   # User's custom Java (optional)
│   │   └── resources/
│   │       ├── fabric.mod.json
│   │       └── assets/mymod/
│   ├── build.gradle
│   ├── settings.gradle
│   ├── gradle.properties
│   └── gradle/wrapper/...
│
└── .redstone/                    # MANAGED BY REDSTONE
    ├── native/
    │   ├── dart_mc_bridge.dylib
    │   └── libdart_dll.dylib
    ├── bridge/
    │   └── java/com/redstone/
    │       ├── RedstoneBridge.java
    │       ├── RedstoneModLoader.java
    │       └── proxy/...
    └── version.json
```

### CLI Package Structure

```
packages/redstone_cli/
├── bin/
│   └── redstone.dart             # Entry point
├── lib/
│   ├── redstone_cli.dart         # Public exports
│   └── src/
│       ├── commands/
│       │   ├── command_runner.dart
│       │   ├── create_command.dart
│       │   ├── run_command.dart
│       │   ├── build_command.dart
│       │   ├── devices_command.dart
│       │   ├── doctor_command.dart
│       │   └── upgrade_command.dart
│       ├── project/
│       │   ├── redstone_project.dart    # Project discovery & loading
│       │   └── pubspec_config.dart      # Parse redstone: section
│       ├── runner/
│       │   ├── minecraft_runner.dart    # Process management
│       │   ├── hot_reload_client.dart   # VM service connection
│       │   └── build_runner.dart        # Build orchestration
│       ├── template/
│       │   ├── template_renderer.dart   # Variable substitution
│       │   └── project_creator.dart     # Copy & customize template
│       └── util/
│           ├── logger.dart              # Colored output
│           ├── platform.dart            # OS/arch detection
│           └── process_utils.dart       # Process helpers
├── templates/                    # Bundled with CLI
│   ├── app/                      # Default project template
│   │   ├── lib/
│   │   │   └── main.dart.tmpl
│   │   ├── pubspec.yaml.tmpl
│   │   ├── README.md.tmpl
│   │   └── minecraft/
│   │       ├── build.gradle.tmpl
│   │       ├── settings.gradle.tmpl
│   │       ├── gradle.properties.tmpl
│   │       └── src/main/resources/
│   │           └── fabric.mod.json.tmpl
│   ├── bridge/                   # Java bridge source
│   │   └── java/com/redstone/
│   │       ├── RedstoneBridge.java
│   │       ├── RedstoneModLoader.java
│   │       └── proxy/
│   │           ├── DartBlockProxy.java
│   │           ├── DartEntityProxy.java
│   │           └── ProxyRegistry.java
│   └── native/                   # Pre-built native libs
│       ├── macos-arm64/
│       │   ├── dart_mc_bridge.dylib
│       │   └── libdart_dll.dylib
│       ├── macos-x64/
│       ├── linux-x64/
│       └── windows-x64/
└── pubspec.yaml
```

## Key Files

### pubspec.yaml (Generated Project)

```yaml
name: my_mod
description: A Minecraft mod built with Redstone
version: 1.0.0
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  redstone:
    path: ../../packages/redstone  # Local for now, pub.dev later

# Redstone configuration (like flutter: section in Flutter)
redstone:
  minecraft_version: "1.21.1"
  org: com.example
  author: Your Name
```

### lib/main.dart (Generated)

```dart
import 'package:redstone/redstone.dart';

void main() {
  Redstone.initialize();

  // Register your blocks
  BlockRegistry.register(ExampleBlock());
}

class ExampleBlock extends CustomBlock {
  ExampleBlock() : super(
    id: 'my_mod:example_block',
    settings: BlockSettings(
      hardness: 1.0,
      resistance: 1.0,
    ),
  );

  @override
  ActionResult onUse(UseContext ctx) {
    ctx.player.sendMessage('§aHello from Redstone!');
    return ActionResult.success;
  }
}
```

### minecraft/build.gradle (Generated)

```gradle
plugins {
    id 'fabric-loom' version '1.14-SNAPSHOT'
    id 'java'
}

version = project.mod_version
group = project.maven_group

repositories {
    mavenCentral()
}

sourceSets {
    main {
        java {
            // Include Redstone bridge (managed)
            srcDir '../.redstone/bridge/java'
            // User's custom Java (optional)
            srcDir 'src/main/java'
        }
    }
}

dependencies {
    minecraft "com.mojang:minecraft:${project.minecraft_version}"
    mappings "net.fabricmc:yarn:${project.yarn_mappings}:v2"
    modImplementation "net.fabricmc:fabric-loader:${project.loader_version}"
    modImplementation "net.fabricmc.fabric-api:fabric-api:${project.fabric_version}"
}

// ... rest of standard Fabric config
```

### .redstone/version.json

```json
{
  "redstone_cli_version": "1.0.0",
  "bridge_version": "1.0.0",
  "native_version": "1.0.0",
  "platform": "macos-arm64",
  "created_at": "2024-12-15T12:00:00Z"
}
```

## CLI Commands

### `redstone create <project_name>`

Creates a new Redstone project.

**Usage:**
```bash
redstone create my_mod
redstone create my_mod --org com.mycompany
redstone create my_mod --minecraft-version 1.21.1
```

**Options:**
| Flag | Description | Default |
|------|-------------|---------|
| `--org` | Organization identifier | `com.example` |
| `--minecraft-version` | Target MC version | `1.21.1` |
| `--description` | Mod description | `A Minecraft mod built with Redstone` |
| `--author` | Author name | From git config |

**Interactive prompts (if not provided):**
1. Description (optional)
2. Author (auto-detect from git)

**Process:**
1. Validate project name (lowercase_with_underscores)
2. Create project directory
3. Copy & render templates (variable substitution)
4. Detect platform (macos-arm64, macos-x64, linux-x64, windows-x64)
5. Copy native libs to `.redstone/native/`
6. Copy bridge code to `.redstone/bridge/`
7. Write `.redstone/version.json`
8. Run `dart pub get`
9. Print success message with next steps

**Output:**
```
Creating Redstone project "my_mod"...

  ✓ Created project structure
  ✓ Copied native libraries (macos-arm64)
  ✓ Installed bridge code
  ✓ Ran dart pub get

All done! Your Redstone project is ready.

Next steps:
  cd my_mod
  redstone run

Happy modding! 🧱
```

### `redstone run`

Builds and runs Minecraft with hot reload support.

**Usage:**
```bash
redstone run
redstone run -d minecraft-1.20.4
redstone run --no-hot-reload
```

**Options:**
| Flag | Description |
|------|-------------|
| `-d, --device` | Target Minecraft version |
| `--no-hot-reload` | Disable hot reload |
| `--verbose` | Show detailed output |

**Interactive keys:**
```
🔥 Redstone is running my_mod on Minecraft 1.21.1

Hot reload enabled. Watching for changes...

Press:
  r  Hot reload
  R  Hot restart (rebuild all)
  q  Quit
  c  Clear screen
  h  Help
```

**Process:**
1. Find project root (look for pubspec.yaml with redstone: section)
2. Build native library (if source changed)
3. Copy Dart mod to `minecraft/run/mods/`
4. Copy native libs to `minecraft/run/natives/`
5. Start Minecraft via `./gradlew runClient`
6. Connect to Dart VM service (port 5858)
7. Listen for 'r' key → trigger hot reload
8. Handle Ctrl+C → graceful shutdown

### `redstone build`

Builds the project without running.

**Usage:**
```bash
redstone build
redstone build --release
```

**Process:**
1. Build native library
2. Build Java mod (`./gradlew build`)
3. Copy Dart mod
4. Report success

### `redstone devices`

Lists available Minecraft versions/configurations.

**Output:**
```
Available Minecraft configurations:

  minecraft-1.21.1  • Fabric 0.18.2  • Default
  minecraft-1.20.4  • Fabric 0.15.0

To use: redstone run -d minecraft-1.20.4
```

### `redstone doctor`

Checks the development environment.

**Output:**
```
Redstone Doctor
───────────────────────────────────────
✓ Dart SDK 3.8.2
✓ Java 21.0.1 (required: 21+)
✓ Gradle 9.2.1
✓ Native libraries installed (macos-arm64)
✓ dart_dll version 0.2.0 (Dart 3.8.2)
✗ CMake not found
  └ Only needed if building native from source

Issues found: 1 (non-blocking)
```

### `redstone upgrade`

Updates `.redstone/` to latest version.

**Usage:**
```bash
redstone upgrade
redstone upgrade --check  # Just check, don't upgrade
```

**Output:**
```
Checking for updates...

Current: 1.0.0
Latest:  1.1.0

Upgrading .redstone/...
  ✓ Updated bridge code (1.0.0 → 1.1.0)
  ✓ Updated native libraries

Upgrade complete!
```

## Implementation Phases

### Phase 1: Basic Structure
- [ ] Create `packages/redstone_cli/` directory structure
- [ ] Set up pubspec.yaml with dependencies
- [ ] Implement command runner with args package
- [ ] Add `--help` and `--version` flags

### Phase 2: Create Command
- [ ] Extract templates from current project:
  - [ ] Java bridge code from `myfirstmod/src/.../dartbridge/`
  - [ ] Build files (build.gradle, etc.)
  - [ ] Fabric configuration
- [ ] Build template renderer (variable substitution)
- [ ] Implement platform detection
- [ ] Copy native libraries based on platform
- [ ] Generate `.redstone/` directory

### Phase 3: Run Command
- [ ] Port `ProcessRunner` from existing CLI
- [ ] Port `HotReloadClient` from existing CLI
- [ ] Implement interactive key handling (r, R, q, h, c)
- [ ] Add file watching (optional)
- [ ] Handle graceful shutdown

### Phase 4: Supporting Commands
- [ ] Implement `build` command
- [ ] Implement `devices` command
- [ ] Implement `doctor` command
- [ ] Implement `upgrade` command

### Phase 5: Dart API Package
- [ ] Create `packages/redstone/` (the Dart API)
- [ ] Move/refactor code from `dart_mc_bridge/dart_mod/lib/api/`
- [ ] Clean up exports
- [ ] Add documentation

### Phase 6: Polish
- [ ] Error handling and user-friendly messages
- [ ] Progress indicators
- [ ] Colored output
- [ ] Documentation

## Dependencies

### redstone_cli/pubspec.yaml

```yaml
name: redstone_cli
description: CLI tool for building Minecraft mods with Dart
version: 1.0.0

environment:
  sdk: ^3.0.0

dependencies:
  args: ^2.4.0              # CLI argument parsing
  path: ^1.8.0              # Path manipulation
  yaml: ^3.1.0              # Parse pubspec.yaml
  yaml_edit: ^2.1.0         # Edit YAML files
  vm_service: ^14.0.0       # Hot reload
  async: ^2.11.0            # Async utilities
  io: ^1.0.0                # IO utilities
  cli_util: ^0.4.0          # CLI utilities
  collection: ^1.18.0       # Collection utilities

dev_dependencies:
  test: ^1.24.0
  lints: ^3.0.0
```

## Template Variables

Templates use `{{variable}}` syntax:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{project_name}}` | Dart package name | `my_mod` |
| `{{project_name_title}}` | Title case | `My Mod` |
| `{{description}}` | Mod description | `A cool mod` |
| `{{org}}` | Organization | `com.example` |
| `{{author}}` | Author name | `John Doe` |
| `{{minecraft_version}}` | MC version | `1.21.1` |
| `{{fabric_version}}` | Fabric API version | `0.139.4+1.21.1` |
| `{{loader_version}}` | Fabric loader | `0.18.2` |
| `{{yarn_mappings}}` | Yarn version | `1.21.1+build.3` |
| `{{java_package}}` | Java package path | `com/example/my_mod` |

## Migration from Current Structure

To create the templates, we'll extract from the current codebase:

| Source | Destination |
|--------|-------------|
| `myfirstmod/src/.../dartbridge/*.java` | `templates/bridge/java/com/redstone/` |
| `myfirstmod/build.gradle` | `templates/app/minecraft/build.gradle.tmpl` |
| `myfirstmod/src/main/resources/fabric.mod.json` | `templates/app/minecraft/.../fabric.mod.json.tmpl` |
| `dart_mc_bridge/dart_mod/lib/api/` | `packages/redstone/lib/` |
| `dart_mc_bridge/native/build/*.dylib` | `templates/native/macos-arm64/` |
| `dart_mc_bridge/native/deps/dart_dll/lib/` | `templates/native/macos-arm64/` |

## Open Questions

1. **Versioning**: How do we version the bridge/native separately from CLI?
2. **Updates**: Should `redstone upgrade` backup user's `.redstone/` first?
3. **Multiple MC versions**: Support multiple versions in one project?
4. **Asset pipeline**: Should `redstone build` process assets (textures)?

## Next Steps

1. Create the directory structure
2. Extract and templatize current code
3. Implement `create` command first
4. Test end-to-end flow
5. Add remaining commands
