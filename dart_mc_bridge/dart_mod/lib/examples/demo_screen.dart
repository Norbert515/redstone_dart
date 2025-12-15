/// Example screen demonstrating the Dart GUI API with native widgets.
///
/// This file shows how to create a custom Minecraft screen using Dart.
/// It demonstrates:
/// - Screen lifecycle (init, render, tick, onClose)
/// - Drawing text, shapes, and gradients with GuiGraphics
/// - Using native Minecraft widgets (Button, EditBox)
/// - Using Minecraft-style UI helper methods
/// - Handling keyboard and mouse input
/// - Using McColors for Minecraft-style colors
library;

import '../api/gui/gui.dart';

/// A demonstration screen showing various GUI API features.
///
/// This screen displays a Minecraft-style panel with:
/// - Title and separator
/// - Screen info (size, mouse position, clicks)
/// - Item slots demonstration
/// - Native interactive buttons
/// - Text input field
/// - Animated progress bar
///
/// ## Usage
/// ```dart
/// // Open the demo screen
/// showDemoScreen();
/// ```
class DemoScreen extends Screen {
  /// Track how many times the user has clicked.
  int clickCount = 0;

  /// Time since screen was opened (for animations).
  int tickCount = 0;

  /// The "Click Me" button widget.
  late Button clickMeButton;

  /// The "Close" button widget.
  late Button closeButton;

  /// The text input field.
  late EditBox nameInput;

  /// Current text from the input field.
  String inputText = '';

  /// Create a new demo screen.
  DemoScreen() : super('Dart GUI Demo');

  @override
  void init() {
    // Called when screen is initialized.
    // At this point, width and height are available.
    print('DemoScreen initialized! Size: $width x $height');

    // =========================================================================
    // Calculate centered panel position
    // =========================================================================
    const panelWidth = 220;
    const panelHeight = 190;
    final panelX = (width - panelWidth) ~/ 2;
    final panelY = (height - panelHeight) ~/ 2;

    // =========================================================================
    // Create native widgets
    // =========================================================================

    // "Click Me" button - uses Minecraft's native button rendering
    clickMeButton = addButton(
      x: panelX + 10,
      y: panelY + 100,
      width: 90,
      height: 20,
      text: 'Click Me',
      onPressed: () {
        clickCount++;
        print('Click Me button pressed! Count: $clickCount');
      },
    );

    // "Close" button
    closeButton = addButton(
      x: panelX + 110,
      y: panelY + 100,
      width: 90,
      height: 20,
      text: 'Close',
      onPressed: () {
        print('Close button pressed!');
        close();
      },
    );

    // Text input field
    nameInput = addEditBox(
      x: panelX + 10,
      y: panelY + 130,
      width: 190,
      height: 20,
      placeholder: 'Enter your name...',
      onChanged: (text) {
        inputText = text;
        print('Text changed: $text');
      },
    );
  }

  @override
  void tick() {
    // Called every game tick (20 times per second).
    // Good for animations or state updates.
    tickCount++;
  }

  @override
  void render(GuiGraphics graphics, int mouseX, int mouseY, double partialTick) {
    // =========================================================================
    // Draw semi-transparent background
    // =========================================================================
    graphics.fill(0, 0, width, height, McColors.withAlpha(McColors.black, 180));

    // =========================================================================
    // Calculate centered panel position
    // =========================================================================
    const panelWidth = 220;
    const panelHeight = 190;
    final panelX = (width - panelWidth) ~/ 2;
    final panelY = (height - panelHeight) ~/ 2;

    // =========================================================================
    // Draw main panel using helper method
    // =========================================================================
    graphics.drawPanel(panelX, panelY, panelWidth, panelHeight);

    // =========================================================================
    // Title (centered on panel) - no shadow for light background
    // =========================================================================
    graphics.drawCenteredString(
      'Dart GUI Demo',
      panelX + panelWidth ~/ 2,
      panelY + 8,
      color: 0xFF404040,
      shadow: false,
    );

    // =========================================================================
    // Separator line below title
    // =========================================================================
    graphics.drawSeparator(panelX + 7, panelY + 20, panelWidth - 14);

    // =========================================================================
    // Info section - no shadow for light background
    // =========================================================================
    graphics.drawString(
      'Screen: $width x $height',
      panelX + 10,
      panelY + 30,
      color: 0xFF404040,
      shadow: false,
    );
    graphics.drawString(
      'Mouse: $mouseX, $mouseY',
      panelX + 10,
      panelY + 42,
      color: 0xFF404040,
      shadow: false,
    );
    graphics.drawString(
      'Clicks: $clickCount',
      panelX + 10,
      panelY + 54,
      color: 0xFF404040,
      shadow: false,
    );

    // =========================================================================
    // Draw item slots using helper method
    // =========================================================================
    graphics.drawSlot(panelX + 10, panelY + 70);
    graphics.drawSlot(panelX + 30, panelY + 70);
    graphics.drawSlot(panelX + 50, panelY + 70);

    // =========================================================================
    // Native widgets are rendered automatically by Minecraft!
    // No need to draw buttons or the edit box here.
    // =========================================================================

    // =========================================================================
    // Progress bar using helper method
    // =========================================================================
    graphics.drawString(
      'Progress:',
      panelX + 10,
      panelY + 160,
      color: 0xFF404040,
      shadow: false,
    );
    graphics.drawProgressBar(
      panelX + 70,
      panelY + 158,
      120,
      12,
      (tickCount % 100) / 100.0,
    );
  }

  @override
  bool keyPressed(int keyCode, int scanCode, int modifiers) {
    // Close screen on ESC
    if (keyCode == Keys.escape) {
      close();
      return true;
    }

    // Log other key presses
    print('Key pressed: ${Keys.getKeyName(keyCode)}');

    // Show info about modifier keys
    if (Keys.isShiftDown(modifiers)) {
      print('  (with Shift)');
    }
    if (Keys.isControlDown(modifiers)) {
      print('  (with Control)');
    }

    return false;
  }

  @override
  bool mouseClicked(double mouseX, double mouseY, int button) {
    // Note: Native widgets handle their own click events automatically!
    // We no longer need to manually check button bounds.
    print('Mouse clicked at ($mouseX, $mouseY) with ${Keys.getMouseButtonName(button)}');
    return false; // Let widgets handle the click
  }

  @override
  bool mouseScrolled(double mouseX, double mouseY, double deltaX, double deltaY) {
    print('Mouse scrolled: deltaX=$deltaX, deltaY=$deltaY');
    return true;
  }

  @override
  void onClose() {
    // Called when screen is closed.
    // Good place to clean up or save state.
    print('DemoScreen closed! Total clicks: $clickCount, Total ticks: $tickCount');
    if (inputText.isNotEmpty) {
      print('Final input text: $inputText');
    }
  }
}

/// Show the demo screen.
///
/// Call this function to open the demo screen.
/// The screen can be closed by pressing ESC or clicking the Close button.
///
/// ## Example
/// ```dart
/// // From a block interaction:
/// showDemoScreen();
///
/// // Or from an event handler:
/// Events.onSomeEvent(() {
///   showDemoScreen();
/// });
/// ```
void showDemoScreen() {
  DemoScreen().show();
}
