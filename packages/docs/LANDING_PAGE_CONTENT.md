# Redstone Dart Landing Page Content Reference

This document contains all section variations for the Redstone Dart landing page. The team can mix and match variations to create the final page.

---

# 1. HERO SECTION

## Variation A: Developer-Focused

### Minecraft Modding, Finally Modern

Write Minecraft mods with a language designed for productivity. Dart's clean syntax, powerful type system, and instant hot reload make modding actually enjoyable.

**CTA:** Get Started | View on GitHub

---

## Variation B: Speed-Focused

### From Code Change to In-Game in Seconds

Stop waiting for builds. Redstone's hot reload lets you see your changes instantly—no restart required. Iterate faster than ever before.

**CTA:** Try Hot Reload | Watch Demo

---

## Variation C: Simplicity-Focused

### Write Minecraft Mods in Dart

No more boilerplate. No more ceremony. Just clean, expressive code that does what you mean. Define a block in 5 lines, not 50.

```dart
BlockRegistry.register(CustomBlock(
  id: 'mymod:ruby_block',
  settings: BlockSettings(hardness: 3.0),
  model: BlockModel.cubeAll(texture: 'textures/ruby_block.png'),
));
```

**CTA:** Start Building | Read the Docs

---

## Variation D: Bold/Provocative

### Java is Optional

Minecraft modding has been stuck in Java for over a decade. Redstone changes that. Write mods in Dart—a modern language with null safety, async/await, and an incredible developer experience.

**CTA:** Break Free | Learn More

---

## Variation E: Community-Focused

### Minecraft Modding for Dart Developers

Already love Dart? Now you can bring that same great experience to Minecraft. Build blocks, items, entities, and more with the language you already know.

**CTA:** Join the Community | Get Started

---

# 2. FEATURES SECTION

## Variation A: Icon Grid

### Why Redstone?

| | | |
|:---:|:---:|:---:|
| **Modern Language** | **Hot Reload** | **Type Safety** |
| Write clean, expressive Dart code with null safety and pattern matching | See changes instantly without restarting Minecraft | Catch errors at compile time, not runtime |
| **Batteries Included** | **E2E Testing** | **Simple CLI** |
| Blocks, items, entities, recipes, commands—all built in | Test your mods in a headless Minecraft server | One command to build, run, and test |

---

## Variation B: Three Pillars

### Built for Modern Development

#### Modern Language
Dart brings null safety, pattern matching, async/await, and a clean syntax to Minecraft modding. No more verbose Java boilerplate—just code that reads like what it does.

#### Instant Feedback
Hot reload means you see your changes in-game within seconds. Change a block texture, tweak entity behavior, or adjust a recipe—all without restarting.

#### Batteries Included
Everything you need is built in: blocks, items, entities, commands, recipes, loot tables, GUI screens. Plus a CLI that handles building, running, and testing.

---

## Variation C: Before/After Comparison

### Less Code. More Done.

| Java (Fabric) | Dart (Redstone) |
|--------------|-----------------|
| Create a Block class | Define inline or extend `CustomBlock` |
| Create a BlockItem class | Automatic |
| Register the block | `BlockRegistry.register()` |
| Register the item | Automatic |
| Create blockstates JSON | Generated from `BlockModel` |
| Create block model JSON | Generated from `BlockModel` |
| Create item model JSON | Automatic |
| Add texture file | Just reference the path |
| Add language file entry | Optional `displayName` parameter |
| **~150 lines across 8 files** | **~10 lines in 1 file** |

---

## Variation D: Feature Cards

### Everything You Need

#### Blocks
Define custom blocks with properties, models, and behavior. From simple cubes to complex multi-state blocks.

```dart
CustomBlock(
  id: 'mymod:amethyst_lamp',
  settings: BlockSettings(hardness: 2.0, luminance: 15),
  model: BlockModel.cubeAll(texture: 'textures/amethyst_lamp.png'),
)
```

#### Items
Create items with custom behavior, models, and crafting recipes. Food, tools, weapons, and more.

```dart
CustomItem(
  id: 'mymod:ruby_sword',
  settings: ItemSettings(maxStackSize: 1),
  model: ItemModel.handheld(texture: 'textures/ruby_sword.png'),
)
```

