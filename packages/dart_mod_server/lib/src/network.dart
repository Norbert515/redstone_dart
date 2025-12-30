/// Server-side network module for client-server communication.
library;

// ignore_for_file: unused_field

import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:ffi/ffi.dart';

/// Server-side network handler for sending packets to clients.
///
/// This class provides the server-side API for sending packets to clients
/// and registering handlers for receiving packets from clients.
class ServerNetwork {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  // Dart-side packet handlers
  static final List<void Function(int playerId, ModPacket packet)>
      _packetHandlers = [];

  /// Initialize the server network module.
  static void init(String libraryPath) {
    if (_initialized) return;

    _lib = DynamicLibrary.open(libraryPath);
    _initialized = true;

    // Bind functions
    _bindFunctions();

    // Register S2C packet decoders
    registerS2CPackets();
    registerC2SPackets();

    // Register native callback for receiving packets
    _registerNativeCallback();
  }

  // Native function bindings
  static late final _ServerRegisterPacketReceivedHandler
      _serverRegisterPacketReceivedHandler;
  static late final _ServerSetSendPacketToClientCallback
      _serverSetSendPacketToClientCallback;
  static late final _ServerSendPacketToClient _serverSendPacketToClient;

  static void _bindFunctions() {
    final lib = _lib!;

    _serverRegisterPacketReceivedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_PacketReceivedCallbackNative>>),
        void Function(Pointer<NativeFunction<_PacketReceivedCallbackNative>>)>(
        'server_register_packet_received_handler');

    _serverSetSendPacketToClientCallback = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_SendPacketToClientCallbackNative>>),
        void Function(Pointer<NativeFunction<_SendPacketToClientCallbackNative>>)>(
        'server_set_send_packet_to_client_callback');

    _serverSendPacketToClient = lib.lookupFunction<
        Void Function(Int32, Int32, Pointer<Uint8>, Int32),
        void Function(int, int, Pointer<Uint8>, int)>(
        'server_send_packet_to_client');
  }

  static void _registerNativeCallback() {
    // Create a static callback that can be passed to native code
    final callbackPtr = Pointer.fromFunction<_PacketReceivedCallbackNative>(
        _onPacketReceived);
    _serverRegisterPacketReceivedHandler(callbackPtr);
  }

  /// Native callback invoked when a packet is received from a client.
  static void _onPacketReceived(
      int playerId, int packetType, Pointer<Uint8> data, int dataLength) {
    // Copy data to Dart memory
    final bytes = Uint8List(dataLength);
    for (var i = 0; i < dataLength; i++) {
      bytes[i] = data[i];
    }

    // Decode the packet
    final packet = PacketRegistry.decode(packetType, bytes);
    if (packet == null) {
      print('[ServerNetwork] Unknown packet type: $packetType');
      return;
    }

    // Notify all handlers
    for (final handler in _packetHandlers) {
      try {
        handler(playerId, packet);
      } catch (e) {
        print('[ServerNetwork] Error in packet handler: $e');
      }
    }
  }

  /// Register a handler for receiving packets from clients.
  ///
  /// The handler will be called for all received packets.
  /// Use pattern matching to handle specific packet types:
  ///
  /// ```dart
  /// ServerNetwork.onPacketReceived((playerId, packet) {
  ///   switch (packet) {
  ///     case UIActionPacket(:final actionType, :final widgetId):
  ///       print('Player $playerId clicked widget $widgetId');
  ///       break;
  ///   }
  /// });
  /// ```
  static void onPacketReceived(
      void Function(int playerId, ModPacket packet) handler) {
    _packetHandlers.add(handler);
  }

  /// Remove a packet handler.
  static void removePacketHandler(
      void Function(int playerId, ModPacket packet) handler) {
    _packetHandlers.remove(handler);
  }

  /// Send a packet to a specific player.
  ///
  /// ```dart
  /// ServerNetwork.sendToPlayer(playerId, BlockUpdatePacket(
  ///   x: 100, y: 64, z: 100,
  ///   blockId: 'minecraft:diamond_block',
  /// ));
  /// ```
  static void sendToPlayer(int playerId, ModPacket packet) {
    if (!_initialized) {
      print('[ServerNetwork] Not initialized');
      return;
    }

    final bytes = packet.encodePayload();
    final nativeBytes = calloc<Uint8>(bytes.length);

    try {
      for (var i = 0; i < bytes.length; i++) {
        nativeBytes[i] = bytes[i];
      }
      _serverSendPacketToClient(playerId, packet.typeId, nativeBytes, bytes.length);
    } finally {
      calloc.free(nativeBytes);
    }
  }

  /// Send a block update packet to a player.
  static void sendBlockUpdate(int playerId, int x, int y, int z, String blockId,
      {Map<String, dynamic>? stateData}) {
    sendToPlayer(playerId, BlockUpdatePacket(
      x: x, y: y, z: z,
      blockId: blockId,
      stateData: stateData,
    ));
  }

  /// Send an entity update packet to a player.
  static void sendEntityUpdate(int playerId, int entityId, {
    String? entityType,
    double? x, double? y, double? z,
    double? health,
    Map<String, dynamic>? customData,
    bool removed = false,
  }) {
    sendToPlayer(playerId, EntityUpdatePacket(
      entityId: entityId,
      entityType: entityType,
      x: x, y: y, z: z,
      health: health,
      customData: customData,
      removed: removed,
    ));
  }

  /// Send screen data to a player's client UI.
  static void sendScreenData(int playerId, int screenId, String key, dynamic value) {
    sendToPlayer(playerId, ScreenDataPacket(
      screenId: screenId,
      key: key,
      value: value,
    ));
  }

  /// Send a general state sync packet to a player.
  static void sendSyncState(int playerId, String category, String key, dynamic value) {
    sendToPlayer(playerId, SyncStatePacket(
      category: category,
      key: key,
      value: value,
    ));
  }

  /// Send a custom server event to a player.
  static void sendServerEvent(int playerId, String eventName, Map<String, dynamic> payload) {
    sendToPlayer(playerId, ServerEventPacket(
      eventName: eventName,
      payload: payload,
    ));
  }
}

// Native callback signatures
typedef _PacketReceivedCallbackNative = Void Function(
    Int32 playerId, Int32 packetType, Pointer<Uint8> data, Int32 dataLength);
typedef _SendPacketToClientCallbackNative = Void Function(
    Int32 playerId, Int32 packetType, Pointer<Uint8> data, Int32 dataLength);

// Native function typedefs
typedef _ServerRegisterPacketReceivedHandler = void Function(
    Pointer<NativeFunction<_PacketReceivedCallbackNative>>);
typedef _ServerSetSendPacketToClientCallback = void Function(
    Pointer<NativeFunction<_SendPacketToClientCallbackNative>>);
typedef _ServerSendPacketToClient = void Function(
    int, int, Pointer<Uint8>, int);
