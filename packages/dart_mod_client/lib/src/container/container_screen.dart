/// Base class for container screens with automatic data syncing.
library;

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:flutter/widgets.dart';

import 'container_watcher.dart';

/// Base class for container screens with automatic data syncing.
///
/// This widget provides automatic lifecycle management for [ContainerWatcher],
/// starting the watcher when the screen is shown and stopping it when disposed.
///
/// Subclass this to create container screens that automatically sync
/// [SyncedInt] values from the Java side.
///
/// Example:
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
///     return Watch(
///       value: container.cookProgress,
///       builder: (context, progress) => Text('Progress: $progress'),
///     );
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
/// Manages the [ContainerWatcher] lifecycle automatically.
/// Access the container via [container] and menu ID via [menuId].
abstract class ContainerScreenState<T extends ContainerDefinition>
    extends State<ContainerScreen<T>> {
  late final ContainerWatcher _watcher;

  /// The container definition with synced values.
  T get container => widget.container;

  /// The menu ID from Java for this container instance.
  int get menuId => widget.menuId;

  @override
  void initState() {
    super.initState();
    _watcher = ContainerWatcher(
      container: container,
      menuId: menuId,
    );
    _watcher.start();
  }

  @override
  void dispose() {
    _watcher.stop();
    super.dispose();
  }
}
