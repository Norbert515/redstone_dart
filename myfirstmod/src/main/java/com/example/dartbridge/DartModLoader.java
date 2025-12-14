package com.example.dartbridge;

import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.event.player.PlayerBlockBreakEvents;
import net.fabricmc.fabric.api.event.player.UseBlockCallback;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.minecraft.commands.Commands;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.Style;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.InteractionHand;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.nio.file.Path;

/**
 * Fabric mod initializer that loads and manages the Dart VM.
 *
 * This class is responsible for:
 * - Initializing the Dart VM when the server starts
 * - Forwarding Minecraft events to Dart handlers
 * - Shutting down the Dart VM when the server stops
 */
public class DartModLoader implements ModInitializer {
    public static final String MOD_ID = "dart_bridge";
    private static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);
    private static long tickCounter = 0;
    private static MinecraftServer serverInstance = null;

    /**
     * Get the path to the Dart script file.
     */
    private static String getScriptPath() {
        // Look for dart_mod in several locations
        // Prefer the package structure (dart_mod/lib/dart_mod.dart) over single file
        String[] searchPaths = {
            "../../dart_mc_bridge/dart_mod/lib/dart_mod.dart",  // Source location (for hot reload)
            "mods/dart_mod/lib/dart_mod.dart",  // Package structure
            "mods/dart_mod.dart",                // Single file
            "dart_mod/lib/dart_mod.dart",
            "dart_mod.dart",
            "config/dart_mod.dart"
        };

        String runDir = System.getProperty("user.dir");
        for (String path : searchPaths) {
            File f = new File(runDir, path);
            if (f.exists()) {
                return f.getAbsolutePath();
            }
        }

        // Default path
        return Path.of(runDir, "mods", "dart_mod", "lib", "dart_mod.dart").toAbsolutePath().toString();
    }

    @Override
    public void onInitialize() {
        LOGGER.info("[{}] Initializing Dart Bridge mod...", MOD_ID);

        if (!DartBridge.isLibraryLoaded()) {
            LOGGER.error("[{}] Native library not loaded, Dart Bridge will be disabled", MOD_ID);
            return;
        }

        // Initialize Dart VM NOW during mod initialization (before registry freeze)
        // This is critical - block registration must happen during onInitialize()
        String scriptPath = getScriptPath();
        LOGGER.info("[{}] Script path: {}", MOD_ID, scriptPath);

        File scriptFile = new File(scriptPath);
        if (!scriptFile.exists()) {
            LOGGER.error("[{}] Dart script not found at: {}", MOD_ID, scriptPath);
            LOGGER.error("[{}] Please place your dart_mod.dart file in the mods folder", MOD_ID);
        } else {
            // Initialize Dart VM synchronously during mod init
            // This allows Dart to register blocks before the registry freezes
            if (!DartBridge.safeInit(scriptPath)) {
                LOGGER.error("[{}] Failed to initialize Dart VM!", MOD_ID);
            } else {
                LOGGER.info("[{}] Dart VM initialized successfully!", MOD_ID);
            }
        }

        // Set up server reference and chat handler when server starts
        ServerLifecycleEvents.SERVER_STARTING.register(server -> {
            serverInstance = server;
            DartBridge.setServerInstance(server);
            LOGGER.info("[{}] Server starting, setting up chat handler...", MOD_ID);

            // Register chat message handler
            DartBridge.setChatMessageHandler((playerId, message) -> {
                if (serverInstance == null) return;

                // Find player by entity ID
                for (ServerPlayer player : serverInstance.getPlayerList().getPlayers()) {
                    if (player.getId() == playerId) {
                        player.sendSystemMessage(Component.literal(message));
                        return;
                    }
                }
                // If player not found, broadcast to all
                LOGGER.warn("[{}] Player with ID {} not found, broadcasting message", MOD_ID, playerId);
                serverInstance.getPlayerList().broadcastSystemMessage(Component.literal(message), false);
            });
        });

        // Shutdown Dart VM when server stops
        ServerLifecycleEvents.SERVER_STOPPED.register(server -> {
            LOGGER.info("[{}] Server stopped, shutting down Dart VM...", MOD_ID);
            DartBridge.safeShutdown();
            DartBridge.setServerInstance(null);
            serverInstance = null;
        });

        // Register /darturl command to show service URL
        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            dispatcher.register(Commands.literal("darturl")
                .executes(context -> {
                    String url = DartBridge.getServiceUrl();
                    if (url != null) {
                        Component message = Component.literal("[Dart] VM Service URL: ")
                            .withStyle(Style.EMPTY.withColor(0x00AAFF))
                            .append(Component.literal(url)
                                .withStyle(Style.EMPTY.withColor(0x55FF55)));
                        context.getSource().sendSuccess(() -> message, false);
                    } else {
                        context.getSource().sendFailure(Component.literal("[Dart] VM not initialized"));
                    }
                    return 1;
                }));
        });

        // Send welcome message when player joins
        ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> {
            if (DartBridge.isInitialized()) {
                String url = DartBridge.getServiceUrl();
                ServerPlayer player = handler.getPlayer();

                // Send Dart support message
                Component dartMessage = Component.literal("[Dart] ")
                    .withStyle(Style.EMPTY.withColor(0x00AAFF))
                    .append(Component.literal("Running with Dart support!")
                        .withStyle(Style.EMPTY.withColor(0xFFFFFF)));

                player.sendSystemMessage(dartMessage);

                if (url != null) {
                    Component urlMessage = Component.literal("[Dart] ")
                        .withStyle(Style.EMPTY.withColor(0x00AAFF))
                        .append(Component.literal("Service URL: ")
                            .withStyle(Style.EMPTY.withColor(0xFFFFFF)))
                        .append(Component.literal(url)
                            .withStyle(Style.EMPTY.withColor(0x55FF55)));

                    player.sendSystemMessage(urlMessage);
                }
            }
        });

        // Register tick event - process Dart async tasks and dispatch tick
        ServerTickEvents.END_SERVER_TICK.register(server -> {
            if (DartBridge.isInitialized()) {
                DartBridge.dispatchTick(tickCounter++);
                DartBridge.safeTick();
            }
        });

        // Register block break event
        PlayerBlockBreakEvents.BEFORE.register((world, player, pos, state, blockEntity) -> {
            if (!DartBridge.isInitialized()) return true;

            // Check if this is a Dart proxy block
            if (state.getBlock() instanceof com.example.dartbridge.proxy.DartBlockProxy proxyBlock) {
                // Call the proxy-specific handler which returns whether to allow the break
                boolean allowBreak = DartBridge.onProxyBlockBreak(
                    proxyBlock.getDartHandlerId(),
                    world.hashCode(),
                    pos.getX(),
                    pos.getY(),
                    pos.getZ(),
                    player.getId()
                );
                return allowBreak;
            }

            // For non-proxy blocks, use the generic dispatch
            int result = DartBridge.dispatchBlockBreak(
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                player.getId()
            );

            // Return true to allow break, false to cancel
            return result != 0;
        });

        // Register block interact event
        UseBlockCallback.EVENT.register((player, world, hand, hitResult) -> {
            if (!DartBridge.isInitialized()) return InteractionResult.PASS;

            var pos = hitResult.getBlockPos();
            int handValue = (hand == InteractionHand.MAIN_HAND) ? 0 : 1;

            int result = DartBridge.dispatchBlockInteract(
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                player.getId(),
                handValue
            );

            if (result == 0) {
                return InteractionResult.FAIL;
            } else {
                return InteractionResult.PASS;
            }
        });

        LOGGER.info("[{}] Dart Bridge mod initialized!", MOD_ID);
    }
}
