# Hot Reload

Hot reload is what makes Redstone.Dart feel magical. Change your code, press `r`, and see the changes in under a second—without restarting Minecraft.

## How It Works

When you run `redstone run`, the Dart VM inside Minecraft connects to a VM service. When you press `r`:

1. Your Dart code is recompiled
2. The new code is injected into the running VM
3. The next time your callback is invoked, it runs the new code

The key insight: the **proxy objects** in Java stay the same. They're still registered with Minecraft, still have the same handler IDs. But the **Dart methods they call** can change.

```
[Player clicks block]
    ↓
[Java proxy receives event]
    ↓
[Proxy looks up handler ID]
    ↓
[Calls Dart method]  ← This method body can change!
```

## What Can Change

✅ **Method bodies** — Change what `onUse()` does

✅ **Logic and calculations** — Update formulas, conditions

✅ **Messages and feedback** — Change text, particles, sounds

✅ **Event handlers** — Update `onTick`, `onPlayerJoin` behavior

## What Can't Change

❌ **Block/item registrations** — Minecraft's registry is frozen at startup

❌ **Block settings** — Hardness, light level, etc. are stored in Java

❌ **Block models and textures** — Loaded at startup from asset files

❌ **New blocks or items** — Can't add to a frozen registry

### Why This Limitation?

Minecraft's architecture. The game freezes its registries early in startup—before most code runs. This is a Minecraft limitation that affects all mods, not just Redstone.

The workaround: design your blocks/items upfront, then iterate on their behavior. You can always restart to add new blocks.

## Using Hot Reload

1. Start your mod with `redstone run`
2. Edit your Dart code
3. Press `r` in the terminal
4. Test your changes in-game

That's it. No waiting for compilation, no waiting for Minecraft to restart.

## State Preservation

Hot reload preserves state. Variables keep their values:

```dart
var counter = 0;

Events.onTick(() {
  counter++;  // Keeps counting across reloads
});
```

This is usually what you want—your game state doesn't reset. But be aware of it when debugging.

If you need to reset state, you can add a reset mechanism:

```dart
var counter = 0;

Events.onPlayerJoin((player) {
  if (player.name == 'reset') {  // Or some other trigger
    counter = 0;
  }
});
```

## DevTools

For deeper debugging, connect Dart DevTools:

1. Run `/darturl` in Minecraft chat
2. Copy the VM service URL (like `ws://127.0.0.1:5858/ws`)
3. Open it in DevTools or your IDE

From DevTools you can:
- Set breakpoints
- Inspect variables
- View console output
- Profile performance

## When to Restart

Sometimes you need to restart Minecraft:

- Adding new blocks or items
- Changing block settings (hardness, light level)
- Updating textures or models
- After a crash

Press `q` to quit, then `redstone run` to start fresh.
