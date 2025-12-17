# CLI Reference

The `redstone` CLI is your main tool for creating and running Redstone.Dart mods.

## Commands

### `redstone create <name>`

Create a new Redstone.Dart mod project.

```bash
redstone create my_mod
redstone create my_mod --org com.mycompany
redstone create my_mod --minecraft-version 1.21.1
redstone create my_mod --empty
```

| Option | Description | Default |
|--------|-------------|---------|
| `--org` | Organization identifier | `com.example` |
| `-d, --description` | Mod description | "A Minecraft mod built with Redstone" |
| `--author` | Author name | Auto-detected from git |
| `-m, --minecraft-version` | Target Minecraft version | Latest stable |
| `--empty` | Create minimal project without examples | `false` |

### `redstone run`

Build and run your mod in Minecraft with hot reload support.

```bash
redstone run
redstone run -d minecraft-1.20.4
redstone run --verbose
```

| Option | Description | Default |
|--------|-------------|---------|
| `-d, --device` | Target Minecraft version | `minecraft-1.21.1` |
| `--hot-reload` | Enable hot reload | `true` |
| `-v, --verbose` | Verbose output | `false` |

**Interactive commands while running:**

| Key | Action |
|-----|--------|
| `r` | Hot reload — apply code changes instantly |
| `q` | Quit Minecraft |
| `c` | Clear terminal |
| `h` | Show help |

### `redstone build`

Build your mod without launching Minecraft.

```bash
redstone build
redstone build --release
```

| Option | Description |
|--------|-------------|
| `--release` | Build in release mode |

### `redstone generate`

Regenerate Minecraft assets (blockstates, models, textures, loot tables).

```bash
redstone generate
```

This is automatically run by `redstone run` and `redstone build`, but you can run it manually if needed.

### `redstone devices`

List available Minecraft versions.

```bash
redstone devices
```

Output:

```
Available devices:
  minecraft-1.21.1 (default)
  minecraft-1.21
  minecraft-1.20.4
  minecraft-1.20.1
```

### `redstone doctor`

Check your development environment.

```bash
redstone doctor
```

Checks:
- ✓ Dart SDK installed
- ✓ Java 21+ installed
- ○ Gradle (optional)
- ○ CMake (optional, for building native libs)

### `redstone upgrade`

Check for and apply Redstone updates.

```bash
redstone upgrade
redstone upgrade --check  # Check only, don't apply
```

## Global Options

| Option | Description |
|--------|-------------|
| `--version` | Print Redstone version |
| `-v, --verbose` | Enable verbose logging |
| `--help` | Show help |
