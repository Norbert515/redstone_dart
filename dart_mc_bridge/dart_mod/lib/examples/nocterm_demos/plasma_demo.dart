/// Plasma demo component for nocterm Minecraft rendering.
///
/// Animated plasma/lava lamp effect using overlapping sine waves.
/// Creates a mesmerizing color gradient animation.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:nocterm/nocterm.dart';

/// Configuration for the Plasma demo.
/// Modify these values and hot reload to see changes instantly!
class PlasmaConfig {
  PlasmaConfig._();

  /// Speed multiplier for animation (default: 0.1)
  static const double speed = 0.5;

  /// Saturation of colors (0.0-1.0, default: 0.8)
  static const double saturation = 0.8;

  /// Value/brightness of colors (0.0-1.0, default: 0.9)
  static const double brightness = 0.9;

  /// Hue offset in degrees (0-360, default: 180)
  /// Changes the color palette: 0=red, 60=yellow, 120=green, 180=cyan, 240=blue, 300=magenta
  static const double hueOffset = 180;

  /// Hue range in degrees (default: 180)
  /// How much of the color spectrum to use
  static const double hueRange = 180;

  /// Wave frequency X (default: 0.3)
  static const double waveFreqX = 0.3;

  /// Wave frequency Y (default: 0.3)
  static const double waveFreqY = 0.3;
}

/// Custom painter for animated plasma/lava lamp effect.
class PlasmaPainter extends CustomPainter {
  PlasmaPainter({required this.frame});

  final int frame;

  @override
  void paint(TerminalCanvas canvas, Size size) {
    final width = size.width.toInt();
    final height = size.height.toInt();
    final time = frame * PlasmaConfig.speed;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Create plasma effect using overlapping sine waves
        final value1 = math.sin(x * PlasmaConfig.waveFreqX + time);
        final value2 = math.sin(y * PlasmaConfig.waveFreqY + time * 0.7);
        final value3 = math.sin((x + y) * 0.2 + time * 0.5);
        final value4 =
            math.sin(math.sqrt((x - width / 2) * (x - width / 2) + (y - height / 2) * (y - height / 2)) * 0.3 - time);

        final combined = (value1 + value2 + value3 + value4) / 4.0;
        final normalized = (combined + 1) / 2; // 0 to 1

        // Create gradient using config values
        final hue = (normalized * PlasmaConfig.hueRange + PlasmaConfig.hueOffset) % 360;
        final color = _hsvToRgb(hue, PlasmaConfig.saturation, PlasmaConfig.brightness);

        canvas.fillRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          ' ',
          style: TextStyle(backgroundColor: color),
        );
      }
    }
  }

  Color _hsvToRgb(double h, double s, double v) {
    final c = v * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = v - c;

    double r, g, b;
    if (h < 60) {
      r = c;
      g = x;
      b = 0;
    } else if (h < 120) {
      r = x;
      g = c;
      b = 0;
    } else if (h < 180) {
      r = 0;
      g = c;
      b = x;
    } else if (h < 240) {
      r = 0;
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      g = 0;
      b = c;
    } else {
      r = c;
      g = 0;
      b = x;
    }

    return Color.fromRGB(
      ((r + m) * 255).round().clamp(0, 255),
      ((g + m) * 255).round().clamp(0, 255),
      ((b + m) * 255).round().clamp(0, 255),
    );
  }

  @override
  bool shouldRepaint(PlasmaPainter oldDelegate) => frame != oldDelegate.frame;
}

/// Animated plasma/lava lamp effect component.
class PlasmaComponent extends StatefulComponent {
  const PlasmaComponent({super.key, this.gridWidth = 21, this.gridHeight = 16});

  final int gridWidth;
  final int gridHeight;

  @override
  State<PlasmaComponent> createState() => _PlasmaState();
}

class _PlasmaState extends State<PlasmaComponent> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
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
      painter: PlasmaPainter(frame: _frame),
      size: Size(component.gridWidth.toDouble(), component.gridHeight.toDouble()),
    );
  }
}
