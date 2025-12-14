# Minecraft Mod Development Guide (Fabric 1.21.11)

This document captures key learnings for AI agents working on Minecraft mods with Fabric.

## Project Structure

```
myfirstmod/
├── src/
│   ├── main/java/com/example/       # Server + shared code
│   │   ├── ExampleMod.java          # Main mod entrypoint
│   │   └── block/                   # Blocks, entities, menus
│   ├── client/java/com/example/     # Client-only code (rendering, GUI)
│   └── main/resources/
│       ├── fabric.mod.json          # Mod metadata
│       └── assets/modid/            # Textures, models, lang
├── mc-sources/                      # Extracted Minecraft sources (run `just extract-sources`)
│   ├── common/                      # Server + shared Minecraft code
│   └── client/                      # Client-only Minecraft code
├── justfile                         # Development commands
└── build.gradle                     # Build configuration
```

## Essential Commands

```bash
just build            # Build the mod
just run              # Run Minecraft with mod
just br               # Build and run
just extract-sources  # Extract Minecraft sources to mc-sources/ for reference
just info             # Show project info
```

## Critical: API Reference

**ALWAYS check `mc-sources/` before writing code.** Online tutorials are often outdated.

```bash
# Extract sources first (only needed once)
just extract-sources

# Then read the actual API
cat mc-sources/common/net/minecraft/world/level/block/state/BlockBehaviour.java
```

### Key Source Locations

| What | Path |
|------|------|
| Block methods | `mc-sources/common/net/minecraft/world/level/block/state/BlockBehaviour.java` |
| BlockEntity | `mc-sources/common/net/minecraft/world/level/block/entity/BlockEntity.java` |
| Container/Menu | `mc-sources/common/net/minecraft/world/inventory/AbstractContainerMenu.java` |
| GUI rendering | `mc-sources/client/net/minecraft/client/gui/GuiGraphics.java` |
| Screen base | `mc-sources/client/net/minecraft/client/gui/screens/inventory/AbstractContainerScreen.java` |

## 1.21.11 API Specifics (Mojang Mappings)

### Identifier (not ResourceLocation)
```java
// CORRECT for 1.21.11
import net.minecraft.resources.Identifier;
Identifier.fromNamespaceAndPath("modid", "block_name")

// WRONG (old API)
// ResourceLocation.fromNamespaceAndPath(...)  // doesn't exist
```

### Block Methods
```java
// Override these protected methods in your Block class:

// Called when block is broken and should drop items
protected void spawnAfterBreak(BlockState state, ServerLevel world, BlockPos pos, ItemStack tool, boolean dropExperience)

// Called when entity walks into the block
protected void entityInside(BlockState state, Level world, BlockPos pos, Entity entity, InsideBlockEffectApplier effectApplier, boolean movedByPiston)

// Right-click with empty hand
protected InteractionResult useWithoutItem(BlockState state, Level world, BlockPos pos, Player player, BlockHitResult hit)

// Right-click with item
protected InteractionResult useItemOn(ItemStack stack, BlockState state, Level world, BlockPos pos, Player player, InteractionHand hand, BlockHitResult hit)

// Called after block is removed
protected void affectNeighborsAfterRemoval(BlockState state, ServerLevel world, BlockPos pos, boolean movedByPiston)

// Check if on server
world.isClientSide()  // method call, not field access
```

### BlockEntity Save/Load
```java
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;

@Override
protected void saveAdditional(ValueOutput output) {
    super.saveAdditional(output);
    output.putInt("MyValue", myValue);
    output.putBoolean("MyFlag", myFlag);
}

@Override
protected void loadAdditional(ValueInput input) {
    super.loadAdditional(input);
    myValue = input.getIntOr("MyValue", 0);
    myFlag = input.getBooleanOr("MyFlag", false);
}
```

