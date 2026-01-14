/// Block entity for the Screen Controller.
///
/// Manages multi-block screen detection and FlutterDisplay lifecycle.
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:dart_mod_server/dart_mod_server.dart';
import 'package:minecraft_flutter_dev_common/minecraft_flutter_dev_common.dart';

import 'screen_block.dart';
import 'screen_controller_block.dart';

/// Represents a detected screen grid.
class ScreenGrid {
  final BlockPos controllerPos;
  final Set<BlockPos> screenBlocks;
  final int minX, maxX, minY, maxY, minZ, maxZ;

  ScreenGrid({
    required this.controllerPos,
    required this.screenBlocks,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.minZ,
    required this.maxZ,
  });

  /// Width of the bounding box (X axis).
  int get width => maxX - minX + 1;

  /// Height of the bounding box (Y axis).
  int get height => maxY - minY + 1;

  /// Depth of the bounding box (Z axis).
  int get depth => maxZ - minZ + 1;

  /// Determine the screen plane orientation.
  ///
  /// Returns the axis that is "flat" (has size 1):
  /// - [ScreenPlane.xy] if depth == 1 (vertical wall facing Z)
  /// - [ScreenPlane.yz] if width == 1 (vertical wall facing X)
  /// - [ScreenPlane.xz] if height == 1 (horizontal floor/ceiling)
  ScreenPlane get plane {
    if (depth == 1) return ScreenPlane.xy;
    if (width == 1) return ScreenPlane.yz;
    if (height == 1) return ScreenPlane.xz;
    // If no dimension is 1, default to XY (most common for wall displays)
    return ScreenPlane.xy;
  }

  /// Get the display dimensions based on orientation.
  ///
  /// Returns (displayWidth, displayHeight) in blocks.
  (double, double) get displayDimensions {
    return switch (plane) {
      ScreenPlane.xy => (width.toDouble(), height.toDouble()),
      ScreenPlane.yz => (depth.toDouble(), height.toDouble()),
      ScreenPlane.xz => (width.toDouble(), depth.toDouble()),
    };
  }

  /// Get the yaw rotation for the display based on plane.
  double get displayYaw {
    return switch (plane) {
      ScreenPlane.xy => 0.0, // Facing Z+ (south)
      ScreenPlane.yz => 90.0, // Facing X+ (east)
      ScreenPlane.xz => 0.0, // Horizontal (floor/ceiling)
    };
  }

  /// Get the pitch rotation for the display based on plane.
  double get displayPitch {
    return switch (plane) {
      ScreenPlane.xy => 0.0, // Vertical
      ScreenPlane.yz => 0.0, // Vertical
      ScreenPlane.xz => 90.0, // Horizontal (facing up)
    };
  }

  /// Get the center position for the display entity.
  ///
  /// The position is offset by 0.5 blocks in front of the screen surface
  /// so the display appears on the face of the blocks, not inside them.
  Vec3 get displayCenter {
    // Base center of the bounding box
    final centerX = minX + width / 2.0;
    final centerY = minY + height / 2.0;
    final centerZ = minZ + depth / 2.0;

    // Offset to position the display in front of the blocks
    // We offset by 0.5 blocks in the direction the screen faces
    return switch (plane) {
      // XY plane (wall facing Z): offset in Z direction
      // Offset towards positive Z (south face of blocks)
      ScreenPlane.xy => Vec3(centerX, centerY, maxZ + 0.51),
      // YZ plane (wall facing X): offset in X direction
      // Offset towards positive X (east face of blocks)
      ScreenPlane.yz => Vec3(maxX + 0.51, centerY, centerZ),
      // XZ plane (floor/ceiling): offset in Y direction
      // Offset towards positive Y (top face of blocks)
      ScreenPlane.xz => Vec3(centerX, maxY + 0.51, centerZ),
    };
  }

  /// Encode the grid layout as a string for passing to Flutter.
  ///
  /// Format: rows separated by comma, 1=block present, 0=gap.
  /// The grid is always encoded in display coordinates (width x height).
  String encodeGridLayout() {
    final (gridWidth, gridHeight) = switch (plane) {
      ScreenPlane.xy => (width, height),
      ScreenPlane.yz => (depth, height),
      ScreenPlane.xz => (width, depth),
    };

    final rows = <String>[];
    for (var row = gridHeight - 1; row >= 0; row--) {
      final rowChars = StringBuffer();
      for (var col = 0; col < gridWidth; col++) {
        final worldPos = switch (plane) {
          ScreenPlane.xy => BlockPos(minX + col, minY + row, minZ),
          ScreenPlane.yz => BlockPos(minX, minY + row, minZ + col),
          ScreenPlane.xz => BlockPos(minX + col, minY, minZ + row),
        };
        rowChars.write(screenBlocks.contains(worldPos) ? '1' : '0');
      }
      rows.add(rowChars.toString());
    }
    return rows.join(',');
  }
}

/// Screen plane orientation.
enum ScreenPlane {
  /// XY plane - vertical wall facing Z axis.
  xy,

  /// YZ plane - vertical wall facing X axis.
  yz,

  /// XZ plane - horizontal (floor/ceiling).
  xz,
}

