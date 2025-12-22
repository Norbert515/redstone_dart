# Redstone Dart - Minecraft Modding with Dart

This is a framework for creating Minecraft mods using Dart instead of Java. It uses a JNI bridge to connect Dart code running in a native library with Minecraft's Java runtime.

## Project Structure

```
packages/
├── dart_mc/           # Main Dart API library for mod developers
├── java_mc_bridge/    # Java bridge code (server + client)
│   ├── src/main/      # Server-side/common Java code
│   └── src/client/    # Client-only Java code (renderers, GUI)
├── redstone_cli/      # CLI tool for building and running mods
└── generic_jni_bridge/ # Low-level JNI communication layer

example/
└── basic_dart_mod/    # Example mod demonstrating all features
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
# In example/basic_dart_mod/
redstone run          # Build and run the mod with hot reload
redstone build        # Build without running

# Testing entities
/spawnzombie          # Spawn custom zombie
/spawncow             # Spawn custom cow
```

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

## Testing

```bash
# Run example mod
cd example/basic_dart_mod
redstone run

# In-game commands to test entities:
/spawnzombie   # Spawns DartZombie with custom model
/spawncow      # Spawns DartCow with custom model
```
