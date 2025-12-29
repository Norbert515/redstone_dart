import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// A Minecraft-style slider widget.
class McSlider extends StatefulWidget {
  /// Current value (0.0 to 1.0).
  final double value;

  /// Called when the value changes.
  final ValueChanged<double>? onChanged;

  /// Called when dragging ends.
  final ValueChanged<double>? onChangeEnd;

  /// Optional label text.
  final String? label;

  /// Whether the slider is enabled.
  final bool enabled;

  /// Slider width.
  final double width;

  const McSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.onChangeEnd,
    this.label,
    this.enabled = true,
    this.width = McSizes.buttonDefaultWidth,
  });

  @override
  State<McSlider> createState() => _McSliderState();
}

class _McSliderState extends State<McSlider> {
  bool _isDragging = false;
  bool _isHovered = false;

  void _updateValue(double localX, double width, double scale) {
    final handleWidth = McSizes.sliderHandleWidth * scale;
    final trackWidth = width - handleWidth;
    final newValue = ((localX - handleWidth / 2) / trackWidth).clamp(0.0, 1.0);
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final width = widget.width * scale;
    final height = McSizes.sliderHeight * scale;

    return MouseRegion(
      onEnter: widget.enabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _isHovered = false) : null,
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onHorizontalDragStart: widget.enabled
            ? (details) {
                setState(() => _isDragging = true);
                _updateValue(details.localPosition.dx, width, scale);
              }
            : null,
        onHorizontalDragUpdate: widget.enabled
            ? (details) => _updateValue(details.localPosition.dx, width, scale)
            : null,
        onHorizontalDragEnd: widget.enabled
            ? (_) {
                setState(() => _isDragging = false);
                widget.onChangeEnd?.call(widget.value);
              }
            : null,
        onTapDown: widget.enabled
            ? (details) => _updateValue(details.localPosition.dx, width, scale)
            : null,
        child: CustomPaint(
          painter: _McSliderPainter(
            value: widget.value,
            isHovered: _isHovered,
            isDragging: _isDragging,
            isEnabled: widget.enabled,
            scale: scale,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: widget.label != null
                ? Center(
                    child: Text(
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
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _McSliderPainter extends CustomPainter {
  final double value;
  final bool isHovered;
  final bool isDragging;
  final bool isEnabled;
  final double scale;

  _McSliderPainter({
    required this.value,
    required this.isHovered,
    required this.isDragging,
    required this.isEnabled,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderWidth = 2.0 * scale;
    final handleWidth = McSizes.sliderHandleWidth * scale;

    // Track background
    final trackColor = isEnabled
        ? (isHovered ? McColors.buttonTopHovered : McColors.slotBackground)
        : McColors.buttonTopDisabled;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = trackColor,
    );

    // Track border
    final borderPaint = Paint()
      ..color = McColors.slotBorderDark
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

    // Handle position
    final handleX = borderWidth + value * (size.width - handleWidth - borderWidth * 2);

    // Handle
    final handleColor = isDragging
        ? McColors.white
        : (isHovered ? McColors.buttonTopHovered : McColors.buttonTopNormal);
    canvas.drawRect(
      Rect.fromLTWH(handleX, borderWidth, handleWidth, size.height - borderWidth * 2),
      Paint()..color = handleColor,
    );

    // Handle border
    canvas.drawRect(
      Rect.fromLTWH(handleX, borderWidth, handleWidth, size.height - borderWidth * 2),
      Paint()
        ..color = McColors.slotBorderDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * scale,
    );
  }

  @override
  bool shouldRepaint(_McSliderPainter oldDelegate) {
    return value != oldDelegate.value ||
        isHovered != oldDelegate.isHovered ||
        isDragging != oldDelegate.isDragging ||
        isEnabled != oldDelegate.isEnabled;
  }
}
