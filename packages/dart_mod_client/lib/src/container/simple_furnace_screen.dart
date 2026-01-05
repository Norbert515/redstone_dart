/// Flutter screen for the SimpleFurnace container.
library;

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

import '../gui/slot_reporter.dart';
import 'container_screen.dart';
import 'watch.dart';

/// Flutter screen for the SimpleFurnace container.
///
/// Displays a furnace UI with:
/// - Input slot (top)
/// - Fuel slot (bottom-left)
/// - Output slot (right)
/// - Flame indicator showing fuel burn progress
/// - Arrow showing cooking progress
/// - Player inventory at the bottom
///
/// Uses [Watch2] to reactively rebuild progress indicators when synced values
/// change from the server.
///
/// Example usage:
/// ```dart
/// GuiRegistry.register<SimpleFurnaceContainer>(
///   (container, menuId) => SimpleFurnaceScreen(
///     container: container,
///     menuId: menuId,
///   ),
/// );
/// ```
class SimpleFurnaceScreen extends ContainerScreen<SimpleFurnaceContainer> {
  const SimpleFurnaceScreen({
    super.key,
    required super.container,
    required super.menuId,
  });

  @override
  ContainerScreenState<SimpleFurnaceContainer> createState() =>
      _SimpleFurnaceScreenState();
}

class _SimpleFurnaceScreenState
    extends ContainerScreenState<SimpleFurnaceContainer> {
  @override
  Widget build(BuildContext context) {
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
              const McText.title('Furnace'),

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
                        slotIndex: SimpleFurnaceContainer.inputSlot,
                        child: const McSlot(),
                      ),
                      const SizedBox(height: 4),
                      // Flame indicator (fuel remaining)
                      Watch2(
                        container.litTime,
                        container.litDuration,
                        builder: (litTime, litDuration) {
                          final progress =
                              litDuration > 0 ? litTime / litDuration : 0.0;
                          return _FurnaceFlame(
                            progress: progress,
                            isLit: litTime > 0,
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      // Fuel slot (index 1)
                      SlotReporter(
                        slotIndex: SimpleFurnaceContainer.fuelSlot,
                        child: const McSlot(),
                      ),
                    ],
                  ),

                  const SizedBox(width: 24),

                  // Arrow progress indicator
                  Watch2(
                    container.cookingProgress,
                    container.cookingTotalTime,
                    builder: (progress, total) {
                      final cookProgress = total > 0 ? progress / total : 0.0;
                      return _FurnaceArrow(progress: cookProgress);
                    },
                  ),

                  const SizedBox(width: 24),

                  // Output slot (index 2)
                  SlotReporter(
                    slotIndex: SimpleFurnaceContainer.outputSlot,
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
class _FurnaceFlame extends StatelessWidget {
  /// Progress value (0.0 to 1.0). 1.0 = full flame, 0.0 = empty.
  final double progress;

  /// Whether the furnace is currently lit (burning fuel).
  final bool isLit;

  const _FurnaceFlame({
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
/// Matches the vanilla Minecraft furnace arrow appearance (24x17 pixels).
class _FurnaceArrow extends StatelessWidget {
  /// Progress value (0.0 to 1.0). 1.0 = full arrow, 0.0 = empty.
  final double progress;

  const _FurnaceArrow({required this.progress});

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
  bool shouldReclip(_VerticalProgressClipper oldClipper) =>
      progress != oldClipper.progress;
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
  bool shouldReclip(_HorizontalProgressClipper oldClipper) =>
      progress != oldClipper.progress;
}
