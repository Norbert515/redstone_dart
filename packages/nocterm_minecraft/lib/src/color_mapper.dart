import 'package:dart_mod_common/dart_mod_common.dart';

/// Maps RGB colors to the nearest Minecraft concrete block.
class ColorMapper {
  // 16 concrete block colors (RGB values)
  static const Map<String, List<int>> _concreteColors = {
    'minecraft:white_concrete': [207, 213, 214],
    'minecraft:orange_concrete': [224, 97, 1],
    'minecraft:magenta_concrete': [169, 48, 159],
    'minecraft:light_blue_concrete': [36, 137, 199],
    'minecraft:yellow_concrete': [241, 175, 21],
    'minecraft:lime_concrete': [94, 169, 24],
    'minecraft:pink_concrete': [213, 101, 143],
    'minecraft:gray_concrete': [55, 58, 62],
    'minecraft:light_gray_concrete': [125, 125, 115],
    'minecraft:cyan_concrete': [21, 119, 136],
    'minecraft:purple_concrete': [100, 32, 156],
    'minecraft:blue_concrete': [45, 47, 143],
    'minecraft:brown_concrete': [96, 60, 32],
    'minecraft:green_concrete': [73, 91, 36],
    'minecraft:red_concrete': [142, 33, 33],
    'minecraft:black_concrete': [8, 10, 15],
  };

  /// Get the concrete block closest to the given RGB color.
  static Block getBlock(int r, int g, int b) {
    String closest = 'minecraft:white_concrete';
    double minDistance = double.infinity;

    for (final entry in _concreteColors.entries) {
      final rgb = entry.value;
      final distance = _colorDistance(r, g, b, rgb[0], rgb[1], rgb[2]);
      if (distance < minDistance) {
        minDistance = distance;
        closest = entry.key;
      }
    }

    return Block(closest);
  }

  /// Get block from a 32-bit ARGB color value.
  static Block getBlockFromArgb(int argb) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return getBlock(r, g, b);
  }

  /// Euclidean distance in RGB space.
  static double _colorDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
    final dr = r1 - r2;
    final dg = g1 - g2;
    final db = b1 - b2;
    return (dr * dr + dg * dg + db * db).toDouble();
  }
}
