/// nocterm_minecraft - Minecraft block-based rendering backend for nocterm
///
/// This package allows rendering nocterm terminal UIs as colored blocks
/// in Minecraft.
///
/// ## Usage
///
/// ```dart
/// import 'package:nocterm_minecraft/nocterm_minecraft.dart';
/// import 'package:dart_mc_mod/dart_mod.dart';
///
/// // Define screen corners (must be in same vertical plane)
/// final screen = MinecraftScreen.fromCorners(
///   BlockPos(100, 64, 200),
///   BlockPos(100, 84, 240),  // Same X, different Y and Z
/// );
///
/// // Create binding with the overworld
/// final mcBinding = MinecraftBinding(
///   screen: screen,
///   world: World.overworld,
/// );
///
/// // Attach to nocterm's terminal binding
/// mcBinding.attach(terminalBinding);
/// ```
library nocterm_minecraft;

export 'src/minecraft_binding.dart' show MinecraftBinding;
export 'src/minecraft_screen.dart' show MinecraftScreen;
export 'src/color_mapper.dart' show ColorMapper;
export 'src/block_renderer.dart' show BlockRenderer, BlockChange, RenderResult;
export 'src/screen_corner_block.dart' show ScreenCornerBlock;
