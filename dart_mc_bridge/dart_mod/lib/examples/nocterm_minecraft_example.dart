/// Example nocterm UI rendered to Minecraft blocks.
///
/// This demonstrates rendering a terminal UI as colored concrete blocks
/// in the Minecraft world using nocterm's declarative component system.
library;

import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/backend/terminal.dart' as term;
import 'package:nocterm/src/binding/terminal_binding.dart';
import 'package:nocterm/src/buffer.dart' as buf;
import 'package:nocterm_minecraft/nocterm_minecraft.dart';
import 'package:dart_mc_mod/dart_mod.dart' show BlockPos;

import '../api/world.dart';
import '../api/block.dart';
import '../api/custom_block.dart';
import '../api/block_registry.dart';
import '../api/player.dart';
// ignore: unused_import - used by demoCreateTestScreen
import '../src/bridge.dart';
import '../src/types.dart';

// =============================================================================
// Animated nocterm Components
// =============================================================================

/// Custom painter for diagonal rainbow wave pattern.
/// Draws diagonal stripes that animate over time.
class RainbowWavePainter extends CustomPainter {
  RainbowWavePainter({required this.frame});

  final int frame;

  // Rainbow colors
  static const _colors = [
    Color.fromRGB(255, 0, 0), // Red
    Color.fromRGB(255, 127, 0), // Orange
    Color.fromRGB(255, 255, 0), // Yellow
    Color.fromRGB(0, 255, 0), // Green
    Color.fromRGB(0, 255, 255), // Cyan
    Color.fromRGB(0, 0, 255), // Blue
    Color.fromRGB(139, 0, 255), // Purple
    Color.fromRGB(255, 0, 255), // Magenta
  ];

  @override
  void paint(TerminalCanvas canvas, Size size) {
    for (int y = 0; y < size.height; y++) {
      for (int x = 0; x < size.width; x++) {
        // Diagonal stripes: x + y gives diagonal, add frame for animation
        final colorIndex = ((x + y + frame) ~/ 3) % _colors.length;
        final color = _colors[colorIndex];

        // Fill this pixel with the background color
        canvas.fillRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          ' ', // Space character (we only care about background)
          style: TextStyle(backgroundColor: color),
        );
      }
    }
  }

  @override
  bool shouldRepaint(RainbowWavePainter oldDelegate) {
    return frame != oldDelegate.frame;
  }
}

/// An animated rainbow stripes component using setState and CustomPaint.
/// Creates diagonal rainbow stripes that animate.
class RainbowWaveComponent extends StatefulComponent {
  const RainbowWaveComponent({super.key, this.gridWidth = 21, this.gridHeight = 16});

  final int gridWidth;
  final int gridHeight;

  @override
  State<RainbowWaveComponent> createState() => _RainbowWaveState();
}

class _RainbowWaveState extends State<RainbowWaveComponent> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    // Animate at ~4 FPS for smooth scrolling
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      setState(() => _frame++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return CustomPaint(
      painter: RainbowWavePainter(frame: _frame),
      size: Size(component.gridWidth.toDouble(), component.gridHeight.toDouble()),
    );
  }
}

/// A static UI demo component (no animation).
/// Simple solid color fill to test rendering works.
class StaticUIComponent extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    // Just a solid red container that fills the entire space
    return Container(
      color: Colors.red,
    );
  }
}

// =============================================================================
// Minecraft Screen Manager with Declarative Rendering
// =============================================================================

/// Manages nocterm rendering to Minecraft.
class MinecraftScreenManager {
  static MinecraftScreenManager? _instance;
  static MinecraftScreenManager get instance => _instance ??= MinecraftScreenManager._();

  MinecraftScreenManager._();

  MinecraftScreen? _screen;
  TerminalBinding? _binding;
  HeadlessBackend? _backend;
  bool _isRunning = false;
  bool _bindingInitialized = false;

  MinecraftScreen? get screen => _screen;
  bool get isRunning => _isRunning;

  /// Start rendering a nocterm component to a Minecraft screen.
  void start(MinecraftScreen screen, Component component) {
    _screen = screen;
    _isRunning = true;

    // Create binding only once (to avoid extension registration conflicts)
    if (!_bindingInitialized) {
      _backend = HeadlessBackend(
        size: Size(screen.width.toDouble(), screen.height.toDouble()),
      );
      final terminal = term.Terminal(_backend!, size: _backend!.getSize());
      _binding = TerminalBinding(terminal);
      _bindingInitialized = true;
      print('[nocterm_mc] Created TerminalBinding');
    } else {
      // Update backend size if screen dimensions changed
      _backend!.notifySizeChanged(Size(screen.width.toDouble(), screen.height.toDouble()));
    }

    // Hook up buffer rendering to Minecraft
    _binding!.onBufferPainted = (buffer) {
      if (_isRunning && _screen != null) {
        _renderBufferToMinecraft(buffer, _screen!);
      }
    };

    // Attach component and trigger render
    _binding!.attachRootComponent(component);
    _binding!.scheduleFrame();

    print('[nocterm_mc] Started rendering ${screen.width}x${screen.height}');
  }

  /// Stop the current rendering session (but keep binding alive).
  void stop() {
    _isRunning = false;
    _binding?.onBufferPainted = null;
    print('[nocterm_mc] Stopped rendering');
  }

