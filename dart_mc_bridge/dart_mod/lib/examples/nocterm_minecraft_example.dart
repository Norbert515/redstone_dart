/// Example nocterm UI rendered to Minecraft blocks.
///
/// This demonstrates rendering a terminal UI as colored concrete blocks
/// in the Minecraft world.
library;

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_minecraft/nocterm_minecraft.dart';
import 'package:dart_mc_mod/dart_mod.dart' show BlockPos;

import '../api/world.dart';
import '../api/block.dart';
import '../api/custom_block.dart';
import '../api/block_registry.dart';
import '../api/player.dart';
import '../src/bridge.dart';
import '../src/types.dart';

/// A simple test component with colored boxes.
class TestMinecraftUI extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return Column(
      children: [
        // Red header bar
        Container(
          color: Colors.red,
          height: 3,
          child: Center(
            child: Text('Minecraft nocterm'),
          ),
        ),
        // Main content area with colored sections
        Expanded(
          child: Row(
            children: [
              // Blue sidebar
              Container(
                color: Colors.blue,
                width: 5,
              ),
              // Green main area
              Expanded(
                child: Container(
                  color: Colors.green,
                  child: Center(
                    child: Container(
                      color: Colors.yellow,
                      width: 8,
                      height: 4,
                      child: Center(
                        child: Text('Hi!'),
                      ),
                    ),
                  ),
                ),
              ),
              // Magenta sidebar
              Container(
                color: Colors.magenta,
                width: 5,
              ),
            ],
          ),
        ),
        // Cyan footer
        Container(
          color: Colors.cyan,
          height: 2,
        ),
      ],
    );
  }
}

/// A colorful gradient test pattern.
class ColorTestPattern extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return Column(
      children: [
        _colorRow(Colors.white, Colors.black),
        _colorRow(Colors.red, Colors.brightRed),
        _colorRow(Colors.yellow, Colors.brightYellow),
        _colorRow(Colors.green, Colors.cyan),
        _colorRow(Colors.blue, Colors.brightBlue),
        _colorRow(Colors.magenta, Colors.brightMagenta),
      ],
    );
  }

  Component _colorRow(Color left, Color right) {
    return Expanded(
      child: Row(
        children: [
          Expanded(child: Container(color: left)),
          Expanded(child: Container(color: right)),
        ],
      ),
    );
  }
}

// =============================================================================
// Screen Manager - Manages active Minecraft screens
// =============================================================================

/// Manages nocterm screens rendered in Minecraft.
class MinecraftScreenManager {
  static MinecraftScreenManager? _instance;
  static MinecraftScreenManager get instance => _instance ??= MinecraftScreenManager._();

  MinecraftScreenManager._();

  MinecraftBinding? _activeBinding;
  MinecraftScreen? _activeScreen;

  /// Animation state
  bool _animationRunning = false;
  int _animationFrame = 0;

  /// Create and activate a screen at the given corners.
  /// Corners must be in the same vertical plane (same X or same Z).
  void createScreen(BlockPos corner1, BlockPos corner2) {
    // Dispose existing screen if any
    _activeBinding?.detach();
    _animationRunning = false;

    try {
      _activeScreen = MinecraftScreen.fromCorners(corner1, corner2);
      _activeBinding = MinecraftBinding(
        screen: _activeScreen!,
        world: World.overworld,
      );
      print('[nocterm_mc] Screen created: ${_activeScreen!.width}x${_activeScreen!.height}');
    } catch (e) {
      print('[nocterm_mc] Failed to create screen: $e');
    }
  }

  /// Get the active binding (to attach to TerminalBinding).
  MinecraftBinding? get binding => _activeBinding;

  /// Get the active screen dimensions.
  MinecraftScreen? get screen => _activeScreen;

  /// Whether animation is currently running.
  bool get isAnimating => _animationRunning;

  /// Current animation frame.
  int get animationFrame => _animationFrame;

  /// Start the animation loop.
  void startAnimation() {
    _animationRunning = true;
    _animationFrame = 0;
  }

  /// Stop the animation loop.
  void stopAnimation() {
    _animationRunning = false;
  }

  /// Called every tick to update animation.
  /// Returns true if a frame was rendered.
  bool tick(int gameTick) {
    if (!_animationRunning || _activeScreen == null) return false;

    // Render every 4 ticks (5 FPS) to avoid overwhelming the server
    if (gameTick % 4 != 0) return false;

    _animationFrame++;
    _renderAnimatedFrame(_activeScreen!, World.overworld, _animationFrame);
    return true;
  }

