import 'dart:ui';

/// Minecraft color constants extracted from the game's source code.
///
/// These colors match the exact values used in Minecraft's Java GUI implementation.
/// Colors are specified in ARGB format.
abstract final class McColors {
  // ============================================================================
  // Common Colors (from CommonColors.java)
  // ============================================================================

  /// Pure white - default text, active elements
  static const Color white = Color(0xFFFFFFFF);

  /// Pure black - backgrounds, outlines
  static const Color black = Color(0xFF000000);

  /// Standard gray - suggestions, secondary text
  static const Color gray = Color(0xFF808080);

  /// Dark gray - title labels in inventory screens
  static const Color darkGray = Color(0xFF404040);

  /// Light gray - inactive/disabled text
  static const Color lightGray = Color(0xFFA0A0A0);

  /// Lighter gray - subtle elements
  static const Color lighterGray = Color(0xFFBABABA);

  /// Red - errors, warnings
  static const Color red = Color(0xFFFF0000);

  /// Soft red - soft warnings
  static const Color softRed = Color(0xFFDF6F6F);

  /// Green - success indicators
  static const Color green = Color(0xFF00FF00);

  /// Blue - links, text highlight
  static const Color blue = Color(0xFF0000FF);

  /// Yellow - highlights, max stack count
  static const Color yellow = Color(0xFFFFFF00);

  // ============================================================================
  // Text Colors
  // ============================================================================

  /// Default text color in edit boxes
  static const Color textDefault = Color(0xFFE0E0E0);

  /// Uneditable/disabled text color
  static const Color textUneditable = Color(0xFF6F6F6F);

  /// Text selection/highlight background
  static const Color textHighlight = Color(0xFF0000FF);

  /// Suggestion text color (command suggestions)
  static const Color textSuggestion = Color(0xFF808080);

  /// Cursor color in multi-line edit boxes
  static const Color cursor = Color(0xFFD0D0D0);

  // ============================================================================
  // Widget State Colors
  // ============================================================================

  /// Selection border when focused
  static const Color selectionFocused = Color(0xFFFFFFFF);

  /// Selection border when unfocused
  static const Color selectionUnfocused = Color(0xFF808080);

  /// Active tab text color
  static const Color tabActive = Color(0xFFFFFFFF);

  /// Inactive tab text color
  static const Color tabInactive = Color(0xFFA0A0A0);

  // ============================================================================
  // Screen Background Colors
  // ============================================================================

  /// Transparent overlay top color (renderTransparentBackground)
  /// 75% opacity dark
  static const Color transparentOverlayTop = Color(0xC0101010);

  /// Transparent overlay bottom color (gradient)
  /// 81% opacity dark
  static const Color transparentOverlayBottom = Color(0xD0101010);

  // ============================================================================
  // Panel Colors (Minecraft's standard GUI panel colors)
  // ============================================================================

  /// Standard panel background (light gray)
  static const Color panelBackground = Color(0xFFC6C6C6);

  /// Panel border dark (bottom-right edges for 3D effect)
  static const Color panelBorderDark = Color(0xFF373737);

  /// Panel border light (top-left edges for 3D effect)
  static const Color panelBorderLight = Color(0xFFFFFFFF);

  /// Slot background color (darker gray)
  static const Color slotBackground = Color(0xFF8B8B8B);

  /// Slot border dark
  static const Color slotBorderDark = Color(0xFF373737);

  /// Slot border light
  static const Color slotBorderLight = Color(0xFFFFFFFF);

  // ============================================================================
  // Button Colors
  // ============================================================================

  /// Button gradient top (normal state)
  static const Color buttonTopNormal = Color(0xFF7F7F7F);

  /// Button gradient bottom (normal state)
  static const Color buttonBottomNormal = Color(0xFF5F5F5F);

  /// Button gradient top (hovered state)
  static const Color buttonTopHovered = Color(0xFF8F8FFF);

  /// Button gradient bottom (hovered state)
  static const Color buttonBottomHovered = Color(0xFF5F5FAF);

  /// Button gradient top (pressed state)
  static const Color buttonTopPressed = Color(0xFF5F5F5F);

  /// Button gradient bottom (pressed state)
  static const Color buttonBottomPressed = Color(0xFF7F7F7F);

  /// Button gradient top (disabled state)
  static const Color buttonTopDisabled = Color(0xFF404040);

  /// Button gradient bottom (disabled state)
  static const Color buttonBottomDisabled = Color(0xFF303030);

  /// Button border color
  static const Color buttonBorder = Color(0xFF373737);

  /// Button border color when pressed
  static const Color buttonBorderPressed = Color(0xFF1F1F1F);

  // ============================================================================
  // Tooltip Colors
  // ============================================================================

  /// Tooltip background (semi-transparent dark purple)
  static const Color tooltipBackground = Color(0xF0100010);

  /// Tooltip border outer
  static const Color tooltipBorderOuter = Color(0xFF000000);

  /// Tooltip border inner (purple gradient)
  static const Color tooltipBorderInner = Color(0xFF5000FF);

  // ============================================================================
  // Chat/Formatting Colors (Minecraft formatting codes)
  // ============================================================================

  /// §0 - Black
  static const Color formatBlack = Color(0xFF000000);

  /// §1 - Dark Blue
  static const Color formatDarkBlue = Color(0xFF0000AA);

  /// §2 - Dark Green
  static const Color formatDarkGreen = Color(0xFF00AA00);

  /// §3 - Dark Aqua
  static const Color formatDarkAqua = Color(0xFF00AAAA);

  /// §4 - Dark Red
  static const Color formatDarkRed = Color(0xFFAA0000);

  /// §5 - Dark Purple
  static const Color formatDarkPurple = Color(0xFFAA00AA);

  /// §6 - Gold
  static const Color formatGold = Color(0xFFFFAA00);

  /// §7 - Gray
  static const Color formatGray = Color(0xFFAAAAAA);

  /// §8 - Dark Gray
  static const Color formatDarkGray = Color(0xFF555555);

  /// §9 - Blue
  static const Color formatBlue = Color(0xFF5555FF);

  /// §a - Green
  static const Color formatGreen = Color(0xFF55FF55);

  /// §b - Aqua
  static const Color formatAqua = Color(0xFF55FFFF);

  /// §c - Red
  static const Color formatRed = Color(0xFFFF5555);

  /// §d - Light Purple
  static const Color formatLightPurple = Color(0xFFFF55FF);

  /// §e - Yellow
  static const Color formatYellow = Color(0xFFFFFF55);

  /// §f - White
  static const Color formatWhite = Color(0xFFFFFFFF);
}
