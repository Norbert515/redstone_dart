import 'package:flutter/widgets.dart';
import 'mc_colors.dart';

/// Minecraft UI dimension and spacing constants.
///
/// All measurements are in pixels at GUI scale 1x.
abstract final class McSizes {
  // ============================================================================
  // Button Dimensions
  // ============================================================================

  /// Small button width
  static const double buttonSmallWidth = 120;

  /// Default button width
  static const double buttonDefaultWidth = 150;

  /// Big button width
  static const double buttonBigWidth = 200;

  /// Standard button height
  static const double buttonHeight = 20;

  /// Default spacing between buttons
  static const double buttonSpacing = 8;

  /// Button text margin from edges
  static const double buttonTextMargin = 2;

  /// Button border width
  static const double buttonBorderWidth = 2;

  // ============================================================================
  // Slot Dimensions
  // ============================================================================

  /// Outer slot size (including border)
  static const double slotSize = 18;

  /// Inner item area (without border)
  static const double itemSize = 16;

  /// Slot border width
  static const double slotBorderWidth = 1;

  /// Slot highlight overlay size (extends beyond slot)
  static const double slotHighlightSize = 24;

  /// Slot highlight offset from slot position
  static const double slotHighlightOffset = 4;

  // ============================================================================
  // Text Field Dimensions
  // ============================================================================

  /// Text field inner padding (when bordered)
  static const double textFieldPadding = 4;

  /// Text field border width
  static const double textFieldBorderWidth = 4;

  /// Cursor width (vertical line)
  static const double cursorWidth = 1;

  /// Cursor blink interval in milliseconds
  static const int cursorBlinkIntervalMs = 300;

  // ============================================================================
  // Checkbox Dimensions
  // ============================================================================

  /// Checkbox box size
  static const double checkboxSize = 17;

  /// Spacing between checkbox and label
  static const double checkboxSpacing = 4;

  /// Checkbox padding
  static const double checkboxPadding = 8;

  // ============================================================================
  // Slider Dimensions
  // ============================================================================

  /// Slider height
  static const double sliderHeight = 20;

  /// Slider handle width
  static const double sliderHandleWidth = 8;

  /// Slider text margin
  static const double sliderTextMargin = 2;

  // ============================================================================
  // Tab Dimensions
  // ============================================================================

  /// Selected tab extends down by this amount
  static const double tabSelectedOffset = 3;

  /// Tab text margin
  static const double tabTextMargin = 1;

  /// Tab underline height
  static const double tabUnderlineHeight = 1;

  /// Tab underline horizontal margin
  static const double tabUnderlineMarginX = 4;

  /// Tab underline bottom margin
  static const double tabUnderlineMarginBottom = 2;

  // ============================================================================
  // Scrollbar Dimensions
  // ============================================================================

  /// Scrollbar width
  static const double scrollbarWidth = 6;

  /// Minimum scroller height
  static const double scrollerMinHeight = 32;

  /// Maximum scroller inset from edges
  static const double scrollerMaxInset = 8;

  /// Separator height (top/bottom)
  static const double separatorHeight = 2;

  // ============================================================================
  // Tooltip Dimensions
  // ============================================================================

  /// Tooltip offset from cursor
  static const double tooltipMouseOffset = 12;

  /// Tooltip padding (all sides)
  static const double tooltipPadding = 3;

  /// Tooltip outer margin
  static const double tooltipMargin = 9;

  /// Extra space after first tooltip line
  static const double tooltipFirstLineExtraSpace = 2;

  // ============================================================================
  // Screen/Container Dimensions
  // ============================================================================

  /// Standard inventory screen width
  static const double inventoryWidth = 176;

  /// Standard inventory screen height
  static const double inventoryHeight = 166;

  /// Background texture dimensions
  static const double backgroundTextureSize = 256;

  /// Row height in containers
  static const double rowHeight = 18;

  /// Player inventory section height
  static const double inventorySectionHeight = 114;

  /// Title label X position
  static const double titleLabelX = 8;

  /// Title label Y position
  static const double titleLabelY = 6;

  /// Inventory label X position
  static const double inventoryLabelX = 8;

  // ============================================================================
  // Panel Dimensions
  // ============================================================================

  /// Panel border width
  static const double panelBorderWidth = 3;

  /// Panel corner radius (for rounded variant)
  static const double panelCornerRadius = 4;

  /// Panel padding
  static const double panelPadding = 8;
}

/// Typography constants for Minecraft UI.
abstract final class McTypography {
  /// Base font height (Minecraft bitmap font)
  static const double fontHeight = 8;

  /// Line height (font height + spacing)
  static const double lineHeight = 9;

  /// Text shadow offset
  static const double shadowOffset = 1;

  /// Default text style with shadow
  static TextStyle get textDefault => const TextStyle(
        fontFamily: 'Minecraft', // Requires Minecraft font asset
        fontSize: fontHeight,
        height: lineHeight / fontHeight,
        color: McColors.white,
        shadows: [
          Shadow(
            color: McColors.black,
            offset: Offset(shadowOffset, shadowOffset),
          ),
        ],
      );

  /// Label text style (no shadow, dark gray)
  static TextStyle get textLabel => const TextStyle(
        fontFamily: 'Minecraft',
        fontSize: fontHeight,
        height: lineHeight / fontHeight,
        color: McColors.darkGray,
      );

  /// Disabled text style
  static TextStyle get textDisabled => const TextStyle(
        fontFamily: 'Minecraft',
        fontSize: fontHeight,
        height: lineHeight / fontHeight,
        color: McColors.lightGray,
        shadows: [
          Shadow(
            color: McColors.black,
            offset: Offset(shadowOffset, shadowOffset),
          ),
        ],
      );
}

/// Theme data for Minecraft UI widgets.
class McTheme extends InheritedWidget {
  /// The GUI scale factor (1x, 2x, 3x, 4x, Auto)
  final double guiScale;

  /// Whether to use high-resolution textures
  final bool useHighResTextures;

  const McTheme({
    super.key,
    required super.child,
    this.guiScale = 2.0,
    this.useHighResTextures = false,
  });

  /// Get the nearest McTheme from the widget tree.
  static McTheme? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<McTheme>();
  }

  /// Get GUI scale, falling back to default if not in tree.
  static double scaleOf(BuildContext context) {
    return of(context)?.guiScale ?? 2.0;
  }

  @override
  bool updateShouldNotify(McTheme oldWidget) {
    return guiScale != oldWidget.guiScale ||
        useHighResTextures != oldWidget.useHighResTextures;
  }
}
