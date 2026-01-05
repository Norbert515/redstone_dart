/// Type-safe registry for mapping ContainerDefinition types to screen builders.
library;

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:flutter/widgets.dart';

/// Builder function for creating container screens.
///
/// Takes the container definition and menu ID, returns a widget.
typedef ContainerScreenBuilder<T extends ContainerDefinition> = Widget Function(
  T container,
  int menuId,
);

/// Type-safe registry for mapping [ContainerDefinition] types to screen builders.
///
/// This registry enables automatic screen creation based on container type.
/// Register a builder for each container type, then use [build] to create
/// the appropriate screen when a container is opened.
///
/// Example:
/// ```dart
/// // During mod initialization:
/// GuiRegistry.register<SimpleFurnaceContainer>((container, menuId) {
///   return FurnaceScreen(container: container, menuId: menuId);
/// });
///
/// // When container opens (called by GuiRouter):
/// final screen = GuiRegistry.build(myFurnaceContainer, menuId);
/// ```
class GuiRegistry {
  static final Map<Type, ContainerScreenBuilder<ContainerDefinition>>
      _builders = {};

  // Private constructor to prevent instantiation
  GuiRegistry._();

  /// Register a screen builder for a container type.
  ///
  /// The builder will be called when [build] is invoked with a container
  /// of the registered type.
  ///
  /// Example:
  /// ```dart
  /// GuiRegistry.register<SimpleFurnaceContainer>((container, menuId) {
  ///   return FurnaceScreen(container: container, menuId: menuId);
  /// });
  /// ```
  static void register<T extends ContainerDefinition>(
    ContainerScreenBuilder<T> builder,
  ) {
    _builders[T] = (container, menuId) => builder(container as T, menuId);
  }

  /// Build a screen for a container.
  ///
  /// Returns a widget built by the registered builder for this container's
  /// runtime type, or null if no builder is registered.
  ///
  /// This is typically called by [GuiRouter] when a container opens.
  static Widget? build(ContainerDefinition container, int menuId) {
    final builder = _builders[container.runtimeType];
    if (builder != null) {
      return builder(container, menuId);
    }
    return null;
  }

  /// Check if a screen builder is registered for a container type.
  ///
  /// Returns true if [register] has been called for type [T].
  static bool has<T extends ContainerDefinition>() => _builders.containsKey(T);

  /// Check if a screen builder is registered for a container instance.
  ///
  /// Returns true if [register] has been called for the container's runtime type.
  static bool hasFor(ContainerDefinition container) =>
      _builders.containsKey(container.runtimeType);

  /// Clear all registered builders.
  ///
  /// Primarily useful for testing.
  static void clear() => _builders.clear();
}
