// basic_dart_mod - A Minecraft mod built with Redstone
//
// This is your mod's entry point. Register your blocks, entities,
// and other game objects here.
//
// This example showcases many dart_mc APIs:
// - Custom blocks with interactive behavior
// - Custom items with use callbacks
// - Commands (heal, feed, fly, spawn, time)
// - Crafting recipes (shaped and shapeless)
// - Loot table modifications
// - Event handlers (player join, death, damage, chat)

// Dart MC API imports
import 'package:dart_mc/dart_mc.dart';

// Feature modules
import 'blocks/blocks.dart';
import 'commands/commands.dart';
import 'entities/entities.dart';
import 'events/events.dart';
import 'items/items.dart';
import 'loot_tables/loot_tables.dart';
import 'recipes/recipes.dart';

/// Main entry point for your mod.
///
/// This is called when the Dart VM is initialized by the native bridge.
void main() {
  print('Basic Dart Mod mod initialized!');

  // Initialize the native bridge
  Bridge.initialize();

  // Register proxy handlers (required for custom blocks and items)
  Events.registerProxyBlockHandlers();
  Events.registerProxyItemHandlers();

  // =========================================================================
  // Register your custom items here
  // Items must be registered BEFORE blocks that reference them as drops
  // =========================================================================
  registerItems();

  // =========================================================================
  // Register your custom blocks here
  // This MUST happen before the registry freezes (during mod initialization)
  // =========================================================================
  registerBlocks();

  // =========================================================================
  // Register custom entities
  // Demonstrates the Entity System API (CustomMonster, CustomAnimal, CustomProjectile)
  // =========================================================================
  registerEntities();

  // =========================================================================
  // Register custom commands
  // Demonstrates the Commands API
  // =========================================================================
  registerCommands();

  // =========================================================================
  // Register crafting recipes
  // Demonstrates the Recipes API
  // =========================================================================
  registerRecipes();

  // =========================================================================
  // Register loot table modifications
  // Demonstrates the LootTables API
  // =========================================================================
  registerLootTables();

  // =========================================================================
  // Register event handlers
  // Demonstrates the Events API
  // =========================================================================
  registerEventHandlers();

  print(
      'Basic Dart Mod ready with ${BlockRegistry.blockCount} custom blocks and ${EntityRegistry.entityCount} custom entities!');
  print('  Commands: /heal, /feed, /fly, /spawn, /time, /spawnzombie, /spawncow, /fireball');
  print('  Items: DartItem, EffectWand');
  print('  Blocks: HelloBlock, TerraformerBlock, MidasBlock, LightningRodBlock,');
  print('          MobSpawnerBlock, PartyBlock, WeatherControlBlock, EntityRadarBlock');
  print('  Entities: DartZombie (monster), DartCow (animal), DartFireball (projectile)');
}
