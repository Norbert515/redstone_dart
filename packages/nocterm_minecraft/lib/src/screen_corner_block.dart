import 'package:dart_mc/dart_mc.dart';

/// Marker block for defining nocterm screen corners.
///
/// Place two of these blocks in the same vertical plane (same X or same Z)
/// to define a rectangular screen area.
class ScreenCornerBlock extends CustomBlock {
  /// Singleton instance - use [ScreenCornerBlock.instance] to access.
  static final ScreenCornerBlock instance = ScreenCornerBlock._();

  /// The block ID for referencing this block.
  static const String blockId = 'dartmod:screen_corner';

  ScreenCornerBlock._()
      : super(
          id: blockId,
          settings: BlockSettings(
            hardness: 0.5, // Easy to break
            resistance: 0.5,
          ),
        );

  /// Register this block with the game.
  /// Must be called during mod initialization before BlockRegistry.freeze().
  static void register() {
    BlockRegistry.register(instance);
  }
}
