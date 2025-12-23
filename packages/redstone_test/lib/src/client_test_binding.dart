/// Test environment binding for Minecraft client tests.
///
/// This binding hooks into the server's tick system to drive
/// async test execution for visual/client-side tests.
/// Uses polling to detect when the client is ready.
library;

import 'dart:async';

import 'package:dart_mc/dart_mc.dart';

/// Singleton binding that initializes the client test environment.
///
/// Uses server tick events to poll for client readiness, since the
/// client callback system doesn't have FFI bindings. In singleplayer
/// mode, the integrated server runs alongside the client.
class ClientTestBinding {
  static ClientTestBinding? _instance;

  int _currentTick = 0;
  final Map<int, List<Completer<void>>> _tickCompleters = {};
  bool _clientReady = false;
  final List<Completer<void>> _readyCompleters = [];

  ClientTestBinding._() {
    _registerServerTickHandler();
  }

  /// Ensure the binding is initialized.
  ///
  /// Returns the singleton instance, creating it if necessary.
  /// Throws [StateError] if not running inside Minecraft client.
  static ClientTestBinding ensureInitialized() {
    if (!Bridge.isInitialized) {
      throw StateError(
        'Client tests must be run with "redstone test --client", not "dart test".\n'
        'The test framework requires a running Minecraft client.\n'
        '\n'
        'Usage:\n'
        '  redstone test --client              # Run all client tests\n'
        '  redstone test --client test/foo.dart # Run specific client test\n',
      );
    }
    _instance ??= ClientTestBinding._();
    return _instance!;
  }

  /// Get the singleton instance.
  ///
  /// Throws if [ensureInitialized] hasn't been called.
  static ClientTestBinding get instance {
    if (_instance == null) {
      throw StateError(
        'ClientTestBinding not initialized. '
        'Call ClientTestBinding.ensureInitialized() first.',
      );
    }
    return _instance!;
  }

  /// Get the current tick (from server).
  int get currentTick => _currentTick;

  /// Check if the client is ready (world loaded, player present).
  bool get isClientReady => _clientReady;

  /// Register a completer to be completed after [targetTick].
  void registerTickCompleter(int targetTick, Completer<void> completer) {
    _tickCompleters.putIfAbsent(targetTick, () => []).add(completer);
  }

  /// Wait until the client is ready (world loaded).
  Future<void> waitForClientReady() {
    if (_clientReady) return Future.value();
    final completer = Completer<void>();
    _readyCompleters.add(completer);
    return completer.future;
  }

  void _registerServerTickHandler() {
    // Use server tick events to poll for client readiness.
    // In singleplayer mode, the integrated server runs alongside the client.
    // This avoids needing complex FFI callbacks for client events.
    Events.addTickListener(_onServerTick);
  }

  void _onServerTick(int tick) {
    _currentTick = tick;

    // Poll for client readiness
    if (!_clientReady && ClientBridge.isClientReady()) {
      _clientReady = true;
      // Complete all ready waiters
      for (final completer in _readyCompleters) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
      _readyCompleters.clear();
    }

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
