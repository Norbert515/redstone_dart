/// Registry for Dart-defined container types.
library;

import 'package:dart_mod_common/dart_mod_common.dart';

import 'dart_container.dart';
import 'container_manager.dart';

/// Definition for a container type.
///
/// Defines the properties of a container that can be opened by blocks
/// or other game elements.
class ContainerDefinition {
  /// Unique identifier for this container type (e.g., "mymod:diamond_chest").
  final String id;

  /// Display title shown at the top of the container screen.
  final String title;

  /// Number of rows in the container grid.
  final int rows;

  /// Number of columns in the container grid (default 9 for chest-like).
  final int columns;

  /// Factory function to create container instances.
  final ContainerFactory factory;

  /// Creates a container definition.
  ///
  /// [id] Must be in the format "namespace:path" (e.g., "mymod:custom_chest")
  /// [title] Display title shown to the player
  /// [rows] Number of rows (default 3)
  /// [columns] Number of columns (default 9)
  /// [factory] Factory function that creates container instances
  const ContainerDefinition({
    required this.id,
    required this.title,
    this.rows = 3,
    this.columns = 9,
    required this.factory,
  });

  /// Total number of slots in this container.
  int get slotCount => rows * columns;
}

/// Registry for container types defined in Dart.
///
/// All container types should be registered during mod initialization.
/// Once registered, containers can be opened by blocks or other game elements.
///
/// Example:
/// ```dart
/// void onModInit() {
///   ContainerRegistry.registerSimple<MyChestContainer>(
///     id: 'mymod:diamond_chest',
///     title: 'Diamond Chest',
///     rows: 3,
///     factory: (menuId) => MyChestContainer(menuId),
///   );
/// }
/// ```
class ContainerRegistry {
  static final Map<String, ContainerDefinition> _definitions = {};
  static bool _initialized = false;

  ContainerRegistry._(); // Private constructor - all static

  /// Register a container type.
  ///
  /// The container type will be available for opening by blocks
  /// and other game elements.
  ///
  /// Throws [ArgumentError] if the ID format is invalid.
  /// Throws [StateError] if a container with this ID is already registered.
  static void register(ContainerDefinition definition) {
    // Validate ID format
    final parts = definition.id.split(':');
    if (parts.length != 2) {
      throw ArgumentError(
        'Invalid container ID format. Expected "namespace:path", got: ${definition.id}',
      );
    }

    if (_definitions.containsKey(definition.id)) {
      throw StateError('Container type already registered: ${definition.id}');
    }

    _definitions[definition.id] = definition;

    // Register with ContainerManager for callback routing
    ContainerManager.registerFactory(definition.id, definition.factory);

    // Notify Java side about this container type
    _registerWithJava(definition);

    print(
        'ContainerRegistry: Registered ${definition.id} (${definition.rows}x${definition.columns})');
  }

  /// Register container type with Java side.
  static void _registerWithJava(ContainerDefinition definition) {
    try {
      GenericJniBridge.callStaticVoidMethod(
        'com/redstone/DartBridge',
        'registerContainerType',
        '(Ljava/lang/String;Ljava/lang/String;II)V',
        [definition.id, definition.title, definition.rows, definition.columns],
      );
    } catch (e) {
      // Log but don't fail - Java side may not have this method yet
      print('ContainerRegistry: Warning - Could not register with Java: $e');
    }
  }

  /// Convenience method to register a simple container.
  ///
  /// This is a shorthand for creating a [ContainerDefinition] and registering it.
  ///
  /// Example:
  /// ```dart
  /// ContainerRegistry.registerSimple<MyContainer>(
  ///   id: 'mymod:custom_chest',
  ///   title: 'Custom Chest',
  ///   rows: 3,
  ///   factory: (menuId) => MyContainer(menuId),
  /// );
  /// ```
  static void registerSimple<T extends DartContainer>({
    required String id,
    required String title,
    int rows = 3,
    int columns = 9,
    required T Function(int menuId) factory,
  }) {
    register(ContainerDefinition(
      id: id,
      title: title,
      rows: rows,
      columns: columns,
      factory: factory,
    ));
  }

  /// Get a container definition by ID.
  ///
  /// Returns null if no container type is registered with that ID.
  static ContainerDefinition? getDefinition(String id) => _definitions[id];

  /// Get all registered container type IDs.
  static List<String> get registeredIds => _definitions.keys.toList();

  /// Get the number of registered container types.
  static int get containerTypeCount => _definitions.length;

  /// Check if a container type is registered.
  static bool isRegistered(String id) => _definitions.containsKey(id);

  /// Initialize the container registry.
  ///
  /// This should be called once during mod startup to set up callback routing.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    // Initialize ContainerManager for callback routing
    ContainerManager.init();

    print('ContainerRegistry: Initialized');
  }

  /// Get all registered container definitions.
  static Iterable<ContainerDefinition> get allDefinitions => _definitions.values;
}
