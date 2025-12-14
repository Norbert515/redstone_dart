/// Clock demo component for nocterm Minecraft rendering.
///
/// Digital clock display showing HH:MM with blinking colon.
/// Uses 3x5 pixel digit patterns for rendering numbers.
library;

import 'dart:async';

import 'package:nocterm/nocterm.dart';

/// Custom painter for digital clock display.
class ClockPainter extends CustomPainter {
  ClockPainter({required this.time});

  final DateTime time;

  // 3x5 digit patterns
  static const _digits = <int, List<String>>{
    0: ['###', '# #', '# #', '# #', '###'],
    1: [' # ', '## ', ' # ', ' # ', '###'],
    2: ['###', '  #', '###', '#  ', '###'],
    3: ['###', '  #', '###', '  #', '###'],
    4: ['# #', '# #', '###', '  #', '  #'],
    5: ['###', '#  ', '###', '  #', '###'],
    6: ['###', '#  ', '###', '# #', '###'],
    7: ['###', '  #', '  #', '  #', '  #'],
    8: ['###', '# #', '###', '# #', '###'],
    9: ['###', '# #', '###', '  #', '###'],
  };

  static const _colon = [' ', '#', ' ', '#', ' '];

  @override
  void paint(TerminalCanvas canvas, Size size) {
    final width = size.width.toInt();
    final height = size.height.toInt();

    // Fill background dark blue
    const bgColor = Color.fromRGB(0, 0, 40);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        canvas.fillRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          ' ',
          style: const TextStyle(backgroundColor: bgColor),
        );
      }
    }

    // Format time
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    // Calculate starting position to center the clock
    // Each digit is 3 wide, colon is 1 wide, with 1 space between
    // HH:MM = 3+1+3+1+1+1+3+1+3 = 17
    const digitWidth = 3;
    const colonWidth = 1;
    const spacing = 1;
    const totalWidth = digitWidth + spacing + digitWidth + spacing + colonWidth + spacing + digitWidth + spacing + digitWidth;
    final startX = (width - totalWidth) ~/ 2;
    final startY = (height - 5) ~/ 2;

    const digitColor = Color.fromRGB(0, 255, 255);

    int currentX = startX;

    // Draw hour
    _drawDigit(canvas, int.parse(hour[0]), currentX, startY, digitColor);
    currentX += digitWidth + spacing;
    _drawDigit(canvas, int.parse(hour[1]), currentX, startY, digitColor);
    currentX += digitWidth + spacing;

    // Draw colon (blink every second)
    if (time.second % 2 == 0) {
      _drawColon(canvas, currentX, startY, digitColor);
    }
    currentX += colonWidth + spacing;

    // Draw minute
    _drawDigit(canvas, int.parse(minute[0]), currentX, startY, digitColor);
    currentX += digitWidth + spacing;
    _drawDigit(canvas, int.parse(minute[1]), currentX, startY, digitColor);
  }

  void _drawDigit(TerminalCanvas canvas, int digit, int x, int y, Color color) {
    final pattern = _digits[digit]!;
    for (int dy = 0; dy < 5; dy++) {
      for (int dx = 0; dx < 3; dx++) {
        if (pattern[dy][dx] == '#') {
          canvas.fillRect(
            Rect.fromLTWH((x + dx).toDouble(), (y + dy).toDouble(), 1, 1),
            ' ',
            style: TextStyle(backgroundColor: color),
          );
        }
      }
    }
  }

  void _drawColon(TerminalCanvas canvas, int x, int y, Color color) {
    for (int dy = 0; dy < 5; dy++) {
      if (_colon[dy] == '#') {
        canvas.fillRect(
          Rect.fromLTWH(x.toDouble(), (y + dy).toDouble(), 1, 1),
          ' ',
          style: TextStyle(backgroundColor: color),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ClockPainter oldDelegate) => time.second != oldDelegate.time.second;
}

/// Digital clock display component.
class ClockComponent extends StatefulComponent {
  const ClockComponent({super.key, this.gridWidth = 21, this.gridHeight = 16});

  final int gridWidth;
  final int gridHeight;

  @override
  State<ClockComponent> createState() => _ClockState();
}

class _ClockState extends State<ClockComponent> {
  Timer? _timer;
  DateTime _time = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _time = DateTime.now());
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
      painter: ClockPainter(time: _time),
      size: Size(component.gridWidth.toDouble(), component.gridHeight.toDouble()),
    );
  }
}
