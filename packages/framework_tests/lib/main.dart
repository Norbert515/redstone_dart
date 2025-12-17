// framework_tests - A Minecraft mod built with Redstone
//
// This is your mod's entry point. Register your blocks, entities,
// and other game objects here.

// Dart MC API imports
import 'package:dart_mc/dart_mc.dart';

/// Example custom block that shows a message when right-clicked.
///
/// This demonstrates how to create custom blocks in Dart.
/// The block will appear in the creative menu under "Building Blocks".
class HelloBlock extends CustomBlock {
  HelloBlock() : super(
    id: 'framework_tests:hello_block',
    settings: BlockSettings(
      hardness: 1.0,
      resistance: 1.0,
      requiresTool: false,
    ),
  );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    // Get player info and send a message
    final player = Players.getPlayer(playerId);
    if (player != null) {
      player.sendMessage('Hello from Framework Tests! You clicked at ($x, $y, $z)');
    }
    return ActionResult.success;
  }

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    print('HelloBlock broken at ($x, $y, $z) by player $playerId');
    return true; // Allow the block to be broken
  }
}

/// Main entry point for your mod.
///
/// This is called when the Dart VM is initialized by the native bridge.
void main() {
  print('Framework Tests mod initialized!');

  // Initialize the native bridge
  Bridge.initialize();

  // Register proxy block handlers (required for custom blocks)
  Events.registerProxyBlockHandlers();

  // =========================================================================
  // Register your custom blocks here
  // This MUST happen before the registry freezes (during mod initialization)
  // =========================================================================
  BlockRegistry.register(HelloBlock());

  // Add more blocks here:
  // BlockRegistry.register(MyOtherBlock());

  // Freeze the block registry (no more blocks can be registered after this)
  BlockRegistry.freeze();

  // =========================================================================
  // Register event handlers (optional)
  // =========================================================================
  Events.onBlockBreak((x, y, z, playerId) {
    // Called when ANY block is broken
    // Return EventResult.deny to prevent breaking
    return EventResult.allow;
  });

  Events.addTickListener((tick) {
    // Called every game tick (20 times per second)
    // Use for animations, timers, etc.
  });

  print('Framework Tests ready with ${BlockRegistry.blockCount} custom blocks!');
}
