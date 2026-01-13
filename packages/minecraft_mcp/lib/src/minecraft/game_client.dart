import 'dart:convert';

import 'package:http/http.dart' as http;

import '../protocol/game_protocol.dart';

/// HTTP client for communicating with the game server.
///
/// This client is used by the MCP server to send commands to the
/// Minecraft client running the game server.
class GameClient {
  /// Base URL of the game server.
  final String baseUrl;

  /// HTTP client instance.
  final http.Client _client;

  /// Create a new game client.
  GameClient({
    String host = 'localhost',
    int port = 8765,
    http.Client? client,
  })  : baseUrl = 'http://$host:$port',
        _client = client ?? http.Client();

  /// Close the HTTP client.
  void close() => _client.close();

  // ===========================================================================
  // Helper Methods
  // ===========================================================================

  /// Send a GET request and parse JSON response.
  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? queryParams]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final response = await _client.get(uri);
    _checkResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Send a POST request with JSON body.
  Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    _checkResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Check response status and throw if error.
  void _checkResponse(http.Response response) {
    if (response.statusCode >= 400) {
      final body = response.body;
      String message;
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        message = json['error'] as String? ?? 'Unknown error';
      } catch (_) {
        message = body.isNotEmpty ? body : 'HTTP ${response.statusCode}';
      }
      throw GameClientException(message, response.statusCode);
    }
  }

  // ===========================================================================
  // Health/Status
  // ===========================================================================

  /// Check if the game server is healthy and reachable.
  Future<bool> isHealthy() async {
    try {
      final response = await _get('/health');
      return response['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Get the current game status.
  Future<StatusResponse> getStatus() async {
    final response = await _get('/status');
    return StatusResponse.fromJson(response);
  }

  // ===========================================================================
  // Block Operations
  // ===========================================================================

  /// Place a block at the specified coordinates.
  Future<void> placeBlock(int x, int y, int z, String blockId) async {
    await _post('/block/place', {
      'x': x,
      'y': y,
      'z': z,
      'blockId': blockId,
    });
  }

  /// Get the block at the specified coordinates.
  Future<String> getBlock(int x, int y, int z) async {
    final response = await _get('/block', {
      'x': x.toString(),
      'y': y.toString(),
      'z': z.toString(),
    });
    return BlockResponse.fromJson(response).blockId;
  }

  /// Fill a region with blocks.
  Future<void> fillBlocks(
    int fromX,
    int fromY,
    int fromZ,
    int toX,
    int toY,
    int toZ,
    String blockId,
  ) async {
    await _post('/block/fill', {
      'fromX': fromX,
      'fromY': fromY,
      'fromZ': fromZ,
      'toX': toX,
      'toY': toY,
      'toZ': toZ,
      'blockId': blockId,
    });
  }

  // ===========================================================================
  // Entity Operations
  // ===========================================================================

  /// Spawn an entity at the specified location.
  Future<EntityInfo> spawnEntity(
    String entityType,
    double x,
    double y,
    double z,
  ) async {
    final response = await _post('/entity/spawn', {
      'entityType': entityType,
      'x': x,
      'y': y,
      'z': z,
    });
    return EntityInfo.fromJson(response);
  }

  /// Query entities within a radius of a position.
  Future<List<EntityInfo>> getEntities(
    double centerX,
    double centerY,
    double centerZ,
    double radius, {
    String? entityType,
  }) async {
    final params = {
      'centerX': centerX.toString(),
      'centerY': centerY.toString(),
      'centerZ': centerZ.toString(),
      'radius': radius.toString(),
    };
    if (entityType != null) {
      params['entityType'] = entityType;
    }
    final response = await _get('/entities', params);
    return EntitiesResponse.fromJson(response).entities;
  }

  // ===========================================================================
  // Player/Camera Operations
  // ===========================================================================

  /// Teleport the player to the specified coordinates.
  Future<void> teleportPlayer(double x, double y, double z) async {
    await _post('/player/teleport', {
      'x': x,
      'y': y,
      'z': z,
    });
  }

  /// Set the camera position and orientation.
  Future<void> positionCamera(
    double x,
    double y,
    double z,
    double yaw,
    double pitch,
  ) async {
    await _post('/camera/position', {
      'x': x,
      'y': y,
      'z': z,
      'yaw': yaw,
      'pitch': pitch,
    });
  }

  /// Make the player look at a specific position.
  Future<void> lookAt(double x, double y, double z) async {
    await _post('/camera/look-at', {
      'x': x,
      'y': y,
      'z': z,
    });
  }

  // ===========================================================================
  // Screenshot Operations
  // ===========================================================================

  /// Take a screenshot with the specified name.
  ///
  /// Returns the path to the saved screenshot.
  Future<String?> takeScreenshot(String name) async {
    final response = await _post('/screenshot', {'name': name});
    return ScreenshotResponse.fromJson(response).path;
  }

  /// Get a screenshot as base64-encoded data.
  Future<String?> getScreenshotBase64(String name) async {
    final response = await _get('/screenshot/$name');
    return ScreenshotResponse.fromJson(response).base64Data;
  }

  // ===========================================================================
  // Input Operations
  // ===========================================================================

  /// Press and release a key.
  Future<void> pressKey(int keyCode) async {
    await _post('/input/key', {
      'keyCode': keyCode,
      'hold': false,
    });
  }

  /// Hold a key for a duration.
  Future<void> holdKeyFor(int keyCode, int durationMs) async {
    await _post('/input/key', {
      'keyCode': keyCode,
      'hold': true,
      'duration': durationMs,
    });
  }

  /// Click at a position on screen.
  Future<void> click(int button, int x, int y) async {
    await _post('/input/click', {
      'button': button,
      'x': x,
      'y': y,
    });
  }

  /// Type text into the current input field.
  Future<void> typeText(String text) async {
    await _post('/input/type', {
      'text': text,
    });
  }

  /// Hold a mouse button down.
  Future<void> holdMouse(int button) async {
    await _post('/input/mouse/hold', {
      'button': button,
    });
  }

  /// Release a held mouse button.
  Future<void> releaseMouse(int button) async {
    await _post('/input/mouse/release', {
      'button': button,
    });
  }

  /// Move the mouse cursor to screen coordinates.
  Future<void> moveMouse(int x, int y) async {
    await _post('/input/mouse/move', {
      'x': x,
      'y': y,
    });
  }

  /// Scroll the mouse wheel.
  Future<void> scroll(double horizontal, double vertical) async {
    await _post('/input/scroll', {
      'horizontal': horizontal,
      'vertical': vertical,
    });
  }

  // ===========================================================================
  // Time/Command Operations
  // ===========================================================================

  /// Wait for a specified number of game ticks.
  Future<void> waitTicks(int ticks) async {
    await _post('/wait', {
      'ticks': ticks,
    });
  }

  /// Set the in-game time of day.
  Future<void> setTimeOfDay(int time) async {
    await _post('/time', {
      'time': time,
    });
  }

  /// Execute a Minecraft command.
  ///
  /// Returns the command result if successful.
  Future<String?> executeCommand(String command) async {
    final response = await _post('/command', {
      'command': command,
    });
    final result = CommandResponse.fromJson(response);
    if (!result.success) {
      throw GameClientException(result.error ?? 'Command failed', 400);
    }
    return result.result;
  }

  // ===========================================================================
  // Tick Control Operations
  // ===========================================================================

  /// Freeze game ticks.
  ///
  /// Players continue to move but world stops updating.
  Future<void> freezeTicks() async {
    await _post('/tick/freeze');
  }

  /// Unfreeze game ticks.
  ///
  /// Resumes normal game execution.
  Future<void> unfreezeTicks() async {
    await _post('/tick/unfreeze');
  }

  /// Step forward by a specific number of ticks.
  ///
  /// Auto-freezes if not already frozen.
  Future<void> stepTicks(int count) async {
    await _post('/tick/step', {'count': count});
  }

  /// Set the game tick rate.
  ///
  /// Default is 20 ticks per second. Range: 1-10000.
  Future<void> setTickRate(double rate) async {
    await _post('/tick/rate', {'rate': rate});
  }

  /// Sprint through a number of ticks as fast as possible.
  ///
  /// No delay between ticks.
  Future<void> sprintTicks(int count) async {
    await _post('/tick/sprint', {'count': count});
  }

  /// Get the current tick state.
  ///
  /// Returns information about frozen state, tick rate, stepping, and sprinting.
  Future<TickStateResponse> getTickState() async {
    final response = await _get('/tick/state');
    return TickStateResponse.fromJson(response);
  }
}

/// Exception thrown by the game client.
class GameClientException implements Exception {
  /// Error message.
  final String message;

  /// HTTP status code if applicable.
  final int? statusCode;

  GameClientException(this.message, [this.statusCode]);

  @override
  String toString() {
    if (statusCode != null) {
      return 'GameClientException: $message (HTTP $statusCode)';
    }
    return 'GameClientException: $message';
  }
}
