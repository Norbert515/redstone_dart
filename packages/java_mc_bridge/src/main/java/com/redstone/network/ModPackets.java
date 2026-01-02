package com.redstone.network;

import net.fabricmc.fabric.api.networking.v1.PayloadTypeRegistry;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.RegistryFriendlyByteBuf;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;
import net.minecraft.resources.Identifier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Registers all mod packet types with Fabric networking.
 *
 * <p>This class handles the registration of custom packet payloads for
 * communication between the server Dart VM and client Flutter runtime.
 */
public class ModPackets {
    private static final Logger LOGGER = LoggerFactory.getLogger("ModPackets");

    /** The mod's networking channel identifier. */
    public static final Identifier CHANNEL_ID = Identifier.fromNamespaceAndPath("redstone", "packets");

    /** Packet payload type ID for mod packets. */
    public static final CustomPacketPayload.Type<ModPacketPayload> MOD_PACKET_TYPE =
            new CustomPacketPayload.Type<>(CHANNEL_ID);

    /** Codec for reading/writing mod packets. */
    public static final StreamCodec<RegistryFriendlyByteBuf, ModPacketPayload> MOD_PACKET_CODEC =
            StreamCodec.of(ModPacketPayload::write, ModPacketPayload::read);

    private static boolean initialized = false;

    /**
     * Initialize packet registration.
     * Should be called during mod initialization on both client and server.
     */
    public static void register() {
        if (initialized) {
            return;
        }
        initialized = true;

        LOGGER.info("Registering mod packet types...");

        // Register S2C (Server-to-Client) packets
        PayloadTypeRegistry.playS2C().register(MOD_PACKET_TYPE, MOD_PACKET_CODEC);

        // Register C2S (Client-to-Server) packets
        PayloadTypeRegistry.playC2S().register(MOD_PACKET_TYPE, MOD_PACKET_CODEC);

        LOGGER.info("Mod packet types registered successfully");
    }

    /**
     * Register server-side packet handlers.
     * Should be called during server mod initialization.
     */
    public static void registerServerHandlers() {
        LOGGER.info("Registering server packet handlers...");

        // Handle packets from clients (C2S)
        ServerPlayNetworking.registerGlobalReceiver(MOD_PACKET_TYPE, (payload, context) -> {
            // Process on the server thread
            context.server().execute(() -> {
                C2SPacketHandler.handlePacket(
                        payload.packetType(),
                        payload.data(),
                        context.player()
                );
            });
        });

        LOGGER.info("Server packet handlers registered");
    }
}
