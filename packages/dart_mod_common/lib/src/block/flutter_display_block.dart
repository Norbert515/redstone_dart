/// Convenience class for blocks that display Flutter content on a face.
library;

import 'custom_block.dart';
import 'block_settings.dart';
import 'block_model.dart';
import '../types.dart';
import '../block_entity/flutter_display_block_entity.dart';

/// A block that displays Flutter UI content on one of its faces.
///
/// This is a convenience class for creating single-block Flutter displays.
/// For multi-block displays (like large TV screens), use [FlutterDisplayBlockEntity]
/// directly in your block's [createBlockEntity] method.
///
/// ## Example - Simple TV Block
///
/// ```dart
/// final tvBlock = FlutterDisplayBlock(
///   id: 'mymod:tv_block',
///   facing: Direction.north,
///   emissive: true,
///   settings: BlockSettings(
///     hardness: 2.0,
///     resistance: 6.0,
///   ),
/// );
/// BlockRegistry.register(tvBlock);
/// ```
///
/// ## Example - Custom TV with Interaction
///
/// ```dart
/// class InteractiveTVBlock extends FlutterDisplayBlock {
///   InteractiveTVBlock() : super(
///     id: 'mymod:interactive_tv',
///     facing: Direction.north,
///   );
///
///   @override
///   ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
///     // Handle interaction (e.g., change channel)
///     print('Player interacted with TV at ($x, $y, $z)');
///     return ActionResult.success;
///   }
/// }
/// ```
class FlutterDisplayBlock extends CustomBlock {
  /// The Flutter surface ID to display (0 = main surface).
  final int surfaceId;

  /// Which block face displays the Flutter content.
  final Direction facing;

  /// Whether to use fullbright lighting.
  final bool emissive;

  /// Creates a Flutter display block.
  ///
  /// Parameters:
  /// - [id] Block identifier (e.g., 'mymod:tv_block')
  /// - [surfaceId] Flutter surface to display (default 0 = main surface)
  /// - [facing] Which face to render on (default north)
  /// - [emissive] Use fullbright lighting (default true)
  /// - [settings] Block settings (default solid block)
  /// - [model] Block model for textures (optional)
  FlutterDisplayBlock({
    required String id,
    this.surfaceId = 0,
    this.facing = Direction.north,
    this.emissive = true,
    BlockSettings? settings,
    BlockModel? model,
  }) : super(
          id: id,
          settings: settings ??
              BlockSettings(
                hardness: 2.0,
                resistance: 6.0,
              ),
          model: model,
        );

  /// Creates the Flutter display block entity for this block.
  ///
  /// Override this method to customize the block entity.
  FlutterDisplayBlockEntity createBlockEntity() {
    return FlutterDisplayBlockEntity(
      id: '${id}_entity',
      surfaceId: surfaceId,
      facing: facing,
      emissive: emissive,
    );
  }
}
