/// Example container screen demonstrating the Container GUI API.
///
/// This file shows how to create a custom container screen using Dart.
/// Container screens are special screens that:
/// - Have real inventory slots managed by Minecraft
/// - Support item drag-drop, shift-click transfers
/// - Automatically sync items between client and server
///
/// ## Usage
/// This screen is opened by right-clicking the DartContainerBlock.
/// It demonstrates:
/// - Drawing a custom background panel
/// - Adding container slots in a 3x3 grid
/// - Adding player inventory slots
/// - Rendering text and labels
///
/// ## Initialization
/// Call [initDemoContainerScreen] during mod initialization to register
/// the screen factory.
library;

import '../api/gui/gui.dart';
import '../api/gui/container_screen.dart';

/// Example container screen with a 3x3 grid of slots.
///
/// This screen demonstrates the Container GUI API by creating
/// a simple chest-like interface with 9 container slots arranged
/// in a 3x3 grid.
class DemoContainerScreen extends ContainerScreen {
  /// Create a new demo container screen.
  ///
  /// The screen has 9 container slots (3x3 grid).
  DemoContainerScreen() : super(title: 'Dart Container', slotCount: 9);

  @override
  void init() {
    print('DemoContainerScreen initialized! Size: $width x $height');
    print(
        'Panel position: ($leftPos, $topPos), size: ($imageWidth x $imageHeight)');

    // Note: Slots are added in Java (DartContainerMenu constructor)
    // Dart only handles the visual rendering of the background
  }

  @override
  void renderBackground(
      GuiGraphics graphics, int mouseX, int mouseY, double partialTick) {
    // Draw main panel background
    graphics.drawPanel(leftPos, topPos, imageWidth, imageHeight);

    // Title
    graphics.drawCenteredString(
      'Dart Container',
      leftPos + imageWidth ~/ 2,
      topPos + 6,
      color: 0xFF404040,
      shadow: false,
    );

    // Draw slot backgrounds for the 3x3 grid
    // Java slot positions: startX = (176 - 3*18)/2 = 61, startY = 17
    // Slot sprite should be drawn 1 pixel before the slot position
    const int containerStartX = 61;
    const int containerStartY = 17;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        graphics.drawSlot(
          leftPos + containerStartX + col * 18 - 1,
          topPos + containerStartY + row * 18 - 1,
        );
      }
    }

    // Label for player inventory
    graphics.drawString(
      'Inventory',
      leftPos + 8,
      topPos + 71,
      color: 0xFF404040,
      shadow: false,
    );

    // Draw slot backgrounds for player inventory (3 rows of 9)
    // Java: playerInvY = 17 + 3*18 + 14 = 85, startX = 8
    const int playerInvStartX = 8;
    const int playerInvStartY = 85;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 9; col++) {
        graphics.drawSlot(
          leftPos + playerInvStartX + col * 18 - 1,
          topPos + playerInvStartY + row * 18 - 1,
        );
      }
    }

    // Draw hotbar slots (1 row of 9)
    // Java: hotbar = playerInvY + 58 = 143
    const int hotbarY = 143;
    for (int col = 0; col < 9; col++) {
      graphics.drawSlot(
        leftPos + playerInvStartX + col * 18 - 1,
        topPos + hotbarY - 1,
      );
    }
  }

  @override
  void onClose() {
    print('DemoContainerScreen closed!');
  }
}

/// Initialize the demo container screen system.
///
/// This sets up the screen factory so that when Java opens a DartContainerMenu,
/// Dart automatically creates a DemoContainerScreen to render it.
///
/// Call this during mod initialization, typically in your main entry point.
void initDemoContainerScreen() {
  // Initialize container screen callbacks
  initContainerScreenCallbacks();

  // Set the factory to create DemoContainerScreen instances
  ContainerScreen.screenFactory = () => DemoContainerScreen();

  print('DemoContainerScreen factory registered');
}