#### Entities
Spawn custom creatures with configurable AI, models, and behavior. Passive animals or aggressive monsters.

```dart
CustomMonster(
  id: 'mymod:ice_golem',
  settings: MonsterSettings(
    maxHealth: 50,
    attackDamage: 8,
    model: EntityModel.humanoid(texture: 'textures/ice_golem.png'),
  ),
)
```

#### Commands
Register server commands with arguments, permissions, and tab completion.

```dart
CommandRegistry.register(
  Command('heal')
    ..executes((ctx) => ctx.source.player?.heal(20)),
);
```

#### Recipes
Define crafting, smelting, and custom recipes with a fluent API.

```dart
RecipeRegistry.register(
  ShapedRecipe(
    result: ItemStack('mymod:ruby_block', 1),
    pattern: ['RRR', 'RRR', 'RRR'],
    key: {'R': 'mymod:ruby'},
  ),
);
```

#### GUI Screens
Build custom screens and HUDs with a widget-based API.

```dart
class MyScreen extends Screen {
  @override
  void render(GuiGraphics g) {
    g.drawCenteredString('Welcome!', width ~/ 2, 20, 0xFFFFFF);
    g.drawTexture('textures/gui/panel.png', 10, 40, 200, 100);
  }
}
```

---

# 3. CODE EXAMPLES SECTION

## Variation A: Tabbed Examples

### See It in Action

**[Blocks] [Items] [Entities]**

#### Blocks Tab
```dart
import 'package:dart_mc/dart_mc.dart';

class RubyOre extends CustomBlock {
  RubyOre() : super(
    id: 'mymod:ruby_ore',
    settings: BlockSettings(
      hardness: 3.0,
      requiresTool: true,
    ),
    model: BlockModel.cubeAll(
      texture: 'assets/textures/block/ruby_ore.png',
    ),
    drops: [ItemStack('mymod:ruby', 1, max: 3)],
  );
}

void main() {
  BlockRegistry.register(RubyOre());
}
```

#### Items Tab
```dart
import 'package:dart_mc/dart_mc.dart';

class RubyPickaxe extends CustomItem {
  RubyPickaxe() : super(
    id: 'mymod:ruby_pickaxe',
    displayName: 'Ruby Pickaxe',
    settings: ItemSettings(
      maxStackSize: 1,
      durability: 1500,
    ),
    model: ItemModel.handheld(
      texture: 'assets/textures/item/ruby_pickaxe.png',
    ),
  );

  @override
  double getMiningSpeed(Block block) => 9.0;
}

void main() {
  ItemRegistry.register(RubyPickaxe());
}
```

#### Entities Tab
```dart
import 'package:dart_mc/dart_mc.dart';

class FrostZombie extends CustomMonster {
  FrostZombie() : super(
    id: 'mymod:frost_zombie',
    displayName: 'Frost Zombie',
    settings: MonsterSettings(
      maxHealth: 30,
      attackDamage: 5,
      movementSpeed: 0.25,
      model: EntityModel.humanoid(
        texture: 'assets/textures/entity/frost_zombie.png',
      ),
    ),
  );

  @override
  void onAttack(Entity target) {
    target.addEffect(Effects.slowness, duration: 100);
  }
}

void main() {
  EntityRegistry.register(FrostZombie());
}
```

---

## Variation B: Side-by-Side Comparison

### Java vs Dart: Creating a Block

#### Java (Fabric)
```java
// ModBlocks.java
public class ModBlocks {
    public static final Block RUBY_BLOCK = new Block(
        FabricBlockSettings.create()
            .strength(3.0f)
            .requiresTool()
    );

    public static void register() {
        Registry.register(
            Registries.BLOCK,
            Identifier.of("mymod", "ruby_block"),
            RUBY_BLOCK
        );
        Registry.register(
            Registries.ITEM,
            Identifier.of("mymod", "ruby_block"),
            new BlockItem(RUBY_BLOCK,
                new Item.Settings())
        );
    }
}
```

Plus 4 JSON files:
- `blockstates/ruby_block.json`
- `models/block/ruby_block.json`
- `models/item/ruby_block.json`
- `lang/en_us.json`

