import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// A widget that renders pixel art from a multi-line string.
///
/// Each character in the [data] string maps to a color from [palette].
/// By default, uses Minecraft's formatting color codes (0-9, A-F).
///
/// Example:
/// ```dart
/// McPixelArt(
///   pixelSize: 4,
///   data: '''
///     ..FF..
///     .FFFF.
///     FFFFFF
///     .FFFF.
///     ..FF..
///   ''',
/// )
/// ```
class McPixelArt extends StatelessWidget {
  /// Size of each pixel in logical pixels (before GUI scale).
  final double pixelSize;

  /// Multi-line string defining the pixel art.
  ///
  /// Each character maps to a color in the palette.
  /// '.' and ' ' are transparent by default.
  final String data;

  /// Color palette mapping characters to colors.
  ///
  /// If null, uses default Minecraft formatting colors (0-9, A-F mapping to §0-§f).
  final Map<String, Color>? palette;

  const McPixelArt({
    super.key,
    this.pixelSize = 1,
    required this.data,
    this.palette,
  });

  /// Default palette using Minecraft formatting colors.
  static const Map<String, Color> defaultPalette = {
    '0': McColors.formatBlack,
    '1': McColors.formatDarkBlue,
    '2': McColors.formatDarkGreen,
    '3': McColors.formatDarkAqua,
    '4': McColors.formatDarkRed,
    '5': McColors.formatDarkPurple,
    '6': McColors.formatGold,
    '7': McColors.formatGray,
    '8': McColors.formatDarkGray,
    '9': McColors.formatBlue,
    'A': McColors.formatGreen,
    'a': McColors.formatGreen,
    'B': McColors.formatAqua,
    'b': McColors.formatAqua,
    'C': McColors.formatRed,
    'c': McColors.formatRed,
    'D': McColors.formatLightPurple,
    'd': McColors.formatLightPurple,
    'E': McColors.formatYellow,
    'e': McColors.formatYellow,
    'F': McColors.formatWhite,
    'f': McColors.formatWhite,
  };

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final rows = _parseData(data);

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxWidth = rows.fold<int>(0, (max, row) => row.length > max ? row.length : max);
    final height = rows.length;

    final scaledPixelSize = pixelSize * scale;
    final totalWidth = maxWidth * scaledPixelSize;
    final totalHeight = height * scaledPixelSize;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: CustomPaint(
        painter: _McPixelArtPainter(
          rows: rows,
          pixelSize: scaledPixelSize,
          palette: palette ?? defaultPalette,
        ),
      ),
    );
  }

  /// Parse the data string into rows, trimming empty lines at start/end.
  static List<String> _parseData(String data) {
    final lines = data.split('\n');

    // Find first non-empty line
    var startIndex = 0;
    while (startIndex < lines.length && lines[startIndex].trim().isEmpty) {
      startIndex++;
    }

    // Find last non-empty line
    var endIndex = lines.length - 1;
    while (endIndex >= 0 && lines[endIndex].trim().isEmpty) {
      endIndex--;
    }

    if (startIndex > endIndex) {
      return [];
    }

    return lines.sublist(startIndex, endIndex + 1);
  }
}

class _McPixelArtPainter extends CustomPainter {
  final List<String> rows;
  final double pixelSize;
  final Map<String, Color> palette;

  _McPixelArtPainter({
    required this.rows,
    required this.pixelSize,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.none;

    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final char = row[x];

        // Skip transparent characters
        if (char == '.' || char == ' ') {
          continue;
        }

        final color = palette[char];
        if (color == null) {
          continue;
        }

        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(
            x * pixelSize,
            y * pixelSize,
            pixelSize,
            pixelSize,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_McPixelArtPainter oldDelegate) {
    return rows != oldDelegate.rows ||
        pixelSize != oldDelegate.pixelSize ||
        palette != oldDelegate.palette;
  }
}
