/// Drawing context for rendering on Minecraft screens.
///
/// This class provides drawing operations for custom GUI screens.
/// An instance is passed to [Screen.render] during each frame.
library;

import '../../src/jni/generic_bridge.dart';

/// The Java class name for DartBridgeClient (client-side).
const _dartBridgeClient = 'com/example/dartbridge/DartBridgeClient';

/// Drawing context for rendering on screens.
///
/// Passed to [Screen.render] - use this to draw text, shapes, and textures.
///
/// Example:
/// ```dart
/// @override
/// void render(GuiGraphics graphics, int mouseX, int mouseY, double partialTick) {
///   // Draw a semi-transparent background
///   graphics.fill(0, 0, width, height, 0x80000000);
///
///   // Draw centered text
///   graphics.drawCenteredString('Hello World!', width ~/ 2, height ~/ 2);
///
///   // Draw a button-like rectangle
///   graphics.renderOutline(100, 50, 80, 20, 0xFFFFFFFF);
///   graphics.drawCenteredString('Click Me', 140, 55);
/// }
/// ```
class GuiGraphics {
  final int _screenId;

  /// Creates a GuiGraphics context for the given screen.
  /// This is typically called internally by the Screen class.
  GuiGraphics._(this._screenId);

  /// Creates a GuiGraphics context for a screen ID.
  /// Used internally by the Screen class during rendering.
  factory GuiGraphics.forScreen(int screenId) {
    return GuiGraphics._(screenId);
  }

  // ===========================================================================
  // Text Drawing
  // ===========================================================================

