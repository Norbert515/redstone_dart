// Server entry point for dual-runtime mode
//
// This file handles ALL game logic:
// - Block/Item/Entity registrations
// - Commands
// - Recipes
// - Loot tables
// - Event handlers
// - Custom AI goals
//
// It runs on the Server thread using the pure Dart VM (dart_dll).

// Server-side Dart mod API
import 'package:dart_mod_server/dart_mod_server.dart';

// MCP runtime for AI-controlled testing
import 'package:minecraft_mcp/runtime.dart';

// Custom blocks
import 'src/flutter_display_controller_block.dart';

/// Server-side entry point for the mod.
///
/// This is called when the server-side Dart VM is initialized.
/// Registration of items/blocks/entities must be deferred until Java signals
/// that registries are ready.
void main() {
  print('Minecraft Flutter Dev server mod initialized!');

  // Initialize the native bridge
  // Note: In dual-runtime mode, the bridge is initialized by the native code
  // before main() is called, so this may be a no-op or skip if already initialized.
  Bridge.initialize();

  // Register proxy handlers (required for custom blocks and items)
  // These handlers don't use Minecraft registries, so they can be set up immediately
  Events.registerProxyBlockHandlers();
  Events.registerProxyItemHandlers();

  // Defer registration until Java signals that registries are ready
  // This is critical for timing - Dart's main() runs immediately
  // but Minecraft's registries may not be ready yet
  Bridge.onRegistryReady(() {
    print('Registry ready - registering items, blocks, entities...');

    // =========================================================================
    // Register your custom blocks here
    // =========================================================================
    FlutterDisplayControllerBlock.register();

    // =========================================================================
    // Register your custom items here
    // =========================================================================
    // ItemRegistry.register(MyItem());

    // =========================================================================
    // Register your custom entities here
    // =========================================================================
    // EntityRegistry.register(MyEntity());

    // =========================================================================
    // Register commands, recipes, loot tables, events as needed
    // =========================================================================

    print('Minecraft Flutter Dev server mod ready with ${BlockRegistry.blockCount} custom blocks!');

    // Initialize MCP runtime for AI-controlled testing (if enabled)
    // This starts an HTTP server that allows external AI agents to control Minecraft
    initializeMcpRuntime();
  });
}
