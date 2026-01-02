import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

// Example screens
import 'screens/widget_showcase.dart';
import 'screens/crafting_table_screen.dart';
import 'screens/chest_screen.dart';
import 'screens/furnace_screen.dart';
import 'screens/pause_menu_screen.dart';

void main() {
  runApp(const MinecraftUIExampleApp());
}

class MinecraftUIExampleApp extends StatelessWidget {
  const MinecraftUIExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minecraft UI Examples',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ExampleSelector(),
    );
  }
}

/// Main screen to select which example to view
class ExampleSelector extends StatelessWidget {
  const ExampleSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return McTheme(
      guiScale: 2.0,
      child: Scaffold(
        backgroundColor: McColors.black,
        body: Container(
          // Simulated Minecraft background (gradient overlay)
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                McColors.transparentOverlayTop,
                McColors.transparentOverlayBottom,
              ],
            ),
          ),
          child: Center(
            child: McPanel(
              width: 250,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const McText(
                    'Minecraft UI Examples',
                    fontSize: 1.5,
                  ),
                  const SizedBox(height: 24),

                  // Widget Showcase
                  McButton(
                    text: 'Widget Showcase',
                    size: McButtonSize.large,
                    onPressed: () => _openExample(context, const WidgetShowcase()),
                  ),
                  const SizedBox(height: 8),

                  // Crafting Table
                  McButton(
                    text: 'Crafting Table',
                    size: McButtonSize.large,
                    onPressed: () => _openExample(context, const CraftingTableScreen()),
                  ),
                  const SizedBox(height: 8),

                  // Chest
                  McButton(
                    text: 'Chest',
                    size: McButtonSize.large,
                    onPressed: () => _openExample(context, const ChestScreen()),
                  ),
                  const SizedBox(height: 8),

                  // Furnace
                  McButton(
                    text: 'Furnace',
                    size: McButtonSize.large,
                    onPressed: () => _openExample(context, const FurnaceScreen()),
                  ),
                  const SizedBox(height: 8),

                  // Pause Menu
                  McButton(
                    text: 'Pause Menu',
                    size: McButtonSize.large,
                    onPressed: () => _openExample(context, const PauseMenuScreen()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openExample(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