  /// Draw a string at the given position.
  ///
  /// [text] - The text to draw
  /// [x] - X position (left edge of text)
  /// [y] - Y position (top edge of text)
  /// [color] - Text color in ARGB format (default: white 0xFFFFFF)
  /// [shadow] - If true, draw with shadow (good for dark backgrounds).
  ///            If false, no shadow (good for light backgrounds like panels).
  void drawString(String text, int x, int y, {int color = 0xFFFFFF, bool shadow = true}) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'guiDrawString',
      '(JLjava/lang/String;IIIZ)V',
      [_screenId, text, x, y, color, shadow],
    );
  }

  /// Draw a centered string at the given position.
  ///
  /// [text] - The text to draw
  /// [centerX] - X position (center of text)
  /// [y] - Y position (top edge of text)
  /// [color] - Text color in ARGB format (default: white 0xFFFFFF)
  /// [shadow] - If true, draw with shadow (good for dark backgrounds).
  ///            If false, no shadow (good for light backgrounds like panels).
  void drawCenteredString(String text, int centerX, int y, {int color = 0xFFFFFF, bool shadow = true}) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'guiDrawCenteredString',
      '(JLjava/lang/String;IIIZ)V',
      [_screenId, text, centerX, y, color, shadow],
    );
  }

  /// Get the width of a string in pixels.
  ///
  /// Useful for positioning text or creating text-based layouts.
  int getStringWidth(String text) {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridgeClient,
      'guiGetStringWidth',
      '(Ljava/lang/String;)I',
      [text],
    );
  }

  /// Get the height of the font in pixels.
  ///
  /// Minecraft's default font height is 9 pixels.
  int getFontHeight() {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridgeClient,
      'guiGetFontHeight',
      '()I',
      [],
    );
  }

  // ===========================================================================
  // Shape Drawing
  // ===========================================================================

  /// Fill a rectangle with a solid color.
  ///
  /// [x1], [y1] - Top-left corner
  /// [x2], [y2] - Bottom-right corner
  /// [color] - Fill color in ARGB format
  ///
  /// Example:
  /// ```dart
  /// // Semi-transparent black background
  /// graphics.fill(0, 0, width, height, 0x80000000);
  /// ```
  void fill(int x1, int y1, int x2, int y2, int color) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'guiFill',
      '(JIIIII)V',
      [_screenId, x1, y1, x2, y2, color],
    );
  }

  /// Fill a rectangle with a vertical gradient.
  ///
  /// [x1], [y1] - Top-left corner
  /// [x2], [y2] - Bottom-right corner
  /// [colorTop] - Color at the top in ARGB format
  /// [colorBottom] - Color at the bottom in ARGB format
  void fillGradient(int x1, int y1, int x2, int y2, int colorTop, int colorBottom) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'guiFillGradient',
      '(JIIIIII)V',
      [_screenId, x1, y1, x2, y2, colorTop, colorBottom],
    );
  }

  /// Draw a horizontal line.
  ///
  /// [x1] - Start X position
  /// [x2] - End X position
  /// [y] - Y position
  /// [color] - Line color in ARGB format
  void hLine(int x1, int x2, int y, int color) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'guiHLine',
      '(JIIII)V',
      [_screenId, x1, x2, y, color],
    );
  }

  /// Draw a vertical line.
  ///
  /// [x] - X position
  /// [y1] - Start Y position
  /// [y2] - End Y position
  /// [color] - Line color in ARGB format
  void vLine(int x, int y1, int y2, int color) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'guiVLine',
      '(JIIII)V',
      [_screenId, x, y1, y2, color],
    );
  }

  /// Draw a rectangle outline (border).
  ///
  /// [x], [y] - Top-left corner
  /// [width], [height] - Size of the rectangle
  /// [color] - Border color in ARGB format
  void renderOutline(int x, int y, int width, int height, int color) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'guiRenderOutline',
      '(JIIIII)V',
      [_screenId, x, y, width, height, color],
    );
  }

  // ===========================================================================
  // Texture Drawing
  // ===========================================================================

  /// Draw a texture (blit) at the specified position.
  ///
  /// [texture] - The texture resource location (e.g., "minecraft:textures/gui/widgets.png")
  /// [x], [y] - Screen position to draw at
  /// [width], [height] - Size to draw
  /// [u], [v] - Texture UV coordinates (0.0-1.0 normalized)
  /// [uWidth], [vHeight] - Size in texture UV space (0.0-1.0 normalized)
  ///
  /// Example:
  /// ```dart
  /// // Draw a button texture
  /// graphics.blit(
  ///   'minecraft:textures/gui/widgets.png',
  ///   x, y, 80, 20,
  ///   0.0, 66/256, 200/256, 20/256,
  /// );
  /// ```
  void blit(
    String texture,
    int x,
    int y,
    int width,
    int height,
    double u,
    double v,
    double uWidth,
    double vHeight,
  ) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'guiBlit',
      '(JLjava/lang/String;IIIIFFFF)V',
      [_screenId, texture, x, y, width, height, u, v, uWidth, vHeight],
    );
  }

  /// Draw a sprite from Minecraft's GUI sprite atlas.
  ///
  /// This is the proper way to render slot backgrounds and other standard MC GUI elements.
  /// Uses Minecraft's built-in sprite system for pixel-perfect rendering.
  ///
  /// [sprite] - The sprite identifier (e.g., "container/slot", "container/furnace/burn_progress")
  /// [x], [y] - Screen position to draw at
  /// [width], [height] - Size to draw
  ///
  /// Example:
  /// ```dart
  /// // Draw a slot background using MC's native sprite
  /// graphics.blitSprite('container/slot', slotX, slotY, 18, 18);
  ///
  /// // Draw a furnace burn progress arrow
  /// graphics.blitSprite('container/furnace/burn_progress', x, y, 14, 14);
  /// ```
  void blitSprite(String sprite, int x, int y, int width, int height) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'guiBlitSprite',
      '(JLjava/lang/String;IIII)V',
      [_screenId, sprite, x, y, width, height],
    );
  }

  /// Draw a texture using pixel-based UV coordinates (convenience method).
  ///
  /// [texture] - The texture resource location
  /// [x], [y] - Screen position to draw at
  /// [width], [height] - Size to draw
  /// [u], [v] - Texture UV coordinates in pixels
  /// [regionWidth], [regionHeight] - Region size in pixels
  /// [textureWidth], [textureHeight] - Total texture size (default: 256x256)
  void blitPixels(
    String texture,
    int x,
    int y,
    int width,
    int height,
    int u,
    int v,
    int regionWidth,
    int regionHeight, {
    int textureWidth = 256,
    int textureHeight = 256,
  }) {
    blit(
      texture,
      x,
      y,
      width,
      height,
      u / textureWidth,
      v / textureHeight,
      regionWidth / textureWidth,
      regionHeight / textureHeight,
    );
  }

  // ===========================================================================
  // Minecraft-Style UI Helpers
  // ===========================================================================

  /// Draw a Minecraft-style panel background (like inventory windows).
  ///
  /// Uses the standard gray with beveled edges look from vanilla Minecraft GUIs.
  ///
  /// [x], [y] - Top-left corner position
  /// [width], [height] - Size of the panel
  ///
  /// Example:
  /// ```dart
  /// // Draw a centered panel
  /// final panelX = (screenWidth - 200) ~/ 2;
  /// final panelY = (screenHeight - 150) ~/ 2;
  /// graphics.drawPanel(panelX, panelY, 200, 150);
  /// ```
  void drawPanel(int x, int y, int width, int height) {
    // Main background (Minecraft standard gray)
    fill(x, y, x + width, y + height, 0xFFC6C6C6);

    // Top and left edges (lighter - highlight)
    hLine(x, x + width - 1, y, 0xFFFFFFFF);
    vLine(x, y, y + height - 1, 0xFFFFFFFF);

    // Bottom and right edges (darker - shadow)
    hLine(x, x + width, y + height - 1, 0xFF555555);
    vLine(x + width - 1, y, y + height, 0xFF555555);

    // Inner shadow (top-left)
    hLine(x + 1, x + width - 2, y + 1, 0xFFDBDBDB);
    vLine(x + 1, y + 1, y + height - 2, 0xFFDBDBDB);

    // Inner highlight (bottom-right)
    hLine(x + 1, x + width - 1, y + height - 2, 0xFF8B8B8B);
    vLine(x + width - 2, y + 1, y + height - 1, 0xFF8B8B8B);
  }

  /// Draw a Minecraft-style item slot (18x18) using the native MC sprite.
  ///
  /// Renders a slot that looks exactly like the inventory slots in vanilla Minecraft
  /// by using the game's built-in slot sprite.
  ///
  /// [x], [y] - Top-left corner position of the slot
  ///
  /// Example:
  /// ```dart
  /// // Draw a row of 9 inventory slots
  /// for (var i = 0; i < 9; i++) {
  ///   graphics.drawSlot(startX + i * 18, startY);
  /// }
  /// ```
  void drawSlot(int x, int y) {
    blitSprite('container/slot', x, y, 18, 18);
  }

  /// Draw a Minecraft-style item slot (18x18) using programmatic drawing.
  ///
  /// Use this if sprite rendering isn't working. For pixel-perfect native look,
  /// use [drawSlot] instead.
  void drawSlotProgrammatic(int x, int y) {
    const slotSize = 18;

    // Outer border (dark gray)
    fill(x, y, x + slotSize, y + slotSize, 0xFF8B8B8B);

    // Inner area (dark background)
    fill(x + 1, y + 1, x + slotSize - 1, y + slotSize - 1, 0xFF373737);

    // Top and left inner edges (shadow - darker)
    hLine(x + 1, x + slotSize - 1, y + 1, 0xFF373737);
    vLine(x + 1, y + 1, y + slotSize - 1, 0xFF373737);

    // Bottom and right inner edges (highlight)
    hLine(x + 1, x + slotSize - 1, y + slotSize - 2, 0xFFFFFFFF);
    vLine(x + slotSize - 2, y + 1, y + slotSize - 1, 0xFFFFFFFF);
  }

  /// Draw a Minecraft-style button.
  ///
  /// Renders a button with the classic Minecraft look, including hover and
  /// disabled states.
  ///
  /// [x], [y] - Top-left corner position
  /// [width], [height] - Size of the button
  /// [text] - Text to display centered on the button
  /// [hovered] - Whether the mouse is hovering over the button
  /// [disabled] - Whether the button is disabled (grayed out)
  ///
  /// Example:
  /// ```dart
  /// final isHovered = mouseX >= btnX && mouseX < btnX + 80 &&
  ///                   mouseY >= btnY && mouseY < btnY + 20;
  /// graphics.drawButton(btnX, btnY, 80, 20, 'Click Me', hovered: isHovered);
  /// ```
  void drawButton(
    int x,
    int y,
    int width,
    int height,
    String text, {
    bool hovered = false,
    bool disabled = false,
  }) {
    final baseColor =
        disabled ? 0xFFA0A0A0 : (hovered ? 0xFF7090FF : 0xFF606060);
    final topColor =
        disabled ? 0xFFC0C0C0 : (hovered ? 0xFFA0C0FF : 0xFF909090);
    final bottomColor =
        disabled ? 0xFF808080 : (hovered ? 0xFF5070D0 : 0xFF404040);

    // Main button body
    fill(x, y, x + width, y + height, baseColor);

    // Top edge (lighter)
    hLine(x, x + width - 1, y, topColor);
    hLine(x + 1, x + width - 2, y + 1, topColor);

    // Left edge (lighter)
    vLine(x, y, y + height - 1, topColor);
    vLine(x + 1, y + 1, y + height - 2, topColor);

    // Bottom edge (darker)
    hLine(x, x + width, y + height - 1, bottomColor);
    hLine(x + 1, x + width - 1, y + height - 2, bottomColor);

    // Right edge (darker)
    vLine(x + width - 1, y, y + height, bottomColor);
    vLine(x + width - 2, y + 1, y + height - 1, bottomColor);

    // Outer border
    renderOutline(x, y, width, height, 0xFF000000);

    // Text (centered)
    final textColor = disabled ? 0xFF606060 : 0xFFFFFFFF;
    drawCenteredString(text, x + width ~/ 2, y + (height - 8) ~/ 2,
        color: textColor);
  }

  /// Draw a title bar at the top of a panel.
  ///
  /// Renders a darker area suitable for displaying a window title.
  ///
  /// [x], [y] - Position of the panel (same as drawPanel)
  /// [width] - Width of the panel
  /// [title] - Title text to display
  ///
  /// Example:
  /// ```dart
  /// graphics.drawPanel(panelX, panelY, 200, 150);
  /// graphics.drawTitleBar(panelX, panelY, 200, 'Inventory');
  /// ```
  void drawTitleBar(int x, int y, int width, String title) {
    // Dark title area
    fill(x + 3, y + 3, x + width - 3, y + 14, 0xFF373737);

    // Title text (centered, darker color for contrast)
    drawCenteredString(title, x + width ~/ 2, y + 5, color: 0xFF404040);
  }

  /// Draw a horizontal separator line.
  ///
  /// Creates a two-tone line that looks recessed into the panel.
  ///
  /// [x] - Left edge position
  /// [y] - Y position
  /// [width] - Width of the separator
  ///
  /// Example:
  /// ```dart
  /// graphics.drawSeparator(panelX + 7, panelY + 20, panelWidth - 14);
  /// ```
  void drawSeparator(int x, int y, int width) {
    hLine(x, x + width, y, 0xFF373737);
    hLine(x, x + width, y + 1, 0xFFFFFFFF);
  }

  /// Draw a progress bar.
  ///
  /// Renders a horizontal progress bar with customizable colors.
  ///
  /// [x], [y] - Top-left corner position
  /// [width], [height] - Size of the progress bar
  /// [progress] - Fill amount from 0.0 (empty) to 1.0 (full)
  /// [fillColor] - Color of the filled portion (default: green)
  /// [bgColor] - Color of the background (default: dark gray)
  ///
  /// Example:
  /// ```dart
  /// // Draw a health bar
  /// graphics.drawProgressBar(
  ///   10, 10, 100, 12,
  ///   player.health / player.maxHealth,
  ///   fillColor: 0xFFAA0000,
  /// );
  /// ```
  void drawProgressBar(
    int x,
    int y,
    int width,
    int height,
    double progress, {
    int fillColor = 0xFF00AA00,
    int bgColor = 0xFF555555,
  }) {
    // Background
    fill(x, y, x + width, y + height, bgColor);

    // Border
    renderOutline(x, y, width, height, 0xFF000000);

    // Fill
    final fillWidth = ((width - 2) * progress.clamp(0.0, 1.0)).toInt();
    if (fillWidth > 0) {
      fill(x + 1, y + 1, x + 1 + fillWidth, y + height - 1, fillColor);
    }
  }

  /// Draw a tooltip-style background (dark with purple border).
  ///
  /// Renders the characteristic Minecraft tooltip background with its
  /// semi-transparent dark fill and purple gradient border.
  ///
  /// [x], [y] - Top-left corner position
  /// [width], [height] - Size of the tooltip
  ///
  /// Example:
  /// ```dart
  /// graphics.drawTooltipBackground(mouseX + 12, mouseY - 12, 150, 40);
  /// graphics.drawString('Item Name', mouseX + 16, mouseY - 8);
  /// ```
  void drawTooltipBackground(int x, int y, int width, int height) {
    // Main background (semi-transparent dark)
    fill(x, y, x + width, y + height, 0xF0100010);

    // Purple border (Minecraft tooltip style)
    renderOutline(x, y, width, height, 0xFF5000FF);
    renderOutline(x + 1, y + 1, width - 2, height - 2, 0xFF28007F);
  }

  /// Draw a checkbox.
  ///
  /// Renders a small checkbox that can be checked or unchecked.
  ///
  /// [x], [y] - Top-left corner position
  /// [checked] - Whether the checkbox is checked
  /// [hovered] - Whether the mouse is hovering over the checkbox
  ///
  /// Example:
  /// ```dart
  /// final checkboxHovered = mouseX >= cbX && mouseX < cbX + 11 &&
  ///                         mouseY >= cbY && mouseY < cbY + 11;
  /// graphics.drawCheckbox(cbX, cbY, isEnabled, hovered: checkboxHovered);
  /// graphics.drawString('Enable feature', cbX + 14, cbY + 2);
  /// ```
  void drawCheckbox(int x, int y, bool checked, {bool hovered = false}) {
    const size = 11;

    // Background
    fill(x, y, x + size, y + size, hovered ? 0xFFA0A0A0 : 0xFF606060);

    // Border
    renderOutline(x, y, size, size, 0xFF000000);

    // Inner area
    fill(x + 1, y + 1, x + size - 1, y + size - 1, 0xFF202020);

    // Checkmark (draw a simple checkmark shape when checked)
    if (checked) {
      hLine(x + 2, x + 4, y + 5, 0xFFFFFFFF);
      hLine(x + 3, x + 5, y + 6, 0xFFFFFFFF);
      hLine(x + 4, x + 6, y + 7, 0xFFFFFFFF);
      hLine(x + 5, x + 8, y + 6, 0xFFFFFFFF);
      hLine(x + 6, x + 9, y + 5, 0xFFFFFFFF);
      hLine(x + 7, x + 9, y + 4, 0xFFFFFFFF);
      hLine(x + 8, x + 9, y + 3, 0xFFFFFFFF);
    }
  }
}

