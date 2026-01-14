/// Flutter screen for configuring the Flutter Display Controller block.
library;

import 'package:dart_mod_client/dart_mod_client.dart';
import 'package:flutter/material.dart';
import 'package:minecraft_flutter_dev_common/minecraft_flutter_dev_common.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

/// GUI screen for configuring the Flutter Display Controller.
///
/// Displays a panel with sliders to control:
/// - Display width (0.5 to 10.0 blocks)
/// - Display height (0.5 to 10.0 blocks)
///
/// Also shows the current active status (powered by redstone).
class FlutterDisplayControllerScreen extends StatelessWidget {
  const FlutterDisplayControllerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final container =
        ContainerScope.of<FlutterDisplayControllerContainer>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: McPanel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const McText.title('Flutter Display Controller'),
                const SizedBox(height: 16),

                // Status indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: container.active ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    McText.label(container.active ? 'Active' : 'Inactive'),
                  ],
                ),
                const SizedBox(height: 16),

                // Width slider
                _DimensionSlider(
                  label: 'Width',
                  value: container.width,
                  onChanged: (v) => container.width = v,
                ),
                const SizedBox(height: 8),

                // Height slider
                _DimensionSlider(
                  label: 'Height',
                  value: container.height,
                  onChanged: (v) => container.height = v,
                ),

                const SizedBox(height: 16),
                const McText.label('Apply redstone signal to activate'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A slider widget for controlling display dimensions.
///
/// Displays a label, McSlider, and current value.
/// Maps 0.5-10.0 blocks range to McSlider's 0.0-1.0 range.
class _DimensionSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _DimensionSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  // Convert block value (0.5-10.0) to slider value (0.0-1.0)
  double _toSliderValue(double blocks) {
    return ((blocks - 0.5) / 9.5).clamp(0.0, 1.0);
  }

  // Convert slider value (0.0-1.0) to block value (0.5-10.0)
  double _toBlockValue(double slider) {
    // Round to nearest 0.5
    final blocks = 0.5 + slider * 9.5;
    return (blocks * 2).round() / 2;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          child: McText.label('$label:'),
        ),
        McSlider(
          value: _toSliderValue(value),
          onChanged: (v) => onChanged(_toBlockValue(v)),
          width: 150,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: McText.label('${value.toStringAsFixed(1)}'),
        ),
      ],
    );
  }
}
