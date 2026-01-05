/// Service that polls container data from Java and updates SyncedInt values.
library;

import 'dart:async';

import 'package:dart_mod_common/dart_mod_common.dart';

/// The Java class name for DartBridgeClient.
const _dartBridgeClient = 'com/redstone/DartBridgeClient';

/// Polls container data from Java at regular intervals and updates SyncedInt values.
///
/// This service bridges the gap between Java's ContainerData system and Dart's
/// [SyncedInt] listener pattern. It polls the Java side for updated values and
/// pushes them to the corresponding [SyncedInt] instances.
///
/// The polling interval is 50ms by default (matching Minecraft's typical tick rate
/// of 20 ticks per second).
///
/// Example:
/// ```dart
/// // In your screen's initState:
/// final watcher = ContainerWatcher(
///   container: myFurnaceContainer,
///   menuId: menuId,
/// );
/// watcher.start();
///
/// // In your screen's dispose:
/// watcher.stop();
/// ```
class ContainerWatcher {
  /// The container definition whose values will be synced.
  final ContainerDefinition container;

  /// The menu ID for this container instance.
  final int menuId;

  /// The polling interval for syncing values.
  final Duration pollInterval;

  Timer? _timer;

  /// Creates a ContainerWatcher.
  ///
  /// [container] is the ContainerDefinition containing SyncedInt values.
  /// [menuId] is the active menu ID from Java.
  /// [pollInterval] defaults to 50ms (matching Minecraft's tick rate).
  ContainerWatcher({
    required this.container,
    required this.menuId,
    this.pollInterval = const Duration(milliseconds: 50),
  });

  /// Whether the watcher is currently running.
  bool get isRunning => _timer != null && _timer!.isActive;

  /// Start polling for container data updates.
  ///
  /// Performs an immediate sync on start, then continues at [pollInterval].
  void start() {
    if (isRunning) return;

    print('[ContainerWatcher] Starting watcher for ${container.runtimeType}, menuId=$menuId');
    print('[ContainerWatcher] syncedValuesList has ${container.syncedValuesList.length} values');
    for (final v in container.syncedValuesList) {
      print('[ContainerWatcher]   - dataSlotIndex=${v.dataSlotIndex}, value=${v.value}');
    }

    // Immediate sync on start
    _sync();

    // Periodic sync
    _timer = Timer.periodic(pollInterval, (_) => _sync());
  }

  /// Stop polling for container data updates.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Perform a single sync of all container data values.
  void _sync() {
    final syncedValues = container.syncedValuesList;

    for (final value in syncedValues) {
      final dataIndex = value.dataSlotIndex;
      if (dataIndex < 0) continue;

      final newValue = _getContainerDataSlot(dataIndex);
      if (newValue != 0) {
        print('[ContainerWatcher] Slot $dataIndex: $newValue');
      }
      value.updateFromSync(newValue);
    }
  }

  /// Get a ContainerData slot value from Java.
  int _getContainerDataSlot(int dataIndex) {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridgeClient,
      'getContainerDataSlot',
      '(I)I',
      [dataIndex],
    );
  }
}
