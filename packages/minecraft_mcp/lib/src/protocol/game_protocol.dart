/// Protocol types for game server communication.
///
/// These types define the JSON request/response format for all game operations.
library;

// =============================================================================
// Block Operations
// =============================================================================

/// Request to place a block.
class PlaceBlockRequest {
  final int x;
  final int y;
  final int z;
  final String blockId;

  PlaceBlockRequest({
    required this.x,
    required this.y,
    required this.z,
    required this.blockId,
  });

  factory PlaceBlockRequest.fromJson(Map<String, dynamic> json) {
    return PlaceBlockRequest(
      x: json['x'] as int,
      y: json['y'] as int,
      z: json['z'] as int,
      blockId: json['blockId'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
        'blockId': blockId,
      };
}

/// Request to get a block.
class GetBlockRequest {
  final int x;
  final int y;
  final int z;

  GetBlockRequest({
    required this.x,
    required this.y,
    required this.z,
  });

  factory GetBlockRequest.fromJson(Map<String, dynamic> json) {
    return GetBlockRequest(
      x: json['x'] as int,
      y: json['y'] as int,
      z: json['z'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
      };
}

/// Response containing block information.
class BlockResponse {
  final String blockId;
  final int x;
  final int y;
  final int z;

  BlockResponse({
    required this.blockId,
    required this.x,
    required this.y,
    required this.z,
  });

  factory BlockResponse.fromJson(Map<String, dynamic> json) {
    return BlockResponse(
      blockId: json['blockId'] as String,
      x: json['x'] as int,
      y: json['y'] as int,
      z: json['z'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'blockId': blockId,
        'x': x,
        'y': y,
        'z': z,
      };
}

/// Request to fill a region with blocks.
class FillBlocksRequest {
  final int fromX;
  final int fromY;
  final int fromZ;
  final int toX;
  final int toY;
  final int toZ;
  final String blockId;

  FillBlocksRequest({
    required this.fromX,
    required this.fromY,
    required this.fromZ,
    required this.toX,
    required this.toY,
    required this.toZ,
    required this.blockId,
  });

  factory FillBlocksRequest.fromJson(Map<String, dynamic> json) {
    return FillBlocksRequest(
      fromX: json['fromX'] as int,
      fromY: json['fromY'] as int,
      fromZ: json['fromZ'] as int,
      toX: json['toX'] as int,
      toY: json['toY'] as int,
      toZ: json['toZ'] as int,
      blockId: json['blockId'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'fromX': fromX,
        'fromY': fromY,
        'fromZ': fromZ,
        'toX': toX,
        'toY': toY,
        'toZ': toZ,
        'blockId': blockId,
      };
}

// =============================================================================
// Entity Operations
// =============================================================================

/// Request to spawn an entity.
class SpawnEntityRequest {
  final String entityType;
  final double x;
  final double y;
  final double z;

  SpawnEntityRequest({
    required this.entityType,
    required this.x,
    required this.y,
    required this.z,
  });

  factory SpawnEntityRequest.fromJson(Map<String, dynamic> json) {
    return SpawnEntityRequest(
      entityType: json['entityType'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'entityType': entityType,
        'x': x,
        'y': y,
        'z': z,
      };
}

/// Request to get entities in a radius.
class GetEntitiesRequest {
  final double centerX;
  final double centerY;
  final double centerZ;
  final double radius;
  final String? entityType;

  GetEntitiesRequest({
    required this.centerX,
    required this.centerY,
    required this.centerZ,
    required this.radius,
    this.entityType,
  });

  factory GetEntitiesRequest.fromJson(Map<String, dynamic> json) {
    return GetEntitiesRequest(
      centerX: (json['centerX'] as num).toDouble(),
      centerY: (json['centerY'] as num).toDouble(),
      centerZ: (json['centerZ'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      entityType: json['entityType'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'centerX': centerX,
        'centerY': centerY,
        'centerZ': centerZ,
        'radius': radius,
        if (entityType != null) 'entityType': entityType,
      };
}

/// Information about an entity.
class EntityInfo {
  final String id;
  final String type;
  final double x;
  final double y;
  final double z;
  final double? health;
  final bool isAlive;

  EntityInfo({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    this.health,
    this.isAlive = true,
  });

  factory EntityInfo.fromJson(Map<String, dynamic> json) {
    return EntityInfo(
      id: json['id'] as String,
      type: json['type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      health: json['health'] != null ? (json['health'] as num).toDouble() : null,
      isAlive: json['isAlive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'x': x,
        'y': y,
        'z': z,
        if (health != null) 'health': health,
        'isAlive': isAlive,
      };
}

/// Response containing a list of entities.
class EntitiesResponse {
  final List<EntityInfo> entities;

  EntitiesResponse({required this.entities});

  factory EntitiesResponse.fromJson(Map<String, dynamic> json) {
    return EntitiesResponse(
      entities: (json['entities'] as List<dynamic>)
          .map((e) => EntityInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'entities': entities.map((e) => e.toJson()).toList(),
      };
}

// =============================================================================
// Player/Camera Operations
// =============================================================================

/// Request to teleport the player.
class TeleportRequest {
  final double x;
  final double y;
  final double z;

  TeleportRequest({
    required this.x,
    required this.y,
    required this.z,
  });

  factory TeleportRequest.fromJson(Map<String, dynamic> json) {
    return TeleportRequest(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
      };
}

/// Request to position the camera.
class PositionCameraRequest {
  final double x;
  final double y;
  final double z;
  final double yaw;
  final double pitch;

  PositionCameraRequest({
    required this.x,
    required this.y,
    required this.z,
    required this.yaw,
    required this.pitch,
  });

  factory PositionCameraRequest.fromJson(Map<String, dynamic> json) {
    return PositionCameraRequest(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      yaw: (json['yaw'] as num).toDouble(),
      pitch: (json['pitch'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
        'yaw': yaw,
        'pitch': pitch,
      };
}

/// Request to look at a position.
class LookAtRequest {
  final double x;
  final double y;
  final double z;

  LookAtRequest({
    required this.x,
    required this.y,
    required this.z,
  });

  factory LookAtRequest.fromJson(Map<String, dynamic> json) {
    return LookAtRequest(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
      };
}

// =============================================================================
// Screenshot Operations
// =============================================================================

/// Request to take a screenshot.
class TakeScreenshotRequest {
  final String name;

  TakeScreenshotRequest({required this.name});

  factory TakeScreenshotRequest.fromJson(Map<String, dynamic> json) {
    return TakeScreenshotRequest(
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
      };
}

/// Response containing screenshot information.
class ScreenshotResponse {
  final String name;
  final String? path;
  final String? base64Data;
  final String? error;

  ScreenshotResponse({
    required this.name,
    this.path,
    this.base64Data,
    this.error,
  });

  factory ScreenshotResponse.fromJson(Map<String, dynamic> json) {
    return ScreenshotResponse(
      name: json['name'] as String,
      path: json['path'] as String?,
      base64Data: json['base64Data'] as String?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (path != null) 'path': path,
        if (base64Data != null) 'base64Data': base64Data,
        if (error != null) 'error': error,
      };
}

// =============================================================================
// Input Operations
// =============================================================================

/// Request to press a key.
class PressKeyRequest {
  final int keyCode;
  final bool hold;
  final int? duration;

  PressKeyRequest({
    required this.keyCode,
    this.hold = false,
    this.duration,
  });

  factory PressKeyRequest.fromJson(Map<String, dynamic> json) {
    return PressKeyRequest(
      keyCode: json['keyCode'] as int,
      hold: json['hold'] as bool? ?? false,
      duration: json['duration'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'keyCode': keyCode,
        'hold': hold,
        if (duration != null) 'duration': duration,
      };
}

/// Request to click the mouse.
class ClickRequest {
  final int button;
  final int x;
  final int y;

  ClickRequest({
    required this.button,
    required this.x,
    required this.y,
  });

  factory ClickRequest.fromJson(Map<String, dynamic> json) {
    return ClickRequest(
      button: json['button'] as int,
      x: json['x'] as int,
      y: json['y'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'button': button,
        'x': x,
        'y': y,
      };
}

/// Request to type text.
class TypeTextRequest {
  final String text;

  TypeTextRequest({required this.text});

  factory TypeTextRequest.fromJson(Map<String, dynamic> json) {
    return TypeTextRequest(
      text: json['text'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
      };
}

/// Request to hold a mouse button.
class HoldMouseRequest {
  final int button;

  HoldMouseRequest({required this.button});

  factory HoldMouseRequest.fromJson(Map<String, dynamic> json) {
    return HoldMouseRequest(
      button: json['button'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'button': button,
      };
}

/// Request to release a mouse button.
class ReleaseMouseRequest {
  final int button;

  ReleaseMouseRequest({required this.button});

  factory ReleaseMouseRequest.fromJson(Map<String, dynamic> json) {
    return ReleaseMouseRequest(
      button: json['button'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'button': button,
      };
}

/// Request to move the mouse cursor.
class MoveMouseRequest {
  final int x;
  final int y;

  MoveMouseRequest({required this.x, required this.y});

  factory MoveMouseRequest.fromJson(Map<String, dynamic> json) {
    return MoveMouseRequest(
      x: json['x'] as int,
      y: json['y'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
      };
}

/// Request to scroll the mouse wheel.
class ScrollRequest {
  final double horizontal;
  final double vertical;

  ScrollRequest({required this.horizontal, required this.vertical});

  factory ScrollRequest.fromJson(Map<String, dynamic> json) {
    return ScrollRequest(
      horizontal: (json['horizontal'] as num).toDouble(),
      vertical: (json['vertical'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'horizontal': horizontal,
        'vertical': vertical,
      };
}

// =============================================================================
// Time/Command Operations
// =============================================================================

/// Request to wait for game ticks.
class WaitTicksRequest {
  final int ticks;

  WaitTicksRequest({required this.ticks});

  factory WaitTicksRequest.fromJson(Map<String, dynamic> json) {
    return WaitTicksRequest(
      ticks: json['ticks'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'ticks': ticks,
      };
}

/// Request to set the time of day.
class SetTimeRequest {
  final int time;

  SetTimeRequest({required this.time});

  factory SetTimeRequest.fromJson(Map<String, dynamic> json) {
    return SetTimeRequest(
      time: json['time'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
      };
}

/// Request to execute a command.
class ExecuteCommandRequest {
  final String command;

  ExecuteCommandRequest({required this.command});

  factory ExecuteCommandRequest.fromJson(Map<String, dynamic> json) {
    return ExecuteCommandRequest(
      command: json['command'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'command': command,
      };
}

/// Response from executing a command.
class CommandResponse {
  final bool success;
  final String? result;
  final String? error;

  CommandResponse({
    required this.success,
    this.result,
    this.error,
  });

  factory CommandResponse.fromJson(Map<String, dynamic> json) {
    return CommandResponse(
      success: json['success'] as bool,
      result: json['result'] as String?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        if (result != null) 'result': result,
        if (error != null) 'error': error,
      };
}

// =============================================================================
// Status/Health
// =============================================================================

/// Response containing server status.
class StatusResponse {
  final bool running;
  final bool clientReady;
  final int? currentTick;
  final int? windowWidth;
  final int? windowHeight;

  StatusResponse({
    required this.running,
    required this.clientReady,
    this.currentTick,
    this.windowWidth,
    this.windowHeight,
  });

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(
      running: json['running'] as bool,
      clientReady: json['clientReady'] as bool,
      currentTick: json['currentTick'] as int?,
      windowWidth: json['windowWidth'] as int?,
      windowHeight: json['windowHeight'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'running': running,
        'clientReady': clientReady,
        if (currentTick != null) 'currentTick': currentTick,
        if (windowWidth != null) 'windowWidth': windowWidth,
        if (windowHeight != null) 'windowHeight': windowHeight,
      };
}

/// Generic success response.
class SuccessResponse {
  final bool success;
  final String? message;

  SuccessResponse({
    this.success = true,
    this.message,
  });

  factory SuccessResponse.fromJson(Map<String, dynamic> json) {
    return SuccessResponse(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        if (message != null) 'message': message,
      };
}

/// Generic error response.
class ErrorResponse {
  final String error;
  final int? code;

  ErrorResponse({
    required this.error,
    this.code,
  });

  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    return ErrorResponse(
      error: json['error'] as String,
      code: json['code'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'error': error,
        if (code != null) 'code': code,
      };
}

// =============================================================================
// Tick Control Operations
// =============================================================================

/// Request to step forward by a number of ticks.
class StepTicksRequest {
  final int count;

  StepTicksRequest({required this.count});

  factory StepTicksRequest.fromJson(Map<String, dynamic> json) {
    return StepTicksRequest(
      count: json['count'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'count': count,
      };
}

/// Request to set the tick rate.
class SetTickRateRequest {
  final double rate;

  SetTickRateRequest({required this.rate});

  factory SetTickRateRequest.fromJson(Map<String, dynamic> json) {
    return SetTickRateRequest(
      rate: (json['rate'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'rate': rate,
      };
}

/// Request to sprint through a number of ticks.
class SprintTicksRequest {
  final int count;

  SprintTicksRequest({required this.count});

  factory SprintTicksRequest.fromJson(Map<String, dynamic> json) {
    return SprintTicksRequest(
      count: json['count'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'count': count,
      };
}

/// Response containing tick state information.
class TickStateResponse {
  final bool frozen;
  final double tickRate;
  final bool stepping;
  final bool sprinting;
  final int frozenTicksToRun;

  TickStateResponse({
    required this.frozen,
    required this.tickRate,
    required this.stepping,
    required this.sprinting,
    required this.frozenTicksToRun,
  });

  factory TickStateResponse.fromJson(Map<String, dynamic> json) {
    return TickStateResponse(
      frozen: json['frozen'] as bool,
      tickRate: (json['tickRate'] as num).toDouble(),
      stepping: json['stepping'] as bool,
      sprinting: json['sprinting'] as bool,
      frozenTicksToRun: json['frozenTicksToRun'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'frozen': frozen,
        'tickRate': tickRate,
        'stepping': stepping,
        'sprinting': sprinting,
        'frozenTicksToRun': frozenTicksToRun,
      };
}
