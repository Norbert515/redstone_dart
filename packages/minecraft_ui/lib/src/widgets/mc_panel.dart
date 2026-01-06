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
    final bgPaint = Paint()
      ..color = backgroundColor
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    final darkPaint = Paint()
      ..color = borderDarkColor
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    final lightPaint = Paint()
      ..color = borderLightColor
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    final blackPaint = Paint()
      ..color = const Color(0xFF000000)
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    // Real Minecraft panel structure (from outside to inside):
    // 1. Black outline (1px) with CORNER PIXELS CUT OFF for pixel-rounded look
    // 2. Light/white inner edge (borderWidth) on TOP and LEFT
    // 3. Dark inner edge (borderWidth) on BOTTOM and RIGHT
    // 4. Background fill

    // For inset panels: light and dark are swapped
    final topLeftPaint = inset ? darkPaint : lightPaint;
    final bottomRightPaint = inset ? lightPaint : darkPaint;

    // p = 1 scaled pixel (black outline thickness)
    // We use borderWidth/2 as the pixel size since borderWidth is typically 2
    final p = borderWidth / 2;
    final bw = borderWidth; // Inner border width

    // 1. Black outline with corners cut off (pixel-rounded)
    // Top edge - skip first and last pixel
    canvas.drawRect(Rect.fromLTWH(p, 0, size.width - 2 * p, p), blackPaint);
    // Bottom edge - skip first and last pixel
    canvas.drawRect(
        Rect.fromLTWH(p, size.height - p, size.width - 2 * p, p), blackPaint);
    // Left edge - skip first and last pixel
    canvas.drawRect(Rect.fromLTWH(0, p, p, size.height - 2 * p), blackPaint);
    // Right edge - skip first and last pixel
    canvas.drawRect(
        Rect.fromLTWH(size.width - p, p, p, size.height - 2 * p), blackPaint);

    // 2. Light edges (inside black outline, top and left)
    // These create the "raised" look - light comes from top-left
    // Top light - full inner width
    canvas.drawRect(
        Rect.fromLTWH(p, p, size.width - 2 * p, bw), topLeftPaint);
    // Left light - below top light, don't overlap
    canvas.drawRect(
        Rect.fromLTWH(p, p + bw, bw, size.height - 2 * p - bw), topLeftPaint);

    // 3. Dark edges (inside black outline, bottom and right)
    // Bottom dark - full inner width
    canvas.drawRect(
        Rect.fromLTWH(p, size.height - p - bw, size.width - 2 * p, bw),
        bottomRightPaint);
    // Right dark - above bottom dark, don't overlap
    canvas.drawRect(
        Rect.fromLTWH(size.width - p - bw, p, bw, size.height - 2 * p - bw),
        bottomRightPaint);

    // 4. Background fill
    canvas.drawRect(
        Rect.fromLTWH(
            p + bw, p + bw, size.width - 2 * p - 2 * bw, size.height - 2 * p - 2 * bw),
        bgPaint);
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