#### Dart (Redstone)
```dart
// main.dart
BlockRegistry.register(CustomBlock(
  id: 'mymod:ruby_block',
  displayName: 'Ruby Block',
  settings: BlockSettings(
    hardness: 3.0,
    requiresTool: true,
  ),
  model: BlockModel.cubeAll(
    texture: 'textures/ruby_block.png',
  ),
));
```

That's it. Models and blockstates are generated automatically.

---

## Variation C: Progressive Complexity

### Start Simple, Go Deep

#### Beginner: Your First Block
```dart
// A simple decorative block
BlockRegistry.register(CustomBlock(
  id: 'mymod:jade_block',
  model: BlockModel.cubeAll(texture: 'textures/jade.png'),
));
```

#### Intermediate: Block with Properties
```dart
// A lamp that can be turned on/off
class JadeLamp extends CustomBlock {
  JadeLamp() : super(
    id: 'mymod:jade_lamp',
    settings: BlockSettings(hardness: 1.5),
    model: BlockModel.cubeAll(texture: 'textures/jade_lamp.png'),
    properties: [BoolProperty('lit', defaultValue: false)],
  );

  @override
  int getLuminance(BlockState state) {
    return state.get('lit') ? 15 : 0;
  }

  @override
  void onUse(BlockState state, Player player, BlockPos pos) {
    world.setBlockState(pos, state.with('lit', !state.get('lit')));
  }
}
```

#### Advanced: Custom Entity with AI
```dart
// A friendly golem that follows players
class JadeGolem extends CustomMonster {
  JadeGolem() : super(
    id: 'mymod:jade_golem',
    settings: MonsterSettings(
      maxHealth: 100,
      attackDamage: 15,
      model: EntityModel.humanoid(texture: 'textures/jade_golem.png'),
    ),
  );

  @override
  void initGoals() {
    goals.add(1, SwimGoal(this));
    goals.add(2, MeleeAttackGoal(this, speed: 1.0));
    goals.add(3, FollowPlayerGoal(this, range: 10.0));
    goals.add(4, WanderAroundGoal(this));

    targetSelector.add(1, RevengeGoal(this));
    targetSelector.add(2, TargetHostilesGoal(this));
  }
}
```

---

## Variation D: Complete Mod Snippet

### A Real Mod in Under 50 Lines

```dart
import 'package:dart_mc/dart_mc.dart';

// ===== BLOCKS =====
final rubyOre = CustomBlock(
  id: 'gemcraft:ruby_ore',
  settings: BlockSettings(hardness: 3.0, requiresTool: true),
  model: BlockModel.cubeAll(texture: 'textures/ruby_ore.png'),
  drops: [ItemStack('gemcraft:ruby', 1, max: 3)],
);

final rubyBlock = CustomBlock(
  id: 'gemcraft:ruby_block',
  settings: BlockSettings(hardness: 5.0),
  model: BlockModel.cubeAll(texture: 'textures/ruby_block.png'),
);

// ===== ITEMS =====
final ruby = CustomItem(
  id: 'gemcraft:ruby',
  model: ItemModel.generated(texture: 'textures/ruby.png'),
);

// ===== RECIPES =====
final rubyBlockRecipe = ShapedRecipe(
  result: ItemStack('gemcraft:ruby_block', 1),
  pattern: ['RRR', 'RRR', 'RRR'],
  key: {'R': 'gemcraft:ruby'},
);

final rubyFromBlockRecipe = ShapelessRecipe(
  result: ItemStack('gemcraft:ruby', 9),
  ingredients: ['gemcraft:ruby_block'],
);

// ===== REGISTRATION =====
void main() {
  BlockRegistry.register(rubyOre);
  BlockRegistry.register(rubyBlock);
  ItemRegistry.register(ruby);
  RecipeRegistry.register(rubyBlockRecipe);
  RecipeRegistry.register(rubyFromBlockRecipe);
}
```

This mod adds:
- Ruby ore that drops 1-3 rubies
- Ruby block for storage
- Ruby item
- Crafting recipes (9 rubies → block, block → 9 rubies)

---

# 4. DEVELOPER EXPERIENCE SECTION

