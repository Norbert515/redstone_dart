import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// A Minecraft-style tab bar.
class McTabBar extends StatelessWidget {
  /// The tabs to display.
  final List<McTab> tabs;

  /// Currently selected tab index.
  final int selectedIndex;

  /// Called when a tab is selected.
  final ValueChanged<int>? onTabSelected;

  const McTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < tabs.length; i++)
          _McTabButton(
            tab: tabs[i],
            isSelected: i == selectedIndex,
            onTap: onTabSelected != null ? () => onTabSelected!(i) : null,
          ),
      ],
    );
  }
}

/// A single tab in a Minecraft tab bar.
class McTab {
  /// The tab label.
  final String label;

  /// Optional icon widget.
  final Widget? icon;

  const McTab({
    required this.label,
    this.icon,
  });
}

class _McTabButton extends StatefulWidget {
  final McTab tab;
  final bool isSelected;
  final VoidCallback? onTap;

  const _McTabButton({
    required this.tab,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<_McTabButton> createState() => _McTabButtonState();
}

class _McTabButtonState extends State<_McTabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final padding = 8.0 * scale;
    final selectedOffset = McSizes.tabSelectedOffset * scale;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: EdgeInsets.only(
            bottom: widget.isSelected ? 0 : selectedOffset,
            top: widget.isSelected ? selectedOffset : 0,
          ),
          child: CustomPaint(
            painter: _McTabPainter(
              isSelected: widget.isSelected,
              isHovered: _isHovered,
              scale: scale,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: padding / 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.tab.icon != null) ...[
                    widget.tab.icon!,
                    SizedBox(width: 4 * scale),
                  ],
                  Text(
                    widget.tab.label,
                    style: TextStyle(
                      fontSize: McTypography.fontHeight * scale,
                      color: widget.isSelected ? McColors.tabActive : McColors.tabInactive,
                      shadows: [
                        Shadow(
                          color: McColors.black.withValues(alpha: 0.4),
                          offset: Offset(scale, scale),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _McTabPainter extends CustomPainter {
  final bool isSelected;
  final bool isHovered;
  final double scale;

  _McTabPainter({
    required this.isSelected,
    required this.isHovered,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgColor = isSelected
        ? McColors.panelBackground
        : (isHovered ? McColors.slotBackground : McColors.buttonTopDisabled);

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    // Border
    final borderPaint = Paint()
      ..color = McColors.slotBorderDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );

    // Underline for selected
    if (isSelected) {
      canvas.drawRect(
        Rect.fromLTWH(
          McSizes.tabUnderlineMarginX * scale,
          size.height - McSizes.tabUnderlineHeight * scale - McSizes.tabUnderlineMarginBottom * scale,
          size.width - McSizes.tabUnderlineMarginX * 2 * scale,
          McSizes.tabUnderlineHeight * scale,
        ),
        Paint()..color = McColors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_McTabPainter oldDelegate) {
    return isSelected != oldDelegate.isSelected ||
        isHovered != oldDelegate.isHovered;
  }
}