// ===========================================================================
// Color Utilities
// ===========================================================================

/// Utility class for color manipulation.
class McColors {
  McColors._();

  /// Create a color from ARGB components (0-255 each).
  static int argb(int a, int r, int g, int b) {
    return ((a & 0xFF) << 24) |
        ((r & 0xFF) << 16) |
        ((g & 0xFF) << 8) |
        (b & 0xFF);
  }

  /// Create a color from RGB components with full opacity.
  static int rgb(int r, int g, int b) => argb(255, r, g, b);

  /// Create a color with modified alpha.
  static int withAlpha(int color, int alpha) {
    return (color & 0x00FFFFFF) | ((alpha & 0xFF) << 24);
  }

  // Common colors
  static const int white = 0xFFFFFFFF;
  static const int black = 0xFF000000;
  static const int red = 0xFFFF0000;
  static const int green = 0xFF00FF00;
  static const int blue = 0xFF0000FF;
  static const int yellow = 0xFFFFFF00;
  static const int cyan = 0xFF00FFFF;
  static const int magenta = 0xFFFF00FF;

  // Minecraft colors (vanilla text colors)
  static const int mcBlack = 0xFF000000;
  static const int mcDarkBlue = 0xFF0000AA;
  static const int mcDarkGreen = 0xFF00AA00;
  static const int mcDarkAqua = 0xFF00AAAA;
  static const int mcDarkRed = 0xFFAA0000;
  static const int mcDarkPurple = 0xFFAA00AA;
  static const int mcGold = 0xFFFFAA00;
  static const int mcGray = 0xFFAAAAAA;
  static const int mcDarkGray = 0xFF555555;
  static const int mcBlue = 0xFF5555FF;
  static const int mcGreen = 0xFF55FF55;
  static const int mcAqua = 0xFF55FFFF;
  static const int mcRed = 0xFFFF5555;
  static const int mcLightPurple = 0xFFFF55FF;
  static const int mcYellow = 0xFFFFFF55;
  static const int mcWhite = 0xFFFFFFFF;
}
