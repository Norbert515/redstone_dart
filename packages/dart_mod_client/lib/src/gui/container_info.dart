/// Information about an open container, passed to GUI builders.
library;

/// Information about an open container, passed to GUI builders.
///
/// This is passed to [GuiRoute.builder] when a container is opened.
/// It contains the container's menu ID, type, title, and slot layout information.
///
/// Example:
/// ```dart
/// GuiRoute(
///   containerId: 'mymod:custom_chest',
///   builder: (context, info) {
///     print('Container opened: ${info.title}');
///     print('Menu ID: ${info.menuId}');
///     print('Size: ${info.rows}x${info.columns}');
///     return MyChestScreen(info: info);
///   },
/// )
/// ```
class ContainerInfo {
  /// The menu ID assigned by the server.
  ///
  /// This is used to identify the container for item operations.
  final int menuId;

  /// The container type ID (e.g., 'mymod:custom_chest').
  ///
  /// This matches the [GuiRoute.containerId] that was used to route to this screen.
  final String containerId;

  /// The display title of the container.
  ///
  /// This is the title shown at the top of the container GUI.
  final String title;

  /// The number of rows in the container.
  ///
  /// For a standard chest, this is 3. For a double chest, this is 6.
  /// For furnace-like containers, this is typically 1.
  final int rows;

  /// The number of columns in the container.
  ///
  /// For most containers, this is 9 (matching the player inventory width).
  final int columns;

  /// Creates container information.
  const ContainerInfo({
    required this.menuId,
    required this.containerId,
    required this.title,
    required this.rows,
    required this.columns,
  });

  /// The total number of container slots (excluding player inventory).
  int get slotCount => rows * columns;

  @override
  String toString() =>
      'ContainerInfo(menuId: $menuId, containerId: $containerId, '
      'title: $title, ${rows}x$columns)';

  @override
  bool operator ==(Object other) =>
      other is ContainerInfo &&
      menuId == other.menuId &&
      containerId == other.containerId &&
      title == other.title &&
      rows == other.rows &&
      columns == other.columns;

  @override
  int get hashCode => Object.hash(menuId, containerId, title, rows, columns);
}
