/// Item registry interface.
library;

import '../item/custom_item.dart';

/// Abstract interface for item registration.
///
/// The actual implementation is in dart_mod_server which handles
/// the FFI calls to register items with the Minecraft server.
abstract class ItemRegistryBase {
  /// Register a custom item type.
  void register(CustomItem item);

  /// Get a registered item by ID.
  CustomItem? get(String id);

  /// Check if an item is registered.
  bool isRegistered(String id);

  /// Get all registered item IDs.
  Iterable<String> get registeredIds;
}
