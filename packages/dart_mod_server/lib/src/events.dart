/// Server-side event system.
library;

/// Event handler function types.
typedef ServerStartingHandler = void Function();
typedef ServerStartedHandler = void Function();
typedef ServerStoppingHandler = void Function();
typedef TickHandler = void Function(int tick);
typedef PlayerJoinHandler = void Function(int playerId);
typedef PlayerLeaveHandler = void Function(int playerId);

/// Server-side event registry.
class ServerEvents {
  static final ServerEvents _instance = ServerEvents._();
  static ServerEvents get instance => _instance;

  ServerEvents._();

  final List<ServerStartingHandler> _serverStartingHandlers = [];
  final List<ServerStartedHandler> _serverStartedHandlers = [];
  final List<ServerStoppingHandler> _serverStoppingHandlers = [];
  final List<TickHandler> _tickHandlers = [];
  final List<PlayerJoinHandler> _playerJoinHandlers = [];
  final List<PlayerLeaveHandler> _playerLeaveHandlers = [];

  /// Register a handler for server starting event.
  void onServerStarting(ServerStartingHandler handler) {
    _serverStartingHandlers.add(handler);
  }

  /// Register a handler for server started event.
  void onServerStarted(ServerStartedHandler handler) {
    _serverStartedHandlers.add(handler);
  }

  /// Register a handler for server stopping event.
  void onServerStopping(ServerStoppingHandler handler) {
    _serverStoppingHandlers.add(handler);
  }

  /// Register a handler for server tick event.
  void onTick(TickHandler handler) {
    _tickHandlers.add(handler);
  }

  /// Register a handler for player join event.
  void onPlayerJoin(PlayerJoinHandler handler) {
    _playerJoinHandlers.add(handler);
  }

  /// Register a handler for player leave event.
  void onPlayerLeave(PlayerLeaveHandler handler) {
    _playerLeaveHandlers.add(handler);
  }

  // ==========================================================================
  // Internal dispatch methods (called by native bridge)
  // ==========================================================================

  void dispatchServerStarting() {
    for (final handler in _serverStartingHandlers) {
      handler();
    }
  }

  void dispatchServerStarted() {
    for (final handler in _serverStartedHandlers) {
      handler();
    }
  }

  void dispatchServerStopping() {
    for (final handler in _serverStoppingHandlers) {
      handler();
    }
  }

  void dispatchTick(int tick) {
    for (final handler in _tickHandlers) {
      handler(tick);
    }
  }

  void dispatchPlayerJoin(int playerId) {
    for (final handler in _playerJoinHandlers) {
      handler(playerId);
    }
  }

  void dispatchPlayerLeave(int playerId) {
    for (final handler in _playerLeaveHandlers) {
      handler(playerId);
    }
  }
}
