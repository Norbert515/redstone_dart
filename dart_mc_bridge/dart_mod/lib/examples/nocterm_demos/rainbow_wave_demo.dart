/// Rainbow wave demo component for nocterm Minecraft rendering.
///
/// Creates animated diagonal rainbow stripes that scroll across the screen.
/// Demonstrates custom painting with animation using Timer.periodic.
library;

import 'dart:async';

import 'package:nocterm/nocterm.dart';

/// Custom painter for diagonal rainbow wave pattern.
/// Draws diagonal stripes that animate over time.
class RainbowWavePainter extends CustomPainter {
  RainbowWavePainter({required this.frame});

  final int frame;

  // Rainbow colors
  static const _colors = [
    Color.fromRGB(255, 0, 0), // Red
    Color.fromRGB(255, 127, 0), // Orange
    Color.fromRGB(255, 255, 0), // Yellow
    Color.fromRGB(0, 255, 0), // Green
    Color.fromRGB(0, 255, 255), // Cyan
    Color.fromRGB(0, 0, 255), // Blue
    Color.fromRGB(139, 0, 255), // Purple
    Color.fromRGB(255, 0, 255), // Magenta
  ];

  @override
  void paint(TerminalCanvas canvas, Size size) {
    for (int y = 0; y < size.height; y++) {
      for (int x = 0; x < size.width; x++) {
        // Diagonal stripes: x + y gives diagonal, add frame for animation
        final colorIndex = ((x + y + frame) ~/ 3) % _colors.length;
        final color = _colors[colorIndex];

        // Fill this pixel with the background color
        canvas.fillRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          ' ', // Space character (we only care about background)
          style: TextStyle(backgroundColor: color),
        );
      }
    }
  }

  @override
  bool shouldRepaint(RainbowWavePainter oldDelegate) {
    return frame != oldDelegate.frame;
  }
}

/// An animated rainbow stripes component using setState and CustomPaint.
/// Creates diagonal rainbow stripes that animate.
class RainbowWaveComponent extends StatefulComponent {
  const RainbowWaveComponent({super.key, this.gridWidth = 21, this.gridHeight = 16});

  final int gridWidth;
  final int gridHeight;

  @override
  State<RainbowWaveComponent> createState() => _RainbowWaveState();
}

class _RainbowWaveState extends State<RainbowWaveComponent> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    // Animate at ~4 FPS for smooth scrolling
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      setState(() => _frame++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return CustomPaint(
      painter: RainbowWavePainter(frame: _frame),
      size: Size(component.gridWidth.toDouble(), component.gridHeight.toDouble()),
    );
  }
}
