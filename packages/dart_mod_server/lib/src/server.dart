/// Server lifecycle and tick control API.
///
/// Provides access to server status, tick control, and graceful shutdown
/// from Dart code.
library;

import 'dart:convert';

import 'package:dart_mod_common/src/jni/jni_internal.dart';

/// Server lifecycle and tick control.
///
/// This class provides static methods to:
/// - Query server status (running, player count, uptime, TPS)
/// - Control game ticks (freeze, unfreeze, step, sprint, set rate)
/// - Gracefully halt the server
///
/// Example:
/// ```dart
/// // Check server status
/// if (Server.isRunning) {
///   print('Players: ${Server.playerCount}');
///   print('TPS: ${Server.ticksPerSecond}');
/// }
///
/// // Freeze time for testing
/// Server.freezeTicks();
/// // ... do something ...
/// Server.stepTicks(1); // Advance one tick
/// Server.unfreezeTicks();
///
/// // Graceful shutdown
/// Server.halt();
/// ```
class Server {
  Server._();

  static const _dartBridge = 'com/redstone/DartBridge';

  // ===========================================================================
  // Status
  // ===========================================================================

  /// Whether the server is currently running.
  static bool get isRunning {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isServerRunning',
      '()Z',
    );
  }

  /// Current number of players connected to the server.
  static int get playerCount {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getPlayerCount',
      '()I',
    );
  }

  /// Server uptime since start.
  static Duration get uptime {
    final millis = GenericJniBridge.callStaticLongMethod(
      _dartBridge,
      'getServerUptime',
      '()J',
    );
    return Duration(milliseconds: millis);
  }

  /// Current ticks per second.
  ///
  /// A healthy server runs at 20 TPS. Lower values indicate lag.
  /// The value is capped at 20.0 even if the server is running faster.
  static double get ticksPerSecond {
    final avgTickTime = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getAverageTickTime',
      '()D',
    );
    if (avgTickTime <= 0) return 20.0;
    return (1000.0 / avgTickTime).clamp(0.0, 20.0);
  }

  // ===========================================================================
  // Tick Control
  // ===========================================================================

  /// Set the game tick rate.
  ///
  /// Default is 20 ticks per second. Range: 1-10000.
  /// Higher values speed up the game, lower values slow it down.
  static void setTickRate(double tps) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setTickRate',
      '(D)V',
      [tps],
    );
  }

  /// Freeze game ticks.
  ///
  /// While frozen, players can still move but world updates stop.
  /// Use [stepTicks] to manually advance time while frozen.
  static void freezeTicks() {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'freezeTicks',
      '()V',
    );
  }

  /// Unfreeze game ticks and resume normal game execution.
  static void unfreezeTicks() {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'unfreezeTicks',
      '()V',
    );
  }

  /// Step forward by a specific number of ticks while frozen.
  ///
  /// If not already frozen, this will auto-freeze first.
  static void stepTicks(int count) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'stepTicks',
      '(I)V',
      [count],
    );
  }

  /// Run a number of ticks as fast as possible (no delay between ticks).
  ///
  /// Useful for fast-forwarding through time in tests.
  static void sprintTicks(int count) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'sprintTicks',
      '(I)V',
      [count],
    );
  }

  /// Whether game ticks are currently frozen.
  static bool get isTicksFrozen {
    final state = _getTickState();
    return state['frozen'] as bool? ?? false;
  }

  /// Current tick rate (ticks per second setting).
  static double get tickRate {
    final state = _getTickState();
    return (state['tickRate'] as num?)?.toDouble() ?? 20.0;
  }

  /// Whether the server is currently sprinting ticks.
  static bool get isSprinting {
    final state = _getTickState();
    return state['sprinting'] as bool? ?? false;
  }

  /// Whether the server is currently stepping through ticks.
  static bool get isStepping {
    final state = _getTickState();
    return state['stepping'] as bool? ?? false;
  }

  static Map<String, dynamic> _getTickState() {
    final json = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getTickState',
      '()Ljava/lang/String;',
    );
    if (json == null || json.isEmpty) {
      return {
        'frozen': false,
        'tickRate': 20.0,
        'stepping': false,
        'sprinting': false,
      };
    }
    return jsonDecode(json) as Map<String, dynamic>;
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  /// Stop the Minecraft server gracefully.
  ///
  /// This will save the world and disconnect all players before shutting down.
  static void halt() {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'stopServer',
      '()V',
    );
  }
}
