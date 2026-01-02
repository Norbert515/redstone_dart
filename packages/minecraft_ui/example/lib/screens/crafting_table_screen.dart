import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

/// Recreates the Minecraft Crafting Table GUI
class CraftingTableScreen extends StatefulWidget {
  const CraftingTableScreen({super.key});

  @override
  State<CraftingTableScreen> createState() => _CraftingTableScreenState();
}

class _CraftingTableScreenState extends State<CraftingTableScreen> {
  // Simulated inventory - 9 crafting slots + 1 output + 36 player inventory
  final List<_ItemSlot> _craftingSlots = List.generate(9, (_) => _ItemSlot());
  final _ItemSlot _outputSlot = _ItemSlot();
  final List<_ItemSlot> _playerInventory = List.generate(36, (_) => _ItemSlot());

  @override
  void initState() {
    super.initState();
    // Pre-populate some slots for demo
    _playerInventory[0] = _ItemSlot(color: McColors.formatGray, count: 64); // Cobblestone
    _playerInventory[1] = _ItemSlot(color: McColors.formatGold, count: 32); // Gold
    _playerInventory[2] = _ItemSlot(color: McColors.formatDarkAqua, count: 16); // Diamond
    _playerInventory[3] = _ItemSlot(color: McColors.formatRed, count: 8); // Redstone
  }

  @override
  Widget build(BuildContext context) {
    return McTheme(
      guiScale: 2.0,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                McColors.transparentOverlayTop,
                McColors.transparentOverlayBottom,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Back button
              Positioned(
                top: 16,
                left: 16,
                child: McButton(
                  text: '< Back',
                  size: McButtonSize.small,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

              // Main crafting UI
              Center(
                child: McPanel(
                  width: 176,
                  height: 166,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 6),
                        child: McText.title('Crafting'),
                      ),

                      const SizedBox(height: 8),

                      // Crafting area
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            // 3x3 crafting grid
                            _buildCraftingGrid(),
                            const SizedBox(width: 8),

                            // Arrow
                            const _CraftingArrow(),
                            const SizedBox(width: 8),

                            // Output slot
                            _buildSlot(_outputSlot, isOutput: true),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Player inventory label
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 2),
                        child: McText.label('Inventory'),
                      ),

                      // Player inventory
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: _buildPlayerInventory(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCraftingGrid() {
    return Column(
      children: [
        for (int row = 0; row < 3; row++)
          Row(
            children: [
              for (int col = 0; col < 3; col++)
                _buildSlot(_craftingSlots[row * 3 + col]),
            ],
          ),
      ],
    );
  }

  Widget _buildPlayerInventory() {
    return Column(
      children: [
        // Main inventory (3 rows of 9)
        for (int row = 0; row < 3; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int col = 0; col < 9; col++)
                _buildSlot(_playerInventory[row * 9 + col]),
            ],
          ),

        const SizedBox(height: 4),

        // Hotbar (1 row of 9)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int col = 0; col < 9; col++)
              _buildSlot(_playerInventory[27 + col]),
          ],
        ),
      ],
    );
  }

  Widget _buildSlot(_ItemSlot slot, {bool isOutput = false}) {
    return McSlot(
      item: slot.hasItem
          ? Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: slot.color,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          : null,
      count: slot.count,
      onTap: () {
        setState(() {
          if (slot.hasItem) {
            // Remove item
            slot.color = null;
            slot.count = null;
          } else {
            // Add random item
            slot.color = McColors.formatGreen;
            slot.count = 1;
          }
        });
      },
    );
  }
}

/// Simple item slot data
class _ItemSlot {
  Color? color;
  int? count;

  _ItemSlot({this.color, this.count});

  bool get hasItem => color != null;
}

/// Crafting arrow with animation
class _CraftingArrow extends StatelessWidget {
  const _CraftingArrow();

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);

    return CustomPaint(
      painter: _ArrowPainter(scale: scale),
      child: SizedBox(
        width: 22 * scale,
        height: 15 * scale,
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final double scale;

  _ArrowPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = McColors.slotBackground;

    // Draw arrow shape
    final path = Path()
      ..moveTo(0, size.height * 0.3)
      ..lineTo(size.width * 0.65, size.height * 0.3)
      ..lineTo(size.width * 0.65, 0)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.65, size.height)
      ..lineTo(size.width * 0.65, size.height * 0.7)
      ..lineTo(0, size.height * 0.7)
      ..close();

    canvas.drawPath(path, paint);

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = McColors.slotBorderDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * scale,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}
