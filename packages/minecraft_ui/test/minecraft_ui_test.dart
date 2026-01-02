import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

void main() {
  test('McColors contains expected colors', () {
    expect(McColors.white, isNotNull);
    expect(McColors.black, isNotNull);
    expect(McColors.panelBackground, isNotNull);
  });

  test('McSizes contains expected dimensions', () {
    expect(McSizes.buttonHeight, 20);
    expect(McSizes.slotSize, 18);
    expect(McSizes.itemSize, 16);
  });
}
