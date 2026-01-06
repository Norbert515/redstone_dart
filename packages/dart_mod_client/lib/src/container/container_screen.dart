/// Base class for container screens.
library;

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:flutter/widgets.dart';

/// Base class for container screens.
///
/// This provides a simple base for screens that display container data.
/// Container data synchronization is handled automatically by [ContainerScope],
/// which wraps screens when using the `containerBuilder` + `screenBuilder`
/// pattern in [GuiRoute].
///
/// Example using ContainerScope (recommended):
/// ```dart
/// class FurnaceScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final container = ContainerScope.of<SimpleFurnaceContainer>(context);
///     return Text('Progress: ${container.cookProgress.value}');
///   }
/// }
/// ```
///
/// Example using ContainerScreen base class (for legacy compatibility):
/// ```dart
/// class FurnaceScreen extends ContainerScreen<SimpleFurnaceContainer> {
///   const FurnaceScreen({
///     super.key,
///     required super.container,
///     required super.menuId,
///   });
///
///   @override
///   State<FurnaceScreen> createState() => _FurnaceScreenState();
/// }
///
/// class _FurnaceScreenState extends ContainerScreenState<SimpleFurnaceContainer> {
///   @override
///   Widget build(BuildContext context) {
///     return Text('Progress: ${container.cookProgress.value}');
///   }
/// }
/// ```
abstract class ContainerScreen<T extends ContainerDefinition>
    extends StatefulWidget {
  /// The container definition with synced values.
  final T container;

  /// The menu ID from Java for this container instance.
  final int menuId;

  /// Creates a container screen.
  const ContainerScreen({
    super.key,
    required this.container,
    required this.menuId,
  });
}

/// Base state class for [ContainerScreen].
///
/// Provides convenient access to [container] and [menuId].
/// Data synchronization is handled by [ContainerScope] in the widget tree.
abstract class ContainerScreenState<T extends ContainerDefinition>
    extends State<ContainerScreen<T>> {
  /// The container definition with synced values.
  T get container => widget.container;

  /// The menu ID from Java for this container instance.
  int get menuId => widget.menuId;
}
