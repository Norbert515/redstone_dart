import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// A Minecraft-style progress bar.
///
/// Can be horizontal (like furnace arrow) or vertical (like furnace flame).
class McProgressBar extends StatelessWidget {
  /// Progress value (0.0 to 1.0).
  final double progress;

  /// Width of the progress bar.
  final double width;

  /// Height of the progress bar.
  final double height;

  /// Direction of progress fill.
  final Axis direction;

  /// Whether to fill from end instead of start.
  final bool reversed;

  /// Background color.
  final Color backgroundColor;

  /// Fill color.
  final Color fillColor;

  /// Border color.
  final Color borderColor;

  const McProgressBar({
    super.key,
    required this.progress,
    this.width = 24,
    this.height = 16,
    this.direction = Axis.horizontal,
    this.reversed = false,
    this.backgroundColor = McColors.slotBackground,
    this.fillColor = McColors.white,
    this.borderColor = McColors.slotBorderDark,
  });

  /// Creates a horizontal arrow-style progress bar (like furnace cooking).
  const McProgressBar.arrow({
    super.key,
    required this.progress,
    this.width = 24,
    this.height = 16,
    this.backgroundColor = McColors.slotBackground,
    this.fillColor = McColors.white,
    this.borderColor = McColors.slotBorderDark,
  })  : direction = Axis.horizontal,
        reversed = false;

  /// Creates a vertical flame-style progress bar (like furnace fuel).
  const McProgressBar.flame({
    super.key,
    required this.progress,
    this.width = 14,
    this.height = 14,
    this.backgroundColor = McColors.slotBackground,
    this.fillColor = McColors.formatGold,
    this.borderColor = McColors.slotBorderDark,
  })  : direction = Axis.vertical,
        reversed = true; // Fills from bottom

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);

    return CustomPaint(
      painter: _McProgressBarPainter(
        progress: progress.clamp(0.0, 1.0),
        direction: direction,
        reversed: reversed,
        backgroundColor: backgroundColor,
        fillColor: fillColor,
        borderColor: borderColor,
        scale: scale,
      ),
      child: SizedBox(
        width: width * scale,
        height: height * scale,
      ),
    );
  }
}

class _McProgressBarPainter extends CustomPainter {
  final double progress;
  final Axis direction;
  final bool reversed;
  final Color backgroundColor;
  final Color fillColor;
  final Color borderColor;
  final double scale;

  _McProgressBarPainter({
    required this.progress,
    required this.direction,
    required this.reversed,
    required this.backgroundColor,
    required this.fillColor,
    required this.borderColor,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderWidth = 1.0 * scale;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );

    // Border
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    // Fill
    if (progress > 0) {
      Rect fillRect;
      if (direction == Axis.horizontal) {
        final fillWidth = (size.width - borderWidth * 2) * progress;
        if (reversed) {
          fillRect = Rect.fromLTWH(
            size.width - borderWidth - fillWidth,
            borderWidth,
            fillWidth,
            size.height - borderWidth * 2,
          );
        } else {
          fillRect = Rect.fromLTWH(
            borderWidth,
            borderWidth,
            fillWidth,
            size.height - borderWidth * 2,
          );
        }
      } else {
        final fillHeight = (size.height - borderWidth * 2) * progress;
        if (reversed) {
          fillRect = Rect.fromLTWH(
            borderWidth,
            size.height - borderWidth - fillHeight,
            size.width - borderWidth * 2,
            fillHeight,
          );
        } else {
          fillRect = Rect.fromLTWH(
            borderWidth,
            borderWidth,
            size.width - borderWidth * 2,
            fillHeight,
          );
        }
      }
      canvas.drawRect(fillRect, Paint()..color = fillColor);
    }
  }

  @override
  bool shouldRepaint(_McProgressBarPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        fillColor != oldDelegate.fillColor ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
