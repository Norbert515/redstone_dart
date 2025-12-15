import 'package:dart_mc/dart_mc.dart';

/// Represents a single block change to be rendered.
class BlockChange {
  final BlockPos pos;
  final Block block;

  const BlockChange(this.pos, this.block);

  @override
  String toString() => 'BlockChange($pos, $block)';

  @override
  bool operator ==(Object other) =>
      other is BlockChange && pos == other.pos && block == other.block;

  @override
  int get hashCode => Object.hash(pos, block);
}

/// Renders blocks to the Minecraft world in batches.
///
/// This class collects block changes and executes them efficiently
/// using the World.setBlock() API.
class BlockRenderer {
  /// The world to render blocks into.
  final World world;

  /// Creates a BlockRenderer for the given world.
  ///
  /// Example:
  /// ```dart
  /// final renderer = BlockRenderer(World.overworld);
  /// ```
  BlockRenderer(this.world);

  /// Render all block changes to the world.
  ///
  /// Each change is applied in order using [World.setBlock].
  /// Returns the number of blocks successfully placed.
  ///
  /// Example:
  /// ```dart
  /// final changes = [
  ///   BlockChange(BlockPos(0, 64, 0), Block.stone),
  ///   BlockChange(BlockPos(1, 64, 0), Block.cobblestone),
  /// ];
  /// final placed = renderer.render(changes);
  /// print('Placed $placed blocks');
  /// ```
  int render(List<BlockChange> changes) {
    var successCount = 0;
    for (final change in changes) {
      if (world.setBlock(change.pos, change.block)) {
        successCount++;
      }
    }
    return successCount;
  }

  /// Render a single block change to the world.
  ///
  /// Returns true if the block was successfully placed.
  bool renderSingle(BlockChange change) {
    return world.setBlock(change.pos, change.block);
  }

  /// Render blocks and return detailed results.
  ///
  /// Returns a [RenderResult] containing success/failure information.
  RenderResult renderWithResult(List<BlockChange> changes) {
    final failed = <BlockChange>[];
    var successCount = 0;

    for (final change in changes) {
      if (world.setBlock(change.pos, change.block)) {
        successCount++;
      } else {
        failed.add(change);
      }
    }

    return RenderResult(
      totalChanges: changes.length,
      successCount: successCount,
      failedChanges: failed,
    );
  }
}

/// Result of a batch render operation.
class RenderResult {
  /// Total number of block changes attempted.
  final int totalChanges;

  /// Number of blocks successfully placed.
  final int successCount;

  /// List of block changes that failed to apply.
  final List<BlockChange> failedChanges;

  const RenderResult({
    required this.totalChanges,
    required this.successCount,
    required this.failedChanges,
  });

  /// Number of blocks that failed to place.
  int get failureCount => failedChanges.length;

  /// Whether all blocks were successfully placed.
  bool get allSucceeded => failedChanges.isEmpty;

  @override
  String toString() =>
      'RenderResult($successCount/$totalChanges succeeded, $failureCount failed)';
}
