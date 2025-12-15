/// Dart Minecraft GUI API
///
/// This library provides classes for creating custom GUI screens in Minecraft.
///
/// ## Overview
///
/// The GUI API allows you to create custom screens that integrate with
/// Minecraft's rendering and input systems. Key classes:
///
/// - [Screen] - Base class for custom screens
/// - [GuiGraphics] - Drawing context for rendering
/// - [Keys] - Key code constants for input handling
/// - [McColors] - Color utilities and constants
///
/// ## Example
///
/// ```dart
/// import 'package:dart_mod/api/gui/gui.dart';
///
/// class HelloScreen extends Screen {
///   HelloScreen() : super('Hello Screen');
///
///   @override
///   void render(GuiGraphics graphics, int mouseX, int mouseY, double partialTick) {
///     // Draw semi-transparent background
///     graphics.fill(0, 0, width, height, 0x80000000);
///
///     // Draw centered title
///     graphics.drawCenteredString(
///       'Hello, Minecraft!',
///       width ~/ 2,
///       height ~/ 2 - 20,
///       color: McColors.mcYellow,
///     );
///
///     // Draw instructions
///     graphics.drawCenteredString(
///       'Press ESC to close',
///       width ~/ 2,
///       height ~/ 2 + 10,
///       color: McColors.mcGray,
///     );
///   }
///
///   @override
///   bool keyPressed(int keyCode, int scanCode, int modifiers) {
///     if (keyCode == Keys.escape) {
///       close();
///       return true;
///     }
///     return false;
///   }
/// }
///
/// // Open the screen
/// void showHelloScreen() {
///   HelloScreen().show();
/// }
/// ```
library;

export 'gui_graphics.dart';
export 'keys.dart';
export 'screen.dart';
export 'widgets.dart';
