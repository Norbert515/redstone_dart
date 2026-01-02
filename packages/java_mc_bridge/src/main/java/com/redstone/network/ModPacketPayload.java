package com.redstone.network;

import net.minecraft.network.RegistryFriendlyByteBuf;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;

/**
 * Custom packet payload for mod networking.
 *
 * <p>This is the actual data carrier for packets sent between
 * the server and client Dart/Flutter runtimes.
 *
 * <p>Format:
 * <ul>
 *   <li>1 byte: packet type ID</li>
 *   <li>4 bytes: payload length</li>
 *   <li>N bytes: payload data</li>
 * </ul>
 */
public record ModPacketPayload(int packetType, byte[] data) implements CustomPacketPayload {

    @Override
    public Type<? extends CustomPacketPayload> type() {
        return ModPackets.MOD_PACKET_TYPE;
    }

    /**
     * Write this payload to a buffer.
     */
    public static void write(RegistryFriendlyByteBuf buf, ModPacketPayload payload) {
        buf.writeByte(payload.packetType);
        buf.writeInt(payload.data.length);
        buf.writeBytes(payload.data);
    }

    /**
     * Read a payload from a buffer.
     */
    public static ModPacketPayload read(RegistryFriendlyByteBuf buf) {
        int packetType = buf.readByte() & 0xFF;
        int length = buf.readInt();
        byte[] data = new byte[length];
        buf.readBytes(data);
        return new ModPacketPayload(packetType, data);
    }

    /**
     * Create a payload from raw packet bytes.
     * The bytes should be in the format: [type(1)][length(4)][data(N)]
     */
    public static ModPacketPayload fromBytes(byte[] bytes) {
        if (bytes.length < 5) {
            throw new IllegalArgumentException("Packet too short: " + bytes.length);
        }

        int packetType = bytes[0] & 0xFF;
        int length = ((bytes[1] & 0xFF) << 24) |
                     ((bytes[2] & 0xFF) << 16) |
                     ((bytes[3] & 0xFF) << 8) |
                     (bytes[4] & 0xFF);

        if (bytes.length < 5 + length) {
            throw new IllegalArgumentException("Packet data incomplete: expected " + (5 + length) + ", got " + bytes.length);
        }

        byte[] data = new byte[length];
        System.arraycopy(bytes, 5, data, 0, length);

        return new ModPacketPayload(packetType, data);
    }

    /**
     * Convert this payload to raw packet bytes.
     */
    public byte[] toBytes() {
        byte[] bytes = new byte[5 + data.length];

        bytes[0] = (byte) packetType;
        bytes[1] = (byte) ((data.length >> 24) & 0xFF);
        bytes[2] = (byte) ((data.length >> 16) & 0xFF);
        bytes[3] = (byte) ((data.length >> 8) & 0xFF);
        bytes[4] = (byte) (data.length & 0xFF);

        System.arraycopy(data, 0, bytes, 5, data.length);

        return bytes;
    }
}