## Variation A: CLI Showcase

### Three Commands. That's It.

```bash
# Create a new mod
redstone create my_awesome_mod

# Run with hot reload
redstone run

# Test in headless server
redstone test
```

No Gradle configuration. No Maven. No XML. Just build and run.

---

## Variation B: Hot Reload Focus

### Change Code. See It Instantly.

1. Edit your block's texture path
2. Save the file
3. See the new texture in-game

No restart. No rebuild. Just instant feedback.

**Average iteration time:** Under 2 seconds

Compare that to traditional modding where every change requires:
- Stopping the game
- Rebuilding the mod
- Restarting Minecraft
- Loading into your test world

**Traditional iteration time:** 30-60 seconds

---

## Variation C: Workflow Timeline

### Your Development Day

| Time | Traditional Modding | Redstone |
|------|-------------------|----------|
| 9:00 | Start Gradle build | `redstone run` |
| 9:02 | Still building... | Already testing |
| 9:05 | Finally launched | Made 5 iterations |
| 9:10 | Make a change, rebuild | Hot reload, done |
| 9:12 | Still rebuilding... | Made 3 more iterations |
| 9:15 | Test one thing | Tested everything |

**Redstone developers ship faster because they iterate faster.**

---

## Variation D: IDE Experience

### World-Class Tooling

#### Autocomplete That Works
Dart's type system means your IDE knows exactly what methods and properties are available. No more guessing API names.

#### Instant Error Feedback
See errors as you type, not when you build. Null safety catches potential crashes before they happen.

#### Refactoring Made Easy
Rename a class, extract a method, move a file—your IDE handles it all safely.

#### Documentation at Your Fingertips
Hover over any API to see docs. Jump to definition with a click. Everything is connected.

**Supported IDEs:**
- VS Code with Dart extension
- Android Studio / IntelliJ IDEA
- Any editor with Dart LSP support

---

## Variation E: Pain Points Solved

### We Fixed the Annoying Parts

| Pain Point | Traditional | Redstone |
|-----------|-------------|----------|
| Build times | Minutes | Seconds |
| Iteration speed | Rebuild everything | Hot reload |
| JSON files | Write by hand | Auto-generated |
| Runtime errors | Crash and guess | Caught at compile time |
| Testing | Manual in-game | Automated E2E |
| Documentation | Hunt through wikis | Inline in IDE |
| Boilerplate | Copy-paste starter code | Minimal, expressive API |
| Asset generation | Multiple tools | `redstone generate` |

---

# 5. TESTING SECTION

## Variation A: Code-Forward

### Test Like a Professional

```dart
import 'package:redstone_test/redstone_test.dart';

void main() async {
  await group('Ruby Ore', () async {
    await testMinecraft('drops rubies when mined', (game) async {
      // Place the ore
      final pos = BlockPos(100, 64, 100);
      game.placeBlock(pos, 'gemcraft:ruby_ore');

      // Mine it
      game.simulateMining(pos, tool: 'minecraft:iron_pickaxe');
      await game.waitTicks(5);

      // Check for drops
      final items = game.getDroppedItemsNear(pos);
      expect(items, contains(isItem('gemcraft:ruby')));
      expect(items.where((i) => i.id == 'gemcraft:ruby').length,
             inRange(1, 3));
    });

    await testMinecraft('requires iron pickaxe', (game) async {
      final pos = BlockPos(100, 64, 100);
      game.placeBlock(pos, 'gemcraft:ruby_ore');

      // Try mining with hand
      game.simulateMining(pos, tool: null);
      await game.waitTicks(20);

      // Block should still be there
      expect(game.getBlock(pos), isBlock('gemcraft:ruby_ore'));
    });
  });
}
```

---

## Variation B: Benefits Focus

### Test Your Mods Properly

#### Headless Server Testing
Tests run in a real Minecraft server—just without graphics. Same world, same physics, same behavior.

#### Tick-Based Control
Wait for specific game ticks, not arbitrary timeouts. `await game.waitTicks(20)` waits exactly 1 second of game time.

#### CI/CD Ready
Run tests in your GitHub Actions, GitLab CI, or any CI system. No display required.