  /// Clear the screen blocks.
  void clearScreen() {
    if (_screen == null) return;

    final world = World.overworld;
    for (var y = 0; y < _screen!.height; y++) {
      for (var x = 0; x < _screen!.width; x++) {
        final pos = _screen!.bufferToWorld(x, y);
        world.setBlock(pos, Block.air);
      }
    }
    print('[nocterm_mc] Screen cleared');
  }

  /// Dispose the screen (but keep binding for reuse).
  void dispose() {
    stop();
    _screen = null;
  }

  /// Render a nocterm buffer to Minecraft blocks.
  void _renderBufferToMinecraft(buf.Buffer buffer, MinecraftScreen screen) {
    final world = World.overworld;

    // Debug: log first cell's color to see if animation is working
    final firstCell = buffer.getCell(0, 0);
    final firstBg = firstCell.style.backgroundColor;

    for (int y = 0; y < buffer.height && y < screen.height; y++) {
      for (int x = 0; x < buffer.width && x < screen.width; x++) {
        final cell = buffer.getCell(x, y);
        final bgColor = cell.style.backgroundColor;

        // Render background color as blocks
        if (bgColor != null && !bgColor.isDefault) {
          final argb = (bgColor.alpha << 24) | (bgColor.red << 16) | (bgColor.green << 8) | bgColor.blue;
          final block = ColorMapper.getBlockFromArgb(argb);
          final worldPos = screen.bufferToWorld(x, y);
          world.setBlock(worldPos, block);
        } else {
          // No background = use white concrete as fallback
          final worldPos = screen.bufferToWorld(x, y);
          world.setBlock(worldPos, Block('minecraft:white_concrete'));
        }
      }
    }
  }
}

// =============================================================================
// Block Registration
// =============================================================================

/// Register nocterm minecraft blocks.
void registerNoctermMinecraftBlocks() {
  print('[nocterm_mc] Registering nocterm minecraft blocks...');
  ScreenCornerBlock.register();
  BlockRegistry.register(NoctermDemoBlock());
  print('[nocterm_mc] Blocks registered: screen_corner, nocterm_demo');
}

// =============================================================================
// Demo Trigger Block
// =============================================================================

/// Demo block for nocterm Minecraft rendering.
/// - Right-click: Create screen with static UI
/// - Right-click again: Start rainbow wave animation
/// - Sneak + right-click: Clear and stop
class NoctermDemoBlock extends CustomBlock {
  NoctermDemoBlock()
      : super(
          id: 'dartmod:nocterm_demo',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final manager = MinecraftScreenManager.instance;

    // Sneak + click = clear
    if (player.isSneaking) {
      manager.clearScreen();
      manager.dispose();
      player.sendMessage('§a[nocterm] §fScreen cleared!');
      return ActionResult.success;
    }

    // If screen exists, toggle to animated
    if (manager.screen != null) {
      // Switch to animated rainbow wave
      player.sendMessage('§a[nocterm] §f🌈 Starting rainbow wave animation...');
      manager.start(
        manager.screen!,
        RainbowWaveComponent(
          gridWidth: manager.screen!.width,
          gridHeight: manager.screen!.height,
        ),
      );
      player.sendMessage('§7Using declarative nocterm components with setState');
      return ActionResult.success;
    }

    // Create new screen
    _createScreen(player, x, y, z);
    return ActionResult.success;
  }

  void _createScreen(Player player, int blockX, int blockY, int blockZ) {
    final yaw = player.yaw;
    final bool facingX = (yaw > 45 && yaw <= 135) || (yaw > 225 && yaw <= 315);

    const screenWidth = 21;
    const screenHeight = 16;
    const distance = 5;

    final BlockPos corner1;
    final BlockPos corner2;

    if (facingX) {
      final zOffset = (yaw > 45 && yaw <= 135) ? -distance : distance;
      final screenZ = blockZ + zOffset;
      corner1 = BlockPos(blockX - screenWidth ~/ 2, blockY + screenHeight, screenZ);
      corner2 = BlockPos(blockX + screenWidth ~/ 2, blockY + 1, screenZ);
    } else {
      final xOffset = (yaw <= 45 || yaw > 315) ? distance : -distance;
      final screenX = blockX + xOffset;
      corner1 = BlockPos(screenX, blockY + screenHeight, blockZ - screenWidth ~/ 2);
      corner2 = BlockPos(screenX, blockY + 1, blockZ + screenWidth ~/ 2);
    }

    player.sendMessage('§b[nocterm] §fCreating ${screenWidth}x${screenHeight} screen...');

    try {
      final screen = MinecraftScreen.fromCorners(corner1, corner2);

      // Start with static UI
      MinecraftScreenManager.instance.start(screen, StaticUIComponent());

      player.sendMessage('§a[nocterm] §fScreen created with static UI!');
      player.sendMessage('§7Right-click again for 🌈 rainbow animation');
      player.sendMessage('§7Sneak + click to clear');
    } catch (e) {
      player.sendMessage('§c[nocterm] §fFailed: $e');
    }
  }
}

/// Tick handler - not needed anymore since Timer.periodic handles animation
void noctermTick(int tick) {
  // Animation is handled by Timer.periodic in StatefulComponents
}
