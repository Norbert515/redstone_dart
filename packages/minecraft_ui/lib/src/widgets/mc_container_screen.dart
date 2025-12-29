import 'package:flutter/widgets.dart';
import '../theme/mc_theme.dart';
import 'mc_panel.dart';
import 'mc_text.dart';

/// A Minecraft-style container screen layout.
///
/// This provides the standard layout for inventory-style screens with
/// a title, content area, and player inventory section.
class McContainerScreen extends StatelessWidget {
  /// The screen title.
  final String title;

  /// The main content widget (crafting grid, chest slots, etc.)
  final Widget content;

  /// Optional player inventory widget.
  final Widget? playerInventory;

  /// Screen width (defaults to standard inventory width).
  final double width;

  /// Screen height (defaults to standard inventory height).
  final double height;

  /// Called when the screen should close.
  final VoidCallback? onClose;

  const McContainerScreen({
    super.key,
    required this.title,
    required this.content,
    this.playerInventory,
    this.width = McSizes.inventoryWidth,
    this.height = McSizes.inventoryHeight,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);

    return Center(
      child: McPanel(
        width: width,
        height: height,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: EdgeInsets.only(
                left: McSizes.titleLabelX * scale,
                top: McSizes.titleLabelY * scale,
              ),
              child: McText.title(title),
            ),

            // Main content area
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(8 * scale),
                child: content,
              ),
            ),

            // Player inventory (if provided)
            if (playerInventory != null) ...[
              Padding(
                padding: EdgeInsets.only(
                  left: McSizes.inventoryLabelX * scale,
                  bottom: 2 * scale,
                ),
                child: const McText.label('Inventory'),
              ),
              Padding(
                padding: EdgeInsets.all(8 * scale),
                child: playerInventory,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A standard player inventory layout (3x9 main + 1x9 hotbar).
class McPlayerInventory extends StatelessWidget {
  /// The inventory slots (should be 36 slots total).
  final List<Widget> slots;

  /// Called when a slot is clicked.
  final void Function(int index)? onSlotTap;

  const McPlayerInventory({
    super.key,
    required this.slots,
    this.onSlotTap,
  }) : assert(slots.length == 36, 'Player inventory must have 36 slots');

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final slotSize = McSizes.slotSize * scale;

    return Column(
      children: [
        // Main inventory (3 rows of 9)
        for (int row = 0; row < 3; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int col = 0; col < 9; col++)
                SizedBox(
                  width: slotSize,
                  height: slotSize,
                  child: slots[row * 9 + col],
                ),
            ],
          ),

        SizedBox(height: 4 * scale),

        // Hotbar (1 row of 9)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int col = 0; col < 9; col++)
              SizedBox(
                width: slotSize,
                height: slotSize,
                child: slots[27 + col],
              ),
          ],
        ),
      ],
    );
  }
}
