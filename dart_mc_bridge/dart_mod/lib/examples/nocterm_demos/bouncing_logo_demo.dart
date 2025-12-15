/// Bouncing logo demo component for nocterm Minecraft rendering.
///
/// DVD logo style bouncing rectangle animation.
/// The logo bounces off edges and changes color on each bounce.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:nocterm/nocterm.dart';

/// Configuration for the Bouncing Logo demo.
/// Modify these values and hot reload to see changes instantly!
class BouncingLogoConfig {
  BouncingLogoConfig._();

  /// Logo width in blocks (default: 4)
  static const int logoWidth = 4;

  /// Logo height in blocks (default: 3)
  static const int logoHeight = 3;

  /// Horizontal speed (default: 0.5)
  static const double speedX = 0.5;

  /// Vertical speed (default: 0.3)
  static const double speedY = 0.3;

  /// Animation interval in milliseconds (default: 50)
  static const int intervalMs = 50;

  /// Initial color for the logo
  static const initialColor = Color.fromRGB(255, 0, 0);
}

/// Custom painter for DVD logo style bouncing rectangle.
class BouncingLogoPainter extends CustomPainter {
  BouncingLogoPainter({
    required this.x,
    required this.y,
    required this.color,
    required this.logoWidth,
    required this.logoHeight,
  });

  final double x;
  final double y;
  final Color color;
  final int logoWidth;
  final int logoHeight;

  @override
  void paint(TerminalCanvas canvas, Size size) {
    final width = size.width.toInt();
    final height = size.height.toInt();

    // Fill background black
    for (int py = 0; py < height; py++) {
      for (int px = 0; px < width; px++) {
        canvas.fillRect(
          Rect.fromLTWH(px.toDouble(), py.toDouble(), 1, 1),
          ' ',
          style: const TextStyle(backgroundColor: Color.fromRGB(0, 0, 0)),
        );
      }
    }

    // Draw the bouncing logo
    final logoX = x.toInt();
    final logoY = y.toInt();
    for (int ly = 0; ly < logoHeight; ly++) {
      for (int lx = 0; lx < logoWidth; lx++) {
        final px = logoX + lx;
        final py = logoY + ly;
        if (px >= 0 && px < width && py >= 0 && py < height) {
          canvas.fillRect(
            Rect.fromLTWH(px.toDouble(), py.toDouble(), 1, 1),
            ' ',
            style: TextStyle(backgroundColor: color),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(BouncingLogoPainter oldDelegate) =>
      x != oldDelegate.x || y != oldDelegate.y || color != oldDelegate.color;
}

/// DVD logo style bouncing rectangle animation.
class BouncingLogoComponent extends StatefulComponent {
  const BouncingLogoComponent({super.key, this.gridWidth = 21, this.gridHeight = 16});

  final int gridWidth;
  final int gridHeight;

  @override
  State<BouncingLogoComponent> createState() => _BouncingLogoState();
}

class _BouncingLogoState extends State<BouncingLogoComponent> {
  Timer? _timer;
  double _x = 2;
  double _y = 2;
  double _dx = BouncingLogoConfig.speedX;
  double _dy = BouncingLogoConfig.speedY;
  Color _color = BouncingLogoConfig.initialColor;

  final math.Random _random = math.Random();

  static const _colors = [
    Color.fromRGB(255, 0, 0),
    Color.fromRGB(0, 255, 0),
    Color.fromRGB(0, 0, 255),
    Color.fromRGB(255, 255, 0),
    Color.fromRGB(255, 0, 255),
    Color.fromRGB(0, 255, 255),
    Color.fromRGB(255, 128, 0),
    Color.fromRGB(128, 0, 255),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: BouncingLogoConfig.intervalMs), (_) {
      setState(() {
        _x += _dx;
        _y += _dy;

        bool hitEdge = false;

        // Bounce off edges
        if (_x <= 0 || _x + BouncingLogoConfig.logoWidth >= component.gridWidth) {
          _dx = -_dx;
          _x = _x.clamp(0, (component.gridWidth - BouncingLogoConfig.logoWidth).toDouble());
          hitEdge = true;
        }
        if (_y <= 0 || _y + BouncingLogoConfig.logoHeight >= component.gridHeight) {
          _dy = -_dy;
          _y = _y.clamp(0, (component.gridHeight - BouncingLogoConfig.logoHeight).toDouble());
          hitEdge = true;
        }

        // Change color on edge hit
        if (hitEdge) {
          _color = _colors[_random.nextInt(_colors.length)];
        }
      });
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
      painter: BouncingLogoPainter(
        x: _x,
        y: _y,
        color: _color,
        logoWidth: BouncingLogoConfig.logoWidth,
        logoHeight: BouncingLogoConfig.logoHeight,
      ),
      size: Size(component.gridWidth.toDouble(), component.gridHeight.toDouble()),
    );
  }
}
