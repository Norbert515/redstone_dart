package com.redstone.network;

import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.server.level.ServerPlayer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handles sending packets from server to client (S2C).
 *
 * <p>This class provides methods to send packets from the server Dart VM
 * to the client Flutter runtime via Minecraft's networking system.
 */
public class S2CPacketHandler {
    private static final Logger LOGGER = LoggerFactory.getLogger("S2CPacketHandler");

    /**
     * Send a packet to a specific player.
     *
     * @param player The player to send the packet to
     * @param packetType The packet type ID
     * @param data The packet payload data
     */
    public static void sendToPlayer(ServerPlayer player, int packetType, byte[] data) {
        if (player == null || player.connection == null) {
            LOGGER.warn("Cannot send packet: player or connection is null");
            return;
        }

        ModPacketPayload payload = new ModPacketPayload(packetType, data);
        ServerPlayNetworking.send(player, payload);
    }

    /**
     * Send a packet to a specific player using raw bytes.
     *
     * @param player The player to send the packet to
     * @param packetBytes The complete packet bytes (type + length + data)
     */
    public static void sendToPlayer(ServerPlayer player, byte[] packetBytes) {
        if (player == null || player.connection == null) {
            LOGGER.warn("Cannot send packet: player or connection is null");
            return;
        }

        try {
            ModPacketPayload payload = ModPacketPayload.fromBytes(packetBytes);
            ServerPlayNetworking.send(player, payload);
        } catch (IllegalArgumentException e) {
            LOGGER.error("Failed to parse packet bytes: {}", e.getMessage());
        }
    }

    /**
     * Send a packet to all players on the server.
     *
     * @param server The Minecraft server instance
     * @param packetType The packet type ID
     * @param data The packet payload data
     */
    public static void sendToAll(net.minecraft.server.MinecraftServer server, int packetType, byte[] data) {
        if (server == null) {
            LOGGER.warn("Cannot broadcast packet: server is null");
            return;
        }

        ModPacketPayload payload = new ModPacketPayload(packetType, data);
        for (ServerPlayer player : server.getPlayerList().getPlayers()) {
            if (player.connection != null) {
                ServerPlayNetworking.send(player, payload);
            }
        }
    }

    /**
     * Send a packet to all players in a specific world/dimension.
     *
     * @param level The server level to broadcast to
     * @param packetType The packet type ID
     * @param data The packet payload data
     */
    public static void sendToLevel(net.minecraft.server.level.ServerLevel level, int packetType, byte[] data) {
        if (level == null) {
            LOGGER.warn("Cannot send to level: level is null");
            return;
        }

        ModPacketPayload payload = new ModPacketPayload(packetType, data);
        for (ServerPlayer player : level.players()) {
            if (player.connection != null) {
                ServerPlayNetworking.send(player, payload);
            }
        }
    }

    /**
     * Send a packet to all players within a radius of a position.
     *
     * @param level The server level
     * @param x Center X position
     * @param y Center Y position
     * @param z Center Z position
     * @param radius The radius to send within
     * @param packetType The packet type ID
     * @param data The packet payload data
     */
    public static void sendToNearby(net.minecraft.server.level.ServerLevel level,
                                    double x, double y, double z, double radius,
                                    int packetType, byte[] data) {
        if (level == null) {
            LOGGER.warn("Cannot send to nearby: level is null");
            return;
        }

        double radiusSq = radius * radius;
        ModPacketPayload payload = new ModPacketPayload(packetType, data);

        for (ServerPlayer player : level.players()) {
            if (player.connection != null) {
                double distSq = player.distanceToSqr(x, y, z);
                if (distSq <= radiusSq) {
                    ServerPlayNetworking.send(player, payload);
                }
            }
        }
    }
}
