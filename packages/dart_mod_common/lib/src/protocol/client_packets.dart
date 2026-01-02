/// Client-to-Server (C2S) packets.
library;

import 'dart:typed_data';

import 'packet.dart';
import 'packet_types.dart';

/// UI action types.
enum UIActionType {
  /// Button was clicked.
  buttonClick,

  /// Text field value changed.
  textChange,

  /// Slider value changed.
  sliderChange,

  /// Checkbox toggled.
  checkboxToggle,

  /// Custom action.
  custom,
}

/// UI action packet (user clicked button, changed text, etc.).
class UIActionPacket extends ModPacket {
  /// The screen ID where the action occurred.
  final int screenId;

  /// The widget ID that triggered the action.
  final int widgetId;

  /// The type of UI action.
  final UIActionType actionType;

  /// Additional action data (depends on action type).
  final Map<String, dynamic>? data;

  UIActionPacket({
    required this.screenId,
    required this.widgetId,
    required this.actionType,
    this.data,
  });

  @override
  int get typeId => PacketTypes.uiAction;

  @override
  Uint8List encodePayload() {
    return ModPacket.encodeJson({
      'screenId': screenId,
      'widgetId': widgetId,
      'actionType': actionType.index,
      if (data != null) 'data': data,
    });
  }

  /// Decode from payload bytes.
  static UIActionPacket decode(Uint8List payload) {
    final json = ModPacket.decodeJson(payload);
    return UIActionPacket(
      screenId: json['screenId'] as int,
      widgetId: json['widgetId'] as int,
      actionType: UIActionType.values[json['actionType'] as int],
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

/// Request data types.
enum RequestDataType {
  /// Request entity data.
  entity,

  /// Request block data.
  block,

  /// Request player data.
  player,

  /// Request inventory data.
  inventory,

  /// Request world data.
  world,

  /// Request custom data.
  custom,
}

/// Client requests data from server.
class RequestDataPacket extends ModPacket {
  /// The type of data being requested.
  final RequestDataType requestType;

  /// Request-specific parameters.
  final Map<String, dynamic> parameters;

  /// Optional request ID for matching responses.
  final int? requestId;

  RequestDataPacket({
    required this.requestType,
    required this.parameters,
    this.requestId,
  });

  @override
  int get typeId => PacketTypes.requestData;

  @override
  Uint8List encodePayload() {
    return ModPacket.encodeJson({
      'requestType': requestType.index,
      'parameters': parameters,
      if (requestId != null) 'requestId': requestId,
    });
  }

  /// Decode from payload bytes.
  static RequestDataPacket decode(Uint8List payload) {
    final json = ModPacket.decodeJson(payload);
    return RequestDataPacket(
      requestType: RequestDataType.values[json['requestType'] as int],
      parameters: json['parameters'] as Map<String, dynamic>,
      requestId: json['requestId'] as int?,
    );
  }
}

/// Custom client event packet.
class ClientEventPacket extends ModPacket {
  /// The event name.
  final String eventName;

  /// Event payload data.
  final Map<String, dynamic> payload;

  ClientEventPacket({
    required this.eventName,
    required this.payload,
  });

  @override
  int get typeId => PacketTypes.clientEvent;

  @override
  Uint8List encodePayload() {
    return ModPacket.encodeJson({
      'eventName': eventName,
      'payload': payload,
    });
  }

  /// Decode from payload bytes.
  static ClientEventPacket decode(Uint8List payload) {
    final data = ModPacket.decodeJson(payload);
    return ClientEventPacket(
      eventName: data['eventName'] as String,
      payload: data['payload'] as Map<String, dynamic>,
    );
  }
}

/// Initialize C2S packet decoders in the registry.
void registerC2SPackets() {
  PacketRegistry.register(PacketTypes.uiAction, UIActionPacket.decode);
  PacketRegistry.register(PacketTypes.requestData, RequestDataPacket.decode);
  PacketRegistry.register(PacketTypes.clientEvent, ClientEventPacket.decode);
}
