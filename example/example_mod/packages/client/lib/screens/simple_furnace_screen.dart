/// Flutter screen for the SimpleFurnace container.
library;

import 'package:dart_mod_client/dart_mod_client.dart';
import 'package:example_mod_common/example_mod_common.dart';
import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

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
/// Uses [ContainerScope] to access the container and automatically rebuild
/// when synced values change from the server.
///
/// Example usage:
/// ```dart
/// GuiRoute(
///   title: 'Simple Furnace',
///   containerBuilder: () => SimpleFurnaceContainer(),
///   screenBuilder: (context) => const SimpleFurnaceScreen(),
/// )
/// ```
class SimpleFurnaceScreen extends StatelessWidget {
  const SimpleFurnaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final container = ContainerScope.of<SimpleFurnaceContainer>(context);

    // Access synced values directly - widget rebuilds automatically when they change
    final litTime = container.litTime.value;
    final litDuration = container.litDuration.value;
    final cookingProgress = container.cookingProgress.value;
    final cookingTotalTime = container.cookingTotalTime.value;

    // Calculate progress values
    final fuelProgress = litDuration > 0 ? litTime / litDuration : 0.0;
    final cookProgress = cookingTotalTime > 0 ? cookingProgress / cookingTotalTime : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(
            child: Banner(
              message: 'This is Flutter!',
              location: BannerLocation.topStart,
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
                            _FurnaceFlame(
                              progress: fuelProgress,
                              isLit: litTime > 0,
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
                        _FurnaceArrow(progress: cookProgress),

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
          ),

          // Uncomment for video (hot reload): fun "Powered by Flutter" badge.
          const Positioned(
            right: 90,
            bottom: 130,
            child: _FlutterHypeBadge(),
          ),
        ],
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
........................
........................
..............X.........
..............XX........
..............XXX.......
..............XXXX......
..XXXXXXXXXXXXXXXXX.....
..XXXXXXXXXXXXXXXXXX....
..XXXXXXXXXXXXXXXXXXX...
..XXXXXXXXXXXXXXXXXX....
..XXXXXXXXXXXXXXXXX.....
..............XXXX......
..............XXX.......
..............XX........
..............X.........
........................
........................''';

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

/// A fun little "Powered by Flutter" badge (for video).
///
/// Intended to be placed as an overlay in the bottom-right corner.
class _FlutterHypeBadge extends StatefulWidget {
  const _FlutterHypeBadge();

  @override
  State<_FlutterHypeBadge> createState() => _FlutterHypeBadgeState();
}

class _FlutterHypeBadgeState extends State<_FlutterHypeBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Tap-to-cycle text for a bit of "wow it's interactive" on camera.
  static const List<String> _messages = [
    'Powered by Flutter',
    'Hot reload magic',
    'Pixel UI, real Flutter',
    'Vibes: 60fps',
  ];

  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cycleMessage() {
    setState(() {
      _messageIndex = (_messageIndex + 1) % _messages.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = _messages[_messageIndex];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value; // 0..1
        final lift = (t - 0.5).abs(); // 0.5..0
        final translateY = -2.0 + (lift * 4.0); // subtle bounce
        final rotate = (t - 0.5) * 0.10; // subtle wiggle

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.rotate(
            angle: rotate,
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _cycleMessage,
          borderRadius: BorderRadius.circular(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xCC0B0E14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6EE7FF), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FlutterLogo(size: 18),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
