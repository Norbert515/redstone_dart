/// Base packet class for client-server communication.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Base class for all mod packets.
///
/// Packets are used to synchronize state between the server Dart VM
/// and the client Flutter runtime.
abstract class ModPacket {
  /// The packet type ID, used for deserialization.
  int get typeId;

  /// Encode the packet payload to bytes.
  ///
  /// Subclasses should override this to encode their specific data.
  Uint8List encodePayload();

  /// Encode the full packet (type ID + length + payload).
  Uint8List encode() {
    final payload = encodePayload();
    final buffer = ByteData(5 + payload.length);

    // [1 byte: packet type ID]
    buffer.setUint8(0, typeId);

    // [4 bytes: payload length]
    buffer.setUint32(1, payload.length, Endian.big);

    // [N bytes: payload]
    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(5, 5 + payload.length, payload);

    return bytes;
  }

  /// Decode a packet from bytes.
  ///
  /// Returns null if the bytes are invalid or incomplete.
  static ModPacket? decode(Uint8List bytes) {
    if (bytes.length < 5) return null;

    final buffer = ByteData.sublistView(bytes);
    final typeId = buffer.getUint8(0);
    final payloadLength = buffer.getUint32(1, Endian.big);

    if (bytes.length < 5 + payloadLength) return null;

    final payload = bytes.sublist(5, 5 + payloadLength);

    return _decodeByType(typeId, payload);
  }

  /// Decode a packet by its type ID.
  static ModPacket? _decodeByType(int typeId, Uint8List payload) {
    return PacketRegistry.decode(typeId, payload);
  }

  /// Helper to encode a JSON payload.
  static Uint8List encodeJson(Map<String, dynamic> data) {
    return Uint8List.fromList(utf8.encode(jsonEncode(data)));
  }

  /// Helper to decode a JSON payload.
  static Map<String, dynamic> decodeJson(Uint8List payload) {
    return jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
  }
}

/// Registry for packet decoders.
///
/// This allows registering custom packet types and their decoders.
class PacketRegistry {
  static final Map<int, ModPacket Function(Uint8List)> _decoders = {};

  /// Register a packet decoder.
  static void register(int typeId, ModPacket Function(Uint8List) decoder) {
    _decoders[typeId] = decoder;
  }

  /// Decode a packet by type ID.
  static ModPacket? decode(int typeId, Uint8List payload) {
    final decoder = _decoders[typeId];
    if (decoder == null) return null;
    return decoder(payload);
  }

  /// Check if a packet type is registered.
  static bool isRegistered(int typeId) => _decoders.containsKey(typeId);
}
