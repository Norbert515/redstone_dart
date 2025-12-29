import 'package:flutter/widgets.dart';
import '../theme/mc_colors.dart';
import '../theme/mc_theme.dart';

/// A Minecraft-style scrollbar widget.
class McScrollbar extends StatefulWidget {
  /// The scroll controller to attach to.
  final ScrollController controller;

  /// The scrollable child widget.
  final Widget child;

  /// Whether to show the scrollbar.
  final bool thumbVisibility;

  const McScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.thumbVisibility = true,
  });

  @override
  State<McScrollbar> createState() => _McScrollbarState();
}

class _McScrollbarState extends State<McScrollbar> {
  double _thumbPosition = 0;
  double _thumbSize = 0;
  bool _isDragging = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateThumb);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateThumb);
    super.dispose();
  }

  void _updateThumb() {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    if (position.maxScrollExtent <= 0) {
      setState(() {
        _thumbPosition = 0;
        _thumbSize = 1;
      });
      return;
    }

    setState(() {
      _thumbSize = position.viewportDimension / (position.maxScrollExtent + position.viewportDimension);
      _thumbPosition = position.pixels / position.maxScrollExtent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = McTheme.scaleOf(context);
    final scrollbarWidth = McSizes.scrollbarWidth * scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(child: widget.child),
            if (widget.thumbVisibility && _thumbSize < 1)
              MouseRegion(
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: GestureDetector(
                  onVerticalDragStart: (details) {
                    setState(() => _isDragging = true);
                  },
                  onVerticalDragUpdate: (details) {
                    if (!widget.controller.hasClients) return;
                    final position = widget.controller.position;
                    final trackHeight = constraints.maxHeight - McSizes.scrollerMinHeight * scale;
                    final delta = details.delta.dy / trackHeight;
                    final newOffset = (position.pixels + delta * position.maxScrollExtent)
                        .clamp(0.0, position.maxScrollExtent);
                    widget.controller.jumpTo(newOffset);
                  },
                  onVerticalDragEnd: (_) {
                    setState(() => _isDragging = false);
                  },
                  child: CustomPaint(
                    painter: _McScrollbarPainter(
                      thumbPosition: _thumbPosition,
                      thumbSize: _thumbSize,
                      isHovered: _isHovered,
                      isDragging: _isDragging,
                      scale: scale,
                    ),
                    child: SizedBox(
                      width: scrollbarWidth,
                      height: constraints.maxHeight,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _McScrollbarPainter extends CustomPainter {
  final double thumbPosition;
  final double thumbSize;
  final bool isHovered;
  final bool isDragging;
  final double scale;

  _McScrollbarPainter({
    required this.thumbPosition,
    required this.thumbSize,
    required this.isHovered,
    required this.isDragging,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Track background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = McColors.slotBackground.withValues(alpha: 0.5),
    );

    // Calculate thumb dimensions
    final minThumbHeight = McSizes.scrollerMinHeight * scale;
    final trackHeight = size.height;
    final thumbHeight = (trackHeight * thumbSize).clamp(minThumbHeight, trackHeight);
    final availableTrack = trackHeight - thumbHeight;
    final thumbTop = thumbPosition * availableTrack;

    // Thumb
    final thumbColor = isDragging
        ? McColors.white
        : (isHovered ? McColors.lighterGray : McColors.lightGray);

    canvas.drawRect(
      Rect.fromLTWH(0, thumbTop, size.width, thumbHeight),
      Paint()..color = thumbColor,
    );

    // Thumb border
    canvas.drawRect(
      Rect.fromLTWH(0, thumbTop, size.width, thumbHeight),
      Paint()
        ..color = McColors.slotBorderDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * scale,
    );
  }

  @override
  bool shouldRepaint(_McScrollbarPainter oldDelegate) {
    return thumbPosition != oldDelegate.thumbPosition ||
        thumbSize != oldDelegate.thumbSize ||
        isHovered != oldDelegate.isHovered ||
        isDragging != oldDelegate.isDragging;
  }
}
