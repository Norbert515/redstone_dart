package com.redstone.network;

import com.redstone.DartBridgeClient;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Client-side packet handler.
 *
 * <p>This class handles receiving packets from the server and
 * dispatching them to the client Flutter runtime.
 */
@Environment(EnvType.CLIENT)
public class ClientPacketHandler {
    private static final Logger LOGGER = LoggerFactory.getLogger("ClientPacketHandler");

    private static boolean registered = false;

    /**
     * Register client-side packet handlers.
     * Should be called during client mod initialization.
     */
    public static void registerHandlers() {
        if (registered) {
            return;
        }
        registered = true;

        LOGGER.info("Registering client packet handlers...");

        // Handle packets from server (S2C)
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.MOD_PACKET_TYPE, (payload, context) -> {
            // Process on the render thread
            context.client().execute(() -> {
                handlePacket(payload.packetType(), payload.data());
            });
        });

        LOGGER.info("Client packet handlers registered");
    }

    /**
     * Handle a packet received from the server.
     *
     * @param packetType The packet type ID
     * @param data The packet payload data
     */
    public static void handlePacket(int packetType, byte[] data) {
        LOGGER.debug("Received S2C packet type {} with {} bytes", packetType, data.length);

        // Dispatch to native bridge -> Flutter/Dart client runtime
        DartBridgeClient.dispatchServerPacket(packetType, data);
    }

    /**
     * Send a packet to the server.
     *
     * @param packetType The packet type ID
     * @param data The packet payload data
     */
    public static void sendToServer(int packetType, byte[] data) {
        ModPacketPayload payload = new ModPacketPayload(packetType, data);
        ClientPlayNetworking.send(payload);
    }

    /**
     * Send a packet to the server using raw bytes.
     *
     * @param packetBytes The complete packet bytes (type + length + data)
     */
    public static void sendToServer(byte[] packetBytes) {
        try {
            ModPacketPayload payload = ModPacketPayload.fromBytes(packetBytes);
            ClientPlayNetworking.send(payload);
        } catch (IllegalArgumentException e) {
            LOGGER.error("Failed to parse packet bytes: {}", e.getMessage());
        }
    }
}
