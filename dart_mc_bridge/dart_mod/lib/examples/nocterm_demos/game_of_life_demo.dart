/// Game of Life demo component for nocterm Minecraft rendering.
///
/// Conway's Game of Life cellular automaton.
/// Cells live or die based on the number of neighbors.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:nocterm/nocterm.dart';

/// Configuration for the Game of Life demo.
/// Modify these values and hot reload to see changes instantly!
class GameOfLifeConfig {
  GameOfLifeConfig._();

  /// Initial density of alive cells (0.0-1.0, default: 0.3)
  static const double initialDensity = 0.3;

  /// Update interval in milliseconds (default: 300)
  static const int intervalMs = 300;

  /// Color for alive cells
  static const aliveColor = Color.fromRGB(255, 255, 255);

  /// Color for dead cells
  static const deadColor = Color.fromRGB(0, 0, 0);
}

/// Custom painter for Conway's Game of Life.
class GameOfLifePainter extends CustomPainter {
  GameOfLifePainter({required this.grid});

  final List<List<bool>> grid;

  @override
  void paint(TerminalCanvas canvas, Size size) {
    final width = size.width.toInt();
    final height = size.height.toInt();

    for (int y = 0; y < height && y < grid.length; y++) {
      for (int x = 0; x < width && x < grid[y].length; x++) {
        final alive = grid[y][x];
        const aliveColor = GameOfLifeConfig.aliveColor;
        const deadColor = GameOfLifeConfig.deadColor;
        final color = alive ? aliveColor : deadColor;

        canvas.fillRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          ' ',
          style: TextStyle(backgroundColor: color),
        );
      }
    }
  }

  @override
  bool shouldRepaint(GameOfLifePainter oldDelegate) => true; // Always repaint on update
}

/// Conway's Game of Life component.
class GameOfLifeComponent extends StatefulComponent {
  const GameOfLifeComponent({super.key, this.gridWidth = 21, this.gridHeight = 16});

  final int gridWidth;
  final int gridHeight;

  @override
  State<GameOfLifeComponent> createState() => _GameOfLifeState();
}

class _GameOfLifeState extends State<GameOfLifeComponent> {
  Timer? _timer;
  late List<List<bool>> _grid;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initGrid();
    _timer = Timer.periodic(Duration(milliseconds: GameOfLifeConfig.intervalMs), (_) {
      setState(() => _step());
    });
  }

  void _initGrid() {
    _grid = List.generate(
      component.gridHeight,
      (y) => List.generate(
        component.gridWidth,
        (x) => _random.nextDouble() < GameOfLifeConfig.initialDensity,
      ),
    );
  }

  void _step() {
    final newGrid = List.generate(
      component.gridHeight,
      (y) => List.generate(component.gridWidth, (x) => false),
    );

    for (int y = 0; y < component.gridHeight; y++) {
      for (int x = 0; x < component.gridWidth; x++) {
        final neighbors = _countNeighbors(x, y);
        final alive = _grid[y][x];

        if (alive) {
          // Survives with 2 or 3 neighbors
          newGrid[y][x] = neighbors == 2 || neighbors == 3;
        } else {
          // Born with exactly 3 neighbors
          newGrid[y][x] = neighbors == 3;
        }
      }
    }

    _grid = newGrid;
  }

  int _countNeighbors(int x, int y) {
    int count = 0;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = (x + dx + component.gridWidth) % component.gridWidth;
        final ny = (y + dy + component.gridHeight) % component.gridHeight;
        if (_grid[ny][nx]) count++;
      }
    }
    return count;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return CustomPaint(
      painter: GameOfLifePainter(grid: _grid),
      size: Size(component.gridWidth.toDouble(), component.gridHeight.toDouble()),
    );
  }
}
