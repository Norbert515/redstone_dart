import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// A Minecraft-style checkbox widget.
class McCheckbox extends StatefulWidget {
  /// Whether the checkbox is checked.
  final bool value;

  /// Called when the value changes.
  final ValueChanged<bool>? onChanged;

  /// Optional label text.
  final String? label;

  /// Whether the checkbox is enabled.
  final bool enabled;

  const McCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.enabled = true,
  });

  @override
  State<McCheckbox> createState() => _McCheckboxState();
}

class _McCheckboxState extends State<McCheckbox> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final boxSize = McSizes.checkboxSize * scale;

    return MouseRegion(
      onEnter: widget.enabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _isHovered = false) : null,
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? () => widget.onChanged?.call(!widget.value) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: _McCheckboxPainter(
                isChecked: widget.value,
                isHovered: _isHovered,
                isEnabled: widget.enabled,
                scale: scale,
              ),
              child: SizedBox(width: boxSize, height: boxSize),
            ),
            if (widget.label != null) ...[
              SizedBox(width: McSizes.checkboxSpacing * scale),
              Text(
                widget.label!,
                style: TextStyle(
                  fontSize: McTypography.fontHeight * scale,
                  color: widget.enabled ? McColors.white : McColors.lightGray,
                  shadows: [
                    Shadow(
                      color: McColors.black.withValues(alpha: 0.4),
                      offset: Offset(scale, scale),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _McCheckboxPainter extends CustomPainter {
  final bool isChecked;
  final bool isHovered;
  final bool isEnabled;
  final double scale;

  _McCheckboxPainter({
    required this.isChecked,
    required this.isHovered,
    required this.isEnabled,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderWidth = 2.0 * scale;

    // Background
    final bgColor = isEnabled
        ? (isHovered ? McColors.buttonTopHovered : McColors.slotBackground)
        : McColors.buttonTopDisabled;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    // Border
    final borderColor = isHovered ? McColors.white : McColors.slotBorderDark;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRect(
      Rect.fromLTWH(
        borderWidth / 2,
        borderWidth / 2,
        size.width - borderWidth,
        size.height - borderWidth,
      ),
      borderPaint,
    );

    // Checkmark
    if (isChecked) {
      final checkPaint = Paint()
        ..color = isEnabled ? McColors.white : McColors.lightGray
        ..strokeWidth = 2 * scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square;

      final path = Path()
        ..moveTo(size.width * 0.2, size.height * 0.5)
        ..lineTo(size.width * 0.4, size.height * 0.7)
        ..lineTo(size.width * 0.8, size.height * 0.3);

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_McCheckboxPainter oldDelegate) {
    return isChecked != oldDelegate.isChecked ||
        isHovered != oldDelegate.isHovered ||
        isEnabled != oldDelegate.isEnabled;
  }
}
