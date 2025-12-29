import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// A Minecraft-style text input field.
///
/// Features bordered appearance with focus state, cursor blinking,
/// and text selection.
class McTextField extends StatefulWidget {
  /// Initial text value.
  final String? initialValue;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when editing is complete (Enter pressed or focus lost).
  final ValueChanged<String>? onSubmitted;

  /// Placeholder text shown when empty.
  final String? placeholder;

  /// Maximum length of text (null for unlimited).
  final int? maxLength;

  /// Whether the field is enabled.
  final bool enabled;

  /// Whether to show the border.
  final bool bordered;

  /// Custom width (null for flexible).
  final double? width;

  /// Text editing controller.
  final TextEditingController? controller;

  /// Focus node.
  final FocusNode? focusNode;

  const McTextField({
    super.key,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.placeholder,
    this.maxLength,
    this.enabled = true,
    this.bordered = true,
    this.width,
    this.controller,
    this.focusNode,
  });

  @override
  State<McTextField> createState() => _McTextFieldState();
}

class _McTextFieldState extends State<McTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final borderWidth = widget.bordered ? McSizes.textFieldBorderWidth * scale : 0.0;
    final padding = McSizes.textFieldPadding * scale;

    return CustomPaint(
      painter: _McTextFieldPainter(
        borderWidth: borderWidth,
        isFocused: _isFocused,
        isEnabled: widget.enabled,
      ),
      child: Container(
        width: widget.width != null ? widget.width! * scale : null,
        height: (McSizes.buttonHeight + (widget.bordered ? McSizes.textFieldBorderWidth * 2 : 0)) * scale,
        padding: EdgeInsets.symmetric(horizontal: padding),
        alignment: Alignment.centerLeft,
        child: EditableText(
          controller: _controller,
          focusNode: _focusNode,
          style: TextStyle(
            fontSize: McTypography.fontHeight * scale,
            color: widget.enabled ? McColors.textDefault : McColors.textUneditable,
          ),
          cursorColor: McColors.cursor,
          backgroundCursorColor: McColors.black,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          maxLines: 1,
          readOnly: !widget.enabled,
        ),
      ),
    );
  }
}

class _McTextFieldPainter extends CustomPainter {
  final double borderWidth;
  final bool isFocused;
  final bool isEnabled;

  _McTextFieldPainter({
    required this.borderWidth,
    required this.isFocused,
    required this.isEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (borderWidth <= 0) return;

    // Background
    final bgColor = isEnabled ? McColors.black : McColors.darkGray;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    // Border (highlighted when focused)
    final borderColor = isFocused ? McColors.white : McColors.slotBorderDark;
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
  }

  @override
  bool shouldRepaint(_McTextFieldPainter oldDelegate) {
    return borderWidth != oldDelegate.borderWidth ||
        isFocused != oldDelegate.isFocused ||
        isEnabled != oldDelegate.isEnabled;
  }
}
