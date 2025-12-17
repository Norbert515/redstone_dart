/// Test environment binding for Minecraft mod tests.
///
/// This binding hooks into the game's tick system to drive
/// async test execution.
library;

import 'dart:async';

import 'package:dart_mc/dart_mc.dart';

/// Singleton binding that initializes the test environment.
///
/// Hooks into [Events.onTick] to drive async test execution.
/// Does NOT do automatic cleanup - users control setUp/tearDown.
class MinecraftTestBinding {
  static MinecraftTestBinding? _instance;

  int _currentTick = 0;
  final Map<int, List<Completer<void>>> _tickCompleters = {};

  MinecraftTestBinding._() {
    _registerTickHandler();
  }

  /// Ensure the binding is initialized.
  ///
  /// Returns the singleton instance, creating it if necessary.
  /// Throws [StateError] if not running inside Minecraft.
  static MinecraftTestBinding ensureInitialized() {
    if (!Bridge.isInitialized) {
      throw StateError(
        'Minecraft tests must be run with "redstone test", not "dart test".\n'
        'The test framework requires a running Minecraft server.\n'
        '\n'
        'Usage:\n'
        '  redstone test              # Run all tests\n'
        '  redstone test test/foo.dart # Run specific test\n',
      );
    }
    _instance ??= MinecraftTestBinding._();
    return _instance!;
  }

  /// Get the singleton instance.
  ///
  /// Throws if [ensureInitialized] hasn't been called.
  static MinecraftTestBinding get instance {
    if (_instance == null) {
      throw StateError(
        'MinecraftTestBinding not initialized. '
        'Call MinecraftTestBinding.ensureInitialized() first.',
      );
    }
    return _instance!;
  }

  /// Get the current game tick.
  int get currentTick => _currentTick;

  /// Register a completer to be completed after [targetTick].
  void registerTickCompleter(int targetTick, Completer<void> completer) {
    _tickCompleters.putIfAbsent(targetTick, () => []).add(completer);
  }

  void _registerTickHandler() {
    Events.onTick(_onTick);
  }

  void _onTick(int tick) {
    _currentTick = tick;

    // Complete all completers for ticks that have passed
    final ticksToRemove = <int>[];
    for (final entry in _tickCompleters.entries) {
      if (entry.key <= tick) {
        for (final completer in entry.value) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
        ticksToRemove.add(entry.key);
      }
    }

    // Clean up completed ticks
    for (final tickToRemove in ticksToRemove) {
      _tickCompleters.remove(tickToRemove);
    }
  }
}
