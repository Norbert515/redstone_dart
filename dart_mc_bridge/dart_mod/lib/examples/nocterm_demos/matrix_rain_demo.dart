/// Matrix rain demo component for nocterm Minecraft rendering.
///
/// Matrix-style falling green characters animation.
/// Creates columns of green "rain" that fall at varying speeds.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:nocterm/nocterm.dart';

/// Custom painter for Matrix-style falling green characters.
class MatrixRainPainter extends CustomPainter {
  MatrixRainPainter({
    required this.frame,
    required this.columns,
    required this.random,
  });

  final int frame;
  final List<MatrixColumn> columns;
  final math.Random random;

  @override
  void paint(TerminalCanvas canvas, Size size) {
    final width = size.width.toInt();
    final height = size.height.toInt();

    // Fill background black
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        canvas.fillRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          ' ',
          style: const TextStyle(backgroundColor: Color.fromRGB(0, 0, 0)),
        );
      }
    }

    // Draw falling columns
    for (int x = 0; x < columns.length && x < width; x++) {
      final col = columns[x];
      final head = (col.position + frame * col.speed / 10).toInt() % (height + col.length);

      for (int i = 0; i < col.length; i++) {
        final y = head - i;
        if (y >= 0 && y < height) {
          // Fade from bright green (head) to dark green (tail)
          final brightness = ((col.length - i) / col.length * 200 + 55).toInt();
          final green = brightness.clamp(0, 255);
          final color = Color.fromRGB(0, green, 0);

          canvas.fillRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
            ' ',
            style: TextStyle(backgroundColor: color),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(MatrixRainPainter oldDelegate) => frame != oldDelegate.frame;
}

/// Data for a single matrix column.
class MatrixColumn {
  MatrixColumn({
    required this.position,
    required this.speed,
    required this.length,
  });

  final double position;
  final double speed;
  final int length;
}

/// Matrix-style falling green characters animation.
class MatrixRainComponent extends StatefulComponent {
  const MatrixRainComponent({super.key, this.gridWidth = 21, this.gridHeight = 16});

  final int gridWidth;
  final int gridHeight;

  @override
  State<MatrixRainComponent> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<MatrixRainComponent> {
  Timer? _timer;
  int _frame = 0;
  final math.Random _random = math.Random();
  late List<MatrixColumn> _columns;

  @override
  void initState() {
    super.initState();
    _initColumns();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() => _frame++);
    });
  }

  void _initColumns() {
    _columns = List.generate(component.gridWidth, (i) {
      return MatrixColumn(
        position: _random.nextDouble() * component.gridHeight,
        speed: _random.nextDouble() * 2 + 1,
        length: _random.nextInt(8) + 4,
      );
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
      painter: MatrixRainPainter(frame: _frame, columns: _columns, random: _random),
      size: Size(component.gridWidth.toDouble(), component.gridHeight.toDouble()),
    );
  }
}
