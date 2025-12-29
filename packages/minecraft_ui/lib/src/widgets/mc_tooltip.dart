import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// A Minecraft-style tooltip widget.
///
/// Tooltips have a dark purple background with gradient border.
class McTooltip extends StatelessWidget {
  /// The tooltip content (typically a list of text lines).
  final Widget child;

  /// Maximum width before wrapping.
  final double maxWidth;

  const McTooltip({
    super.key,
    required this.child,
    this.maxWidth = 200,
  });

  /// Creates a tooltip with simple text content.
  factory McTooltip.text(String text, {Key? key}) {
    return McTooltip(
      key: key,
      child: Text(text),
    );
  }

  /// Creates a tooltip with multiple lines.
  factory McTooltip.lines(List<String> lines, {Key? key}) {
    return McTooltip(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) => Text(line)).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final padding = McSizes.tooltipPadding * scale;
    final margin = McSizes.tooltipMargin * scale;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth * scale),
      margin: EdgeInsets.all(margin),
      child: CustomPaint(
        painter: _McTooltipPainter(scale: scale),
        child: Padding(
          padding: EdgeInsets.all(padding + 4 * scale), // Extra for border
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: McTypography.fontHeight * scale,
              color: McColors.white,
              shadows: [
                Shadow(
                  color: McColors.black.withValues(alpha: 0.4),
                  offset: Offset(scale, scale),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _McTooltipPainter extends CustomPainter {
  final double scale;

  _McTooltipPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final borderWidth = 2.0 * scale;

    // Background (dark purple, semi-transparent)
    final bgPaint = Paint()..color = McColors.tooltipBackground;
    canvas.drawRect(
      Rect.fromLTWH(borderWidth, borderWidth, size.width - borderWidth * 2, size.height - borderWidth * 2),
      bgPaint,
    );

    // Outer border (black)
    final outerBorderPaint = Paint()
      ..color = McColors.tooltipBorderOuter
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      outerBorderPaint,
    );

    // Inner gradient border (purple)
    final innerBorderPaint = Paint()
      ..color = McColors.tooltipBorderInner.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRect(
      Rect.fromLTWH(
        borderWidth,
        borderWidth,
        size.width - borderWidth * 2,
        size.height - borderWidth * 2,
      ),
      innerBorderPaint,
    );
  }

  @override
  bool shouldRepaint(_McTooltipPainter oldDelegate) => scale != oldDelegate.scale;
}

/// Shows a Minecraft tooltip at the specified position.
class McTooltipOverlay extends StatelessWidget {
  /// The widget that triggers the tooltip.
  final Widget child;

  /// The tooltip content.
  final Widget tooltip;

  /// Whether to show the tooltip.
  final bool visible;

  const McTooltipOverlay({
    super.key,
    required this.child,
    required this.tooltip,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (visible)
          Positioned(
            left: 0,
            top: 0,
            child: McTooltip(child: tooltip),
          ),
      ],
    );
  }
}
