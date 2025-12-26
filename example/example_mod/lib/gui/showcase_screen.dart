import 'package:dart_mc/dart_mc.dart';

/// Example GUI screen with input field and buttons
class ShowcaseScreen extends Screen {
  late EditBox nameInput;
  String statusMessage = '';

  ShowcaseScreen() : super('Showcase GUI');

  @override
  void init() {
    final centerX = width ~/ 2;
    final startY = height ~/ 3;

    // Name input
    nameInput = addEditBox(
      x: centerX - 100,
      y: startY + 20,
      width: 200,
      height: 20,
      placeholder: 'Enter your name...',
    );

    // Save button
    addButton(
      x: centerX - 100,
      y: startY + 60,
      width: 95,
      height: 20,
      text: 'Save',
      onPressed: () {
        if (nameInput.value.isEmpty) {
          statusMessage = '\u00A7cPlease enter a name!';
        } else {
          statusMessage = '\u00A7aSaved: ${nameInput.value}';
        }
      },
    );

    // Cancel button
    addButton(
      x: centerX + 5,
      y: startY + 60,
      width: 95,
      height: 20,
      text: 'Cancel',
      onPressed: close,
    );

    // Fun action buttons
    addButton(
      x: centerX - 100,
      y: startY + 100,
      width: 200,
      height: 20,
      text: 'Lightning Effect',
      onPressed: () {
        statusMessage = '\u00A7e\u26A1 Lightning activated!';
      },
    );

    addButton(
      x: centerX - 100,
      y: startY + 130,
      width: 200,
      height: 20,
      text: 'Heal Player',
      onPressed: () {
        statusMessage = '\u00A7a\u2764 Player healed!';
      },
    );
  }

  @override
  void render(GuiGraphics graphics, int mouseX, int mouseY, double partialTick) {
    // Dark semi-transparent background
    graphics.fill(0, 0, width, height, 0xC0101010);

    // Panel background
    final panelX = width ~/ 2 - 120;
    final panelY = height ~/ 3 - 30;
    graphics.fill(panelX, panelY, panelX + 240, panelY + 200, 0xE0202020);

    // Panel border
    graphics.fill(panelX, panelY, panelX + 240, panelY + 2, 0xFF505050);
    graphics.fill(panelX, panelY + 198, panelX + 240, panelY + 200, 0xFF505050);
    graphics.fill(panelX, panelY, panelX + 2, panelY + 200, 0xFF505050);
    graphics.fill(panelX + 238, panelY, panelX + 240, panelY + 200, 0xFF505050);

    // Title
    graphics.drawCenteredString(
      '\u00A7l\u00A7bShowcase GUI',
      width ~/ 2,
      height ~/ 3 - 15,
    );

    // Label for input
    graphics.drawString(
      'Your Name:',
      width ~/ 2 - 100,
      height ~/ 3 + 8,
      color: 0xAAAAAA,
    );

    // Status message
    if (statusMessage.isNotEmpty) {
      graphics.drawCenteredString(
        statusMessage,
        width ~/ 2,
        height ~/ 3 + 165,
      );
    }

    // Footer
    graphics.drawCenteredString(
      '\u00A77Press ESC to close',
      width ~/ 2,
      height ~/ 3 + 180,
      color: 0x888888,
    );
  }

  @override
  bool keyPressed(int keyCode, int scanCode, int modifiers) {
    if (keyCode == Keys.escape) {
      close();
      return true;
    }
    return false;
  }
}
