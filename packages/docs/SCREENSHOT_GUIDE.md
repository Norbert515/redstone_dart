# Screenshot Guide for Redstone.Dart Documentation

This guide explains how to take screenshots for the documentation. Each screenshot has a placeholder in the docs that you can replace.

## Setup

1. Navigate to the screenshot showcase mod:
   ```bash
   cd example/screenshot_showcase
   ```

2. Run the mod:
   ```bash
   redstone run
   ```

3. Enter a creative mode world (the mod adds `/gamemode creative` if needed)

4. Use F2 to take screenshots (saved to `.minecraft/screenshots/`)

---

## Required Screenshots

### 1. Landing Page Hero (landing-hero.png)
**Location in docs:** app/page.tsx (can embed or link)
**What to show:** Minecraft with a custom block visible and the terminal showing hot reload
**How to take:**
1. Place some `showcase:rainbow_block` in the world
2. Have terminal visible on the side showing `redstone run` output
3. Capture both Minecraft and terminal together
**Dimensions:** 1920x1080 recommended

---

### 2. Hot Reload Demo (hot-reload.gif or hot-reload-before.png + hot-reload-after.png)
**Location in docs:** content/docs/hot-reload.mdx
**What to show:** Code change -> instant result
**How to take:**
1. Show MessageBlock saying "Welcome!"
2. Change the message in code to something else
3. Press `r` in terminal
4. Show new message appearing
**Tips:** Can be a GIF or before/after images

---

### 3. Custom Block Interaction (block-interaction.png)
**Location in docs:** content/docs/blocks.mdx
**What to show:** Player right-clicking the rainbow block, hearts appearing
**How to take:**
1. Place `showcase:rainbow_block`
2. Right-click it
3. Screenshot with particles visible
**Timing:** Capture when particle effect is visible

---

### 4. Custom Item in Hand (item-in-hand.png)
**Location in docs:** content/docs/items.mdx
**What to show:** Player holding the lightning wand
**How to take:**
1. Give yourself the wand: `/give @p showcase:lightning_wand`
2. Hold it in your hand
3. Take screenshot from 3rd person or showing hotbar

---

### 5. Lightning Strike (lightning-strike.png)
**Location in docs:** content/docs/items.mdx
**What to show:** Lightning striking where the wand was used
**How to take:**
1. Hold lightning wand
2. Right-click a block
3. Quickly screenshot the lightning

---

### 6. Custom Zombie (custom-zombie.png)
**Location in docs:** content/docs/entities.mdx
**What to show:** The super zombie entity
**How to take:**
1. Run `/spawnzombie`
2. Screenshot the zombie (ideally at night or in a dark area)
**Tip:** Use night time: `/time set night`

---

### 7. Custom Cow (custom-cow.png)
**Location in docs:** content/docs/entities.mdx
**What to show:** The fluffy cow entity
**How to take:**
1. Run `/spawncow`
2. Screenshot the cow in a nice grassy area

---

### 8. Command Execution (command-heal.png)
**Location in docs:** content/docs/commands.mdx
**What to show:** Chat showing the /heal command output
**How to take:**
1. Damage yourself first (fall damage, etc.)
2. Type `/heal`
3. Screenshot chat showing "You have been healed!"

---

### 9. Command with Arguments (command-xp.png)
**Location in docs:** content/docs/commands.mdx
**What to show:** XP command being used
**How to take:**
1. Type `/give_xp 500`
2. Screenshot showing feedback and XP bar increasing

---

### 10. Recipe in Crafting Table (recipe-shaped.png)
**Location in docs:** content/docs/recipes.mdx
**What to show:** Diamond hammer recipe in crafting grid
**How to take:**
1. Open crafting table
2. Arrange 3 diamonds + 2 sticks in hammer pattern
3. Screenshot showing the output

---

### 11. Recipe Book (recipe-book.png)
**Location in docs:** content/docs/recipes.mdx
**What to show:** Custom recipes appearing in recipe book
**How to take:**
1. Open inventory or crafting table
2. Click recipe book
3. Find showcase recipes
4. Screenshot

---

### 12. Loot Drop (loot-drop.png)
**Location in docs:** content/docs/loot-tables.mdx
**What to show:** Zombie dropping diamonds
**How to take:**
1. Spawn and kill a zombie
2. Screenshot diamond drops on ground
**Tip:** The showcase mod has 50% diamond drop rate for easy testing

