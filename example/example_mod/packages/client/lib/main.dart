// Client entry point for dual-runtime mode
//
// This file handles ONLY the Flutter UI:
// - Flutter app initialization
// - GUI routing for different container types
//
// It runs on the Render thread using the Flutter embedder.
// The Flutter widget tree IS the screen content - no callbacks needed.

// Flutter imports for UI rendering
import 'dart:developer' as developer;

import 'package:dart_mod_client/dart_mod_client.dart';
import 'package:dart_mod_common/src/jni/jni_internal.dart';
import 'package:example_mod_common/example_mod_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

import 'screens/simple_furnace_screen.dart';

/// Client-side entry point for the mod.
///
/// This is called when the client-side Flutter engine is initialized.
/// It sets up the Flutter app which renders directly to the Minecraft screen.
void main() {
  print('Client mod initialized!');

  // Ensure surfaceMain is included in the kernel (prevents tree-shaking)
  // This is a no-op reference that the compiler can't optimize away
  // ignore: unnecessary_null_comparison
  if (surfaceMain == null) {
    throw StateError('surfaceMain should never be null');
  }

  // Print VM service URL for hot reload detection
  // The CLI looks for "flutter: The Dart VM service is listening on ..." pattern
  // We explicitly add the "flutter:" prefix since the embedder doesn't add it
  final serviceInfo = developer.Service.getInfo();
  serviceInfo.then((info) {
    if (info.serverUri != null) {
      // ignore: avoid_print
      print('flutter: The Dart VM service is listening on ${info.serverUri}');
    }
  });

  // Initialize the JNI bridge for calling Java methods from Dart
  GenericJniBridge.init();

  // Register surface widgets for multi-surface rendering
  // These can be displayed on FlutterDisplayEntity in the world
  _registerSurfaceWidgets();

  // Start the Flutter app for UI rendering
  // The Flutter embedder will capture frames from this app and display
  // them in Minecraft's FlutterScreen when invoked
  runApp(const MinecraftGuiApp());

  // Register service extension for hot reload frame scheduling
  developer.registerExtension('ext.redstone.scheduleFrame', (method, params) async {
    SchedulerBinding.instance.scheduleFrame();
    return developer.ServiceExtensionResponse.result('{}');
  });

  print('Client mod ready! Flutter UI initialized.');
}

/// A Minecraft-themed Flutter app for GUI screens.
///
/// This widget tree provides frames to the Flutter embedder, which are then
/// displayed by the Minecraft FlutterScreen when invoked.
///
/// Uses [GuiRouter] to declaratively map container types to screen widgets.
class MinecraftGuiApp extends StatelessWidget {
  const MinecraftGuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
      home: McTheme(
        guiScale: 1.0, // Use 1.0 - Java already scales to framebuffer pixels
        child: GuiRouter(
          routes: [
            // Test chest container
            GuiRoute(
              containerId: 'example_mod:test_chest',
              builder: (context, info) => TestChestScreen(menuId: info.menuId),
            ),
            // SimpleFurnace - demonstrates the new Container API with reactive synced values
            GuiRoute(
              title: 'Simple Furnace',
              containerBuilder: () => SimpleFurnaceContainer(),
              screenBuilder: (context) => const SimpleFurnaceScreen(),
              cacheSlotPositions: true,
            ),
          ],
          // Show a test background when no container is open
          // This helps verify the Metal rendering pipeline is working
          background: Container(
            color: Colors.blue,
            child: const Center(
              child: Text(
                'Flutter Rendering Test',
                style: TextStyle(color: Colors.white, fontSize: 32),
              ),
            ),
          ),
          // Fallback for unknown container types - show a generic screen
          fallback: (context, info) {
            print('[GuiRouter] Unknown container: ${info.containerId}');
            return Center(
              child: McPanel(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: McText.label('Unknown container: ${info.containerId}'),
                ),
              ),
            );
          },
        ),
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

// =============================================================================
// Surface Widget Registration & Multi-Surface Entry Point
// =============================================================================

/// Entry point for spawned Flutter surface engines (multi-surface rendering).
///
/// This is called by the Flutter embedder when a new surface engine starts.
/// It must register the same routes as main() before running SurfaceApp.
///
/// **CRITICAL:** Each spawned engine is an independent Dart isolate that doesn't
/// share memory with the main engine. We must register routes here too!
@pragma('vm:entry-point')
void surfaceMain(List<String> args) {
  print('[surfaceMain] Starting spawned surface engine with args: $args');

  // Register the same surface widgets as main()
  // This is critical because spawned engines don't share memory with main
  _registerSurfaceWidgets();

  // Parse route from entry point arguments (passed via dart_entrypoint_argv)
  final route = SurfaceRouter.parseRouteFromArgs(args);
  print('[surfaceMain] Parsed route: $route');

  // Run the SurfaceApp with the parsed route
  runApp(SurfaceApp(route: route));

  print('[surfaceMain] Spawned surface engine running.');
}

/// Register widgets that can be displayed on FlutterDisplayEntity surfaces.
///
/// Each route maps to a widget builder. When a FlutterDisplay is spawned
/// with a route, the corresponding widget is rendered on that surface.
///
/// **Note:** This function is called by both main() and surfaceMain() to ensure
/// routes are available in all Flutter engines (main and spawned surfaces).
void _registerSurfaceWidgets() {
  // Clock widget - shows current time
  SurfaceRouter.register('clock', () => const ClockWidget());

  // Health bar widget - shows a sample health display
  SurfaceRouter.register('health', () => const HealthBarWidget());

  // Color test widget - cycles through colors
  SurfaceRouter.register('colors', () => const ColorTestWidget());

  print('[Client] Registered ${SurfaceRouter.routes.length} surface widgets');
}

// =============================================================================
// Sample Surface Widgets
// =============================================================================

/// A clock widget showing the current time.
class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  late Stream<DateTime> _timeStream;

  @override
  void initState() {
    super.initState();
    _timeStream = Stream.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: StreamBuilder<DateTime>(
          stream: _timeStream,
          builder: (context, snapshot) {
            final time = snapshot.data ?? DateTime.now();
            final timeStr =
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
            return Text(
              timeStr,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 48,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A health bar widget showing a sample health display.
class HealthBarWidget extends StatelessWidget {
  const HealthBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'HEALTH',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.75,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '15 / 20',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// A widget that cycles through colors for testing.
class ColorTestWidget extends StatefulWidget {
  const ColorTestWidget({super.key});

  @override
  State<ColorTestWidget> createState() => _ColorTestWidgetState();
}

class _ColorTestWidgetState extends State<ColorTestWidget> {
  int _colorIndex = 0;
  static const _colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    // Cycle colors every 2 seconds
    Stream.periodic(const Duration(seconds: 2)).listen((_) {
      if (mounted) {
        setState(() {
          _colorIndex = (_colorIndex + 1) % _colors.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: _colors[_colorIndex],
      child: Center(
        child: Text(
          'Color ${_colorIndex + 1}/${_colors.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}
