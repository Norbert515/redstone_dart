import 'dart:async';

import 'package:dart_mod_client/dart_mod_client.dart';
import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

/// A Flutter-based furnace screen for the Example Furnace block entity.
///
/// This screen:
/// - Displays the 3 furnace slots (input, fuel, output)
/// - Shows burn progress (flame) and cooking progress (arrow)
/// - Reports slot positions to Java for item rendering
/// - Polls progress values from Java via JNI
class ExampleFurnaceScreen extends StatefulWidget {
  /// The menu ID associated with this container.
  final int menuId;

  const ExampleFurnaceScreen({super.key, required this.menuId});

  @override
  State<ExampleFurnaceScreen> createState() => _ExampleFurnaceScreenState();
}

class _ExampleFurnaceScreenState extends State<ExampleFurnaceScreen> {
  late Timer _refreshTimer;
  final _containerView = const ClientContainerView();

  // Progress values polled from Java
  double _litProgress = 0;
  double _burnProgress = 0;
  bool _isLit = false;

  @override
  void initState() {
    super.initState();
    // Poll progress values periodically (20 times per second = every 50ms)
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateProgress();
    });
  }

  void _updateProgress() {
    setState(() {
      _litProgress = _containerView.litProgress;
      _burnProgress = _containerView.burnProgress;
      _isLit = _containerView.isLit;
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Note: GuiRouter already wraps us with SlotPositionScope, so we don't
    // need to create our own. Just use SlotReporter widgets for each slot.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: McPanel(
          width: 176,
          padding: const EdgeInsets.all(7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const McText.title('Example Furnace'),

              const SizedBox(height: 8),

              // Furnace slots and progress indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Input and fuel column
                  Column(
                    children: [
                      // Input slot (index 0)
                      SlotReporter(
                        slotIndex: 0,
                        child: const McSlot(),
                      ),
                      const SizedBox(height: 4),
                      // Flame indicator (fuel remaining)
                      McFurnaceFlame(
                        progress: _litProgress,
                        isLit: _isLit,
                      ),
                      const SizedBox(height: 4),
                      // Fuel slot (index 1)
                      SlotReporter(
                        slotIndex: 1,
                        child: const McSlot(),
                      ),
                    ],
                  ),

                  const SizedBox(width: 24),

                  // Arrow progress indicator
                  McFurnaceArrow(progress: _burnProgress),

                  const SizedBox(width: 24),

                  // Output slot (index 2)
                  SlotReporter(
                    slotIndex: 2,
                    child: const McSlot(),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Player inventory label
              const McText.label('Inventory'),
              const SizedBox(height: 2),

              // Player inventory (3 rows x 9 columns)
              // Slots 3-29 are player main inventory
              for (int row = 0; row < 3; row++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int col = 0; col < 9; col++)
                      SlotReporter(
                        slotIndex: 3 + row * 9 + col,
                        child: const McSlot(),
                      ),
                  ],
                ),

              const SizedBox(height: 4),

              // Player hotbar (1 row x 9 columns)
              // Slots 30-38 are hotbar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int col = 0; col < 9; col++)
                    SlotReporter(
                      slotIndex: 30 + col,
                      child: const McSlot(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minecraft-style furnace flame indicator with pixel-perfect rendering.
///
/// Shows a simple flame silhouette that fills from bottom to top based on [progress].
/// Matches the vanilla Minecraft furnace flame appearance.
class McFurnaceFlame extends StatelessWidget {
  /// Progress value (0.0 to 1.0). 1.0 = full flame, 0.0 = empty.
  final double progress;

  /// Whether the furnace is currently lit (burning fuel).
  final bool isLit;

  const McFurnaceFlame({
    super.key,
    required this.progress,
    this.isLit = true,
  });

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    return CustomPaint(
      painter: _FlamePainter(
        progress: progress.clamp(0.0, 1.0),
        isLit: isLit,
      ),
      size: Size(14 * scale, 14 * scale),
    );
  }
}

class _FlamePainter extends CustomPainter {
  final double progress;
  final bool isLit;

  static const Color _emptyColor = Color(0xFF373737);
  static const Color _litColor = Color(0xFFD87B26);

  // Vanilla Minecraft flame shape (14x14)
  // Each row lists which X columns have pixels, from top (row 0) to bottom (row 13)
  static const List<List<int>> _flameShape = [
    [6, 7], // row 0 (top tip)
    [6, 7],
    [5, 6, 7, 8],
    [5, 6, 7, 8],
    [4, 5, 6, 7, 8, 9],
    [4, 5, 6, 7, 8, 9],
    [3, 4, 5, 6, 7, 8, 9, 10],
    [3, 4, 5, 6, 7, 8, 9, 10],
    [3, 4, 5, 6, 7, 8, 9, 10],
    [3, 4, 5, 6, 7, 8, 9, 10],
    [4, 5, 6, 7, 8, 9],
    [4, 5, 6, 7, 8, 9],
    [5, 6, 7, 8],
    [5, 6, 7, 8], // row 13 (bottom)
  ];

  _FlamePainter({required this.progress, required this.isLit});

  @override
  void paint(Canvas canvas, Size size) {
    final pixelSize = size.width / 14;
    final totalRows = _flameShape.length;

    // Calculate how many rows from the bottom should be lit
    // progress 1.0 = all rows lit, 0.0 = no rows lit
    final litRows = (totalRows * progress).round();
    // The cutoff row index (rows >= this are empty/dark)
    final cutoffRow = totalRows - litRows;

    final emptyPaint = Paint()..color = _emptyColor;
    final litPaint = Paint()..color = _litColor;

    for (int row = 0; row < totalRows; row++) {
      final y = row * pixelSize;
      final isLitRow = isLit && row >= cutoffRow;
      final paint = isLitRow ? litPaint : emptyPaint;

      for (final x in _flameShape[row]) {
        canvas.drawRect(
          Rect.fromLTWH(x * pixelSize, y, pixelSize, pixelSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) {
    return progress != oldDelegate.progress || isLit != oldDelegate.isLit;
  }
}

/// Minecraft-style furnace arrow indicator with pixel-perfect rendering.
///
/// Shows a simple arrow that fills from left to right based on [progress].
/// Matches the vanilla Minecraft furnace arrow appearance (22x16 pixels).
class McFurnaceArrow extends StatelessWidget {
  /// Progress value (0.0 to 1.0). 1.0 = full arrow, 0.0 = empty.
  final double progress;

  const McFurnaceArrow({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    return CustomPaint(
      painter: _ArrowPainter(progress: progress.clamp(0.0, 1.0)),
      size: Size(22 * scale, 16 * scale),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final double progress;

  static const Color _emptyColor = Color(0xFF8B8B8B);
  static const Color _fillColor = Color(0xFFFFFFFF);

  // Vanilla Minecraft arrow shape (22x16)
  // Each row lists [startX, endX] for the arrow shape
  // Shaft is ~5px tall in center, arrowhead is triangle on right
  static const List<List<int>> _arrowShape = [
    [17, 18], // row 0 - arrowhead top
    [16, 19], // row 1
    [16, 20], // row 2
    [15, 21], // row 3
    [15, 22], // row 4
    [0, 22], // row 5 - shaft + arrowhead (shaft starts)
    [0, 22], // row 6
    [0, 22], // row 7 - middle
    [0, 22], // row 8
    [0, 22], // row 9 - shaft + arrowhead (shaft ends)
    [15, 22], // row 10
    [15, 21], // row 11
    [16, 20], // row 12
    [16, 19], // row 13
    [17, 18], // row 14 - arrowhead bottom
    [], // row 15 - empty
  ];

  _ArrowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final pixelW = size.width / 22;
    final pixelH = size.height / 16;

    final emptyPaint = Paint()..color = _emptyColor;
    final fillPaint = Paint()..color = _fillColor;

    // Calculate fill cutoff (in pixels from left)
    final fillCutoff = 22 * progress;

    for (int row = 0; row < _arrowShape.length; row++) {
      final rowData = _arrowShape[row];
      if (rowData.isEmpty) continue;

      final startX = rowData[0];
      final endX = rowData[1];
      final y = row * pixelH;

      // Draw each pixel in the row
      for (int x = startX; x < endX; x++) {
        final isFilled = x < fillCutoff;
        canvas.drawRect(
          Rect.fromLTWH(x * pixelW, y, pixelW, pixelH),
          isFilled ? fillPaint : emptyPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
