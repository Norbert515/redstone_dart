// example_mod - A Minecraft mod built with Redstone
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
// - Flutter UI rendering (via /fluttertest command)

// Flutter imports for UI rendering
import 'package:flutter/material.dart';

// Dart MC API imports
// Hide Widget to avoid conflict with Flutter's Widget class
import 'package:dart_mc/dart_mc.dart' hide Widget;

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
/// With Flutter embedder, this runs immediately when the engine starts.
/// Registration of items/blocks/entities must be deferred until Java signals
/// that registries are ready.
void main() {
  print('Basic Dart Mod mod initialized!');

  // Start the Flutter app for UI rendering
  // This enables the /fluttertest command to display Flutter widgets
  runApp(const MinecraftFlutterApp());

  // Initialize the native bridge
  Bridge.initialize();

  // Register proxy handlers (required for custom blocks and items)
  // These handlers don't use Minecraft registries, so they can be set up immediately
  Events.registerProxyBlockHandlers();
  Events.registerProxyItemHandlers();
  Events.registerCustomGoalHandlers(); // Required for custom Dart-defined AI goals

  // Initialize screen callbacks for GUI
  initScreenCallbacks();

  // NOTE: With the merged thread approach, EventPoller is no longer needed.
  // The Flutter embedder runs the UI isolate on the platform thread, allowing
  // FFI callbacks to work directly. Java calls processFlutterTasks() to pump
  // the Flutter event loop during each tick.

  // Defer registration until Java signals that registries are ready
  // This is critical for Flutter embedder timing - Dart's main() runs immediately
  // but Minecraft's registries may not be ready yet
  Bridge.onRegistryReady(() {
    print('Registry ready - registering items, blocks, entities...');

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
    print('  Commands: /heal, /feed, /fly, /spawn, /time, /spawnzombie, /spawncow, /fireball, /spawncustomzombie');
    print('  Items: DartItem, EffectWand');
    print('  Blocks: HelloBlock, TerraformerBlock, MidasBlock, LightningRodBlock,');
    print('          MobSpawnerBlock, PartyBlock, WeatherControlBlock, EntityRadarBlock');
    print('  Entities: DartZombie, DartCow, DartFireball, CustomGoalZombie (with Dart AI!)');
    print('  Flutter: Use /fluttertest to see the Flutter UI');
  });
}

/// A simple Flutter app that renders a test UI for the /fluttertest command.
///
/// This widget tree provides frames to the Flutter embedder, which are then
/// displayed by the Minecraft FlutterScreen when /fluttertest is invoked.
class MinecraftFlutterApp extends StatelessWidget {
  const MinecraftFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.dark(
          primary: Colors.green,
          secondary: Colors.amber,
        ),
      ),
      home: const FlutterTestScreen(),
    );
  }
}

/// A simple test screen demonstrating Flutter rendering in Minecraft.
class FlutterTestScreen extends StatefulWidget {
  const FlutterTestScreen({super.key});

  @override
  State<FlutterTestScreen> createState() => _FlutterTestScreenState();
}

class _FlutterTestScreenState extends State<FlutterTestScreen> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Flutter in Minecraft!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Counter: $_counter',
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => _counter--),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('-', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _counter++),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('+', style: TextStyle(fontSize: 24)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Press ESC to close',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