/// Block entity for the Screen Controller.
///
/// This block entity monitors redstone signals and spawns/despawns
/// a FlutterDisplayEntity covering all connected screen blocks.
class ScreenControllerEntity
    extends ContainerBlockEntity<ScreenControllerContainer> {
  ScreenControllerEntity() : super(container: ScreenControllerContainer());

  /// Maximum number of blocks to include in a screen grid.
  static const int maxBlocks = 64;

  /// The spawned FlutterDisplay instance (null if none).
  FlutterDisplay? _spawnedDisplay;

  /// Last known redstone state.
  bool _wasPowered = false;

  @override
  void serverTick() {
    final pos = blockPos;
    if (pos == null) return;

    // Check redstone signal
    final world = ServerWorld.overworld;
    final signalStrength = world.getRedstoneSignal(pos);
    final isPowered = signalStrength > 0;

    // Update synced state for client display
    container.isActive.value = isPowered ? 1 : 0;

    // Handle state change
    if (isPowered && !_wasPowered) {
      // Rising edge: detect grid and spawn display
      _spawnFlutterDisplay(pos, world);
    } else if (!isPowered && _wasPowered) {
      // Falling edge: despawn display
      _despawnFlutterDisplay();
    }

    _wasPowered = isPowered;
  }

  /// Find all connected screen blocks using BFS.
  Set<BlockPos> _findConnectedScreens(
      BlockPos start, ServerWorld world, int limit) {
    final visited = <BlockPos>{};
    final queue = Queue<BlockPos>()..add(start);

    while (queue.isNotEmpty && visited.length < limit) {
      final pos = queue.removeFirst();
      if (visited.contains(pos)) continue;

      // Check if this is a screen block or controller
      final block = world.getBlock(pos);
      if (block.id != ScreenBlock.blockId &&
          block.id != ScreenControllerBlock.blockId) {
        continue;
      }

      visited.add(pos);

      // Add orthogonal neighbors (not diagonals)
      queue.add(BlockPos(pos.x + 1, pos.y, pos.z));
      queue.add(BlockPos(pos.x - 1, pos.y, pos.z));
      queue.add(BlockPos(pos.x, pos.y + 1, pos.z));
      queue.add(BlockPos(pos.x, pos.y - 1, pos.z));
      queue.add(BlockPos(pos.x, pos.y, pos.z + 1));
      queue.add(BlockPos(pos.x, pos.y, pos.z - 1));
    }

    return visited;
  }

  /// Calculate bounding box and create ScreenGrid from connected blocks.
  ScreenGrid _calculateGrid(BlockPos controllerPos, Set<BlockPos> blocks) {
    var minX = controllerPos.x;
    var maxX = controllerPos.x;
    var minY = controllerPos.y;
    var maxY = controllerPos.y;
    var minZ = controllerPos.z;
    var maxZ = controllerPos.z;

    for (final pos in blocks) {
      minX = math.min(minX, pos.x);
      maxX = math.max(maxX, pos.x);
      minY = math.min(minY, pos.y);
      maxY = math.max(maxY, pos.y);
      minZ = math.min(minZ, pos.z);
      maxZ = math.max(maxZ, pos.z);
    }

    return ScreenGrid(
      controllerPos: controllerPos,
      screenBlocks: blocks,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      minZ: minZ,
      maxZ: maxZ,
    );
  }

  void _spawnFlutterDisplay(BlockPos pos, ServerWorld world) {
    if (_spawnedDisplay != null) return; // Already spawned

    // Find all connected screen blocks
    final connectedBlocks = _findConnectedScreens(pos, world, maxBlocks);
    if (connectedBlocks.isEmpty) return;

    // Calculate grid layout
    final grid = _calculateGrid(pos, connectedBlocks);
    final (displayWidth, displayHeight) = grid.displayDimensions;
    final gridLayout = grid.encodeGridLayout();

    print('[ScreenController] Found ${connectedBlocks.length} blocks');
    print('[ScreenController] Bounding box: X=${grid.minX}-${grid.maxX}, Y=${grid.minY}-${grid.maxY}, Z=${grid.minZ}-${grid.maxZ}');
    print('[ScreenController] Dimensions: width=${grid.width}, height=${grid.height}, depth=${grid.depth}');
    print('[ScreenController] Detected plane: ${grid.plane}');
    print('[ScreenController] Display size: ${displayWidth}x$displayHeight');
    print('[ScreenController] Position: ${grid.displayCenter}');
    print('[ScreenController] Yaw: ${grid.displayYaw}, Pitch: ${grid.displayPitch}');
    print('[ScreenController] Grid layout: $gridLayout');

    // Spawn FlutterDisplayEntity covering the grid
    final display = FlutterDisplay.spawn(
      position: grid.displayCenter,
      route: 'multiscreen?grid=$gridLayout',
      width: displayWidth,
      height: displayHeight,
      mode: BillboardMode.vertical, // Always face player horizontally
    );

    if (display != null) {
      _spawnedDisplay = display;
      print('[ScreenController] Spawned display at ${grid.displayCenter}');
    }
  }

  void _despawnFlutterDisplay() {
    final display = _spawnedDisplay;
    if (display == null) return;

    display.dispose();
    _spawnedDisplay = null;
    print('[ScreenController] Despawned display');
  }

  @override
  void setRemoved() {
    // Clean up when block is broken
    _despawnFlutterDisplay();
    super.setRemoved();
  }

  @override
  Map<String, dynamic> saveAdditional() {
    final data = super.saveAdditional();
    if (_spawnedDisplay != null) {
      data['spawned_entity_id'] = _spawnedDisplay!.entityId;
    }
    data['was_powered'] = _wasPowered ? 1 : 0;
    return data;
  }

  @override
  void loadAdditional(Map<String, dynamic> nbt) {
    super.loadAdditional(nbt);
    _wasPowered = (nbt['was_powered'] as int? ?? 0) == 1;
  }
}
