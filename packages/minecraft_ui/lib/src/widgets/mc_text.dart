import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// A Minecraft-style text widget with optional shadow effect.
///
/// Minecraft text uses a bitmap font with a 1-pixel shadow offset.
class McText extends StatelessWidget {
  /// The text to display.
  final String text;

  /// The text color.
  final Color color;

  /// Whether to show the text shadow.
  final bool shadow;

  /// Optional font size multiplier (1.0 = normal, 2.0 = double).
  final double fontSize;

  /// Text alignment.
  final TextAlign textAlign;

  /// Maximum number of lines.
  final int? maxLines;

  /// How to handle text overflow.
  final TextOverflow overflow;

  const McText(
    this.text, {
    super.key,
    this.color = McColors.white,
    this.shadow = true,
    this.fontSize = 1.0,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  /// Creates a title-style text (no shadow, dark gray color).
  const McText.title(
    this.text, {
    super.key,
    this.color = McColors.darkGray,
    this.fontSize = 1.0,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  }) : shadow = false;

  /// Creates a label-style text (no shadow, dark gray color).
  const McText.label(
    this.text, {
    super.key,
    this.color = McColors.darkGray,
    this.fontSize = 1.0,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  }) : shadow = false;

  /// Creates a disabled-style text (with shadow, light gray color).
  const McText.disabled(
    this.text, {
    super.key,
    this.color = McColors.lightGray,
    this.fontSize = 1.0,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  }) : shadow = true;

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final effectiveFontSize = McTypography.fontHeight * scale * fontSize;

    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontFamily: 'Minecraft',
        package: 'minecraft_ui',
        fontSize: effectiveFontSize,
        height: McTypography.lineHeight / McTypography.fontHeight,
        color: color,
        shadows: shadow
            ? [
                Shadow(
                  color: McColors.black.withValues(alpha: 0.4),
                  offset: Offset(
                    McTypography.shadowOffset * scale,
                    McTypography.shadowOffset * scale,
                  ),
                ),
              ]
            : null,
      ),
    );
  }
}

/// A rich text widget supporting Minecraft formatting codes.
///
/// Supports formatting codes like §0-§f for colors and §l, §o, §n, §m, §r for styles.
class McFormattedText extends StatelessWidget {
  /// The text with Minecraft formatting codes.
  final String text;

  /// Whether to show text shadows.
  final bool shadow;

  /// Font size multiplier.
  final double fontSize;

  const McFormattedText(
    this.text, {
    super.key,
    this.shadow = true,
    this.fontSize = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final spans = _parseFormattedText(text, scale);

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  List<TextSpan> _parseFormattedText(String text, double scale) {
    final spans = <TextSpan>[];
    final effectiveFontSize = McTypography.fontHeight * scale * fontSize;

    Color currentColor = McColors.white;
    bool isBold = false;
    bool isItalic = false;
    bool isUnderline = false;
    bool isStrikethrough = false;

    final buffer = StringBuffer();
    int i = 0;

    void flushBuffer() {
      if (buffer.isEmpty) return;

      spans.add(TextSpan(
        text: buffer.toString(),
        style: TextStyle(
          fontFamily: 'Minecraft',
          package: 'minecraft_ui',
          fontSize: effectiveFontSize,
          color: currentColor,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: TextDecoration.combine([
            if (isUnderline) TextDecoration.underline,
            if (isStrikethrough) TextDecoration.lineThrough,
          ]),
          shadows: shadow
              ? [
                  Shadow(
                    color: McColors.black.withValues(alpha: 0.4),
                    offset: Offset(
                      McTypography.shadowOffset * scale,
                      McTypography.shadowOffset * scale,
                    ),
                  ),
                ]
              : null,
        ),
      ));
      buffer.clear();
    }

    while (i < text.length) {
      if (text[i] == '§' && i + 1 < text.length) {
        flushBuffer();
        final code = text[i + 1].toLowerCase();

        switch (code) {
          case '0':
            currentColor = McColors.formatBlack;
          case '1':
            currentColor = McColors.formatDarkBlue;
          case '2':
            currentColor = McColors.formatDarkGreen;
          case '3':
            currentColor = McColors.formatDarkAqua;
          case '4':
            currentColor = McColors.formatDarkRed;
          case '5':
            currentColor = McColors.formatDarkPurple;
          case '6':
            currentColor = McColors.formatGold;
          case '7':
            currentColor = McColors.formatGray;
          case '8':
            currentColor = McColors.formatDarkGray;
          case '9':
            currentColor = McColors.formatBlue;
          case 'a':
            currentColor = McColors.formatGreen;
          case 'b':
            currentColor = McColors.formatAqua;
          case 'c':
            currentColor = McColors.formatRed;
          case 'd':
            currentColor = McColors.formatLightPurple;
          case 'e':
            currentColor = McColors.formatYellow;
          case 'f':
            currentColor = McColors.formatWhite;
          case 'l':
            isBold = true;
          case 'o':
            isItalic = true;
          case 'n':
            isUnderline = true;
          case 'm':
            isStrikethrough = true;
          case 'r':
            currentColor = McColors.white;
            isBold = false;
            isItalic = false;
            isUnderline = false;
            isStrikethrough = false;
        }
        i += 2;
      } else {
        buffer.write(text[i]);
        i++;
      }
    }

    flushBuffer();
    return spans;
  }
}
