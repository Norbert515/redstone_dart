import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// A Minecraft-style inventory slot.
///
/// Slots are 18x18 pixels and can contain items, display highlights on hover,
/// and handle click interactions.
class McSlot extends StatefulWidget {
  /// The item widget to display in the slot (typically an item icon).
  final Widget? item;

  /// Item stack count (displayed in bottom-right).
  final int? count;

  /// Called when the slot is clicked.
  final VoidCallback? onTap;

  /// Called when the slot is right-clicked.
  final VoidCallback? onSecondaryTap;

  /// Whether the slot is enabled.
  final bool enabled;

  /// Whether to show the highlight effect.
  final bool showHighlight;

  /// Custom background color (null uses default).
  final Color? backgroundColor;

  const McSlot({
    super.key,
    this.item,
    this.count,
    this.onTap,
    this.onSecondaryTap,
    this.enabled = true,
    this.showHighlight = true,
    this.backgroundColor,
  });

  @override
  State<McSlot> createState() => _McSlotState();
}

class _McSlotState extends State<McSlot> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final size = McSizes.slotSize * scale;
    final itemSize = McSizes.itemSize * scale;
    final borderWidth = McSizes.slotBorderWidth * scale;

    return MouseRegion(
      onEnter: widget.enabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _isHovered = false) : null,
      cursor: widget.enabled && (widget.onTap != null || widget.onSecondaryTap != null)
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onSecondaryTap: widget.enabled ? widget.onSecondaryTap : null,
        child: CustomPaint(
          painter: _McSlotPainter(
            backgroundColor: widget.backgroundColor ?? McColors.slotBackground,
            borderWidth: borderWidth,
            isHovered: _isHovered && widget.showHighlight,
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                // Item centered in slot
                if (widget.item != null)
                  Positioned(
                    left: borderWidth,
                    top: borderWidth,
                    child: SizedBox(
                      width: itemSize,
                      height: itemSize,
                      child: widget.item,
                    ),
                  ),

                // Stack count
                if (widget.count != null && widget.count! > 1)
                  Positioned(
                    right: borderWidth + 1 * scale,
                    bottom: borderWidth + 1 * scale,
                    child: Text(
                      widget.count.toString(),
                      style: TextStyle(
                        fontSize: McTypography.fontHeight * scale * 0.8,
                        color: McColors.white,
                        shadows: [
                          Shadow(
                            color: McColors.black,
                            offset: Offset(scale, scale),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Highlight overlay
                if (_isHovered && widget.showHighlight)
                  Positioned.fill(
                    child: Container(
                      margin: EdgeInsets.all(borderWidth),
                      color: McColors.white.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _McSlotPainter extends CustomPainter {
  final Color backgroundColor;
  final double borderWidth;
  final bool isHovered;

  _McSlotPainter({
    required this.backgroundColor,
    required this.borderWidth,
    required this.isHovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw slot background with inset border (dark top-left, light bottom-right)
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Dark border (top and left) - creates inset look
    final darkPaint = Paint()..color = McColors.slotBorderDark;
    // Top
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, borderWidth),
      darkPaint,
    );
    // Left
    canvas.drawRect(
      Rect.fromLTWH(0, 0, borderWidth, size.height),
      darkPaint,
    );

    // Light border (bottom and right)
    final lightPaint = Paint()..color = McColors.slotBorderLight.withValues(alpha: 0.5);
    // Bottom
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - borderWidth, size.width, borderWidth),
      lightPaint,
    );
    // Right
    canvas.drawRect(
      Rect.fromLTWH(size.width - borderWidth, 0, borderWidth, size.height),
      lightPaint,
    );
  }

  @override
  bool shouldRepaint(_McSlotPainter oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        borderWidth != oldDelegate.borderWidth ||
        isHovered != oldDelegate.isHovered;
  }
}

/// A grid of inventory slots arranged in rows and columns.
class McSlotGrid extends StatelessWidget {
  /// Number of columns in the grid.
  final int columns;

  /// The slot widgets to display.
  final List<McSlot> slots;

  /// Spacing between slots.
  final double spacing;

  const McSlotGrid({
    super.key,
    required this.columns,
    required this.slots,
    this.spacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);

    return Wrap(
      spacing: spacing * scale,
      runSpacing: spacing * scale,
      children: slots,
    );
  }
}
