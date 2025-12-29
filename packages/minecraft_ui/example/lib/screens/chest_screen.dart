import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

/// Recreates the Minecraft Chest GUI
class ChestScreen extends StatefulWidget {
  const ChestScreen({super.key});

  @override
  State<ChestScreen> createState() => _ChestScreenState();
}

class _ChestScreenState extends State<ChestScreen> {
  // 27 chest slots (3 rows) + 36 player inventory
  final List<_ChestItem?> _chestSlots = List.generate(27, (_) => null);
  final List<_ChestItem?> _playerInventory = List.generate(36, (_) => null);

  @override
  void initState() {
    super.initState();
    // Pre-populate some chest items for demo
    _chestSlots[0] = _ChestItem(McColors.formatGold, 64, 'Gold Ingot');
    _chestSlots[1] = _ChestItem(McColors.formatDarkAqua, 32, 'Diamond');
    _chestSlots[4] = _ChestItem(McColors.formatRed, 16, 'Redstone');
    _chestSlots[9] = _ChestItem(McColors.formatGreen, 48, 'Emerald');
    _chestSlots[13] = _ChestItem(McColors.formatLightPurple, 8, 'Enchanted Book');

    // Player inventory
    _playerInventory[27] = _ChestItem(McColors.formatGray, 64, 'Cobblestone');
    _playerInventory[28] = _ChestItem(McColors.formatGold.withValues(alpha: 0.7), 32, 'Oak Planks');
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

              // Main chest UI
              Center(
                child: McPanel(
                  width: 176,
                  height: 168,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 6),
                        child: McText.title('Chest'),
                      ),

                      const SizedBox(height: 4),

                      // Chest slots (3 rows of 9)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildChestGrid(),
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

  Widget _buildChestGrid() {
    return Column(
      children: [
        for (int row = 0; row < 3; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int col = 0; col < 9; col++)
                _buildSlot(_chestSlots, row * 9 + col),
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
                _buildSlot(_playerInventory, row * 9 + col),
            ],
          ),

        const SizedBox(height: 4),

        // Hotbar (1 row of 9)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int col = 0; col < 9; col++)
              _buildSlot(_playerInventory, 27 + col),
          ],
        ),
      ],
    );
  }

  Widget _buildSlot(List<_ChestItem?> slots, int index) {
    final item = slots[index];
    return McSlot(
      item: item != null
          ? Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          : null,
      count: item?.count,
      onTap: () {
        setState(() {
          if (item != null) {
            slots[index] = null;
          } else {
            slots[index] = _ChestItem(
              McColors.formatBlue,
              1,
              'New Item',
            );
          }
        });
      },
    );
  }
}

class _ChestItem {
  final Color color;
  final int count;
  final String name;

  _ChestItem(this.color, this.count, this.name);
}
