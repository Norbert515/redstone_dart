/// Packet type IDs for client-server communication.
library;

/// Enum defining all packet type IDs.
///
/// Server-to-Client packets (S2C): 0x00 - 0x7F
/// Client-to-Server packets (C2S): 0x80 - 0xFF
abstract class PacketTypes {
  // ==========================================================================
  // Server-to-Client (S2C) Packets: 0x00 - 0x7F
  // ==========================================================================

  /// Block update notification (server -> client).
  static const int blockUpdate = 0x01;

  /// Entity state update (server -> client).
  static const int entityUpdate = 0x02;

  /// Screen data for UI display (server -> client).
  static const int screenData = 0x03;

  /// General state synchronization (server -> client).
  static const int syncState = 0x04;

  /// Custom event from server (server -> client).
  static const int serverEvent = 0x05;

  // ==========================================================================
  // Client-to-Server (C2S) Packets: 0x80 - 0xFF
  // ==========================================================================

  /// UI action (button click, etc.) from client (client -> server).
  static const int uiAction = 0x80;

  /// Client requests data from server (client -> server).
  static const int requestData = 0x81;

  /// Custom event from client (client -> server).
  static const int clientEvent = 0x82;

  /// Check if a packet type is server-to-client.
  static bool isS2C(int typeId) => typeId >= 0x00 && typeId < 0x80;

  /// Check if a packet type is client-to-server.
  static bool isC2S(int typeId) => typeId >= 0x80;
}
