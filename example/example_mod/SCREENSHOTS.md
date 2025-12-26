# Screenshot Checklist for Documentation

Run with `cd example/example_mod && redstone run`

Screenshots go in: `packages/docs/public/screenshots/`

## Setup
- [ ] Use `/time set 6000` for daytime screenshots
- [ ] Use `/gamemode creative` for easy placement
- [ ] Press F1 to hide HUD if needed
- [ ] Use F2 to take screenshots

---

## Landing Page
- [ ] **landing-hero.png** - Game + terminal side by side showing hot reload
  - Place some custom blocks, have terminal visible with `redstone run` output

---

## Blocks (`content/docs/blocks.mdx`)
- [ ] **block-rainbow.png** - RainbowBlock with heart particles
  - Place `example_mod:rainbow_block`, right-click, capture particles
- [ ] **block-particle.png** - ParticleBlock with flames
  - Place `example_mod:particle_block`, step on it, capture flames
- [ ] **block-message.png** - MessageBlock showing title
  - Right-click `example_mod:message_block`, capture the title text

---

## Items (`content/docs/items.mdx`)
- [ ] **item-lightning.png** - Lightning strike from wand
  - `/give @p example_mod:lightning_wand`, right-click ground, capture lightning
- [ ] **item-healing.png** - Healing orb with heart particles
  - `/give @p example_mod:healing_orb`, use it, capture hearts
- [ ] **item-teleport.png** - Teleport staff with portal particles
  - `/give @p example_mod:teleport_staff`, use it, capture particles

---

## Entities (`content/docs/entities.mdx`)
- [ ] **entity-zombie.png** - Custom DartZombie
  - `/spawnzombie`, screenshot the zombie
- [ ] **entity-cow.png** - Custom DartCow
  - `/spawncow`, screenshot in a grassy area

---

## Commands (`content/docs/commands.mdx`)
- [ ] **command-heal.png** - Chat showing /heal feedback
  - Take damage, run `/heal`, screenshot chat
- [ ] **command-xp.png** - XP bar after /give_xp
  - Run `/give_xp 500`, screenshot XP bar filling

---

## Recipes (`content/docs/recipes.mdx`)
- [ ] **recipe-crafting.png** - Recipe in crafting table
  - Show a custom recipe in the crafting grid with output

---

## Loot Tables (`content/docs/loot-tables.mdx`)
- [ ] **loot-drop.png** - Modified mob drops
  - Kill a zombie, screenshot the drops

---

## GUI (`content/docs/gui.mdx`)
- [ ] **gui-screen.png** - ShowcaseScreen open
  - Run `/showcase_gui`, screenshot the GUI
- [ ] **gui-input.png** - GUI with text entered
  - Type something, click Save, capture feedback message

---

## Hot Reload (`content/docs/hot-reload.mdx`)
- [ ] **hotreload-terminal.png** - Terminal showing reload
  - Press `r` in terminal, screenshot the output
- [ ] **hotreload-before.png** / **hotreload-after.png** - Code change demo
  - Change MessageBlock message, hot reload, show before/after

---

## Quick Reference

| Command | What it does |
|---------|-------------|
| `/showcase_gui` | Opens demo GUI |
| `/give_xp 500` | Gives 500 XP |
| `/spawnzombie` | Spawns custom zombie |
| `/spawncow` | Spawns custom cow |
| `/heal` | Full heal |

| Block | ID |
|-------|-----|
| Rainbow | `example_mod:rainbow_block` |
| Particle | `example_mod:particle_block` |
| Message | `example_mod:message_block` |

| Item | ID |
|------|-----|
| Lightning Wand | `example_mod:lightning_wand` |
| Healing Orb | `example_mod:healing_orb` |
| Teleport Staff | `example_mod:teleport_staff` |
