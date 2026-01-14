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
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:minecraft_flutter_dev_common/minecraft_flutter_dev_common.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

import 'screens/flutter_display_controller_screen.dart';

/// Client-side entry point for the mod.
///
/// This is called when the client-side Flutter engine is initialized.
/// It sets up the Flutter app which renders directly to the Minecraft screen.
void main() {
  print('Minecraft Flutter Dev client mod initialized!');

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

  print('Minecraft Flutter Dev client mod ready! Flutter UI initialized.');
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
            // Flutter Display Controller configuration screen
            GuiRoute(
              title: 'Flutter Display Controller',
              containerBuilder: FlutterDisplayControllerContainer.new,
              screenBuilder: (context) => const FlutterDisplayControllerScreen(),
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

  // Multi-block screen widget - displays content with gap handling
  // Route format: 'multiscreen?grid=111,101,111'
  // Grid string: rows separated by comma, 1=block present, 0=gap
  SurfaceRouter.registerWithParams('multiscreen', (params) {
    return MultiBlockScreenWidget(gridLayout: params['grid'] ?? '');
  });

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

/// A multi-block screen widget that renders content with transparency for gaps.
///
/// The grid layout is passed via the `gridLayout` parameter as a string:
/// - Rows are separated by commas: "111,101,111"
/// - Each character represents a cell: '1' = block present, '0' = gap
///
/// The widget renders transparent where gaps exist in the grid.
class MultiBlockScreenWidget extends StatefulWidget {
  /// The grid layout string (rows separated by comma, 1=present, 0=gap).
  final String gridLayout;

  const MultiBlockScreenWidget({
    super.key,
    this.gridLayout = '',
  });

  @override
  State<MultiBlockScreenWidget> createState() => _MultiBlockScreenWidgetState();
}

class _MultiBlockScreenWidgetState extends State<MultiBlockScreenWidget> {
  late List<List<bool>> _grid;
  int _animationTick = 0;

  @override
  void initState() {
    super.initState();
    _parseGrid();
    // Animate the display
    Stream.periodic(const Duration(milliseconds: 100)).listen((_) {
      if (mounted) {
        setState(() {
          _animationTick++;
        });
      }
    });
  }

  void _parseGrid() {
    if (widget.gridLayout.isEmpty) {
      _grid = [
        [true]
      ];
      return;
    }

    _grid = widget.gridLayout.split(',').map((row) {
      return row.split('').map((char) => char == '1').toList();
    }).toList();

    print('[MultiBlockScreen] Parsed grid: ${_grid.length} rows');
  }

  @override
  Widget build(BuildContext context) {
    final rows = _grid.length;
    final cols = _grid.isNotEmpty ? _grid.first.length : 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use CustomPaint to only draw in cells that have blocks
        // Gaps will be truly transparent (alpha = 0)
        // Wrap in ColoredBox with transparent to ensure no background
        return ColoredBox(
          color: const Color(0x00000000), // Fully transparent background
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _MultiBlockPainter(
              rows: rows,
              cols: cols,
              grid: _grid,
              animationTick: _animationTick,
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter that renders content only in cells where blocks exist.
/// Gaps (cells without blocks) are left completely transparent.
class _MultiBlockPainter extends CustomPainter {
  final int rows;
  final int cols;
  final List<List<bool>> grid;
  final int animationTick;

  _MultiBlockPainter({
    required this.rows,
    required this.cols,
    required this.grid,
    required this.animationTick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    // Create gradient colors based on animation
    final color1 = HSVColor.fromAHSV(
      1.0,
      (animationTick * 2) % 360,
      0.7,
      0.3,
    ).toColor();
    final color2 = HSVColor.fromAHSV(
      1.0,
      (animationTick * 2 + 120) % 360,
      0.7,
      0.3,
    ).toColor();

    // Draw each cell that has a block
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        if (grid[row][col]) {
          final rect = Rect.fromLTWH(
            col * cellWidth,
            row * cellHeight,
            cellWidth,
            cellHeight,
          );

          // Calculate gradient position for this cell
          final t = (col + row) / (cols + rows - 2).clamp(1, double.infinity);
          final cellColor = Color.lerp(color1, color2, t)!;

          // Fill the cell with color
          final paint = Paint()
            ..color = cellColor
            ..style = PaintingStyle.fill;
          canvas.drawRect(rect, paint);

          // Draw cell border
          final borderPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas.drawRect(rect, borderPaint);
        }
        // Cells without blocks are left unpainted (transparent)
      }
    }

    // Draw centered text
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'MULTI-BLOCK\n',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          TextSpan(
            text: 'DISPLAY\n',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
              fontWeight: FontWeight.w300,
              letterSpacing: 6,
            ),
          ),
          TextSpan(
            text: '${cols}x$rows',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Only draw text if it fits within the active area
    final textX = (size.width - textPainter.width) / 2;
    final textY = (size.height - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(textX, textY));
  }

  @override
  bool shouldRepaint(_MultiBlockPainter oldDelegate) {
    return rows != oldDelegate.rows ||
        cols != oldDelegate.cols ||
        grid != oldDelegate.grid ||
        animationTick != oldDelegate.animationTick;
  }
}

/// Custom painter to draw grid cell boundaries.
class _GridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final List<List<bool>> grid;

  _GridPainter({
    required this.rows,
    required this.cols,
    required this.grid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw grid lines for cells that are present
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        if (grid[row][col]) {
          final rect = Rect.fromLTWH(
            col * cellWidth,
            row * cellHeight,
            cellWidth,
            cellHeight,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return rows != oldDelegate.rows ||
        cols != oldDelegate.cols ||
        grid != oldDelegate.grid;
  }
}
