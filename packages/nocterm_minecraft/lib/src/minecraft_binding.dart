import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/buffer.dart' as buf;
import 'package:dart_mc/dart_mc.dart';

import 'minecraft_screen.dart';
import 'color_mapper.dart';
import 'block_renderer.dart';

/// Connects nocterm rendering to Minecraft block placement.
///
/// This binding attaches to a [TerminalBinding] and listens for buffer paint
/// events. When the buffer is painted, it converts each cell's background
/// color to a Minecraft block and places it in the world.
///
/// Example:
/// ```dart
/// final screen = MinecraftScreen.fromCorners(
///   BlockPos(0, 64, 0),
///   BlockPos(79, 104, 0),
/// );
/// final binding = MinecraftBinding(
///   screen: screen,
///   world: World.overworld,
/// );
/// binding.attach(terminalBinding);
/// ```
class MinecraftBinding {
  /// The screen definition mapping buffer coords to world coords.
  final MinecraftScreen screen;

  /// The renderer for placing blocks in the world.
  final BlockRenderer renderer;

  TerminalBinding? _binding;

  /// Creates a MinecraftBinding for the given screen and world.
  ///
  /// The [screen] defines the rectangular area in the Minecraft world where
  /// blocks will be placed. The [world] is the dimension to place blocks in.
  MinecraftBinding({
    required this.screen,
    required World world,
  }) : renderer = BlockRenderer(world);

  /// Attach to a TerminalBinding to receive buffer updates.
  ///
  /// When attached, every time the terminal buffer is painted, the binding
  /// will convert the buffer content to blocks and render them in Minecraft.
  ///
  /// Only one binding can be attached at a time. Call [detach] first to
  /// attach to a different binding.
  void attach(TerminalBinding binding) {
    _binding = binding;
    binding.onBufferPainted = _onBufferPainted;
  }

  /// Detach from the current binding.
  ///
  /// After detaching, buffer updates will no longer be rendered to Minecraft.
  void detach() {
    _binding?.onBufferPainted = null;
    _binding = null;
  }

  /// Whether this binding is currently attached to a TerminalBinding.
  bool get isAttached => _binding != null;

  void _onBufferPainted(buf.Buffer buffer) {
    final changes = <BlockChange>[];

    // Iterate over the intersection of buffer size and screen size
    final maxY = buffer.height < screen.height ? buffer.height : screen.height;
    final maxX = buffer.width < screen.width ? buffer.width : screen.width;

    for (int y = 0; y < maxY; y++) {
      for (int x = 0; x < maxX; x++) {
        final cell = buffer.getCell(x, y);
        final bgColor = cell.style.backgroundColor;

        if (bgColor != null && !bgColor.isDefault) {
          // Convert Color to ARGB int for ColorMapper
          // Color stores alpha, red, green, blue as separate int fields
          final argb = (bgColor.alpha << 24) |
              (bgColor.red << 16) |
              (bgColor.green << 8) |
              bgColor.blue;
          final block = ColorMapper.getBlockFromArgb(argb);
          final worldPos = screen.bufferToWorld(x, y);
          changes.add(BlockChange(worldPos, block));
        }
        // Skip cells with no background color (leave existing blocks)
      }
    }

    if (changes.isNotEmpty) {
      renderer.render(changes);
    }
  }
}
