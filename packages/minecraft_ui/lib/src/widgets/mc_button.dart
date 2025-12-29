import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// The size variant for a Minecraft button.
enum McButtonSize {
  /// Small button (120px wide)
  small,

  /// Default button (150px wide)
  medium,

  /// Big button (200px wide)
  large,
}

/// A Minecraft-style button with gradient background and 3D border effect.
///
/// The button has four visual states:
/// - Normal: Gray gradient
/// - Hovered: Blue-tinted gradient
/// - Pressed: Inverted gradient
/// - Disabled: Dark gray, no interaction
class McButton extends StatefulWidget {
  /// The button label text.
  final String? text;

  /// Optional custom child widget (overrides text).
  final Widget? child;

  /// Called when the button is pressed.
  final VoidCallback? onPressed;

  /// The button size variant.
  final McButtonSize size;

  /// Optional custom width (overrides size preset).
  final double? width;

  /// Whether the button is enabled.
  final bool enabled;

  const McButton({
    super.key,
    this.text,
    this.child,
    this.onPressed,
    this.size = McButtonSize.medium,
    this.width,
    this.enabled = true,
  }) : assert(text != null || child != null, 'Either text or child must be provided');

  @override
  State<McButton> createState() => _McButtonState();
}

class _McButtonState extends State<McButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  double get _buttonWidth {
    if (widget.width != null) return widget.width!;
    return switch (widget.size) {
      McButtonSize.small => McSizes.buttonSmallWidth,
      McButtonSize.medium => McSizes.buttonDefaultWidth,
      McButtonSize.large => McSizes.buttonBigWidth,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final isEnabled = widget.enabled && widget.onPressed != null;

    // Determine colors based on state
    Color topColor;
    Color bottomColor;
    Color borderColor;
    Color textColor;

    if (!isEnabled) {
      topColor = McColors.buttonTopDisabled;
      bottomColor = McColors.buttonBottomDisabled;
      borderColor = McColors.buttonBorder;
      textColor = McColors.lightGray;
    } else if (_isPressed) {
      topColor = McColors.buttonTopPressed;
      bottomColor = McColors.buttonBottomPressed;
      borderColor = McColors.buttonBorderPressed;
      textColor = McColors.white;
    } else if (_isHovered) {
      topColor = McColors.buttonTopHovered;
      bottomColor = McColors.buttonBottomHovered;
      borderColor = McColors.buttonBorder;
      textColor = McColors.white;
    } else {
      topColor = McColors.buttonTopNormal;
      bottomColor = McColors.buttonBottomNormal;
      borderColor = McColors.buttonBorder;
      textColor = McColors.white;
    }

    return MouseRegion(
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled
            ? (_) {
                setState(() => _isPressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
        child: CustomPaint(
          painter: _McButtonPainter(
            topColor: topColor,
            bottomColor: bottomColor,
            borderColor: borderColor,
            borderWidth: McSizes.buttonBorderWidth * scale,
            isPressed: _isPressed,
          ),
          child: Container(
            width: _buttonWidth * scale,
            height: McSizes.buttonHeight * scale,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: McSizes.buttonTextMargin * scale,
            ),
            child: widget.child ??
                Text(
                  widget.text!,
                  style: TextStyle(
                    fontFamily: 'Minecraft',
                    package: 'minecraft_ui',
                    fontSize: McTypography.fontHeight * scale,
                    color: textColor,
                    shadows: [
                      Shadow(
                        color: McColors.black.withValues(alpha: 0.4),
                        offset: Offset(
                          McTypography.shadowOffset * scale,
                          McTypography.shadowOffset * scale,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
          ),
        ),
      ),
    );
  }
}

class _McButtonPainter extends CustomPainter {
  final Color topColor;
  final Color bottomColor;
  final Color borderColor;
  final double borderWidth;
  final bool isPressed;

  _McButtonPainter({
    required this.topColor,
    required this.bottomColor,
    required this.borderColor,
    required this.borderWidth,
    required this.isPressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()..color = borderColor;

    // Draw outer border
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );

    // Draw gradient background inside border
    final gradientRect = Rect.fromLTWH(
      borderWidth,
      borderWidth,
      size.width - borderWidth * 2,
      size.height - borderWidth * 2,
    );

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [topColor, bottomColor],
    );

    final gradientPaint = Paint()..shader = gradient.createShader(gradientRect);
    canvas.drawRect(gradientRect, gradientPaint);

    // Draw 3D edge highlights
    if (!isPressed) {
      // Light top edge
      canvas.drawRect(
        Rect.fromLTWH(borderWidth, borderWidth, size.width - borderWidth * 2, 1),
        Paint()..color = McColors.white.withValues(alpha: 0.2),
      );
      // Light left edge
      canvas.drawRect(
        Rect.fromLTWH(borderWidth, borderWidth, 1, size.height - borderWidth * 2),
        Paint()..color = McColors.white.withValues(alpha: 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(_McButtonPainter oldDelegate) {
    return topColor != oldDelegate.topColor ||
        bottomColor != oldDelegate.bottomColor ||
        borderColor != oldDelegate.borderColor ||
        borderWidth != oldDelegate.borderWidth ||
        isPressed != oldDelegate.isPressed;
  }
}
