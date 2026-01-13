import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'game_protocol.dart';

/// HTTP server that runs inside Minecraft to handle game operations.
///
/// This server exposes a REST API for controlling the Minecraft client,
/// including block placement, entity management, input simulation, etc.
class GameServer {
  /// Port to listen on.
  final int port;

  /// The HTTP server instance.
  HttpServer? _server;

  /// Reference to the game context provider.
  ///
  /// This is a function that returns the current game context, or null
  /// if Minecraft isn't ready yet.
  GameContextProvider? gameContextProvider;

  /// Create a new game server.
  GameServer({this.port = 8765});

  /// Whether the server is currently running.
  bool get isRunning => _server != null;

  /// Start the HTTP server.
  Future<void> start() async {
    if (_server != null) {
      throw StateError('Server already running');
    }

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(_router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    // ignore: avoid_print
    print('Game server listening on port $port');
  }

  /// Stop the HTTP server.
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  /// CORS middleware for development.
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await handler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  /// Build the router with all endpoints.
  Router get _router {
    final router = Router();

    // Health check
    router.get('/health', _health);

    // Block operations
    router.post('/block/place', _placeBlock);
    router.get('/block', _getBlock);
    router.post('/block/fill', _fillBlocks);

    // Entity operations
    router.post('/entity/spawn', _spawnEntity);
    router.get('/entities', _getEntities);

    // Player/Camera operations
    router.post('/player/teleport', _teleportPlayer);
    router.post('/camera/position', _positionCamera);
    router.post('/camera/look-at', _lookAt);

    // Screenshot operations
    router.post('/screenshot', _takeScreenshot);
    router.get('/screenshot/<name>', _getScreenshot);

    // Input operations
    router.post('/input/key', _pressKey);
    router.post('/input/click', _click);
    router.post('/input/type', _typeText);
    router.post('/input/mouse/hold', _holdMouse);
    router.post('/input/mouse/release', _releaseMouse);
    router.post('/input/mouse/move', _moveMouse);
    router.post('/input/scroll', _scroll);

    // Time/Command operations
    router.post('/wait', _waitTicks);
    router.post('/time', _setTimeOfDay);
    router.post('/command', _executeCommand);

    // Tick Control operations
    router.post('/tick/freeze', _freezeTicks);
    router.post('/tick/unfreeze', _unfreezeTicks);
    router.post('/tick/step', _stepTicks);
    router.post('/tick/rate', _setTickRate);
    router.post('/tick/sprint', _sprintTicks);
    router.get('/tick/state', _getTickState);

    // Status
    router.get('/status', _getStatus);

    return router;
  }

  // ===========================================================================
  // Helper Methods
  // ===========================================================================

  /// Parse JSON body from request.
  Future<Map<String, dynamic>> _parseBody(Request request) async {
    final body = await request.readAsString();
    if (body.isEmpty) return <String, dynamic>{};
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Create a JSON response.
  Response _jsonResponse(Object data, {int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Create an error response.
  Response _errorResponse(String message, {int statusCode = 500, int? code}) {
    return _jsonResponse(
      ErrorResponse(error: message, code: code).toJson(),
      statusCode: statusCode,
    );
  }

  /// Check if game context is available.
  GameContextProvider? _getContext() {
    final context = gameContextProvider;
    return context;
  }

  /// Return 503 if game not ready.
  Response? _checkGameReady() {
    if (_getContext() == null) {
      return _errorResponse(
        'Minecraft client not running or not ready',
        statusCode: 503,
      );
    }
    return null;
  }

  // ===========================================================================
  // Health/Status Endpoints
  // ===========================================================================

  Future<Response> _health(Request request) async {
    final context = _getContext();
    return _jsonResponse({
      'status': 'ok',
      'gameReady': context != null,
    });
  }

  Future<Response> _getStatus(Request request) async {
    final context = _getContext();
    if (context == null) {
      return _jsonResponse(
        StatusResponse(
          running: false,
          clientReady: false,
        ).toJson(),
      );
    }

    return _jsonResponse(
      StatusResponse(
        running: true,
        clientReady: context.isClientReady,
        currentTick: context.currentTick,
        windowWidth: context.windowWidth,
        windowHeight: context.windowHeight,
      ).toJson(),
    );
  }

  // ===========================================================================
  // Block Endpoints
  // ===========================================================================

  Future<Response> _placeBlock(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = PlaceBlockRequest.fromJson(body);
      final context = _getContext()!;

      context.placeBlock(req.x, req.y, req.z, req.blockId);

      return _jsonResponse(SuccessResponse(message: 'Block placed').toJson());
    } catch (e) {
      return _errorResponse('Failed to place block: $e', statusCode: 400);
    }
  }

  Future<Response> _getBlock(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final x = int.parse(request.url.queryParameters['x'] ?? '0');
      final y = int.parse(request.url.queryParameters['y'] ?? '0');
      final z = int.parse(request.url.queryParameters['z'] ?? '0');
      final context = _getContext()!;

      final blockId = context.getBlock(x, y, z);

      return _jsonResponse(
        BlockResponse(blockId: blockId, x: x, y: y, z: z).toJson(),
      );
    } catch (e) {
      return _errorResponse('Failed to get block: $e', statusCode: 400);
    }
  }

  Future<Response> _fillBlocks(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = FillBlocksRequest.fromJson(body);
      final context = _getContext()!;

      context.fillBlocks(
        req.fromX,
        req.fromY,
        req.fromZ,
        req.toX,
        req.toY,
        req.toZ,
        req.blockId,
      );

      return _jsonResponse(SuccessResponse(message: 'Blocks filled').toJson());
    } catch (e) {
      return _errorResponse('Failed to fill blocks: $e', statusCode: 400);
    }
  }

  // ===========================================================================
  // Entity Endpoints
  // ===========================================================================

  Future<Response> _spawnEntity(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = SpawnEntityRequest.fromJson(body);
      final context = _getContext()!;

      final entity = context.spawnEntity(req.entityType, req.x, req.y, req.z);
      if (entity == null) {
        return _errorResponse('Failed to spawn entity', statusCode: 400);
      }

      return _jsonResponse(entity.toJson());
    } catch (e) {
      return _errorResponse('Failed to spawn entity: $e', statusCode: 400);
    }
  }

