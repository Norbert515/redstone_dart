/// Container definition for the Screen Controller block.
///
/// Synced values allow the client to display the screen state.
library;

import 'package:dart_mod_common/dart_mod_common.dart';

/// Container definition for the Screen Controller block.
///
/// This container stores the active state for synchronization between
/// server and client.
class ScreenControllerContainer extends ContainerDefinition {
  @override
  String get id => 'minecraft_flutter_dev:screen_controller';

  @override
  int get slotCount => 0; // No inventory slots needed

  /// Whether the screen is currently active (has redstone signal).
  ///
  /// 0 = inactive, 1 = active.
  final SyncedInt isActive = SyncedInt();

  ScreenControllerContainer() {
    syncedValues([isActive]);
  }

  /// Whether the screen is currently active (powered by redstone).
  bool get active => isActive.value == 1;
}
