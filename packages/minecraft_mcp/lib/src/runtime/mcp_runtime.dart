import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mod_common/src/jni/jni_internal.dart';
import 'package:dart_mod_server/dart_mod_server.dart';

import '../protocol/game_protocol.dart';
import '../protocol/game_server.dart';

/// MCP runtime that runs inside the Minecraft process.
///
/// This component starts the HTTP server and provides game context to it,
/// enabling external MCP clients to control the Minecraft game.
///
/// The runtime bridges the `GameContextProvider` interface expected by
/// `GameServer` with the actual `ClientGameContext` from dart_mod_server.
class McpRuntime implements GameContextProvider {
  /// Port for the HTTP server.
  final int port;

  /// The HTTP game server.
  GameServer? _server;

  /// Binding for tick events and client readiness.
  McpRuntimeBinding? _binding;

  /// Create a new MCP runtime.
  McpRuntime({this.port = 8765});

  /// Whether the runtime has been initialized.
  bool get isInitialized => _server != null;

  /// Initialize the MCP runtime.
  ///
  /// This starts the HTTP server and sets up the game context provider.
  /// Call this after the Minecraft client is ready.
  Future<void> initialize() async {
    if (_server != null) {
      throw StateError('MCP runtime already initialized');
    }

    // Ensure the bridge is initialized (we're running inside Minecraft)
    if (!Bridge.isInitialized) {
      throw StateError('MCP runtime must be run inside Minecraft');
    }

    // Create our binding for tick events
    _binding = McpRuntimeBinding._initialize();

    // Wait for client to be ready
    await _binding!.waitForClientReady();

    // Start the HTTP server
    _server = GameServer(port: port);
    _server!.gameContextProvider = this;
    await _server!.start();

    // Print marker that MinecraftController looks for
    // ignore: avoid_print
    print('[MCP] Server ready on port $port');
  }

  /// Shutdown the MCP runtime.
  Future<void> shutdown() async {
    await _server?.stop();
    _server = null;
  }

  // ===========================================================================
  // GameContextProvider Implementation
  // ===========================================================================

  @override
  bool get isClientReady => _binding?.isClientReady ?? false;

  @override
  int get currentTick => _binding?.currentTick ?? 0;

  @override
  int? get windowWidth => ClientBridge.getWindowWidth();

  @override
  int? get windowHeight => ClientBridge.getWindowHeight();

  // ---------------------------------------------------------------------------
  // Block Operations
  // ---------------------------------------------------------------------------

  @override
  void placeBlock(int x, int y, int z, String blockId) {
    _ensureReady();
    final block = Block(blockId);
    World.overworld.setBlock(BlockPos(x, y, z), block);
  }

  @override
  String getBlock(int x, int y, int z) {
    _ensureReady();
    final block = World.overworld.getBlock(BlockPos(x, y, z));
    return block.id;
  }