  Future<Response> _getEntities(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final centerX = double.parse(request.url.queryParameters['centerX'] ?? '0');
      final centerY = double.parse(request.url.queryParameters['centerY'] ?? '0');
      final centerZ = double.parse(request.url.queryParameters['centerZ'] ?? '0');
      final radius = double.parse(request.url.queryParameters['radius'] ?? '10');
      final entityType = request.url.queryParameters['entityType'];
      final context = _getContext()!;

      final entities = context.getEntities(centerX, centerY, centerZ, radius, entityType: entityType);

      return _jsonResponse(EntitiesResponse(entities: entities).toJson());
    } catch (e) {
      return _errorResponse('Failed to get entities: $e', statusCode: 400);
    }
  }

  // ===========================================================================
  // Player/Camera Endpoints
  // ===========================================================================

  Future<Response> _teleportPlayer(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = TeleportRequest.fromJson(body);
      final context = _getContext()!;

      await context.teleportPlayer(req.x, req.y, req.z);

      return _jsonResponse(SuccessResponse(message: 'Player teleported').toJson());
    } catch (e) {
      return _errorResponse('Failed to teleport player: $e', statusCode: 400);
    }
  }

  Future<Response> _positionCamera(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = PositionCameraRequest.fromJson(body);
      final context = _getContext()!;

      await context.positionCamera(req.x, req.y, req.z, req.yaw, req.pitch);

      return _jsonResponse(SuccessResponse(message: 'Camera positioned').toJson());
    } catch (e) {
      return _errorResponse('Failed to position camera: $e', statusCode: 400);
    }
  }

  Future<Response> _lookAt(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = LookAtRequest.fromJson(body);
      final context = _getContext()!;

      await context.lookAt(req.x, req.y, req.z);

      return _jsonResponse(SuccessResponse(message: 'Camera looking at target').toJson());
    } catch (e) {
      return _errorResponse('Failed to look at position: $e', statusCode: 400);
    }
  }

  // ===========================================================================
  // Screenshot Endpoints
  // ===========================================================================

  Future<Response> _takeScreenshot(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = TakeScreenshotRequest.fromJson(body);
      final context = _getContext()!;

      final path = await context.takeScreenshot(req.name);

      return _jsonResponse(
        ScreenshotResponse(name: req.name, path: path).toJson(),
      );
    } catch (e) {
      return _errorResponse('Failed to take screenshot: $e', statusCode: 400);
    }
  }

  Future<Response> _getScreenshot(Request request, String name) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final context = _getContext()!;
      final base64Data = await context.getScreenshotBase64(name);

      if (base64Data == null) {
        return _errorResponse('Screenshot not found: $name', statusCode: 404);
      }

      return _jsonResponse(
        ScreenshotResponse(name: name, base64Data: base64Data).toJson(),
      );
    } catch (e) {
      return _errorResponse('Failed to get screenshot: $e', statusCode: 400);
    }
  }

  // ===========================================================================
  // Input Endpoints
  // ===========================================================================

  Future<Response> _pressKey(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = PressKeyRequest.fromJson(body);
      final context = _getContext()!;

      if (req.hold && req.duration != null) {
        await context.holdKeyFor(req.keyCode, req.duration!);
      } else if (req.hold) {
        context.holdKey(req.keyCode);
      } else {
        await context.pressKey(req.keyCode);
      }

      return _jsonResponse(SuccessResponse(message: 'Key pressed').toJson());
    } catch (e) {
      return _errorResponse('Failed to press key: $e', statusCode: 400);
    }
  }

  Future<Response> _click(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = ClickRequest.fromJson(body);
      final context = _getContext()!;

      await context.clickAt(req.x.toDouble(), req.y.toDouble(), button: req.button);

      return _jsonResponse(SuccessResponse(message: 'Mouse clicked').toJson());
    } catch (e) {
      return _errorResponse('Failed to click: $e', statusCode: 400);
    }
  }

  Future<Response> _typeText(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = TypeTextRequest.fromJson(body);
      final context = _getContext()!;

      await context.typeChars(req.text);

      return _jsonResponse(SuccessResponse(message: 'Text typed').toJson());
    } catch (e) {
      return _errorResponse('Failed to type text: $e', statusCode: 400);
    }
  }

  Future<Response> _holdMouse(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = HoldMouseRequest.fromJson(body);
      final context = _getContext()!;

      await context.holdMouse(req.button);

      return _jsonResponse(SuccessResponse(message: 'Mouse button held').toJson());
    } catch (e) {
      return _errorResponse('Failed to hold mouse: $e', statusCode: 400);
    }
  }

  Future<Response> _releaseMouse(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = ReleaseMouseRequest.fromJson(body);
      final context = _getContext()!;

      await context.releaseMouse(req.button);

      return _jsonResponse(SuccessResponse(message: 'Mouse button released').toJson());
    } catch (e) {
      return _errorResponse('Failed to release mouse: $e', statusCode: 400);
    }
  }

  Future<Response> _moveMouse(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = MoveMouseRequest.fromJson(body);
      final context = _getContext()!;

      await context.moveMouse(req.x, req.y);

      return _jsonResponse(SuccessResponse(message: 'Mouse moved').toJson());
    } catch (e) {
      return _errorResponse('Failed to move mouse: $e', statusCode: 400);
    }
  }

  Future<Response> _scroll(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = ScrollRequest.fromJson(body);
      final context = _getContext()!;

      await context.scroll(req.horizontal, req.vertical);

      return _jsonResponse(SuccessResponse(message: 'Scrolled').toJson());
    } catch (e) {
      return _errorResponse('Failed to scroll: $e', statusCode: 400);
    }
  }

  // ===========================================================================
  // Time/Command Endpoints
  // ===========================================================================

  Future<Response> _waitTicks(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = WaitTicksRequest.fromJson(body);
      final context = _getContext()!;

      await context.waitTicks(req.ticks);

      return _jsonResponse(SuccessResponse(message: 'Waited ${req.ticks} ticks').toJson());
    } catch (e) {
      return _errorResponse('Failed to wait: $e', statusCode: 400);
    }
  }

  Future<Response> _setTimeOfDay(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = SetTimeRequest.fromJson(body);
      final context = _getContext()!;

      context.setTime(req.time);

      return _jsonResponse(SuccessResponse(message: 'Time set to ${req.time}').toJson());
    } catch (e) {
      return _errorResponse('Failed to set time: $e', statusCode: 400);
    }
  }

  Future<Response> _executeCommand(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = ExecuteCommandRequest.fromJson(body);
      final context = _getContext()!;

      final result = await context.executeCommand(req.command);

      return _jsonResponse(
        CommandResponse(success: true, result: result).toJson(),
      );
    } catch (e) {
      return _jsonResponse(
        CommandResponse(success: false, error: e.toString()).toJson(),
        statusCode: 400,
      );
    }
  }

  // ===========================================================================
  // Tick Control Endpoints
  // ===========================================================================

  Future<Response> _freezeTicks(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final context = _getContext()!;
      context.freezeTicks();
      return _jsonResponse(SuccessResponse(message: 'Ticks frozen').toJson());
    } catch (e) {
      return _errorResponse('Failed to freeze ticks: $e', statusCode: 400);
    }
  }

  Future<Response> _unfreezeTicks(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final context = _getContext()!;
      context.unfreezeTicks();
      return _jsonResponse(SuccessResponse(message: 'Ticks unfrozen').toJson());
    } catch (e) {
      return _errorResponse('Failed to unfreeze ticks: $e', statusCode: 400);
    }
  }

  Future<Response> _stepTicks(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = StepTicksRequest.fromJson(body);
      final context = _getContext()!;

      context.stepTicks(req.count);

      return _jsonResponse(SuccessResponse(message: 'Stepped ${req.count} ticks').toJson());
    } catch (e) {
      return _errorResponse('Failed to step ticks: $e', statusCode: 400);
    }
  }

  Future<Response> _setTickRate(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = SetTickRateRequest.fromJson(body);
      final context = _getContext()!;

      context.setTickRate(req.rate);

      return _jsonResponse(SuccessResponse(message: 'Tick rate set to ${req.rate}').toJson());
    } catch (e) {
      return _errorResponse('Failed to set tick rate: $e', statusCode: 400);
    }
  }

  Future<Response> _sprintTicks(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final body = await _parseBody(request);
      final req = SprintTicksRequest.fromJson(body);
      final context = _getContext()!;

      context.sprintTicks(req.count);

      return _jsonResponse(SuccessResponse(message: 'Sprinting ${req.count} ticks').toJson());
    } catch (e) {
      return _errorResponse('Failed to sprint ticks: $e', statusCode: 400);
    }
  }

  Future<Response> _getTickState(Request request) async {
    final notReady = _checkGameReady();
    if (notReady != null) return notReady;

    try {
      final context = _getContext()!;
      final state = context.getTickState();

      return _jsonResponse(state.toJson());
    } catch (e) {
      return _errorResponse('Failed to get tick state: $e', statusCode: 400);
    }
  }
}

