package com.redstone.network;

import com.redstone.DartBridge;
import net.minecraft.server.level.ServerPlayer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handles receiving packets from client to server (C2S).
 *
 * <p>This class processes packets from the client Flutter runtime
 * and dispatches them to the server Dart VM.
 */
public class C2SPacketHandler {
    private static final Logger LOGGER = LoggerFactory.getLogger("C2SPacketHandler");

    /**
     * Handle a packet received from a client.
     *
     * <p>This method is called on the server thread when a packet is received.
     *
     * @param packetType The packet type ID
     * @param data The packet payload data
     * @param player The player who sent the packet
     */
    public static void handlePacket(int packetType, byte[] data, ServerPlayer player) {
        if (player == null) {
            LOGGER.warn("Received packet from null player");
            return;
        }

        LOGGER.debug("Received C2S packet type {} from player {} with {} bytes",
                packetType, player.getName().getString(), data.length);

        // Dispatch to native bridge -> Dart VM
        DartBridge.dispatchClientPacket(player.getId(), packetType, data);
    }

    /**
     * Packet type ID constants (must match Dart PacketTypes).
     */
    public static class PacketTypes {
        // Server-to-Client (S2C): 0x00 - 0x7F
        public static final int BLOCK_UPDATE = 0x01;
        public static final int ENTITY_UPDATE = 0x02;
        public static final int SCREEN_DATA = 0x03;
        public static final int SYNC_STATE = 0x04;
        public static final int SERVER_EVENT = 0x05;

        // Client-to-Server (C2S): 0x80 - 0xFF
        public static final int UI_ACTION = 0x80;
        public static final int REQUEST_DATA = 0x81;
        public static final int CLIENT_EVENT = 0x82;

        public static boolean isS2C(int typeId) {
            return typeId >= 0x00 && typeId < 0x80;
        }

        public static boolean isC2S(int typeId) {
            return typeId >= 0x80;
        }
    }
}
