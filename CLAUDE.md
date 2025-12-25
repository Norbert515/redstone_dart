# Redstone Dart - Minecraft Modding with Dart

This is a framework for creating Minecraft mods using Dart instead of Java. It uses a JNI bridge to connect Dart code running in a native library with Minecraft's Java runtime.

## Project Structure

```
packages/
├── dart_mc/            # Main Dart API library for mod developers
├── java_mc_bridge/     # Java bridge code (server + client)
│   ├── src/main/       # Server-side/common Java code
│   └── src/client/     # Client-only Java code (renderers, GUI)
├── redstone_cli/       # CLI tool for building and running mods
├── generic_jni_bridge/ # Low-level JNI communication layer
├── native_mc_bridge/   # Native C++ JNI bridge library
├── redstone_test/      # Headless Minecraft E2E test framework
└── framework_tests/    # Comprehensive tests for the framework

example/
└── example_mod/        # Example mod demonstrating all features
```

## Architecture

### Client/Server Split

The codebase uses Fabric Loom's `splitEnvironmentSourceSets()` for client/server separation:

- **Server code** (`src/main/`): Uses `DartBridge` class via JNI
- **Client code** (`src/client/`): Uses `DartBridgeClient` class, marked with `@Environment(EnvType.CLIENT)`
- **Runtime checks**: Java callbacks use `!level.isClientSide()` to ensure server-only execution

### Bridge Communication

1. **Dart → Java**: Via `GenericJniBridge.callStaticVoidMethod()` with JNI signatures
2. **Java → Dart**: Via native callbacks registered during initialization
3. **Manifest system**: Dart writes to `.redstone/manifest.json`, CLI reads it for asset generation

## Key APIs

### Blocks & Items

```dart
class MyBlock extends CustomBlock {
  MyBlock() : super(
    id: 'mymod:my_block',
    settings: BlockSettings(hardness: 2.0),
    model: BlockModel.cubeAll(texture: 'assets/textures/block/my_block.png'),
  );
}

BlockRegistry.register(MyBlock());
```

### Entities with Models

Custom entities can have visual models rendered in-game:

```dart
class MyZombie extends CustomMonster {
  MyZombie() : super(
    id: 'mymod:my_zombie',
    settings: MonsterSettings(
      maxHealth: 30,
      attackDamage: 4,
      model: EntityModel.humanoid(
        texture: 'textures/entity/my_zombie.png',
      ),
    ),
  );
}

EntityRegistry.register(MyZombie());
```

**Available model types:**
- `EntityModel.humanoid(texture)` - Bipedal model (zombie/player-like)
- `EntityModel.quadruped(texture)` - Four-legged model (cow/pig-like)
- `EntityModel.simple(texture, scale)` - Basic scaled model

Entities without a `model` field are invisible (use `NoopRenderer`).

### GUI Screens

```dart
class MyScreen extends Screen {
  @override
  void render(GuiGraphics graphics) {
    graphics.drawString('Hello World', 10, 10, 0xFFFFFF);
  }
}
```

## Development Commands

```bash
# In example/example_mod/
redstone run          # Build and run the mod with hot reload
redstone build        # Build without running
redstone generate     # Regenerate assets (blocks, items, textures)

# Testing entities in-game
/spawnzombie          # Spawn custom zombie
/spawncow             # Spawn custom cow
```

## Build System & Source Regeneration

### Automatic Rebuilds

The CLI automatically detects and rebuilds when sources change:

1. **Java Bridge Changes** (`packages/java_mc_bridge/src/`)
   - Auto-synced on `redstone run` or `redstone test`
   - Hash-based detection via `.redstone/version.json`

2. **Native C++ Bridge Changes** (`packages/native_mc_bridge/src/`)
   - Auto-rebuilt if CMake is available
   - Hash-based detection via `.redstone/version.json`

3. **Asset Generation** (blocks, items, entities)
   - Runs automatically on `redstone run`/`redstone test`
   - Manual: `redstone generate`

### Manual CMake Rebuild (Native Bridge)

When you need to manually rebuild the native C++ bridge:

```bash
cd packages/native_mc_bridge
cmake -B build .
cmake --build build --config release
```

**Output:** `dart_mc_bridge.dylib` (macOS), `dart_mc_bridge.dll` (Windows), `libdart_mc_bridge.so` (Linux)

**Requirements:** CMake 3.21+, C++17 compiler, JDK 21+

### Gradle Source Generation

To generate decompiled Minecraft sources for IDE navigation:

```bash
cd packages/java_mc_bridge
./gradlew genSources
```

## Navigating Minecraft Source Code

When implementing Java bridge code, you need to understand vanilla Minecraft's APIs and patterns. Decompiled Minecraft sources are available for reference.

### Source Location

```
packages/java_mc_bridge/mc-sources/
```

Contains 6,600+ decompiled Java files using official Mojang mappings.

### Setup Commands

```bash
# Full setup (generates and unpacks sources)
just java-setup

# Only unpack sources (if already generated)
just java-unpack-sources

# Clean Loom caches if having issues
just java-clean
```

### Common Source Paths