  /// Clear the screen (fill with air blocks).
  void clearScreen() {
    if (_activeScreen == null) return;
    _animationRunning = false;

    final world = World.overworld;
    for (var y = 0; y < _activeScreen!.height; y++) {
      for (var x = 0; x < _activeScreen!.width; x++) {
        final pos = _activeScreen!.bufferToWorld(x, y);
        world.setBlock(pos, Block.air);
      }
    }
    print('[nocterm_mc] Screen cleared');
  }

  /// Dispose the current screen.
  void dispose() {
    _activeBinding?.detach();
    _activeBinding = null;
    _activeScreen = null;
    _animationRunning = false;
  }

  /// Renders an animated frame with wave/rainbow effect.
  void _renderAnimatedFrame(MinecraftScreen screen, World world, int frame) {
    // Color palette for rainbow effect
    final palette = [
      Block('minecraft:red_concrete'),
      Block('minecraft:orange_concrete'),
      Block('minecraft:yellow_concrete'),
      Block('minecraft:lime_concrete'),
      Block('minecraft:cyan_concrete'),
      Block('minecraft:blue_concrete'),
      Block('minecraft:purple_concrete'),
      Block('minecraft:magenta_concrete'),
    ];

    for (int y = 0; y < screen.height; y++) {
      for (int x = 0; x < screen.width; x++) {
        final pos = screen.bufferToWorld(x, y);

        // Create a wave pattern that moves over time
        // The wave moves diagonally across the screen
        final wave = (x + y + frame) % palette.length;
        final block = palette[wave];

        world.setBlock(pos, block);
      }
    }
  }
}

/// Register the screen corner block and demo trigger block.
/// Call this during mod initialization before BlockRegistry.freeze().
void registerNoctermMinecraftBlocks() {
  print('[nocterm_mc] Registering nocterm minecraft blocks...');
  ScreenCornerBlock.register();
  BlockRegistry.register(NoctermDemoBlock());
  print('[nocterm_mc] Blocks registered: screen_corner, nocterm_demo');
}

// =============================================================================
// Demo Trigger Block - Creates and renders a nocterm screen
// =============================================================================

/// Demo block that creates a nocterm screen and renders a test UI.
/// - Right-click: Create screen with static UI
/// - Right-click again: Start rainbow wave animation
/// - Sneak + right-click: Clear screen and stop animation
class NoctermDemoBlock extends CustomBlock {
  NoctermDemoBlock()
      : super(
          id: 'dartmod:nocterm_demo',
          settings: BlockSettings(
            hardness: 1.0,
            resistance: 1.0,
          ),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Player(playerId);
    final manager = MinecraftScreenManager.instance;

    // Check if sneaking - if so, clear the screen
    if (player.isSneaking) {
      _clearScreen(player);
      return ActionResult.success;
    }

    // If screen exists, toggle animation
    if (manager.screen != null) {
      if (manager.isAnimating) {
        manager.stopAnimation();
        player.sendMessage('§e[nocterm] §fAnimation stopped.');
        // Re-render static UI
        _renderColorDemo(manager.screen!, World.overworld);
      } else {
        manager.startAnimation();
        player.sendMessage('§a[nocterm] §f🌈 Rainbow wave animation started!');
        player.sendMessage('§7Right-click again to stop, sneak+click to clear.');
      }
      return ActionResult.success;
    }

    // Create and render a demo screen
    _createDemoScreen(player, x, y, z);
    return ActionResult.success;
  }

  void _clearScreen(Player player) {
    final manager = MinecraftScreenManager.instance;
    if (manager.screen == null) {
      player.sendMessage('§c[nocterm] §fNo active screen to clear.');
      return;
    }

    manager.clearScreen();
    manager.dispose();
    player.sendMessage('§a[nocterm] §fScreen cleared!');
  }

