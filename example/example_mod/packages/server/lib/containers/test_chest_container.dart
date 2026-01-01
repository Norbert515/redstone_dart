import 'package:dart_mod_server/dart_mod_server.dart';

/// A test container for demonstrating Flutter slot integration.
///
/// This container allows any items to be placed in any slot,
/// making it useful for testing the slot rendering system.
class TestChestContainer extends DartContainer {
  TestChestContainer(super.menuId);

  @override
  bool mayPlaceInSlot(int slotIndex, ItemStack item) {
    // Allow any item in any slot
    return true;
  }

  @override
  bool mayPickupFromSlot(int slotIndex) {
    return true;
  }
}