  @override
  void fillBlocks(
    int fromX,
    int fromY,
    int fromZ,
    int toX,
    int toY,
    int toZ,
    String blockId,
  ) {
    _ensureReady();
    final block = Block(blockId);

    final minX = fromX < toX ? fromX : toX;
    final maxX = fromX > toX ? fromX : toX;
    final minY = fromY < toY ? fromY : toY;
    final maxY = fromY > toY ? fromY : toY;
    final minZ = fromZ < toZ ? fromZ : toZ;
    final maxZ = fromZ > toZ ? fromZ : toZ;

    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        for (var z = minZ; z <= maxZ; z++) {
          World.overworld.setBlock(BlockPos(x, y, z), block);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Entity Operations
  // ---------------------------------------------------------------------------

  @override
  EntityInfo? spawnEntity(String entityType, double x, double y, double z) {
    _ensureReady();
    final entity = Entities.spawn(World.overworld, entityType, Vec3(x, y, z));
    if (entity == null) return null;

    // Get health if it's a living entity
    double? health;
    bool isAlive = true;
    if (entity is LivingEntity) {
      health = entity.health;
      isAlive = !entity.isDead;
    }

    return EntityInfo(
      id: entity.id.toString(),
      type: entity.type,
      x: entity.position.x,
      y: entity.position.y,
      z: entity.position.z,
      health: health,
      isAlive: isAlive,
    );
  }

  @override
  List<EntityInfo> getEntities(
    double centerX,
    double centerY,
    double centerZ,
    double radius, {
    String? entityType,
  }) {
    _ensureReady();
    var entities = Entities.getEntitiesInRadius(
      World.overworld,
      Vec3(centerX, centerY, centerZ),
      radius,
    );

    // Filter by type if specified
    if (entityType != null) {
      entities = entities.where((e) => e.type == entityType).toList();
    }

    return entities.map((e) {
      // Get health if it's a living entity
      double? health;
      bool isAlive = true;
      if (e is LivingEntity) {
        health = e.health;
        isAlive = !e.isDead;
      }

      return EntityInfo(
        id: e.id.toString(),
        type: e.type,
        x: e.position.x,
        y: e.position.y,
        z: e.position.z,
        health: health,
        isAlive: isAlive,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Player/Camera Operations
  // ---------------------------------------------------------------------------

  @override
  Future<void> teleportPlayer(double x, double y, double z) async {
    _ensureReady();
    final players = Players.getAllPlayers();
    if (players.isEmpty) {
      throw StateError('No players in game');
    }
    players.first.teleport(BlockPos(x.toInt(), y.toInt(), z.toInt()));
    await waitTicks(1);
  }

  @override
  Future<void> positionCamera(
    double x,
    double y,
    double z,
    double yaw,
    double pitch,
  ) async {
    _ensureReady();
    ClientBridge.positionCamera(x, y, z, yaw: yaw, pitch: pitch);
    await waitTicks(1);
  }

  @override
  Future<void> lookAt(double x, double y, double z) async {
    _ensureReady();
    ClientBridge.lookAt(x, y, z);
    await waitTicks(1);
  }

  // ---------------------------------------------------------------------------
  // Screenshot Operations
  // ---------------------------------------------------------------------------

  @override
  Future<String?> takeScreenshot(String name) async {
    _ensureReady();
    await waitTicks(1); // Wait for pending renders
    final path = ClientBridge.takeScreenshot(name);
    await waitTicks(2); // Wait for screenshot to be written
    return path;
  }

  @override
  Future<String?> getScreenshotBase64(String name) async {
    _ensureReady();
    final screenshotsDir = ClientBridge.getScreenshotsDirectory();
    if (screenshotsDir == null) return null;

    final file = File('$screenshotsDir/$name.png');
    if (!await file.exists()) {
      // Try without extension
      final fileNoExt = File('$screenshotsDir/$name');
      if (!await fileNoExt.exists()) return null;
      final bytes = await fileNoExt.readAsBytes();
      return base64Encode(bytes);
    }

    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  // ---------------------------------------------------------------------------
  // Input Operations
  // ---------------------------------------------------------------------------

  @override
  Future<void> pressKey(int keyCode) async {
    _ensureReady();
    ClientBridge.pressKey(keyCode);
    await waitTicks(1);
    ClientBridge.releaseKey(keyCode);
    await waitTicks(1);
  }

  @override
  void holdKey(int keyCode) {
    _ensureReady();
    ClientBridge.holdKey(keyCode);
  }

  @override
  Future<void> holdKeyFor(int keyCode, int durationMs) async {
    _ensureReady();
    ClientBridge.holdKey(keyCode);
    // Convert ms to ticks (approximately)
    final ticks = (durationMs / 50).ceil();
    await waitTicks(ticks);
    ClientBridge.releaseKey(keyCode);
    await waitTicks(1);
  }

  @override
  Future<void> clickAt(double x, double y, {int button = 0}) async {
    _ensureReady();
    ClientBridge.setCursorPos(x, y);
    await waitTicks(1);
    ClientBridge.clickMouse(button);
    await waitTicks(1);
  }

  @override
  Future<void> typeChars(String text) async {
    _ensureReady();
    ClientBridge.typeChars(text);
    await waitTicks(1);
  }

  @override
  Future<void> holdMouse(int button) async {
    _ensureReady();
    ClientBridge.holdMouse(button);
    await waitTicks(1);
  }

  @override
  Future<void> releaseMouse(int button) async {
    _ensureReady();
    ClientBridge.releaseMouse(button);
    await waitTicks(1);
  }

  @override
  Future<void> moveMouse(int x, int y) async {
    _ensureReady();
    ClientBridge.setCursorPos(x.toDouble(), y.toDouble());
    await waitTicks(1);
  }

  @override
  Future<void> scroll(double horizontal, double vertical) async {
    _ensureReady();
    ClientBridge.scroll(horizontal, vertical);
    await waitTicks(1);
  }

  // ---------------------------------------------------------------------------
  // Time/Command Operations
  // ---------------------------------------------------------------------------

  @override
  Future<void> waitTicks(int ticks) {
    if (ticks <= 0 || _binding == null) return Future.value();

    final completer = Completer<void>();
    final targetTick = _binding!.currentTick + ticks;
    _binding!.registerTickCompleter(targetTick, completer);
    return completer.future;
  }

  @override
  void setTime(int time) {
    _ensureReady();
    World.overworld.timeOfDay = time;
  }

  @override
  Future<String?> executeCommand(String command) async {
    _ensureReady();
    CommandExecutor.execute(command);
    return 'executed';
  }

  // ---------------------------------------------------------------------------
  // Tick Control Operations
  // ---------------------------------------------------------------------------

  @override
  void freezeTicks() {
    _ensureReady();
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridge',
      'freezeTicks',
      '()V',
      [],
    );
  }

  @override
  void unfreezeTicks() {
    _ensureReady();
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridge',
      'unfreezeTicks',
      '()V',
      [],
    );
  }

  @override
  void stepTicks(int count) {
    _ensureReady();
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridge',
      'stepTicks',
      '(I)V',
      [count],
    );
  }

  @override
  void setTickRate(double rate) {
    _ensureReady();
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridge',
      'setTickRate',
      '(D)V',
      [rate],
    );
  }

  @override
  void sprintTicks(int count) {
    _ensureReady();
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridge',
      'sprintTicks',
      '(I)V',
      [count],
    );
  }

  @override
  TickStateResponse getTickState() {
    _ensureReady();
    final jsonStr = GenericJniBridge.callStaticStringMethod(
      'com/redstone/DartBridge',
      'getTickState',
      '()Ljava/lang/String;',
      [],
    );
    if (jsonStr == null) {
      // Return default state if Java returns null
      return TickStateResponse(
        frozen: false,
        tickRate: 20.0,
        stepping: false,
        sprinting: false,
        frozenTicksToRun: 0,
      );
    }
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return TickStateResponse.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Player Inventory Operations
  // ---------------------------------------------------------------------------

  @override
  void clearInventory() {
    _ensureReady();
    final players = Players.getAllPlayers();
    if (players.isEmpty) return;
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridge',
      'clearPlayerInventory',
      '(I)V',
      [players.first.id],
    );
  }

  @override
  bool giveItem(String itemId, int count) {
    _ensureReady();
    final players = Players.getAllPlayers();
    if (players.isEmpty) return false;
    return GenericJniBridge.callStaticBoolMethod(
      'com/redstone/DartBridge',
      'givePlayerItem',
      '(ILjava/lang/String;I)Z',
      [players.first.id, itemId, count],
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Methods
  // ---------------------------------------------------------------------------

  void _ensureReady() {
    if (!isClientReady) {
      throw StateError('Minecraft client not ready');
    }
  }
}

/// Binding for MCP runtime tick events.
///
/// Similar to ClientTestBinding but simplified for MCP use.
class McpRuntimeBinding {
  static McpRuntimeBinding? _instance;

  int _currentTick = 0;
  final Map<int, List<Completer<void>>> _tickCompleters = {};
  bool _clientReady = false;
  final List<Completer<void>> _readyCompleters = [];

  McpRuntimeBinding._() {
    _registerServerTickHandler();
  }

  /// Initialize the binding singleton.
  static McpRuntimeBinding _initialize() {
    _instance ??= McpRuntimeBinding._();
    return _instance!;
  }

  /// Get the current tick.
  int get currentTick => _currentTick;

  /// Check if the client is ready.
  bool get isClientReady => _clientReady;

  /// Register a completer to be completed after [targetTick].
  void registerTickCompleter(int targetTick, Completer<void> completer) {
    _tickCompleters.putIfAbsent(targetTick, () => []).add(completer);
  }

  /// Wait until the client is ready.
  Future<void> waitForClientReady() {
    if (_clientReady) return Future.value();
    final completer = Completer<void>();
    _readyCompleters.add(completer);
    return completer.future;
  }

  void _registerServerTickHandler() {
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
