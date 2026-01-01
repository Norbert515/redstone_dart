// Client entry point for dual-runtime mode
//
// This file handles ONLY the Flutter UI:
// - Flutter app initialization
// - The MinecraftFlutterApp widget
//
// It runs on the Render thread using the Flutter embedder.
// The Flutter widget tree IS the screen content - no callbacks needed.

// Flutter imports for UI rendering
import 'package:dart_mod_client/dart_mod_client.dart';
import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

/// Client-side entry point for the mod.
///
/// This is called when the client-side Flutter engine is initialized.
/// It sets up the Flutter app which renders directly to the Minecraft screen.
void main() {
  print('Client mod initialized!');

  // Start the Flutter app for UI rendering
  // The Flutter embedder will capture frames from this app and display
  // them in Minecraft's FlutterScreen when invoked
  runApp(const MinecraftGuiApp());

  print('Client mod ready! Flutter UI initialized.');
}

/// A Minecraft-themed Flutter app for GUI screens.
///
/// This widget tree provides frames to the Flutter embedder, which are then
/// displayed by the Minecraft FlutterScreen when invoked.
class MinecraftGuiApp extends StatelessWidget {
  const MinecraftGuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
      home: const McTheme(
        guiScale: 1.0, // Use 1.0 - Java already scales to framebuffer pixels
        // Show the test chest screen for testing the slot position integration
        child: TestChestScreen(menuId: 1),
      ),
    );
  }
}

/// A chest screen that reports slot positions to Java for item rendering.
///
/// This screen displays a 3x9 chest (27 slots) plus the player inventory (36 slots).
/// Each slot is wrapped with [SlotReporter] to report its position to the
/// [FlutterContainerScreen] on the Java side, which renders items on top.
class TestChestScreen extends StatelessWidget {
  /// The menu ID associated with this container.
  final int menuId;

  const TestChestScreen({super.key, required this.menuId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SlotPositionScope(
        menuId: menuId,
        child: Center(
          child: McPanel(
            width: 176, // Standard Minecraft container width
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                const McText.title('Test Chest'),
                const SizedBox(height: 8),

                // Container slots (3 rows x 9 columns = 27 slots)
                // Slots 0-26 are chest slots
                for (int row = 0; row < 3; row++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int col = 0; col < 9; col++)
                        SlotReporter(
                          slotIndex: row * 9 + col,
                          child: const McSlot(),
                        ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Player inventory label
                const Align(
                  alignment: Alignment.centerLeft,
                  child: McText.label('Inventory'),
                ),
                const SizedBox(height: 4),

                // Player main inventory (3 rows x 9 columns = 27 slots)
                // Slots 27-53 are player inventory
                for (int row = 0; row < 3; row++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int col = 0; col < 9; col++)
                        SlotReporter(
                          slotIndex: 27 + row * 9 + col,
                          child: const McSlot(),
                        ),
                    ],
                  ),

                const SizedBox(height: 4),

                // Player hotbar (1 row x 9 columns = 9 slots)
                // Slots 54-62 are hotbar
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int col = 0; col < 9; col++)
                      SlotReporter(
                        slotIndex: 54 + col,
                        child: const McSlot(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
