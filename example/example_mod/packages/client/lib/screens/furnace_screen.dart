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
    // DEBUG: This print will show if hot reload actually loaded new code
    print('🔥🔥🔥 FURNACE BUILD - VERSION 999 🔥🔥🔥');

    // Note: GuiRouter already wraps us with SlotPositionScope, so we don't
    // need to create our own. Just use SlotReporter widgets for each slot.
    return Banner(
      message: 'VERSION 000',
      location: BannerLocation.topStart,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: McPanel(
            width: 176,
            padding: const EdgeInsets.all(70),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const McText.title('Example 0000'),

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

  // Flame shape (14x14 pixels) - diamond-like shape
  static const String _flameShape = '''
......XX......
......XX......
.....XXXX.....
.....XXXX.....
....XXXXXX....
....XXXXXX....
...XXXXXXXX...
...XXXXXXXX...
...XXXXXXXX...
...XXXXXXXX...
....XXXXXX....
....XXXXXX....
.....XXXX.....
.....XXXX.....''';

  static const Color _emptyColor = Color(0xFF373737);
  static const Color _litColor = Color(0xFFD87B26);

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Stack(
      children: [
        // Background: full flame in empty color
        McPixelArt(
          data: _flameShape,
          palette: const {'X': _emptyColor},
        ),
        // Foreground: lit flame clipped from bottom based on progress
        if (isLit && clampedProgress > 0)
          ClipRect(
            clipper: _VerticalProgressClipper(clampedProgress),
            child: McPixelArt(
              data: _flameShape,
              palette: const {'X': _litColor},
            ),
          ),
      ],
    );
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

  // Arrow shape (24x17 pixels) - shaft with arrowhead pointing right
  // Vanilla Minecraft style: horizontal shaft + triangular arrowhead with tip
  static const String _arrowShape = '''
......................X.
.....................XX.
....................XXX.
...................XXXX.
..................XXXXX.
.................XXXXXX.
................XXXXXXX.
...............XXXXXXXX.
XXXXXXXXXXXXXXXXXXXXXXXX
...............XXXXXXXX.
................XXXXXXX.
.................XXXXXX.
..................XXXXX.
...................XXXX.
....................XXX.
.....................XX.
......................X.''';

  static const Color _emptyColor = Color(0xFF8B8B8B);
  static const Color _fillColor = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Stack(
      children: [
        // Background: full arrow in empty color
        McPixelArt(
          data: _arrowShape,
          palette: const {'X': _emptyColor},
        ),
        // Foreground: filled arrow clipped from left based on progress
        if (clampedProgress > 0)
          ClipRect(
            clipper: _HorizontalProgressClipper(clampedProgress),
            child: McPixelArt(
              data: _arrowShape,
              palette: const {'X': _fillColor},
            ),
          ),
      ],
    );
  }
}

/// Clips from bottom to top based on progress (for vertical fill animations).
class _VerticalProgressClipper extends CustomClipper<Rect> {
  final double progress; // 0.0 to 1.0

  _VerticalProgressClipper(this.progress);

  @override
  Rect getClip(Size size) {
    final top = size.height * (1 - progress);
    return Rect.fromLTRB(0, top, size.width, size.height);
  }

  @override
  bool shouldReclip(_VerticalProgressClipper oldClipper) => progress != oldClipper.progress;
}

/// Clips from left to right based on progress (for horizontal fill animations).
class _HorizontalProgressClipper extends CustomClipper<Rect> {
  final double progress; // 0.0 to 1.0

  _HorizontalProgressClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * progress, size.height);
  }

  @override
  bool shouldReclip(_HorizontalProgressClipper oldClipper) => progress != oldClipper.progress;
}