| Feature | Path |
|---------|------|
| Blocks | `mc-sources/net/minecraft/world/level/block/` |
| Items | `mc-sources/net/minecraft/world/item/` |
| Entities | `mc-sources/net/minecraft/world/entity/` |
| Monster AI | `mc-sources/net/minecraft/world/entity/monster/` |
| Animal AI | `mc-sources/net/minecraft/world/entity/animal/` |
| Recipes | `mc-sources/net/minecraft/world/item/crafting/` |
| Registry | `mc-sources/net/minecraft/core/registries/` |
| Server | `mc-sources/net/minecraft/server/` |
| Client | `mc-sources/net/minecraft/client/` |
| Network | `mc-sources/net/minecraft/network/` |

### Cross-Referencing Workflow

When working on Java bridge code:

1. **Identify the Minecraft class** involved in the change
2. **Read the source file** from `mc-sources/`:
   ```
   packages/java_mc_bridge/mc-sources/net/minecraft/world/level/block/Block.java
   ```
3. **Understand the API** - method signatures, inheritance, patterns
4. **Implement following Minecraft's patterns**

### Example Queries

- "How does Minecraft register blocks?" → Read `mc-sources/net/minecraft/core/registries/BuiltInRegistries.java`
- "What methods does a Monster have?" → Read `mc-sources/net/minecraft/world/entity/monster/Monster.java`
- "How do recipes work?" → Read `mc-sources/net/minecraft/world/item/crafting/`

## Testing

### Headless Minecraft E2E Tests

This project uses a custom testing infrastructure that runs tests inside a real headless Minecraft server. **Always write E2E tests to verify your work.**

### Running Tests

```bash
# Run all tests in a project
cd example/example_mod  # or packages/framework_tests
redstone test

# Run specific test file
redstone test test/block_test.dart

# Run tests matching name pattern
redstone test --name "placement"
redstone test -n "can place"

# Run with tags
redstone test --tags slow
redstone test --exclude-tags flaky

# Verbose output
redstone test --verbose
```

### Test Locations

- **Framework tests:** `packages/framework_tests/test/` - Comprehensive tests for all framework features
- **Example mod tests:** `example/example_mod/test/` - Example tests demonstrating patterns

### Writing Tests

```dart
import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  await group('Block operations', () async {
    await testMinecraft('can place and retrieve a block', (game) async {
      final pos = BlockPos(1000, 64, 1000);

      game.placeBlock(pos, Block.stone);
      await game.waitTicks(1);

      expect(game.getBlock(pos), isBlock(Block.stone));
    });
  });
}
```

### Test API Reference (`MinecraftGameContext`)

**World access:**
- `game.world` - Overworld
- `game.nether` - Nether
- `game.end` - The End

**Block operations:**
- `game.placeBlock(pos, block)` - Place a block
- `game.getBlock(pos)` - Get block at position
- `game.fillBlocks(from, to, block)` - Fill region
- `game.isAir(pos)` - Check if air

**Tick-based waiting:**
- `await game.waitTicks(20)` - Wait 1 second (20 ticks)
- `await game.waitUntil(() => condition, maxTicks: 100)`
- `await game.waitUntilOrThrow(() => condition, reason: 'message')`

**Entity operations:**
- `game.spawnEntity(entityType, position)`
- `game.getEntitiesInRadius(center, radius)`
- `game.players`

**Custom matchers:**
- `isBlock(Block.stone)` or `isBlock('minecraft:stone')`
- `isAirBlock`
- `isNotAirBlock`

### Test File Examples

See `packages/framework_tests/test/` for comprehensive examples:
- `block_test.dart` - Block placement and retrieval
- `entity_test.dart` - Entity operations
- `custom_entity_test.dart` - Custom entity spawning
- `events_test.dart` - Event handling
- `commands_test.dart` - Command registration
- `recipes_test.dart` - Recipe registration
- `loot_tables_test.dart` - Loot table testing

## Adding New Features

### Adding a New Entity Model Type

1. **Dart side** (`packages/dart_mc/lib/api/entity_model.dart`):
   - Add new factory constructor to `EntityModel`
   - Create corresponding sealed class implementation

2. **Java client side** (`packages/java_mc_bridge/src/client/`):
   - Update `DartEntityRenderer.java` to handle new model type
   - Update `DartModClientLoader.java` if needed

3. **CLI** (`packages/redstone_cli/lib/src/assets/asset_generator.dart`):
   - Update `_copyEntityTextures()` if new texture handling needed

### Adding Client-Only Dart APIs

1. Create Dart wrapper that calls `DartBridgeClient` via JNI:
   ```dart
   GenericJniBridge.callStaticVoidMethod(
     'com/redstone/DartBridgeClient',
     'methodName',
     '(signature)V',
     [args],
   );
   ```

2. Add corresponding Java method in `DartBridgeClient.java`

## File Locations

| Feature | Dart API | Java Bridge | CLI |
|---------|----------|-------------|-----|
| Blocks | `dart_mc/lib/api/block.dart` | `proxy/DartBlockProxy.java` | `asset_generator.dart` |
| Items | `dart_mc/lib/api/item.dart` | `proxy/DartItemProxy.java` | `asset_generator.dart` |
| Entities | `dart_mc/lib/api/custom_entity.dart` | `proxy/EntityProxyRegistry.java` | `asset_generator.dart` |
| Entity Models | `dart_mc/lib/api/entity_model.dart` | `render/DartEntityRenderer.java` | - |
| GUI | `dart_mc/lib/api/gui/` | `DartBridgeClient.java` | - |

