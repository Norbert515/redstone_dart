/// Example nocterm UI rendered to Minecraft blocks.
///
/// This demonstrates rendering a terminal UI as colored concrete blocks
/// in the Minecraft world using nocterm's declarative component system.
library;

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

import 'nocterm_demos/demos.dart';

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
/// - Right-click: Create screen and cycle through demos
/// - Sneak + right-click: Clear and stop
class NoctermDemoBlock extends CustomBlock {
  NoctermDemoBlock()
      : super(
          id: 'dartmod:nocterm_demo',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  /// Current demo index (persists across interactions).
  static int _currentDemoIndex = 0;

  /// List of available demos with name and builder.
  static final List<(String name, Component Function(int width, int height) builder)> _demos = [
    ('Static Red', (w, h) => StaticUIComponent()),
    ('Rainbow Wave', (w, h) => RainbowWaveComponent(gridWidth: w, gridHeight: h)),
    ('Matrix Rain', (w, h) => MatrixRainComponent(gridWidth: w, gridHeight: h)),
    ('Plasma', (w, h) => PlasmaComponent(gridWidth: w, gridHeight: h)),
    ('Bouncing Logo', (w, h) => BouncingLogoComponent(gridWidth: w, gridHeight: h)),
    ('Clock', (w, h) => ClockComponent(gridWidth: w, gridHeight: h)),
    ('Game of Life', (w, h) => GameOfLifeComponent(gridWidth: w, gridHeight: h)),
  ];

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final manager = MinecraftScreenManager.instance;

    // Sneak + click = clear
    if (player.isSneaking) {
      manager.clearScreen();
      manager.dispose();
      _currentDemoIndex = 0;
      player.sendMessage('§a[nocterm] §fScreen cleared!');
      return ActionResult.success;
    }

    // If screen exists, cycle to next demo
    if (manager.screen != null) {
      _currentDemoIndex = (_currentDemoIndex + 1) % _demos.length;
      final demo = _demos[_currentDemoIndex];
      player.sendMessage('§a[nocterm] §f${demo.$1}');
      manager.start(
        manager.screen!,
        demo.$2(manager.screen!.width, manager.screen!.height),
      );
      return ActionResult.success;
    }

    // Create new screen with first demo
    _currentDemoIndex = 0;
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
      final demo = _demos[_currentDemoIndex];

      // Start with current demo (first one initially)
      MinecraftScreenManager.instance.start(screen, demo.$2(screen.width, screen.height));

      player.sendMessage('§a[nocterm] §f${demo.$1}');
      player.sendMessage('§7Right-click to cycle demos (${_demos.length} total)');
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