---

### 13. GUI Screen (gui-showcase.png)
**Location in docs:** content/docs/gui.mdx
**What to show:** The showcase GUI with input and buttons
**How to take:**
1. Run `/showcase_gui`
2. Type something in the input field
3. Screenshot the full GUI

---

### 14. GUI with Status (gui-status.png)
**Location in docs:** content/docs/gui.mdx
**What to show:** GUI showing feedback after button click
**How to take:**
1. Open GUI with `/showcase_gui`
2. Enter a name and click "Save"
3. Screenshot showing green status message

---

### 15. Terminal with Hot Reload (terminal-hotreload.png)
**Location in docs:** content/docs/hot-reload.mdx
**What to show:** Terminal showing hot reload in action
**How to take:**
1. Have `redstone run` running
2. Press `r`
3. Screenshot terminal showing reload success

---

### 16. DevTools Connected (devtools.png)
**Location in docs:** content/docs/hot-reload.mdx
**What to show:** Dart DevTools connected to the running mod
**How to take:**
1. Run `/darturl` in game
2. Open the URL in browser/DevTools
3. Screenshot DevTools interface

---

### 17. World Manipulation (world-effects.png)
**Location in docs:** content/docs/world.mdx
**What to show:** Particles, explosions, or block placement
**How to take:**
1. Use the particle block (step on it)
2. Or use lightning wand
3. Screenshot visual effect

---

### 18. Player Effects (player-effects.png)
**Location in docs:** content/docs/players.mdx
**What to show:** Player with status effects visible
**How to take:**
1. Use `/effect give @p speed 60 2`
2. Screenshot with effect particles/icons visible

---

## Screenshot Specifications

| Aspect | Recommendation |
|--------|----------------|
| Resolution | 1920x1080 or 1280x720 |
| Format | PNG (preferred) or JPG |
| Naming | lowercase-with-dashes.png |
| Location | `packages/docs/public/screenshots/` |

## Adding Screenshots to Docs

Once you have screenshots, add them to MDX files like this:

```mdx
![Description of image](/screenshots/block-interaction.png)
```

Or with captions:

```mdx
<figure>
  <img src="/screenshots/block-interaction.png" alt="Block interaction" />
  <figcaption>Clicking the rainbow block spawns heart particles</figcaption>
</figure>
```

## Creating Placeholder Images

The docs currently have TODO comments where screenshots should go. You can use these placeholder dimensions:

- Feature screenshots: 800x450
- Full-screen: 1280x720
- UI elements: 400x300
- Code + game side-by-side: 1920x600

## Tips

1. **Consistent lighting** - Use day time for most screenshots (`/time set day`)
2. **Clean inventory** - Clear unnecessary items before GUI screenshots
3. **Simple backgrounds** - Grass or simple terrain, avoid clutter
4. **High contrast** - Make sure text is readable
5. **Show context** - Include enough of the screen to understand what's happening

## Showcase Mod Commands Reference

The screenshot_showcase mod provides these commands:

| Command | Description |
|---------|-------------|
| `/heal` | Restore full health |
| `/give_xp <amount>` | Give experience points |
| `/spawnzombie` | Spawn a super zombie |
| `/spawncow` | Spawn a fluffy cow |
| `/showcase_gui` | Open the showcase GUI |

## Showcase Mod Blocks Reference

| Block | ID | Description |
|-------|-----|-------------|
| Rainbow Block | `showcase:rainbow_block` | Glowing block, spawns hearts on click |
| Particle Block | `showcase:particle_block` | Spawns flames when stepped on |
| Message Block | `showcase:message_block` | Shows title text when clicked |

## Showcase Mod Items Reference

| Item | ID | Description |
|------|-----|-------------|
| Lightning Wand | `showcase:lightning_wand` | Summons lightning on right-click |
| Healing Orb | `showcase:healing_orb` | Heals player to full health |
| Teleport Staff | `showcase:teleport_staff` | Teleports player forward |

## Showcase Mod Entities Reference

| Entity | ID | Description |
|--------|-----|-------------|
| Super Zombie | `showcase:super_zombie` | Enhanced zombie (40 HP, 6 damage) |
| Fluffy Cow | `showcase:fluffy_cow` | Breedable cow (20 HP) |
