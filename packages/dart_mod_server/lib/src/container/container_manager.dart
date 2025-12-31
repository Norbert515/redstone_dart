/// Manages container registration and callback routing.
///
/// This class provides the glue between Java container menu events
/// and Dart container instances, routing callbacks to the appropriate
/// [DartContainer] subclass.
library;

import 'package:dart_mod_common/dart_mod_common.dart';

import 'dart_container.dart';
import 'container_callbacks.dart';

/// Factory function type for creating container instances.
///
/// Takes a menu ID and returns a new [DartContainer] subclass instance.
typedef ContainerFactory = DartContainer Function(int menuId);

/// Manages container registration and callback routing.
///
/// Use this class to:
/// - Register container factories for specific container type IDs
/// - Initialize callback routing (call [init] once during mod startup)
/// - Create container instances when menus open
///
/// Example:
/// ```dart
/// // During mod initialization
/// ContainerManager.init();
///
/// // Register a factory for your container type
/// ContainerManager.registerFactory('mymod:custom_chest', (menuId) {
///   return MyCustomChestContainer(menuId);
/// });
/// ```
class ContainerManager {
  static final Map<String, ContainerFactory> _factories = {};
  static ContainerFactory? _defaultFactory;
  static bool _initialized = false;

  /// Register a container factory for a container type ID.
  ///
  /// When a container menu is opened with the given type ID,
  /// the factory will be called to create a [DartContainer] instance.
  ///
  /// [typeId] The container type identifier (e.g., 'mymod:custom_chest')
  /// [factory] Function that creates a new container instance
  static void registerFactory(String typeId, ContainerFactory factory) {
    _factories[typeId] = factory;
  }

  /// Unregister a container factory.
  ///
  /// [typeId] The container type identifier to unregister
  static void unregisterFactory(String typeId) {
    _factories.remove(typeId);
  }

  /// Set default factory for unregistered container types.
  ///
  /// This factory will be used when no specific factory is registered
  /// for a container type. Set to null to disable default handling.
  static void setDefaultFactory(ContainerFactory? factory) {
    _defaultFactory = factory;
  }

  /// Create a container instance for the given type and menu ID.
  ///
  /// Returns null if no factory is registered for the type and no
  /// default factory is set.
  static DartContainer? createContainer(String typeId, int menuId) {
    final factory = _factories[typeId] ?? _defaultFactory;
    if (factory == null) return null;
    return factory(menuId);
  }

  /// Check if a factory is registered for a container type.
  static bool hasFactory(String typeId) {
    return _factories.containsKey(typeId);
  }

  /// Initialize the callback routing.
  ///
  /// This sets up callback handlers that route container menu events
  /// to the appropriate [DartContainer] instances.
  ///
  /// Call this once during mod initialization, typically in your main() function.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    // Initialize container callbacks
    initContainerMenuCallbacks();

    // Set up Dart-side handlers that route to DartContainer instances
    setSlotClickHandler(_handleSlotClick);
    setQuickMoveHandler(_handleQuickMove);
    setMayPlaceHandler(_handleMayPlace);
    setMayPickupHandler(_handleMayPickup);

    print('ContainerManager: Initialized');
  }

  static int _handleSlotClick(int menuId, int slotIndex, int button,
      ClickType clickType, ItemStack carriedItem) {
    final container = DartContainer.getContainer(menuId);
    if (container == null) return 0;
    return container.onSlotClick(slotIndex, button, clickType, carriedItem);
  }

  static ItemStack? _handleQuickMove(int menuId, int slotIndex) {
    final container = DartContainer.getContainer(menuId);
    if (container == null) return null;
    return container.onQuickMove(slotIndex);
  }

  static bool _handleMayPlace(int menuId, int slotIndex, ItemStack item) {
    final container = DartContainer.getContainer(menuId);
    if (container == null) return true;
    return container.mayPlaceInSlot(slotIndex, item);
  }

  static bool _handleMayPickup(int menuId, int slotIndex) {
    final container = DartContainer.getContainer(menuId);
    if (container == null) return true;
    return container.mayPickupFromSlot(slotIndex);
  }
}
