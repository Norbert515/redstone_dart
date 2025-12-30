// Datagen entry point - does NOT import Flutter
//
// This file is used by the CLI to generate manifest.json for asset generation.
// It mirrors main.dart but without Flutter imports/runApp() which require dart:ui.
// The standard Dart VM doesn't have dart:ui, so we need this separate entry point.

import 'package:dart_mc/dart_mc.dart';

// Feature modules
import 'blocks/blocks.dart';
import 'commands/commands.dart';
import 'entities/entities.dart';
import 'events/events.dart';
import 'items/items.dart';
import 'loot_tables/loot_tables.dart';
import 'recipes/recipes.dart';

void main() {
  print('Running in datagen mode...');

  // Initialize the native bridge (in datagen mode, uses stubs)
  Bridge.initialize();

  // Register proxy handlers (required for custom blocks and items)
  // These handlers don't use Minecraft registries, so they can be set up immediately
  Events.registerProxyBlockHandlers();
  Events.registerProxyItemHandlers();
  Events.registerCustomGoalHandlers();

  // Initialize screen callbacks for GUI (skipped in datagen mode)
  initScreenCallbacks();

  // In datagen mode, Bridge.onRegistryReady calls callback immediately
  Bridge.onRegistryReady(() {
    print('Datagen: Registering items, blocks, entities...');

    // Register all mod content - same order as main.dart
    registerItems();
    registerBlocks();
    registerEntities();
    registerCommands();
    registerRecipes();
    registerLootTables();
    registerEventHandlers();

    print('Datagen complete!');
  });
}
