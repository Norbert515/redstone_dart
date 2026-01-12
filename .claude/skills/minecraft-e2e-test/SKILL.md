---
name: minecraft-e2e-test
description: Control Minecraft for E2E testing. Use this skill when testing Minecraft mods, verifying game behavior, placing blocks, spawning entities, taking screenshots, or running any Minecraft-related tests. Invoke with /minecraft-test or when the user asks to test something in Minecraft.
---

# Minecraft E2E Testing Skill

This skill enables you to control a Minecraft client for end-to-end testing of mods built with the Redstone Dart framework.

## Prerequisites

The Minecraft MCP server must be configured in Claude Code settings. It does NOT need a mod path at startup - you provide that when starting Minecraft.

## Starting Minecraft

To start Minecraft for testing, call `startMinecraft` with the absolute path to your mod:

```
startMinecraft(modPath: "/absolute/path/to/your/mod")
```

**What happens automatically:**
- Builds the mod with `redstone run`
- Creates and loads a superflat test world (`dart_visual_test`)
- Starts the MCP game server inside Minecraft
- Runs in background mode (won't steal window focus)
- Disables hot reload for stability

Just provide the mod path and everything else is handled!

## Available Tools

When the Minecraft MCP is connected, you have access to these tools:

### Lifecycle Management
- `startMinecraft(modPath)` - Start Minecraft with the specified mod (provide absolute path)
- `stopMinecraft` - Stop the Minecraft client
- `getStatus` - Check if Minecraft is running

### Debugging
- `getLogs(lastN?)` - Get all output (Dart prints, Java logs, stderr). Default: last 100 lines.

### World Operations
- `placeBlock(x, y, z, blockId)` - Place a block at coordinates
- `getBlock(x, y, z)` - Get block ID at coordinates
- `fillBlocks(fromX, fromY, fromZ, toX, toY, toZ, blockId)` - Fill a region with blocks

### Entity Operations
- `spawnEntity(entityType, x, y, z)` - Spawn an entity
- `getEntities(centerX, centerY, centerZ, radius)` - Find entities in radius

### Player & Camera
- `teleportPlayer(x, y, z)` - Teleport the player
- `positionCamera(x, y, z, yaw, pitch)` - Set camera position and rotation
- `lookAt(x, y, z)` - Make camera look at a position

### Visual Verification
- `takeScreenshot(name)` - Capture a screenshot
- `getScreenshot(name)` - Get screenshot as base64 data

### Input Simulation
- `pressKey(keyCode)` - Press a keyboard key
- `click(button, x, y)` - Click mouse at screen coordinates (button: 0=left, 1=right, 2=middle)
- `holdMouse(button)` - Hold mouse button down (for breaking blocks, using items)
- `releaseMouse(button)` - Release held mouse button
- `moveMouse(x, y)` - Move cursor to screen coordinates
- `scroll(horizontal, vertical)` - Scroll mouse wheel (positive vertical = scroll up)
- `typeText(text)` - Type text into input field

### Time & Commands
- `waitTicks(ticks)` - Wait for game ticks (20 ticks = 1 second)
- `setTimeOfDay(time)` - Set game time (0=dawn, 6000=noon, 12000=dusk, 18000=midnight)
- `executeCommand(command)` - Run any Minecraft command

## Testing Workflow

### 1. Start Minecraft
```
First, ensure Minecraft is running by checking status or starting it.
```

### 2. Set Up Test Environment
```
- Teleport player to test location
- Clear area with fillBlocks using air
- Set time of day for consistent lighting
- Wait for world to stabilize
```

### 3. Perform Test Actions
```
- Place blocks to test
- Spawn entities
- Simulate player input
- Execute commands
```

### 4. Verify Results
```
- Check block states with getBlock
- Query entities with getEntities
- Take screenshots for visual verification
```

### 5. Clean Up
```
- Remove test blocks/entities
- Reset player position if needed
```

## Common Test Patterns

### Testing Block Placement
```
1. teleportPlayer to test area
2. fillBlocks to clear area (use minecraft:air)
3. waitTicks(20) for world update
4. placeBlock with your custom block
5. waitTicks(5)
6. getBlock to verify placement
7. takeScreenshot for visual record
```

### Testing Custom Entities
```
1. Set up clear test area
2. spawnEntity with your custom entity type
3. waitTicks(20) for entity to initialize
4. getEntities to verify spawn
5. takeScreenshot to capture entity appearance
```

### Testing UI/Screens
```
1. pressKey to open UI (e.g., E for inventory)
2. waitTicks(5) for UI to render
3. takeScreenshot
4. click to interact with UI elements
5. pressKey to close UI
```

### Testing Commands
```
1. executeCommand("give @p minecraft:diamond 64")
2. waitTicks(5)
3. takeScreenshot to verify
```

## Block IDs

Common block IDs:
- `minecraft:air` - Remove blocks
- `minecraft:stone` - Stone block
- `minecraft:dirt` - Dirt block
- `minecraft:grass_block` - Grass
- `minecraft:diamond_block` - Diamond block

Custom mod blocks use format: `modid:block_name`

## Key Codes

Common key codes for input simulation:
- `69` - E (Inventory)
- `27` - Escape
- `32` - Space (Jump)
- `87` - W (Forward)
- `65` - A (Left)
- `83` - S (Back)
- `68` - D (Right)
- `340` - Left Shift (Sneak)

## Coordinate System

Modern Minecraft (1.18+) uses an extended height range:
- World extends from Y=-64 to Y=320
- Sea level is approximately Y=63
- **Superflat test worlds have ground at Y=-60**

When testing in the dart_visual_test world (superflat):
- Ground level: Y=-60
- Player spawn: teleport to Y=-59 or Y=-60
- Place blocks starting at Y=-60
- Spawn entities at Y=-59 (one block above ground)

## Tips

1. **Always wait after actions** - Use `waitTicks` after placing blocks, spawning entities, or any world modification
2. **Use executeCommand for complex setups** - Commands like `/fill`, `/summon`, `/effect` can simplify test setup
3. **Take screenshots liberally** - Visual verification helps confirm test results
4. **Clear test areas first** - Use `fillBlocks` with air to ensure clean test environment
5. **Check status before testing** - Verify Minecraft is running with `getStatus`

## Example Test Session

Testing a custom diamond sword that deals extra damage (in superflat test world):

```
1. getStatus - Verify Minecraft running
2. teleportPlayer(100, -59, 100) - Move to test area (standing on ground at Y=-60)
3. fillBlocks(95, -60, 95, 105, -50, 105, "minecraft:air") - Clear area above ground
4. waitTicks(20)
5. executeCommand("give @p mymod:super_sword") - Give custom item
6. spawnEntity("minecraft:zombie", 100, -59, 103) - Spawn test target (on ground)
7. waitTicks(10)
8. takeScreenshot("before_attack")
9. // Simulate attack with click/key presses
10. waitTicks(20)
11. getEntities(100, -59, 100, 10) - Check if zombie was killed
12. takeScreenshot("after_attack")
```
