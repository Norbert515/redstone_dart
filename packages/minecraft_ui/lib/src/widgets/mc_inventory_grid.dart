import 'package:flutter/widgets.dart';
import '../theme/mc_theme.dart';
import 'mc_slot.dart';

/// A grid of inventory slots for crafting or storage.
class McInventoryGrid extends StatelessWidget {
  /// Number of rows in the grid.
  final int rows;

  /// Number of columns in the grid.
  final int columns;

  /// The slots in the grid (row-major order).
  final List<McSlot> slots;

  /// Spacing between slots (defaults to 0 for standard Minecraft look).
  final double spacing;

  const McInventoryGrid({
    super.key,
    required this.rows,
    required this.columns,
    required this.slots,
    this.spacing = 0,
  }) : assert(
          slots.length == rows * columns,
          'Slots length must match rows * columns',
        );

  /// Creates a 3x3 crafting grid.
  factory McInventoryGrid.crafting({
    Key? key,
    required List<McSlot> slots,
  }) {
    return McInventoryGrid(
      key: key,
      rows: 3,
      columns: 3,
      slots: slots,
    );
  }

  /// Creates a 2x2 crafting grid (player inventory crafting).
  factory McInventoryGrid.craftingSmall({
    Key? key,
    required List<McSlot> slots,
  }) {
    return McInventoryGrid(
      key: key,
      rows: 2,
      columns: 2,
      slots: slots,
    );
  }

  /// Creates a chest grid (3 rows for single chest, 6 for double).
  factory McInventoryGrid.chest({
    Key? key,
    required int rows,
    required List<McSlot> slots,
  }) {
    return McInventoryGrid(
      key: key,
      rows: rows,
      columns: 9,
      slots: slots,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final slotSize = McSizes.slotSize * scale;
    final effectiveSpacing = spacing * scale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int row = 0; row < rows; row++)
          Padding(
            padding: EdgeInsets.only(
              bottom: row < rows - 1 ? effectiveSpacing : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int col = 0; col < columns; col++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: col < columns - 1 ? effectiveSpacing : 0,
                    ),
                    child: SizedBox(
                      width: slotSize,
                      height: slotSize,
                      child: slots[row * columns + col],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A crafting table layout with input grid, arrow, and output slot.
class McCraftingLayout extends StatelessWidget {
  /// The 3x3 input grid slots.
  final List<McSlot> inputSlots;

  /// The output slot.
  final McSlot outputSlot;

  /// Progress of crafting (0.0 to 1.0).
  final double progress;

  const McCraftingLayout({
    super.key,
    required this.inputSlots,
    required this.outputSlot,
    this.progress = 0,
  }) : assert(inputSlots.length == 9, 'Crafting input must have 9 slots');

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final slotSize = McSizes.slotSize * scale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 3x3 crafting grid
        McInventoryGrid.crafting(slots: inputSlots),

        SizedBox(width: 8 * scale),

        // Arrow
        CustomPaint(
          painter: _CraftingArrowPainter(
            progress: progress,
            scale: scale,
          ),
          child: SizedBox(
            width: 24 * scale,
            height: 16 * scale,
          ),
        ),

        SizedBox(width: 8 * scale),

        // Output slot
        SizedBox(
          width: slotSize,
          height: slotSize,
          child: outputSlot,
        ),
      ],
    );
  }
}

class _CraftingArrowPainter extends CustomPainter {
  final double progress;
  final double scale;

  _CraftingArrowPainter({
    required this.progress,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF8B8B8B);

    // Background arrow
    final arrowPath = Path()
      ..moveTo(0, size.height * 0.3)
      ..lineTo(size.width * 0.6, size.height * 0.3)
      ..lineTo(size.width * 0.6, 0)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.6, size.height)
      ..lineTo(size.width * 0.6, size.height * 0.7)
      ..lineTo(0, size.height * 0.7)
      ..close();

    canvas.drawPath(arrowPath, paint);

    // Progress fill
    if (progress > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
      canvas.drawPath(arrowPath, Paint()..color = const Color(0xFFFFFFFF));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CraftingArrowPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
