/// Container definition for the Flutter Display Controller block.
///
/// Synced values allow the client GUI to display and modify settings.
library;

import 'package:dart_mod_common/dart_mod_common.dart';

/// Container definition for the Flutter Display Controller block.
///
/// This container stores the display dimensions (width/height) and active state
/// for synchronization between server and client.
class FlutterDisplayControllerContainer extends ContainerDefinition {
  @override
  String get id => 'minecraft_flutter_dev:flutter_display_controller';

  @override
  int get slotCount => 0; // No inventory slots needed

  /// Display width in blocks, stored as tenths (5 = 0.5, 100 = 10.0).
  ///
  /// Range: 0.5 to 10.0 blocks.
  final SyncedInt widthTenths = SyncedInt();

  /// Display height in blocks, stored as tenths (5 = 0.5, 100 = 10.0).
  ///
  /// Range: 0.5 to 10.0 blocks.
  final SyncedInt heightTenths = SyncedInt();

  /// Whether the display is currently active (has redstone signal).
  ///
  /// 0 = inactive, 1 = active.
  final SyncedInt isActive = SyncedInt();

  FlutterDisplayControllerContainer() {
    // Initialize defaults: 2.0 x 2.0 blocks
    widthTenths.value = 20; // 2.0
    heightTenths.value = 20; // 2.0
    syncedValues([widthTenths, heightTenths, isActive]);
  }

  /// Get the display width in blocks.
  double get width => widthTenths.value / 10.0;

  /// Set the display width in blocks (clamped to 0.5-10.0).
  set width(double w) => widthTenths.value = (w * 10).round().clamp(5, 100);

  /// Get the display height in blocks.
  double get height => heightTenths.value / 10.0;

  /// Set the display height in blocks (clamped to 0.5-10.0).
  set height(double h) => heightTenths.value = (h * 10).round().clamp(5, 100);

  /// Whether the display is currently active (powered by redstone).
  bool get active => isActive.value == 1;
}