#### Real Assertions
Test actual game state: block positions, entity health, item counts, recipe outputs. Not mocked data.

```bash
# Run in CI
redstone test --reporter json > results.json
```

---

## Variation C: Before/After Comparison

### Testing: Then and Now

#### Before (Manual Testing)
1. Launch Minecraft
2. Create test world
3. Give yourself items with `/give`
4. Place blocks manually
5. Try to remember what you tested
6. Hope you didn't miss an edge case
7. Repeat after every change

#### After (Redstone E2E Testing)
1. Write test once
2. Run `redstone test`
3. Get pass/fail results
4. See exactly what failed and why
5. Tests run automatically on every change
6. CI prevents broken code from merging

```bash
$ redstone test

Running tests...
✓ Ruby Ore drops rubies when mined (1.2s)
✓ Ruby Ore requires iron pickaxe (0.8s)
✓ Ruby Block can be crafted from 9 rubies (0.5s)
✓ Ruby Block recipe is reversible (0.4s)

All 4 tests passed!
```

---

## Variation D: What You Can Test

### Full Coverage for Your Mod

- [x] Block placement and breaking
- [x] Block properties and state changes
- [x] Item usage and durability
- [x] Crafting recipe outputs
- [x] Smelting recipe outputs
- [x] Entity spawning and behavior
- [x] Entity AI and pathfinding
- [x] Command execution and output
- [x] Loot table drops
- [x] World generation
- [x] Player interactions
- [x] Tick-based timing
- [x] Multi-world testing (Overworld, Nether, End)

```dart
// Example: Testing a furnace recipe
await testMinecraft('ruby ore smelts to ruby', (game) async {
  final result = game.simulateSmelting('gemcraft:ruby_ore');
  expect(result, isItem('gemcraft:ruby'));
});
```

---

# 6. CALL-TO-ACTION SECTION

## Variation A: Quick Start

### Get Started in 60 Seconds

```bash
# Install the CLI
dart pub global activate redstone_cli

# Create your mod
redstone create my_first_mod
cd my_first_mod

# Run it!
redstone run
```

You'll have a working mod running in under a minute.

**[Get Started →]** **[Read the Docs]** **[View on GitHub]**

---

## Variation B: Two Paths

### Choose Your Adventure

#### New to Modding?
Start with our beginner tutorial. We'll walk you through creating your first block, item, and entity step by step.

**[Start the Tutorial →]**

#### Experienced Modder?
Jump straight into the API reference. You'll feel right at home with familiar concepts and a cleaner syntax.

**[Browse the API →]**

---

## Variation C: Community Focus

### Join the Community

**GitHub** — Star the repo, report issues, contribute code
[github.com/redstone-dart/redstone](https://github.com/redstone-dart/redstone)

**Documentation** — Tutorials, guides, and API reference
[docs.redstone.dev →]

**[Get Started]** **[Star on GitHub]**

---

## Variation D: Minimal

### Ready to Build?

**[Get Started]** **[Documentation]** **[GitHub]**

---

## Variation E: Value Recap

### Why Developers Choose Redstone

- [x] Write less code with Dart's expressive syntax
- [x] Iterate faster with hot reload
- [x] Catch bugs early with static analysis
- [x] Ship confidently with E2E testing
- [x] Focus on your mod, not boilerplate

**[Start Building Today →]**

---

# Additional Elements

## Social Proof (if applicable)

> "Redstone cut my development time in half. Hot reload alone is worth switching for."
> — @dartdev

> "Finally, Minecraft modding that doesn't feel like a chore."
> — @modder123

## FAQ Section

**Q: Does this work with existing Fabric/Forge mods?**
A: Yes! Redstone mods are standard Fabric mods and work alongside any other Fabric mod.

**Q: What Minecraft versions are supported?**
A: Currently 1.21.x. We track the latest stable release.

**Q: Can I use Java alongside Dart?**
A: Yes. You can call Java code from Dart via JNI for advanced use cases.

**Q: Is this production-ready?**
A: Redstone is in active development. We recommend it for new projects and experimentation.

## Footer Links

- Documentation
- GitHub
- Changelog
- License (MIT)

---

*End of content reference document*
