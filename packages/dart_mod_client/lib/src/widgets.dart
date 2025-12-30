/// Minecraft-style widgets for Flutter-based GUIs.
library;

import 'package:flutter/widgets.dart';

/// A Minecraft-style button widget.
class MinecraftButton extends StatelessWidget {
  /// The button label.
  final String label;

  /// Callback when the button is pressed.
  final VoidCallback? onPressed;

  /// Width of the button.
  final double width;

  /// Height of the button.
  final double height;

  /// Whether the button is enabled.
  final bool enabled;

  const MinecraftButton({
    super.key,
    required this.label,
    this.onPressed,
    this.width = 200,
    this.height = 20,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Implement Minecraft-style button rendering
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF808080) : const Color(0xFF505050),
          border: Border.all(color: const Color(0xFF000000)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? const Color(0xFFFFFFFF) : const Color(0xFFA0A0A0),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// A Minecraft-style text input widget.
class MinecraftTextField extends StatefulWidget {
  /// Initial text value.
  final String initialValue;

  /// Callback when text changes.
  final ValueChanged<String>? onChanged;

  /// Width of the text field.
  final double width;

  /// Height of the text field.
  final double height;

  /// Maximum text length.
  final int? maxLength;

  /// Placeholder text when empty.
  final String? placeholder;

  const MinecraftTextField({
    super.key,
    this.initialValue = '',
    this.onChanged,
    this.width = 200,
    this.height = 20,
    this.maxLength,
    this.placeholder,
  });

  @override
  State<MinecraftTextField> createState() => _MinecraftTextFieldState();
}

class _MinecraftTextFieldState extends State<MinecraftTextField> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Implement Minecraft-style text field rendering
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        border: Border.all(color: const Color(0xFFA0A0A0)),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        _value.isEmpty && widget.placeholder != null ? widget.placeholder! : _value,
        style: TextStyle(
          color: _value.isEmpty ? const Color(0xFF707070) : const Color(0xFFE0E0E0),
          fontSize: 14,
        ),
      ),
    );
  }
}

/// A Minecraft-style slider widget.
class MinecraftSlider extends StatefulWidget {
  /// Current value (0.0 to 1.0).
  final double value;

  /// Callback when value changes.
  final ValueChanged<double>? onChanged;

  /// Width of the slider.
  final double width;

  /// Height of the slider.
  final double height;

  /// Label formatter.
  final String Function(double)? labelFormatter;

  const MinecraftSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.width = 200,
    this.height = 20,
    this.labelFormatter,
  });

  @override
  State<MinecraftSlider> createState() => _MinecraftSliderState();
}

class _MinecraftSliderState extends State<MinecraftSlider> {
  @override
  Widget build(BuildContext context) {
    // TODO: Implement Minecraft-style slider rendering
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF808080),
        border: Border.all(color: const Color(0xFF000000)),
      ),
      child: Stack(
        children: [
          // Progress bar
          FractionallySizedBox(
            widthFactor: widget.value,
            child: Container(
              color: const Color(0xFF00FF00),
            ),
          ),
          // Label
          Center(
            child: Text(
              widget.labelFormatter?.call(widget.value) ?? '${(widget.value * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A Minecraft-style checkbox widget.
class MinecraftCheckbox extends StatelessWidget {
  /// Whether the checkbox is checked.
  final bool value;

  /// Callback when value changes.
  final ValueChanged<bool>? onChanged;

  /// Label text.
  final String? label;

  const MinecraftCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged?.call(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? const Color(0xFF00FF00) : const Color(0xFF404040),
              border: Border.all(color: const Color(0xFF000000)),
            ),
            child: value
                ? const Center(
                    child: Text(
                      'X',
                      style: TextStyle(color: Color(0xFF000000), fontSize: 14),
                    ),
                  )
                : null,
          ),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label!,
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
