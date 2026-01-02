/// Definition of a slot's position for pre-registration.
///
/// Used with [GuiRoute.slots] to pre-register slot positions, allowing
/// items to render on the first frame when a container opens.
library;

import 'package:dart_mod_common/dart_mod_common.dart' show SlotType;

// Re-export SlotType for convenience.
export 'package:dart_mod_common/dart_mod_common.dart' show SlotType;

/// Definition of a slot's position for pre-registration.
///
/// Pre-registered slots are sent to Java immediately when a container opens,
/// before the Flutter layout pass completes. This eliminates the 1-2 frame
/// delay before items become visible.
///
/// Example:
/// ```dart
/// GuiRoute(
///   containerId: 'mymod:custom_chest',
///   slots: [
///     // Container slots (3 rows of 9)
///     for (var row = 0; row < 3; row++)
///       for (var col = 0; col < 9; col++)
///         SlotDefinition(
///           index: row * 9 + col,
///           x: 8.0 + col * 18,
///           y: 18.0 + row * 18,
///         ),
///     // Player inventory slots
///     for (var row = 0; row < 3; row++)
///       for (var col = 0; col < 9; col++)
///         SlotDefinition(
///           index: 27 + row * 9 + col,
///           x: 8.0 + col * 18,
///           y: 84.0 + row * 18,
///           type: SlotType.playerInventory,
///         ),
///     // Player hotbar
///     for (var col = 0; col < 9; col++)
///       SlotDefinition(
///         index: 54 + col,
///         x: 8.0 + col * 18,
///         y: 142.0,
///         type: SlotType.playerHotbar,
///       ),
///   ],
///   builder: (context, info) => MyChestScreen(info: info),
/// )
/// ```
class SlotDefinition {
  /// The slot index in the container menu.
  final int index;

  /// X position relative to the screen's top-left corner.
  final double x;

  /// Y position relative to the screen's top-left corner.
  final double y;

  /// Width of the slot in pixels.
  ///
  /// Defaults to 18 (standard Minecraft slot size).
  final double width;

  /// Height of the slot in pixels.
  ///
  /// Defaults to 18 (standard Minecraft slot size).
  final double height;

  /// The type of slot.
  ///
  /// Defaults to [SlotType.container].
  final SlotType type;

  /// Creates a slot definition for pre-registration.
  ///
  /// The [index] is the slot index in the container menu.
  /// The [x] and [y] are the position relative to the screen's top-left corner.
  /// The [width] and [height] default to 18 (standard Minecraft slot size).
  const SlotDefinition({
    required this.index,
    required this.x,
    required this.y,
    this.width = 18,
    this.height = 18,
    this.type = SlotType.container,
  });

  @override
  String toString() =>
      'SlotDefinition(index: $index, x: $x, y: $y, ${width}x$height, $type)';

  @override
  bool operator ==(Object other) =>
      other is SlotDefinition &&
      index == other.index &&
      x == other.x &&
      y == other.y &&
      width == other.width &&
      height == other.height &&
      type == other.type;

  @override
  int get hashCode => Object.hash(index, x, y, width, height, type);
}
