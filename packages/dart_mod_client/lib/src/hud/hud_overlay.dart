/// Base class for HUD overlay widgets.
library;

import 'package:flutter/widgets.dart';

import 'hud_position.dart';

/// Base class for HUD overlay widgets.
///
/// Mod developers extend this to create custom HUD elements that are
/// rendered on top of the Minecraft game view.
///
/// Example:
/// ```dart
/// class HealthOverlay extends HudOverlay {
///   const HealthOverlay({super.key});
///
///   @override
///   HudPosition get position => HudPosition.bottomLeft;
///
///   @override
///   HudOffset get offset => const HudOffset(10, -10);
///
///   @override
///   double get width => 200;
///
///   @override
///   double get height => 50;
///
///   @override
///   Widget build(BuildContext context) {
///     return Container(
///       width: width,
///       height: height,
///       child: const Text('Health: 100'),
///     );
///   }
/// }
/// ```
abstract class HudOverlay extends StatelessWidget {
  /// Creates a HUD overlay widget.
  const HudOverlay({super.key});

  /// The anchor position on screen.
  ///
  /// Determines which corner or edge of the screen the overlay
  /// is anchored to.
  HudPosition get position;

  /// Offset from the anchor position in logical pixels.
  ///
  /// Override this to fine-tune positioning after anchoring.
  /// Defaults to [HudOffset.zero].
  HudOffset get offset => HudOffset.zero;

  /// Width of the overlay in logical pixels.
  double get width;

  /// Height of the overlay in logical pixels.
  double get height;
}
