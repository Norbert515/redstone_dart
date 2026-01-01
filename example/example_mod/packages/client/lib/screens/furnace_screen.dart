import 'dart:async';

import 'package:dart_mod_client/dart_mod_client.dart';
import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

/// A Flutter-based furnace screen for the Example Furnace block entity.
///
/// This screen:
/// - Displays the 3 furnace slots (input, fuel, output)
/// - Shows burn progress (flame) and cooking progress (arrow)
/// - Reports slot positions to Java for item rendering
/// - Polls progress values from Java via JNI
class ExampleFurnaceScreen extends StatefulWidget {
  /// The menu ID associated with this container.
  final int menuId;

  const ExampleFurnaceScreen({super.key, required this.menuId});

  @override
  State<ExampleFurnaceScreen> createState() => _ExampleFurnaceScreenState();
}

class _ExampleFurnaceScreenState extends State<ExampleFurnaceScreen> {
  late Timer _refreshTimer;
  final _containerView = const ClientContainerView();

  // Progress values polled from Java
  double _litProgress = 0;
  double _burnProgress = 0;
  bool _isLit = false;

  @override
  void initState() {
    super.initState();
    // Poll progress values periodically (20 times per second = every 50ms)
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateProgress();
    });
  }

  void _updateProgress() {
    setState(() {
      _litProgress = _containerView.litProgress;
      _burnProgress = _containerView.burnProgress;
      _isLit = _containerView.isLit;
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SlotPositionScope(
        menuId: widget.menuId,
        child: Center(
          child: McPanel(
            width: 176,
            padding: const EdgeInsets.all(7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const McText.title('Example Furnace'),

                const SizedBox(height: 8),

                // Furnace slots and progress indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Input and fuel column
                    Column(
                      children: [
                        // Input slot (index 0)
                        SlotReporter(
                          slotIndex: 0,
                          child: const McSlot(),
                        ),
                        const SizedBox(height: 4),
                        // Flame indicator (fuel remaining)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: _isLit
                              ? Container(color: Colors.orange)
                              : Container(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        // Fuel slot (index 1)
                        SlotReporter(
                          slotIndex: 1,
                          child: const McSlot(),
                        ),
                      ],
                    ),

                    const SizedBox(width: 16),

                    // Arrow progress indicator
                    SizedBox(
                      width: 24,
                      height: 17,
                      child: Stack(
                        children: [
                          Container(color: Colors.grey.shade600),
                          FractionallySizedBox(
                            widthFactor: _burnProgress,
                            child: Container(color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Output slot (index 2)
                    SlotReporter(
                      slotIndex: 2,
                      child: const McSlot(),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Player inventory label
                const McText.label('Inventory'),
                const SizedBox(height: 2),

                // Player inventory (3 rows x 9 columns)
                // Slots 3-29 are player main inventory
                for (int row = 0; row < 3; row++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int col = 0; col < 9; col++)
                        SlotReporter(
                          slotIndex: 3 + row * 9 + col,
                          child: const McSlot(),
                        ),
                    ],
                  ),

                const SizedBox(height: 4),

                // Player hotbar (1 row x 9 columns)
                // Slots 30-38 are hotbar
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int col = 0; col < 9; col++)
                      SlotReporter(
                        slotIndex: 30 + col,
                        child: const McSlot(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
