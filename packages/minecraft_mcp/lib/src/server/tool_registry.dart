import 'dart:io';

import '../minecraft/game_client.dart';
import '../minecraft/minecraft_controller.dart';

/// Registry for MCP tools.
///
/// Defines tool schemas and dispatches tool execution requests.
class ToolRegistry {
  /// Controller for Minecraft lifecycle.
  MinecraftController? minecraftController;

  /// HTTP client for game server communication.
  GameClient? gameClient;

  /// Default port for the game server.
  final int defaultPort;

  ToolRegistry({
    this.minecraftController,
    this.gameClient,
    this.defaultPort = 8765,
  });

  /// Tool definitions.
  final List<ToolDefinition> _tools = [
    // Lifecycle tools
    ToolDefinition(
      name: 'startMinecraft',
      description: 'Start Minecraft client with the specified mod',
      inputSchema: {
        'type': 'object',
        'properties': {
          'modPath': {
            'type': 'string',
            'description': 'Path to the mod directory',
          },
        },
        'required': ['modPath'],
      },
    ),
    ToolDefinition(
      name: 'stopMinecraft',
      description: 'Stop the running Minecraft instance',
      inputSchema: {
        'type': 'object',
        'properties': <String, Object>{},
      },
    ),
    ToolDefinition(
      name: 'getStatus',
      description: 'Get the current status of Minecraft (running, stopped, etc.)',
      inputSchema: {
        'type': 'object',
        'properties': <String, Object>{},
      },
    ),
    ToolDefinition(
      name: 'getLogs',
      description: 'Get all Minecraft output: both Dart print() statements and Java logs. Returns the last N lines of combined output.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'lastN': {
            'type': 'integer',
            'description': 'Only return the last N lines (default: 100)',
          },
        },
      },
    ),

    // World tools
    ToolDefinition(
      name: 'placeBlock',
      description: 'Place a block at the specified coordinates',
      inputSchema: {
        'type': 'object',
        'properties': {
          'x': {'type': 'integer', 'description': 'X coordinate'},
          'y': {
            'type': 'integer',
            'description': 'Y coordinate (world range: -64 to 320, superflat ground: Y=-60, sea level: ~Y=63)',
          },
          'z': {'type': 'integer', 'description': 'Z coordinate'},
          'blockId': {
            'type': 'string',
            'description': 'Block identifier (e.g., "minecraft:stone")',
          },
        },
        'required': ['x', 'y', 'z', 'blockId'],
      },
    ),
    ToolDefinition(
      name: 'getBlock',
      description: 'Get the block at the specified coordinates',
      inputSchema: {
        'type': 'object',
        'properties': {
          'x': {'type': 'integer', 'description': 'X coordinate'},
          'y': {
            'type': 'integer',
            'description': 'Y coordinate (world range: -64 to 320, superflat ground: Y=-60, sea level: ~Y=63)',
          },
          'z': {'type': 'integer', 'description': 'Z coordinate'},
        },
        'required': ['x', 'y', 'z'],
      },
    ),
    ToolDefinition(
      name: 'fillBlocks',
      description: 'Fill a region with blocks',
      inputSchema: {
        'type': 'object',
        'properties': {
          'fromX': {'type': 'integer', 'description': 'Starting X coordinate'},
          'fromY': {
            'type': 'integer',
            'description': 'Starting Y coordinate (world range: -64 to 320, superflat ground: Y=-60)',
          },
          'fromZ': {'type': 'integer', 'description': 'Starting Z coordinate'},
          'toX': {'type': 'integer', 'description': 'Ending X coordinate'},
          'toY': {
            'type': 'integer',
            'description': 'Ending Y coordinate (world range: -64 to 320, superflat ground: Y=-60)',
          },
          'toZ': {'type': 'integer', 'description': 'Ending Z coordinate'},
          'blockId': {
            'type': 'string',
            'description': 'Block identifier (e.g., "minecraft:stone")',
          },
        },
        'required': ['fromX', 'fromY', 'fromZ', 'toX', 'toY', 'toZ', 'blockId'],
      },
    ),

    // Entity tools
    ToolDefinition(
      name: 'spawnEntity',
      description: 'Spawn an entity at the specified location',
      inputSchema: {
        'type': 'object',
        'properties': {
          'entityType': {
            'type': 'string',
            'description': 'Entity type (e.g., "minecraft:zombie")',
          },
          'x': {'type': 'number', 'description': 'X coordinate'},
          'y': {
            'type': 'number',
            'description': 'Y coordinate (world range: -64 to 320, superflat ground: Y=-60, sea level: ~Y=63)',
          },
          'z': {'type': 'number', 'description': 'Z coordinate'},
        },
        'required': ['entityType', 'x', 'y', 'z'],
      },
    ),
    ToolDefinition(
      name: 'getEntities',
      description: 'Query entities within a radius of a position',
      inputSchema: {
        'type': 'object',
        'properties': {
          'centerX': {'type': 'number', 'description': 'Center X coordinate'},
          'centerY': {
            'type': 'number',
            'description': 'Center Y coordinate (world range: -64 to 320, superflat ground: Y=-60)',
          },
          'centerZ': {'type': 'number', 'description': 'Center Z coordinate'},
          'radius': {'type': 'number', 'description': 'Search radius'},
          'entityType': {
            'type': 'string',
            'description': 'Optional filter by entity type',
          },
        },
        'required': ['centerX', 'centerY', 'centerZ', 'radius'],
      },
    ),

    // Player/Camera tools
    ToolDefinition(
      name: 'teleportPlayer',
      description: 'Teleport the player to the specified coordinates',
      inputSchema: {
        'type': 'object',
        'properties': {
          'x': {'type': 'number', 'description': 'X coordinate'},
          'y': {
            'type': 'number',
            'description': 'Y coordinate (world range: -64 to 320, superflat ground: Y=-60, sea level: ~Y=63)',
          },
          'z': {'type': 'number', 'description': 'Z coordinate'},
        },
        'required': ['x', 'y', 'z'],
      },
    ),
    ToolDefinition(
      name: 'positionCamera',
      description: 'Set the camera position and orientation',
      inputSchema: {
        'type': 'object',
        'properties': {
          'x': {'type': 'number', 'description': 'X coordinate'},
          'y': {
            'type': 'number',
            'description': 'Y coordinate (world range: -64 to 320, superflat ground: Y=-60, sea level: ~Y=63)',
          },
          'z': {'type': 'number', 'description': 'Z coordinate'},
          'yaw': {'type': 'number', 'description': 'Yaw rotation (horizontal)'},
          'pitch': {'type': 'number', 'description': 'Pitch rotation (vertical)'},
        },
        'required': ['x', 'y', 'z', 'yaw', 'pitch'],
      },
    ),
    ToolDefinition(
      name: 'lookAt',
      description: 'Make the player look at a specific position',
      inputSchema: {
        'type': 'object',
        'properties': {
          'x': {'type': 'number', 'description': 'Target X coordinate'},
          'y': {
            'type': 'number',
            'description': 'Target Y coordinate (world range: -64 to 320, superflat ground: Y=-60)',
          },
          'z': {'type': 'number', 'description': 'Target Z coordinate'},
        },
        'required': ['x', 'y', 'z'],
      },
    ),

    // Visual tools
    ToolDefinition(
      name: 'takeScreenshot',
      description: 'Capture a screenshot of the current view',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name for the screenshot file',
          },
        },
        'required': ['name'],
      },
    ),
    ToolDefinition(
      name: 'getScreenshot',
      description: 'Get a previously captured screenshot as base64',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the screenshot to retrieve',
          },
        },
        'required': ['name'],
      },
    ),

    // Input tools
    ToolDefinition(
      name: 'pressKey',
      description: 'Simulate a key press',
      inputSchema: {
        'type': 'object',
        'properties': {
          'keyCode': {
            'type': 'integer',
            'description': 'GLFW key code to press',
          },
          'hold': {
            'type': 'boolean',
            'description': 'Whether to hold the key (default: false)',
          },
          'duration': {
            'type': 'integer',
            'description': 'Duration to hold in milliseconds (if hold is true)',
          },
        },
        'required': ['keyCode'],
      },
    ),
    ToolDefinition(
      name: 'click',
      description: 'Simulate a mouse click',
      inputSchema: {
        'type': 'object',
        'properties': {
          'button': {
            'type': 'integer',
            'description': 'Mouse button (0=left, 1=right, 2=middle)',
          },
          'x': {'type': 'integer', 'description': 'Screen X coordinate'},
          'y': {'type': 'integer', 'description': 'Screen Y coordinate'},
        },
        'required': ['button', 'x', 'y'],
      },
    ),
    ToolDefinition(
      name: 'typeText',
      description: 'Type text into the current input field',
      inputSchema: {
        'type': 'object',
        'properties': {
          'text': {
            'type': 'string',
            'description': 'Text to type',
          },
        },
        'required': ['text'],
      },
    ),
    ToolDefinition(
      name: 'holdMouse',
      description: 'Hold a mouse button down (for breaking blocks, using items). Call releaseMouse to release.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'button': {
            'type': 'integer',
            'description': 'Mouse button (0=left, 1=right, 2=middle)',
          },
        },
        'required': ['button'],
      },
    ),
    ToolDefinition(
      name: 'releaseMouse',
      description: 'Release a held mouse button',
      inputSchema: {
        'type': 'object',
        'properties': {
          'button': {
            'type': 'integer',
            'description': 'Mouse button (0=left, 1=right, 2=middle)',
          },
        },
        'required': ['button'],
      },
    ),
    ToolDefinition(
      name: 'moveMouse',
      description: 'Move the mouse cursor to screen coordinates (without clicking)',
      inputSchema: {
        'type': 'object',
        'properties': {
          'x': {'type': 'integer', 'description': 'Screen X coordinate'},
          'y': {'type': 'integer', 'description': 'Screen Y coordinate'},
        },
        'required': ['x', 'y'],
      },
    ),
    ToolDefinition(
      name: 'scroll',
      description: 'Scroll the mouse wheel. Positive vertical = scroll up, negative = scroll down.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'horizontal': {
            'type': 'number',
            'description': 'Horizontal scroll amount',
          },
          'vertical': {
            'type': 'number',
            'description': 'Vertical scroll amount',
          },
        },
        'required': ['horizontal', 'vertical'],
      },
    ),

    // Time/Command tools
    ToolDefinition(
      name: 'waitTicks',
      description: 'Wait for a specified number of game ticks (20 ticks = 1 second)',
      inputSchema: {
        'type': 'object',
        'properties': {
          'ticks': {
            'type': 'integer',
            'description': 'Number of game ticks to wait',
          },
        },
        'required': ['ticks'],
      },
    ),
    ToolDefinition(
      name: 'setTimeOfDay',
      description: 'Set the in-game time of day',
      inputSchema: {
        'type': 'object',
        'properties': {
          'time': {
            'type': 'integer',
            'description': 'Time in ticks (0=dawn, 6000=noon, 12000=dusk, 18000=midnight)',
          },
        },
        'required': ['time'],
      },
    ),
    ToolDefinition(
      name: 'executeCommand',
      description: 'Execute a Minecraft command',
      inputSchema: {
        'type': 'object',
        'properties': {
          'command': {
            'type': 'string',
            'description': 'Command to execute (without leading slash)',
          },
        },
        'required': ['command'],
      },
    ),

    // Tick Control tools
    ToolDefinition(
      name: 'freezeTicks',
      description: 'Freeze game ticks. Players continue to move but world stops updating.',
      inputSchema: {
        'type': 'object',
        'properties': <String, Object>{},
      },
    ),
    ToolDefinition(
      name: 'unfreezeTicks',
      description: 'Unfreeze game ticks and resume normal game execution.',
      inputSchema: {
        'type': 'object',
        'properties': <String, Object>{},
      },
    ),
    ToolDefinition(
      name: 'stepTicks',
      description: 'Step forward by a specific number of ticks while frozen. Auto-freezes if not already frozen.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'count': {
            'type': 'integer',
            'description': 'Number of ticks to step forward',
          },
        },
        'required': ['count'],
      },
    ),
    ToolDefinition(
      name: 'setTickRate',
      description: 'Set the game tick rate. Default is 20 ticks/second. Range: 1-10000.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'rate': {
            'type': 'number',
            'description': 'Ticks per second (1-10000, default 20)',
          },
        },
        'required': ['rate'],
      },
    ),
    ToolDefinition(
      name: 'sprintTicks',
      description: 'Run a number of ticks as fast as possible (no delay between ticks).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'count': {
            'type': 'integer',
            'description': 'Number of ticks to sprint through',
          },
        },
        'required': ['count'],
      },
    ),
    ToolDefinition(
      name: 'getTickState',
      description: 'Get the current tick state (frozen, tick rate, stepping status).',
      inputSchema: {
        'type': 'object',
        'properties': <String, Object>{},
      },
    ),

    // Player Inventory tools
    ToolDefinition(
      name: 'clearInventory',
      description: "Clear the player's inventory completely.",
      inputSchema: {
        'type': 'object',
        'properties': <String, Object>{},
      },
    ),
    ToolDefinition(
      name: 'giveItem',
      description: 'Give an item to the player. If inventory is full, excess items are dropped.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'itemId': {
            'type': 'string',
            'description': 'Item ID (e.g., "minecraft:diamond", "minecraft:diamond_sword")',
          },
          'count': {
            'type': 'integer',
            'description': 'Number of items to give (default 1)',
          },
        },
        'required': ['itemId'],
      },
    ),
  ];

  /// List all available tools.
  List<Map<String, dynamic>> listTools() {
    return _tools.map((tool) => tool.toJson()).toList();
  }

  /// Call a tool by name with the given arguments.
  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final tool = _tools.where((t) => t.name == name).firstOrNull;
    if (tool == null) {
      return _errorResult('Unknown tool "$name"');
    }

    try {
      final result = await _executeTool(name, arguments);
      return _successResult(result);
    } on GameClientException catch (e) {
      return _errorResult('Game server error: ${e.message}', code: e.statusCode);
    } on StateError catch (e) {
      return _errorResult(e.message);
    } catch (e) {
      return _errorResult('Tool execution failed: $e');
    }
  }

  /// Execute a tool and return its result.
  Future<Map<String, dynamic>> _executeTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      // =========================================================================
      // Lifecycle Tools
      // =========================================================================
      case 'startMinecraft':
        return _handleStartMinecraft(args);

      case 'stopMinecraft':
        return _handleStopMinecraft();

      case 'getStatus':
        return _handleGetStatus();

      case 'getLogs':
        return _handleGetLogs(args);

      // =========================================================================
      // World Tools
      // =========================================================================
      case 'placeBlock':
        return _handlePlaceBlock(args);

      case 'getBlock':
        return _handleGetBlock(args);

      case 'fillBlocks':
        return _handleFillBlocks(args);

      // =========================================================================
      // Entity Tools
      // =========================================================================
      case 'spawnEntity':
        return _handleSpawnEntity(args);

      case 'getEntities':
        return _handleGetEntities(args);

      // =========================================================================
      // Player/Camera Tools
      // =========================================================================
      case 'teleportPlayer':
        return _handleTeleportPlayer(args);

      case 'positionCamera':
        return _handlePositionCamera(args);

      case 'lookAt':
        return _handleLookAt(args);

      // =========================================================================
      // Visual Tools
      // =========================================================================
      case 'takeScreenshot':
        return _handleTakeScreenshot(args);

      case 'getScreenshot':
        return _handleGetScreenshot(args);

      // =========================================================================
      // Input Tools
      // =========================================================================
      case 'pressKey':
        return _handlePressKey(args);

      case 'click':
        return _handleClick(args);

      case 'typeText':
        return _handleTypeText(args);

      case 'holdMouse':
        return _handleHoldMouse(args);

      case 'releaseMouse':
        return _handleReleaseMouse(args);

      case 'moveMouse':
        return _handleMoveMouse(args);

      case 'scroll':
        return _handleScroll(args);

      // =========================================================================
      // Time/Command Tools
      // =========================================================================
      case 'waitTicks':
        return _handleWaitTicks(args);

      case 'setTimeOfDay':
        return _handleSetTimeOfDay(args);

      case 'executeCommand':
        return _handleExecuteCommand(args);

      // =========================================================================
      // Tick Control Tools
      // =========================================================================
      case 'freezeTicks':
        return _handleFreezeTicks();

      case 'unfreezeTicks':
        return _handleUnfreezeTicks();

      case 'stepTicks':
        return _handleStepTicks(args);

      case 'setTickRate':
        return _handleSetTickRate(args);

      case 'sprintTicks':
        return _handleSprintTicks(args);

      case 'getTickState':
        return _handleGetTickState();

      // =========================================================================
      // Player Inventory Tools
      // =========================================================================
      case 'clearInventory':
        return _handleClearInventory();

      case 'giveItem':
        return _handleGiveItem(args);

      default:
        throw StateError('Tool "$name" has no implementation');
    }
  }

  // ===========================================================================
  // Lifecycle Tool Handlers
  // ===========================================================================

  Future<Map<String, dynamic>> _handleStartMinecraft(Map<String, dynamic> args) async {
    final modPath = args['modPath'] as String?;

    // Create or update controller if modPath is provided
    if (modPath != null) {
      // Stop existing instance if running with different path
      if (minecraftController != null && minecraftController!.isRunning) {
        await minecraftController!.stop();
      }
      minecraftController = MinecraftController(
        modPath: modPath,
        httpPort: defaultPort,
      );
    }

    if (minecraftController == null) {
      throw StateError('Minecraft controller not configured. Provide modPath argument to startMinecraft.');
    }

    if (minecraftController!.isRunning) {
      throw StateError('Minecraft is already running');
    }

    await minecraftController!.start();

    // Wait for Minecraft to be ready
    final ready = await minecraftController!.waitForReady();
    if (!ready) {
      throw StateError('Minecraft failed to start or timed out');
    }

    // Update game client reference
    gameClient = minecraftController!.gameClient;

    return {
      'success': true,
      'message': 'Minecraft started successfully',
      'status': minecraftController!.status.name,
      'worldName': minecraftController!.worldName,
    };
  }

  Future<Map<String, dynamic>> _handleStopMinecraft() async {
    if (minecraftController == null) {
      throw StateError('Minecraft controller not configured');
    }

    await minecraftController!.stop();
    gameClient = null;

    return {
      'success': true,
      'message': 'Minecraft stopped',
    };
  }

  Map<String, dynamic> _handleGetStatus() {
    if (minecraftController == null) {
      return {
        'configured': false,
        'status': 'not_configured',
        'message': 'Minecraft not started. Call startMinecraft with modPath to start.',
      };
    }

    return {
      'configured': true,
      'status': minecraftController!.status.name,
      'isRunning': minecraftController!.isRunning,
      'worldName': minecraftController!.worldName,
    };
  }

  Map<String, dynamic> _handleGetLogs(Map<String, dynamic> args) {
    if (minecraftController == null) {
      throw StateError('Minecraft controller not configured');
    }

    final lastN = args['lastN'] as int? ?? 100;

    final output = minecraftController!.getProcessOutput(
      lastN: lastN,
      includeStderr: true,
    );

    // Format as readable text
    final lines = output.map((entry) {
      final prefix = entry['isStderr'] == true ? '[stderr] ' : '';
      return '$prefix${entry['line']}';
    }).toList();

    return {
      'lineCount': output.length,
      'output': lines.join('\n'),
    };
  }

  // ===========================================================================
  // World Tool Handlers
  // ===========================================================================

  Future<Map<String, dynamic>> _handlePlaceBlock(Map<String, dynamic> args) async {
    _ensureGameClient();

    final x = args['x'] as int;
    final y = args['y'] as int;
    final z = args['z'] as int;
    final blockId = args['blockId'] as String;

    await gameClient!.placeBlock(x, y, z, blockId);

    return {
      'success': true,
      'x': x,
      'y': y,
      'z': z,
      'blockId': blockId,
    };
  }

  Future<Map<String, dynamic>> _handleGetBlock(Map<String, dynamic> args) async {
    _ensureGameClient();

    final x = args['x'] as int;
    final y = args['y'] as int;
    final z = args['z'] as int;

    final blockId = await gameClient!.getBlock(x, y, z);

    return {
      'blockId': blockId,
      'x': x,
      'y': y,
      'z': z,
    };
  }

  Future<Map<String, dynamic>> _handleFillBlocks(Map<String, dynamic> args) async {
    _ensureGameClient();

    final fromX = args['fromX'] as int;
    final fromY = args['fromY'] as int;
    final fromZ = args['fromZ'] as int;
    final toX = args['toX'] as int;
    final toY = args['toY'] as int;
    final toZ = args['toZ'] as int;
    final blockId = args['blockId'] as String;

    await gameClient!.fillBlocks(fromX, fromY, fromZ, toX, toY, toZ, blockId);

    return {
      'success': true,
      'from': {'x': fromX, 'y': fromY, 'z': fromZ},
      'to': {'x': toX, 'y': toY, 'z': toZ},
      'blockId': blockId,
    };
  }

  // ===========================================================================
  // Entity Tool Handlers
  // ===========================================================================

  Future<Map<String, dynamic>> _handleSpawnEntity(Map<String, dynamic> args) async {
    _ensureGameClient();

    final entityType = args['entityType'] as String;
    final x = (args['x'] as num).toDouble();
    final y = (args['y'] as num).toDouble();
    final z = (args['z'] as num).toDouble();

    final entity = await gameClient!.spawnEntity(entityType, x, y, z);

    return entity.toJson();
  }

  Future<Map<String, dynamic>> _handleGetEntities(Map<String, dynamic> args) async {
    _ensureGameClient();

    final centerX = (args['centerX'] as num).toDouble();
    final centerY = (args['centerY'] as num).toDouble();
    final centerZ = (args['centerZ'] as num).toDouble();
    final radius = (args['radius'] as num).toDouble();
    final entityType = args['entityType'] as String?;

    final entities = await gameClient!.getEntities(
      centerX,
      centerY,
      centerZ,
      radius,
      entityType: entityType,
    );

    return {
      'entities': entities.map((e) => e.toJson()).toList(),
      'count': entities.length,
    };
  }

  // ===========================================================================
  // Player/Camera Tool Handlers
  // ===========================================================================

  Future<Map<String, dynamic>> _handleTeleportPlayer(Map<String, dynamic> args) async {
    _ensureGameClient();

    final x = (args['x'] as num).toDouble();
    final y = (args['y'] as num).toDouble();
    final z = (args['z'] as num).toDouble();

    await gameClient!.teleportPlayer(x, y, z);

    return {
      'success': true,
      'x': x,
      'y': y,
      'z': z,
    };
  }

  Future<Map<String, dynamic>> _handlePositionCamera(Map<String, dynamic> args) async {
    _ensureGameClient();

    final x = (args['x'] as num).toDouble();
    final y = (args['y'] as num).toDouble();
    final z = (args['z'] as num).toDouble();
    final yaw = (args['yaw'] as num).toDouble();
    final pitch = (args['pitch'] as num).toDouble();

    await gameClient!.positionCamera(x, y, z, yaw, pitch);

    return {
      'success': true,
      'x': x,
      'y': y,
      'z': z,
      'yaw': yaw,
      'pitch': pitch,
    };
  }

  Future<Map<String, dynamic>> _handleLookAt(Map<String, dynamic> args) async {
    _ensureGameClient();

    final x = (args['x'] as num).toDouble();
    final y = (args['y'] as num).toDouble();
    final z = (args['z'] as num).toDouble();

    await gameClient!.lookAt(x, y, z);

    return {
      'success': true,
      'lookingAt': {'x': x, 'y': y, 'z': z},
    };
  }

  // ===========================================================================
  // Visual Tool Handlers
  // ===========================================================================

  Future<Map<String, dynamic>> _handleTakeScreenshot(Map<String, dynamic> args) async {
    _ensureGameClient();

    final name = args['name'] as String;

    final path = await gameClient!.takeScreenshot(name);

    return {
      'success': true,
      'name': name,
      'path': path,
    };
  }

  Future<Map<String, dynamic>> _handleGetScreenshot(Map<String, dynamic> args) async {
    _ensureGameClient();

    final name = args['name'] as String;

    // Get screenshots directory and build path
    // Note: We intentionally do NOT return base64 data to avoid flooding agent context.
    // The agent should use the Read tool to view the screenshot file directly.
    final screenshotsDir = await gameClient!.getScreenshotsDirectory();
    if (screenshotsDir == null) {
      throw StateError('Screenshots directory not available');
    }

    final path = '$screenshotsDir/$name.png';
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Screenshot "$name" not found at $path');
    }

    return {
      'name': name,
      'path': path,
      'message': 'Use the Read tool to view this screenshot file',
    };
  }

  // ===========================================================================
  // Input Tool Handlers
  // ===========================================================================

  Future<Map<String, dynamic>> _handlePressKey(Map<String, dynamic> args) async {
    _ensureGameClient();

    final keyCode = args['keyCode'] as int;
    final hold = args['hold'] as bool? ?? false;
    final duration = args['duration'] as int?;

    if (hold && duration != null) {
      await gameClient!.holdKeyFor(keyCode, duration);
    } else {
      await gameClient!.pressKey(keyCode);
    }

    return {
      'success': true,
      'keyCode': keyCode,
      'held': hold,
      'duration': duration,
    };
  }

  Future<Map<String, dynamic>> _handleClick(Map<String, dynamic> args) async {
    _ensureGameClient();

    final button = args['button'] as int;
    final x = args['x'] as int;
    final y = args['y'] as int;

    await gameClient!.click(button, x, y);

    return {
      'success': true,
      'button': button,
      'x': x,
      'y': y,
    };
  }

  Future<Map<String, dynamic>> _handleTypeText(Map<String, dynamic> args) async {
    _ensureGameClient();

    final text = args['text'] as String;

    await gameClient!.typeText(text);

    return {
      'success': true,
      'text': text,
      'length': text.length,
    };
  }

  Future<Map<String, dynamic>> _handleHoldMouse(Map<String, dynamic> args) async {
    _ensureGameClient();

    final button = args['button'] as int;

    await gameClient!.holdMouse(button);

    return {
      'success': true,
      'button': button,
    };
  }

  Future<Map<String, dynamic>> _handleReleaseMouse(Map<String, dynamic> args) async {
    _ensureGameClient();

    final button = args['button'] as int;

    await gameClient!.releaseMouse(button);

    return {
      'success': true,
      'button': button,
    };
  }

  Future<Map<String, dynamic>> _handleMoveMouse(Map<String, dynamic> args) async {
    _ensureGameClient();

    final x = args['x'] as int;
    final y = args['y'] as int;

    await gameClient!.moveMouse(x, y);

    return {
      'success': true,
      'x': x,
      'y': y,
    };
  }

  Future<Map<String, dynamic>> _handleScroll(Map<String, dynamic> args) async {
    _ensureGameClient();

    final horizontal = (args['horizontal'] as num).toDouble();
    final vertical = (args['vertical'] as num).toDouble();

    await gameClient!.scroll(horizontal, vertical);

    return {
      'success': true,
      'horizontal': horizontal,
      'vertical': vertical,
    };
  }

  // ===========================================================================
  // Time/Command Tool Handlers
  // ===========================================================================

  Future<Map<String, dynamic>> _handleWaitTicks(Map<String, dynamic> args) async {
    _ensureGameClient();

    final ticks = args['ticks'] as int;

    await gameClient!.waitTicks(ticks);

    return {
      'success': true,
      'ticksWaited': ticks,
      'approximateMs': ticks * 50, // 20 ticks = 1 second = 1000ms
    };
  }

  Future<Map<String, dynamic>> _handleSetTimeOfDay(Map<String, dynamic> args) async {
    _ensureGameClient();

    final time = args['time'] as int;

    await gameClient!.setTimeOfDay(time);

    return {
      'success': true,
      'time': time,
    };
  }

  Future<Map<String, dynamic>> _handleExecuteCommand(Map<String, dynamic> args) async {
    _ensureGameClient();

    final command = args['command'] as String;

    final result = await gameClient!.executeCommand(command);

    return {
      'success': true,
      'command': command,
      'result': result,
    };
  }

  // ===========================================================================
  // Tick Control Tool Handlers
  // ===========================================================================

  Future<Map<String, dynamic>> _handleFreezeTicks() async {
    _ensureGameClient();

    await gameClient!.freezeTicks();

    return {
      'success': true,
      'message': 'Ticks frozen',
    };
  }

  Future<Map<String, dynamic>> _handleUnfreezeTicks() async {
    _ensureGameClient();

    await gameClient!.unfreezeTicks();

    return {
      'success': true,
      'message': 'Ticks unfrozen',
    };
  }

  Future<Map<String, dynamic>> _handleStepTicks(Map<String, dynamic> args) async {
    _ensureGameClient();

    final count = args['count'] as int;

    await gameClient!.stepTicks(count);

    return {
      'success': true,
      'ticksStepped': count,
    };
  }

  Future<Map<String, dynamic>> _handleSetTickRate(Map<String, dynamic> args) async {
    _ensureGameClient();

    final rate = (args['rate'] as num).toDouble();

    await gameClient!.setTickRate(rate);

    return {
      'success': true,
      'tickRate': rate,
    };
  }

  Future<Map<String, dynamic>> _handleSprintTicks(Map<String, dynamic> args) async {
    _ensureGameClient();

    final count = args['count'] as int;

    await gameClient!.sprintTicks(count);

    return {
      'success': true,
      'ticksSprinted': count,
    };
  }

  Future<Map<String, dynamic>> _handleGetTickState() async {
    _ensureGameClient();

    final state = await gameClient!.getTickState();

    return {
      'frozen': state.frozen,
      'tickRate': state.tickRate,
      'stepping': state.stepping,
      'sprinting': state.sprinting,
      'frozenTicksToRun': state.frozenTicksToRun,
    };
  }

  // ===========================================================================
  // Player Inventory Tool Handlers
  // ===========================================================================

  Future<Map<String, dynamic>> _handleClearInventory() async {
    _ensureGameClient();

    await gameClient!.clearInventory();

    return {
      'success': true,
      'message': 'Inventory cleared',
    };
  }

  Future<Map<String, dynamic>> _handleGiveItem(Map<String, dynamic> args) async {
    _ensureGameClient();

    final itemId = args['itemId'] as String;
    final count = args['count'] as int? ?? 1;

    final success = await gameClient!.giveItem(itemId, count);

    if (!success) {
      throw StateError('Invalid item ID: $itemId');
    }

    return {
      'success': true,
      'itemId': itemId,
      'count': count,
    };
  }

  // ===========================================================================
  // Helper Methods
  // ===========================================================================

  /// Ensure game client is available.
  void _ensureGameClient() {
    // Sync gameClient from controller if available but not yet synced
    if (gameClient == null && minecraftController?.gameClient != null) {
      gameClient = minecraftController!.gameClient;
    }

    if (gameClient == null) {
      throw StateError('Minecraft is not running. Call startMinecraft first.');
    }
  }

  /// Create a success result in MCP format.
  Map<String, dynamic> _successResult(Map<String, dynamic> data) {
    return {
      'content': [
        {
          'type': 'text',
          'text': _formatResultText(data),
        },
      ],
    };
  }

  /// Create an error result in MCP format.
  Map<String, dynamic> _errorResult(String message, {int? code}) {
    return {
      'content': [
        {
          'type': 'text',
          'text': 'Error: $message${code != null ? ' (code: $code)' : ''}',
        },
      ],
      'isError': true,
    };
  }

  /// Format result data as readable text.
  String _formatResultText(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Map || value is List) {
        buffer.writeln('${entry.key}: ${_formatJson(value)}');
      } else {
        buffer.writeln('${entry.key}: $value');
      }
    }
    return buffer.toString().trimRight();
  }

  /// Format complex values as compact JSON.
  String _formatJson(dynamic value) {
    if (value is Map) {
      final parts = value.entries.map((e) => '${e.key}: ${_formatJson(e.value)}');
      return '{${parts.join(', ')}}';
    } else if (value is List) {
      final parts = value.map(_formatJson);
      return '[${parts.join(', ')}]';
    }
    return value.toString();
  }
}

/// Definition of an MCP tool.
class ToolDefinition {
  /// Unique name for the tool.
  final String name;

  /// Human-readable description.
  final String description;

  /// JSON Schema for the input parameters.
  final Map<String, dynamic> inputSchema;

  ToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  /// Convert to JSON for the MCP protocol.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'inputSchema': inputSchema,
    };
  }
}