/// Provider interface for game context operations.
///
/// This interface abstracts the game context so the server can be used
/// with different implementations (e.g., ClientGameContext for actual game,
/// mock for testing).
abstract class GameContextProvider {
  /// Whether the client is ready (world loaded, player present).
  bool get isClientReady;

  /// Get the current tick.
  int get currentTick;

  /// Get the window width.
  int? get windowWidth;

  /// Get the window height.
  int? get windowHeight;

  // Block operations
  void placeBlock(int x, int y, int z, String blockId);
  String getBlock(int x, int y, int z);
  void fillBlocks(int fromX, int fromY, int fromZ, int toX, int toY, int toZ, String blockId);

  // Entity operations
  EntityInfo? spawnEntity(String entityType, double x, double y, double z);
  List<EntityInfo> getEntities(double centerX, double centerY, double centerZ, double radius, {String? entityType});

  // Player/Camera operations
  Future<void> teleportPlayer(double x, double y, double z);
  Future<void> positionCamera(double x, double y, double z, double yaw, double pitch);
  Future<void> lookAt(double x, double y, double z);

  // Screenshot operations
  Future<String?> takeScreenshot(String name);
  Future<String?> getScreenshotBase64(String name);

  // Input operations
  Future<void> pressKey(int keyCode);
  void holdKey(int keyCode);
  Future<void> holdKeyFor(int keyCode, int durationMs);
  Future<void> clickAt(double x, double y, {int button});
  Future<void> typeChars(String text);
  Future<void> holdMouse(int button);
  Future<void> releaseMouse(int button);
  Future<void> moveMouse(int x, int y);
  Future<void> scroll(double horizontal, double vertical);

  // Time/Command operations
  Future<void> waitTicks(int ticks);
  void setTime(int time);
  Future<String?> executeCommand(String command);

  // Tick Control operations
  void freezeTicks();
  void unfreezeTicks();
  void stepTicks(int count);
  void setTickRate(double rate);
  void sprintTicks(int count);
  TickStateResponse getTickState();
}
