/// A route definition for a container GUI screen.
library;

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:flutter/widgets.dart';

import 'container_info.dart';
import 'slot_definition.dart';

/// Cached slot positions from first open.
/// Maps route identifier (containerId or title) to list of slot definitions.
final Map<String, List<SlotDefinition>> _cachedSlotPositions = {};

/// Sets cached slot positions for a route key.
void setCachedSlotPositions(String key, List<SlotDefinition> slots) {
  if (key.isNotEmpty && slots.isNotEmpty) {
    _cachedSlotPositions[key] = slots;
  }
}

/// Gets cached slot positions for a route key.
List<SlotDefinition>? getCachedSlotPositions(String key) {
  return _cachedSlotPositions[key];
}

/// A route definition for a container GUI screen.
///
/// Routes map container type IDs or titles to Flutter screen builders. When a
/// container is opened, the [GuiRouter] finds the matching route and builds
/// the screen.
///
/// You can match containers by:
/// - [containerId] - The registered container type ID (e.g., 'mymod:custom_chest')
/// - [title] - The container's display title (useful for block entity containers)
///
/// Example:
/// ```dart
/// GuiRouter(
///   routes: [
///     // Match by container type ID (legacy builder pattern)
///     GuiRoute(
///       containerId: 'mymod:custom_chest',
///       builder: (context, info) => MyChestScreen(info: info),
///     ),
///     // Match by title with container lifecycle management (new pattern)
///     GuiRoute(
///       title: 'Example Furnace',
///       containerBuilder: () => MyFurnaceContainer(),
///       screenBuilder: (context) => MyFurnaceScreen(),
///       slots: [
///         SlotDefinition(index: 0, x: 56, y: 17),   // Input
///         SlotDefinition(index: 1, x: 56, y: 53),   // Fuel
///         SlotDefinition(index: 2, x: 116, y: 35),  // Output
///       ],
///     ),
///   ],
/// )
/// ```
class GuiRoute {
  /// The container type ID to match (e.g., 'mymod:custom_chest').
  ///
  /// This should match the ID used when registering the container on the
  /// server side. Used for containers opened via [ContainerRegistry].
  ///
  /// Either [containerId] or [title] must be provided.
  final String? containerId;

  /// The container title to match (e.g., 'Example Furnace').
  ///
  /// This is useful for block entity containers that don't have a registered
  /// container type ID. The title is taken from the MenuProvider's display name.
  ///
  /// Either [containerId] or [title] must be provided.
  final String? title;

  /// Legacy builder function that creates the screen widget.
  ///
  /// Called when a container with matching [containerId] or [title] is opened.
  /// The [ContainerInfo] provides details about the container.
  ///
  /// Use this when you want full control over container lifecycle.
  ///
  /// Mutually exclusive with [containerBuilder] + [screenBuilder].
  final Widget Function(BuildContext context, ContainerInfo info)? builder;

  /// Factory function to create the container instance.
  ///
  /// When provided along with [screenBuilder], the [GuiRouter] automatically:
  /// 1. Creates the container via this factory when the menu opens
  /// 2. Wraps the screen with [ContainerScope] for automatic lifecycle management
  /// 3. Provides the container to descendant widgets via [ContainerScope.of]
  ///
  /// This enables the reactive pattern where screens access container state via
  /// `ContainerScope.of<MyContainer>(context)` and automatically rebuild when
  /// synced values change.
  ///
  /// Must be provided together with [screenBuilder].
  final ContainerDefinition Function()? containerBuilder;

  /// Screen builder that doesn't need to handle container lifecycle.
  ///
  /// When provided along with [containerBuilder], the container is automatically
  /// available via [ContainerScope.of] in descendant widgets.
  ///
  /// Example:
  /// ```dart
  /// screenBuilder: (context) => MyFurnaceScreen(),
  ///
  /// // In MyFurnaceScreen:
  /// final container = ContainerScope.of<MyFurnaceContainer>(context);
  /// ```
  ///
  /// Must be provided together with [containerBuilder].
  final Widget Function(BuildContext context)? screenBuilder;

  /// Optional pre-registered slot positions for zero-delay item rendering.
  ///
  /// If provided, these positions are sent to Java immediately when the
  /// container opens, allowing items to render on the first frame.
  ///
  /// Without pre-registration, there's typically a 1-2 frame delay before
  /// items appear while Flutter performs its layout pass.
  ///
  /// Example:
  /// ```dart
  /// slots: [
  ///   // Container slots (3 rows of 9)
  ///   for (var row = 0; row < 3; row++)
  ///     for (var col = 0; col < 9; col++)
  ///       SlotDefinition(
  ///         index: row * 9 + col,
  ///         x: 8.0 + col * 18,
  ///         y: 18.0 + row * 18,
  ///       ),
  /// ]
  /// ```
  final List<SlotDefinition>? slots;

  /// Whether to automatically cache slot positions from a pre-layout pass.
  ///
  /// When true, the [GuiRouter] will build this screen widget once at startup
  /// (offscreen) to capture slot positions. These cached positions are then
  /// sent to Java immediately when the container opens, providing instant
  /// item rendering without the typical 1-2 frame delay.
  ///
  /// This is an alternative to manually specifying [slots] - the positions
  /// are computed automatically from the actual widget layout.
  ///
  /// Defaults to false.
  final bool cacheSlotPositions;

  /// Creates a GUI route definition.
  ///
  /// Either [containerId] or [title] must be provided for matching.
  ///
  /// Provide either:
  /// - [builder] for legacy pattern (full control over container lifecycle)
  /// - [containerBuilder] + [screenBuilder] for automatic container management
  ///
  /// Optional [slots] pre-register slot positions for instant item rendering.
  /// Set [cacheSlotPositions] to true to auto-compute positions from layout.
  const GuiRoute({
    this.containerId,
    this.title,
    this.builder,
    this.containerBuilder,
    this.screenBuilder,
    this.slots,
    this.cacheSlotPositions = false,
  }) : assert(
          containerId != null || title != null,
          'Either containerId or title must be provided',
        ),
       assert(
          builder != null || (containerBuilder != null && screenBuilder != null),
          'Either provide builder, or both containerBuilder and screenBuilder',
        );

  /// Gets the route identifier (containerId or title).
  String get routeKey => containerId ?? title ?? '';

  /// Gets cached slot positions for this route, if available.
  List<SlotDefinition>? get cachedSlots => _cachedSlotPositions[routeKey];

  /// Stores cached slot positions for this route.
  set cachedSlots(List<SlotDefinition>? slots) {
    if (slots != null && slots.isNotEmpty) {
      _cachedSlotPositions[routeKey] = slots;
    }
  }

  /// Gets the effective slots to use - cached positions take precedence,
  /// then explicitly defined slots.
  List<SlotDefinition>? get effectiveSlots => cachedSlots ?? slots;

  /// Checks if this route matches the given container ID and title.
  bool matches(String containerId, String title) {
    // Match by containerId if specified (and non-empty)
    if (this.containerId != null &&
        this.containerId!.isNotEmpty &&
        containerId.isNotEmpty &&
        this.containerId == containerId) {
      return true;
    }

    // Match by title if specified (and non-empty)
    if (this.title != null &&
        this.title!.isNotEmpty &&
        title.isNotEmpty &&
        this.title == title) {
      return true;
    }

    return false;
  }

  @override
  String toString() => 'GuiRoute(containerId: $containerId, '
      'title: $title, slots: ${slots?.length ?? 0})';
}
