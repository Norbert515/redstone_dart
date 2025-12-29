import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// A Minecraft-style panel container with beveled 3D borders.
///
/// This widget recreates the standard Minecraft GUI panel appearance
/// with light top-left edges and dark bottom-right edges.
class McPanel extends StatelessWidget {
  /// The child widget to display inside the panel.
  final Widget? child;

  /// The panel background color.
  final Color backgroundColor;

  /// The border color for dark edges (bottom-right).
  final Color borderDarkColor;

  /// The border color for light edges (top-left).
  final Color borderLightColor;

  /// The border width.
  final double borderWidth;

  /// Optional fixed width. If null, sizes to content.
  final double? width;

  /// Optional fixed height. If null, sizes to content.
  final double? height;

  /// Padding inside the panel.
  final EdgeInsets padding;

  /// Whether to use the inset style (darker, like inventory slots area).
  final bool inset;

  const McPanel({
    super.key,
    this.child,
    this.backgroundColor = McColors.panelBackground,
    this.borderDarkColor = McColors.panelBorderDark,
    this.borderLightColor = McColors.panelBorderLight,
    this.borderWidth = McSizes.panelBorderWidth,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(McSizes.panelPadding),
    this.inset = false,
  });

  /// Creates a panel with inset/sunken style (for slot backgrounds).
  const McPanel.inset({
    super.key,
    this.child,
    this.backgroundColor = McColors.slotBackground,
    this.borderDarkColor = McColors.panelBorderLight,
    this.borderLightColor = McColors.panelBorderDark,
    this.borderWidth = 2,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
  }) : inset = true;

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);

    return CustomPaint(
      painter: _McPanelPainter(
        backgroundColor: backgroundColor,
        borderDarkColor: borderDarkColor,
        borderLightColor: borderLightColor,
        borderWidth: borderWidth * scale,
        inset: inset,
      ),
      child: Container(
        width: width != null ? width! * scale : null,
        height: height != null ? height! * scale : null,
        padding: padding * scale,
        child: child,
      ),
    );
  }
}

class _McPanelPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderDarkColor;
  final Color borderLightColor;
  final double borderWidth;
  final bool inset;

  _McPanelPainter({
    required this.backgroundColor,
    required this.borderDarkColor,
    required this.borderLightColor,
    required this.borderWidth,
    required this.inset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    final darkPaint = Paint()..color = borderDarkColor;
    final lightPaint = Paint()..color = borderLightColor;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      bgPaint,
    );

    // Draw 3D beveled border
    // For normal panels: light on top-left, dark on bottom-right
    // For inset panels: reversed (dark on top-left, light on bottom-right)
    final topLeftPaint = inset ? darkPaint : lightPaint;
    final bottomRightPaint = inset ? lightPaint : darkPaint;

    // Top edge
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, borderWidth),
      topLeftPaint,
    );

    // Left edge
    canvas.drawRect(
      Rect.fromLTWH(0, 0, borderWidth, size.height),
      topLeftPaint,
    );

    // Bottom edge
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - borderWidth, size.width, borderWidth),
      bottomRightPaint,
    );

    // Right edge
    canvas.drawRect(
      Rect.fromLTWH(size.width - borderWidth, 0, borderWidth, size.height),
      bottomRightPaint,
    );

    // Inner border (creates the beveled look)
    if (borderWidth > 1) {
      final innerBorder = borderWidth / 2;

      // Inner top-left highlight
      canvas.drawRect(
        Rect.fromLTWH(innerBorder, innerBorder, size.width - innerBorder * 2, innerBorder),
        Paint()..color = topLeftPaint.color.withValues(alpha: 0.5),
      );
      canvas.drawRect(
        Rect.fromLTWH(innerBorder, innerBorder, innerBorder, size.height - innerBorder * 2),
        Paint()..color = topLeftPaint.color.withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_McPanelPainter oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        borderDarkColor != oldDelegate.borderDarkColor ||
        borderLightColor != oldDelegate.borderLightColor ||
        borderWidth != oldDelegate.borderWidth ||
        inset != oldDelegate.inset;
  }
}