### GUI Rendering (GuiGraphics.blit)
```java
// 1.21.11 signature - uses float UV coordinates
graphics.blit(
    TEXTURE,           // Identifier
    x, y,              // screen position (int)
    width, height,     // size to draw (int)
    u, v,              // UV start (float, 0.0-1.0)
    uWidth, vHeight    // UV size (float, 0.0-1.0)
);

// Example for 176x166 GUI on 256x256 texture:
graphics.blit(TEXTURE, x, y, 176, 166, 0.0f, 0.0f, 176f/256f, 166f/256f);
```

### Opening Menus
```java
// In Block.useWithoutItem():
if (!world.isClientSide()) {
    if (be instanceof MyBlockEntity myEntity) {
        player.openMenu(myEntity);  // Just pass MenuProvider, no position needed
    }
}
```

## Registration Pattern

### Blocks (ModBlocks.java)
```java
public static final Block MY_BLOCK = register(
    "my_block",
    MyBlock::new,
    BlockBehaviour.Properties.of()
        .strength(2.0f)
        .sound(SoundType.METAL),
    true  // register item
);

private static ResourceKey<Block> keyOfBlock(String name) {
    return ResourceKey.create(Registries.BLOCK, Identifier.fromNamespaceAndPath(MOD_ID, name));
}
```

### Block Entities (ModBlockEntities.java)
```java
public static final BlockEntityType<MyBlockEntity> MY_BLOCK_ENTITY =
    register("my_block",
        FabricBlockEntityTypeBuilder.create(MyBlockEntity::new, ModBlocks.MY_BLOCK).build());
```

### Menus (ModMenuTypes.java)
```java
public static final MenuType<MyMenu> MY_MENU = Registry.register(
    BuiltInRegistries.MENU,
    Identifier.fromNamespaceAndPath(MOD_ID, "my_menu"),
    new MenuType<>(MyMenu::new, FeatureFlags.VANILLA_SET)
);
```

### Client Screen Registration (ExampleModClient.java)
```java
@Override
public void onInitializeClient() {
    MenuScreens.register(ModMenuTypes.MY_MENU, MyScreen::new);
}
```

## Resource Files Required

For each block `my_block`:

```
assets/modid/
├── blockstates/my_block.json
├── models/block/my_block.json
├── models/item/my_block.json
├── textures/block/my_block.png (16x16)
└── lang/en_us.json

data/modid/
└── loot_table/blocks/my_block.json
```

### Minimal blockstate JSON
```json
{"variants": {"": {"model": "modid:block/my_block"}}}
```

### Minimal block model JSON
```json
{"parent": "minecraft:block/cube_all", "textures": {"all": "modid:block/my_block"}}
```

### Minimal item model JSON
```json
{"parent": "modid:block/my_block"}
```

## Common Mistakes to Avoid

1. **Don't trust online tutorials** - They're usually for older versions. Check `mc-sources/`.

2. **Build incrementally** - Write one class, build, fix errors, repeat.

3. **Method signatures change** - `onRemove`, `entityInside`, `blit` all changed in 1.21.x.

4. **Identifier not ResourceLocation** - 1.21.11 uses `Identifier`.

5. **ValueInput/ValueOutput** - BlockEntity serialization changed from CompoundTag.

6. **Float UVs for blit** - GUI rendering now uses 0.0-1.0 float UV coordinates.

## Debugging Tips

1. Check logs in the terminal for registration errors
2. Missing textures show as purple/black checkerboard
3. Use `ExampleMod.LOGGER.info()` for debug output
4. Logs show `[modid]` prefix for your mod's messages

## Where Minecraft Sources Come From

Minecraft ships as obfuscated bytecode. Fabric Loom:
1. Downloads Minecraft JARs from Mojang
2. Decompiles with Vineflower
3. Applies Mojang's official mappings
4. Outputs readable Java in `.gradle/loom-cache/`

Run `just extract-sources` to extract to `mc-sources/` for easy reading.