  void _createDemoScreen(Player player, int blockX, int blockY, int blockZ) {
    final world = World.overworld;

    // Get player facing direction from yaw
    final yaw = player.yaw;

    // Determine which plane to use based on player facing
    // Yaw: 0 = south (+Z), 90 = west (-X), 180 = north (-Z), 270 = east (+X)
    final bool facingX = (yaw > 45 && yaw <= 135) || (yaw > 225 && yaw <= 315);

    // Screen dimensions
    const screenWidth = 21;
    const screenHeight = 16;
    const distance = 5; // Blocks in front of player

    final BlockPos corner1;
    final BlockPos corner2;

    if (facingX) {
      // Player facing along X axis - screen on Z plane
      final zOffset = (yaw > 45 && yaw <= 135) ? -distance : distance;
      final screenZ = blockZ + zOffset;
      corner1 = BlockPos(blockX - screenWidth ~/ 2, blockY + screenHeight, screenZ);
      corner2 = BlockPos(blockX + screenWidth ~/ 2, blockY + 1, screenZ);
    } else {
      // Player facing along Z axis - screen on X plane
      final xOffset = (yaw <= 45 || yaw > 315) ? distance : -distance;
      final screenX = blockX + xOffset;
      corner1 = BlockPos(screenX, blockY + screenHeight, blockZ - screenWidth ~/ 2);
      corner2 = BlockPos(screenX, blockY + 1, blockZ + screenWidth ~/ 2);
    }

    player.sendMessage('§b[nocterm] §fCreating ${screenWidth}x${screenHeight} screen...');

    // Create the screen
    final manager = MinecraftScreenManager.instance;
    manager.createScreen(corner1, corner2);

    final screen = manager.screen;
    final binding = manager.binding;

    if (screen == null || binding == null) {
      player.sendMessage('§c[nocterm] §fFailed to create screen!');
      return;
    }

    player.sendMessage('§a[nocterm] §fScreen created! Rendering demo UI...');

    // Now we need to render the UI to the screen
    // We'll directly render a color pattern since we don't have a full nocterm runtime
    _renderColorDemo(screen, world);

    player.sendMessage('§a[nocterm] §fDemo rendered! §7(${screen.width}x${screen.height} blocks)');
    player.sendMessage('§7Right-click again for 🌈 animation, sneak+click to clear.');
  }

  /// Renders a colorful demo pattern directly to the screen.
  void _renderColorDemo(MinecraftScreen screen, World world) {
    // Color pattern: header, body with sidebars, footer
    final colors = [
      ColorMapper.getBlockFromArgb(0xFFE76170), // Red (header)
      ColorMapper.getBlockFromArgb(0xFF8BB3F4), // Blue (sidebar)
      ColorMapper.getBlockFromArgb(0xFF8BD598), // Green (main)
      ColorMapper.getBlockFromArgb(0xFFF1D589), // Yellow (center box)
      ColorMapper.getBlockFromArgb(0xFFC6A0F6), // Magenta (sidebar)
      ColorMapper.getBlockFromArgb(0xFF8BD5CA), // Cyan (footer)
    ];

    for (int y = 0; y < screen.height; y++) {
      for (int x = 0; x < screen.width; x++) {
        final pos = screen.bufferToWorld(x, y);
        Block block;

        // Header (top 3 rows)
        if (y < 3) {
          block = colors[0]; // Red
        }
        // Footer (bottom 2 rows)
        else if (y >= screen.height - 2) {
          block = colors[5]; // Cyan
        }
        // Left sidebar (5 blocks wide)
        else if (x < 5) {
          block = colors[1]; // Blue
        }
        // Right sidebar (5 blocks wide)
        else if (x >= screen.width - 5) {
          block = colors[4]; // Magenta
        }
        // Center yellow box
        else if (y >= screen.height ~/ 2 - 2 && y < screen.height ~/ 2 + 2 &&
                 x >= screen.width ~/ 2 - 4 && x < screen.width ~/ 2 + 4) {
          block = colors[3]; // Yellow
        }
        // Main area
        else {
          block = colors[2]; // Green
        }

        world.setBlock(pos, block);
      }
    }
  }
}

/// Call this from your onTick handler to update animations.
/// Add to your Events.onTick: `noctermTick(tick);`
void noctermTick(int tick) {
  MinecraftScreenManager.instance.tick(tick);
}

/// Demo: Create a test screen and render a UI to it.
/// Call this with player coordinates to create a screen nearby.
void demoCreateTestScreen(int playerX, int playerY, int playerZ, int playerId) {
  // Create a 20x15 screen on the X plane, 5 blocks in front of player
  final corner1 = BlockPos(playerX + 5, playerY + 15, playerZ - 10);
  final corner2 = BlockPos(playerX + 5, playerY, playerZ + 10);

  Bridge.sendChatMessage(playerId, '§b[nocterm] §fCreating test screen...');

  MinecraftScreenManager.instance.createScreen(corner1, corner2);

  final screen = MinecraftScreenManager.instance.screen;
  if (screen != null) {
    Bridge.sendChatMessage(
      playerId,
      '§a[nocterm] §fScreen created: ${screen.width}x${screen.height} blocks',
    );
    Bridge.sendChatMessage(
      playerId,
      '§7Corner 1: (${corner1.x}, ${corner1.y}, ${corner1.z})',
    );
    Bridge.sendChatMessage(
      playerId,
      '§7Corner 2: (${corner2.x}, ${corner2.y}, ${corner2.z})',
    );
  }
}
