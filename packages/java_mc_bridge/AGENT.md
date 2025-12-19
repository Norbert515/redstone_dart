# Java Development Guidelines for AI Agents

## Critical: Reference Official Minecraft Sources

When making ANY Java changes in this project, you **MUST** consult the official Minecraft sources first.

### Source Location

Official Mojang-mapped Minecraft sources are available at:
```
packages/java_mc_bridge/mc-sources/
```

If this directory is empty or doesn't exist, run:
```bash
just java-setup
```

### Why This Matters

This project uses **Fabric Loom with official Mojang mappings**. The decompiled sources in `mc-sources/` contain:

- Correct class names, method names, and field names as defined by Mojang
- Proper method signatures and parameter names
- Accurate inheritance hierarchies
- Official Javadoc comments where available

### Before Making Java Changes

1. **Identify the Minecraft classes involved** in your change
2. **Read the relevant source files** in `mc-sources/` to understand:
   - The exact method signatures you need to use
   - How Minecraft's internal systems work
   - What callbacks/events are available
   - Correct parameter types and return values
3. **Follow Minecraft's patterns** - don't fight the framework

### Common Source Locations

| Area | Path in mc-sources/ |
|------|---------------------|
| Items | `net/minecraft/world/item/` |
| Blocks | `net/minecraft/world/level/block/` |
| Entities | `net/minecraft/world/entity/` |
| Recipes | `net/minecraft/world/item/crafting/` |
| Registry | `net/minecraft/core/Registry.java`, `BuiltInRegistries.java` |
| Server | `net/minecraft/server/` |
| Client | `net/minecraft/client/` |
| Network | `net/minecraft/network/` |

### Example Workflow

```
User: "Add a method to get all registered items"

Agent Steps:
1. Read mc-sources/net/minecraft/core/registries/BuiltInRegistries.java
2. Read mc-sources/net/minecraft/world/item/Item.java
3. Understand how Minecraft's registry system works
4. Implement using correct API patterns
```

### Mixin Development

When writing Mixins:

1. **Always read the target class** in `mc-sources/` first
2. Verify the exact method signature you're targeting
3. Check for `@Environment` annotations (client-only vs server)
4. Understand the method's behavior before injecting

### Do NOT

- Guess at Minecraft API signatures
- Assume method names without checking sources
- Make changes without understanding the surrounding Minecraft code
- Ignore `@Environment` annotations

### Build Commands

```bash
just java-setup          # Generate and unpack sources (first-time setup)
just java-unpack-sources # Re-unpack sources if needed
just java-clean          # Clean Loom caches if having issues
```
