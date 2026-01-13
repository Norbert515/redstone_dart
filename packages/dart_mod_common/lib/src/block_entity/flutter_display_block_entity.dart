/// Block entity for displaying Flutter UI content on block faces.
library;

import 'block_entity.dart';
import 'block_entity_settings.dart';
import '../types.dart';

/// Block entity for displaying Flutter UI content on block faces.
///
/// This block entity supports multi-block displays (e.g., 3x2 TV screen) by tracking
/// the grid position and total grid size. Each block in the grid references the same
/// Flutter surface but displays a different portion based on its grid coordinates.
///
/// ## Example - Single Block Display
///
/// ```dart
/// class TVBlock extends CustomBlock {
///   @override
///   BlockEntity? createBlockEntity(BlockPos pos, BlockState state) {
///     return FlutterDisplayBlockEntity(
///       surfaceId: 0,  // Use main Flutter surface
///       facing: Direction.north,
///       emissive: true,
///     );
///   }
/// }
/// ```
///
/// ## Example - Multi-Block Display (3x2 grid)
///
/// ```dart
/// // Each block in the 3x2 grid creates its own block entity with different grid positions
/// class BigTVBlock extends CustomBlock {
///   final int gridX;
///   final int gridY;
///
///   BigTVBlock({required this.gridX, required this.gridY});
///
///   @override
///   BlockEntity? createBlockEntity(BlockPos pos, BlockState state) {
///     return FlutterDisplayBlockEntity(
///       surfaceId: 0,
///       gridX: gridX,
///       gridY: gridY,
///       gridWidth: 3,
///       gridHeight: 2,
///       facing: Direction.north,
///     );
///   }
/// }
/// ```
class FlutterDisplayBlockEntity extends BlockEntity {
  /// The Flutter surface ID to display.
  ///
  /// - `0` = main Flutter surface (FlutterScreen)
  /// - `>0` = additional surfaces created via multi-surface API
  final int surfaceId;

  /// X position within a multi-block grid (0 = left).
  final int gridX;

  /// Y position within a multi-block grid (0 = top).
  final int gridY;

  /// Total grid width for multi-block displays.
  final int gridWidth;

  /// Total grid height for multi-block displays.
  final int gridHeight;

  /// Which block face displays the Flutter content.
  final Direction facing;

  /// Whether to use fullbright lighting (true = ignore world light).
  final bool emissive;

  /// Creates a Flutter display block entity.
  ///
  /// Parameters:
  /// - [surfaceId] The Flutter surface ID (0 for main surface)
  /// - [gridX] X position in multi-block grid (default 0)
  /// - [gridY] Y position in multi-block grid (default 0)
  /// - [gridWidth] Total grid width (default 1 for single block)
  /// - [gridHeight] Total grid height (default 1 for single block)
  /// - [facing] Which block face to render on (default north)
  /// - [emissive] Whether to use fullbright lighting (default true)
  FlutterDisplayBlockEntity({
    required String id,
    this.surfaceId = 0,
    this.gridX = 0,
    this.gridY = 0,
    this.gridWidth = 1,
    this.gridHeight = 1,
    this.facing = Direction.north,
    this.emissive = true,
  }) : super(
          settings: BlockEntitySettings(id: id),
        );

  @override
  void loadAdditional(Map<String, dynamic> nbt) {
    // Note: The actual properties are synced via Java NBT
    // This Dart-side is mainly for configuration
  }

  @override
  Map<String, dynamic> saveAdditional() {
    return {
      'SurfaceId': surfaceId,
      'GridX': gridX,
      'GridY': gridY,
      'GridWidth': gridWidth,
      'GridHeight': gridHeight,
      'Facing': facing.id,
      'Emissive': emissive,
    };
  }
}
