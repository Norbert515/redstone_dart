/// Block registry interface.
library;

import '../block/custom_block.dart';

/// Abstract interface for block registration.
///
/// The actual implementation is in dart_mod_server which handles
/// the FFI calls to register blocks with the Minecraft server.
abstract class BlockRegistryBase {
  /// Register a custom block type.
  void register(CustomBlock block);

  /// Get a registered block by ID.
  CustomBlock? get(String id);

  /// Check if a block is registered.
  bool isRegistered(String id);

  /// Get all registered block IDs.
  Iterable<String> get registeredIds;
}
