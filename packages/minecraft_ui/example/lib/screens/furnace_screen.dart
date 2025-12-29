import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

/// Recreates the Minecraft Furnace GUI with animated progress
class FurnaceScreen extends StatefulWidget {
  const FurnaceScreen({super.key});

  @override
  State<FurnaceScreen> createState() => _FurnaceScreenState();
}

class _FurnaceScreenState extends State<FurnaceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Furnace state
  bool _isSmelting = false;
  double _cookProgress = 0.0;
  double _burnProgress = 0.0;

  // Slots
  bool _hasInputItem = true;
  bool _hasFuelItem = true;
  bool _hasOutputItem = false;
  int _outputCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_updateProgress);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    if (!_isSmelting) return;

    setState(() {
      // Burn progress decreases
      _burnProgress = 1.0 - (_animationController.value * 2).clamp(0.0, 1.0);

      // Cook progress increases
      _cookProgress = ((_animationController.value - 0.1) * 1.5).clamp(0.0, 1.0);

      // Complete smelting at 100%
      if (_cookProgress >= 1.0 && _hasInputItem) {
        _hasInputItem = false;
        _hasOutputItem = true;
        _outputCount++;
        _cookProgress = 0.0;

        // Check if we can continue smelting
        if (!_hasFuelItem) {
          _isSmelting = false;
          _animationController.stop();
        } else {
          _animationController.reset();
          _animationController.forward();
        }
      }
    });
  }

  void _toggleSmelting() {
    setState(() {
      if (_isSmelting) {
        _isSmelting = false;
        _animationController.stop();
      } else if (_hasInputItem && _hasFuelItem) {
        _isSmelting = true;
        _burnProgress = 1.0;
        _animationController.forward(from: 0);
      }
    });
  }

  void _refuel() {
    setState(() {
      _hasFuelItem = true;
      if (_hasInputItem && !_isSmelting) {
        _toggleSmelting();
      }
    });
  }

  void _addInput() {
    setState(() {
      _hasInputItem = true;
      if (_hasFuelItem && !_isSmelting) {
        _toggleSmelting();
      }
    });
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

              // Main furnace UI
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
                        child: McText.title('Furnace'),
                      ),

                      const SizedBox(height: 8),

                      // Furnace slots
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Input and fuel column
                            Column(
                              children: [
                                // Input slot
                                McSlot(
                                  item: _hasInputItem
                                      ? Container(
                                          margin: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: McColors.formatGray,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        )
                                      : null,
                                  onTap: _addInput,
                                ),
                                const SizedBox(height: 8),
                                // Fuel slot
                                McSlot(
                                  item: _hasFuelItem
                                      ? Container(
                                          margin: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: McColors.formatGold
                                                .withValues(alpha: 0.8),
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        )
                                      : null,
                                  onTap: _refuel,
                                ),
                              ],
                            ),

                            const SizedBox(width: 16),

                            // Progress indicators
                            Column(
                              children: [
                                // Burn indicator (flame)
                                McProgressBar.flame(
                                  progress: _burnProgress,
                                ),
                                const SizedBox(height: 4),
                                // Cook progress (arrow)
                                McProgressBar.arrow(
                                  progress: _cookProgress,
                                ),
                              ],
                            ),

                            const SizedBox(width: 16),

                            // Output slot
                            McSlot(
                              item: _hasOutputItem
                                  ? Container(
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: McColors.formatYellow,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    )
                                  : null,
                              count: _outputCount > 1 ? _outputCount : null,
                              onTap: () {
                                if (_hasOutputItem) {
                                  setState(() {
                                    _hasOutputItem = false;
                                    _outputCount = 0;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Status text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: McText(
                          _isSmelting
                              ? 'Smelting...'
                              : (_hasInputItem && _hasFuelItem
                                  ? 'Ready to smelt'
                                  : 'Add items to smelt'),
                          color: _isSmelting
                              ? McColors.formatGreen
                              : McColors.gray,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Player inventory label
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 2),
                        child: McText.label('Inventory'),
                      ),

                      // Player inventory (simplified)
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

  Widget _buildPlayerInventory() {
    return Column(
      children: [
        // Main inventory (3 rows of 9)
        for (int row = 0; row < 3; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int col = 0; col < 9; col++) const McSlot(),
            ],
          ),

        const SizedBox(height: 4),

        // Hotbar (1 row of 9)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int col = 0; col < 9; col++) const McSlot(),
          ],
        ),
      ],
    );
  }
}
