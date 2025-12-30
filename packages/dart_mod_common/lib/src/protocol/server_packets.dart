/// Server-to-Client (S2C) packets.
library;

import 'dart:typed_data';

import 'packet.dart';
import 'packet_types.dart';

/// Notify client of a block change.
class BlockUpdatePacket extends ModPacket {
  /// The block position X coordinate.
  final int x;

  /// The block position Y coordinate.
  final int y;

  /// The block position Z coordinate.
  final int z;

  /// The block ID (e.g., "minecraft:stone" or "mymod:custom_block").
  final String blockId;

  /// Optional block state data as JSON.
  final Map<String, dynamic>? stateData;

  BlockUpdatePacket({
    required this.x,
    required this.y,
    required this.z,
    required this.blockId,
    this.stateData,
  });

  @override
  int get typeId => PacketTypes.blockUpdate;

  @override
  Uint8List encodePayload() {
    return ModPacket.encodeJson({
      'x': x,
      'y': y,
      'z': z,
      'blockId': blockId,
      if (stateData != null) 'stateData': stateData,
    });
  }

  /// Decode from payload bytes.
  static BlockUpdatePacket decode(Uint8List payload) {
    final data = ModPacket.decodeJson(payload);
    return BlockUpdatePacket(
      x: data['x'] as int,
      y: data['y'] as int,
      z: data['z'] as int,
      blockId: data['blockId'] as String,
      stateData: data['stateData'] as Map<String, dynamic>?,
    );
  }
}

/// Notify client of entity state changes.
class EntityUpdatePacket extends ModPacket {
  /// The entity ID.
  final int entityId;

  /// The entity type ID (e.g., "minecraft:zombie").
  final String? entityType;

  /// Entity position X.
  final double? x;

  /// Entity position Y.
  final double? y;

  /// Entity position Z.
  final double? z;

  /// Entity health.
  final double? health;

  /// Custom entity data as JSON.
  final Map<String, dynamic>? customData;

  /// Whether the entity was removed.
  final bool removed;

  EntityUpdatePacket({
    required this.entityId,
    this.entityType,
    this.x,
    this.y,
    this.z,
    this.health,
    this.customData,
    this.removed = false,
  });

  @override
  int get typeId => PacketTypes.entityUpdate;

  @override
  Uint8List encodePayload() {
    return ModPacket.encodeJson({
      'entityId': entityId,
      if (entityType != null) 'entityType': entityType,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (z != null) 'z': z,
      if (health != null) 'health': health,
      if (customData != null) 'customData': customData,
      if (removed) 'removed': removed,
    });
  }

  /// Decode from payload bytes.
  static EntityUpdatePacket decode(Uint8List payload) {
    final data = ModPacket.decodeJson(payload);
    return EntityUpdatePacket(
      entityId: data['entityId'] as int,
      entityType: data['entityType'] as String?,
      x: (data['x'] as num?)?.toDouble(),
      y: (data['y'] as num?)?.toDouble(),
      z: (data['z'] as num?)?.toDouble(),
      health: (data['health'] as num?)?.toDouble(),
      customData: data['customData'] as Map<String, dynamic>?,
      removed: data['removed'] as bool? ?? false,
    );
  }
}

/// Send data to display in a client UI screen.
class ScreenDataPacket extends ModPacket {
  /// The screen ID this data is for.
  final int screenId;

  /// The data key (identifies what kind of data this is).
  final String key;

  /// The data value (JSON-encodable).
  final dynamic value;

  ScreenDataPacket({
    required this.screenId,
    required this.key,
    required this.value,
  });

  @override
  int get typeId => PacketTypes.screenData;

  @override
  Uint8List encodePayload() {
    return ModPacket.encodeJson({
      'screenId': screenId,
      'key': key,
      'value': value,
    });
  }

  /// Decode from payload bytes.
  static ScreenDataPacket decode(Uint8List payload) {
    final data = ModPacket.decodeJson(payload);
    return ScreenDataPacket(
      screenId: data['screenId'] as int,
      key: data['key'] as String,
      value: data['value'],
    );
  }
}

/// General state synchronization packet.
///
/// Used for synchronizing arbitrary state between server and client.
class SyncStatePacket extends ModPacket {
  /// The state category/namespace.
  final String category;

  /// The state key.
  final String key;

  /// The state value (JSON-encodable).
  final dynamic value;

  SyncStatePacket({
    required this.category,
    required this.key,
    required this.value,
  });

  @override
  int get typeId => PacketTypes.syncState;

  @override
  Uint8List encodePayload() {
    return ModPacket.encodeJson({
      'category': category,
      'key': key,
      'value': value,
    });
  }

  /// Decode from payload bytes.
  static SyncStatePacket decode(Uint8List payload) {
    final data = ModPacket.decodeJson(payload);
    return SyncStatePacket(
      category: data['category'] as String,
      key: data['key'] as String,
      value: data['value'],
    );
  }
}

/// Custom server event packet.
class ServerEventPacket extends ModPacket {
  /// The event name.
  final String eventName;

  /// Event payload data.
  final Map<String, dynamic> payload;

  ServerEventPacket({
    required this.eventName,
    required this.payload,
  });

  @override
  int get typeId => PacketTypes.serverEvent;

  @override
  Uint8List encodePayload() {
    return ModPacket.encodeJson({
      'eventName': eventName,
      'payload': payload,
    });
  }

  /// Decode from payload bytes.
  static ServerEventPacket decode(Uint8List payload) {
    final data = ModPacket.decodeJson(payload);
    return ServerEventPacket(
      eventName: data['eventName'] as String,
      payload: data['payload'] as Map<String, dynamic>,
    );
  }
}

/// Initialize S2C packet decoders in the registry.
void registerS2CPackets() {
  PacketRegistry.register(PacketTypes.blockUpdate, BlockUpdatePacket.decode);
  PacketRegistry.register(PacketTypes.entityUpdate, EntityUpdatePacket.decode);
  PacketRegistry.register(PacketTypes.screenData, ScreenDataPacket.decode);
  PacketRegistry.register(PacketTypes.syncState, SyncStatePacket.decode);
  PacketRegistry.register(PacketTypes.serverEvent, ServerEventPacket.decode);
}
