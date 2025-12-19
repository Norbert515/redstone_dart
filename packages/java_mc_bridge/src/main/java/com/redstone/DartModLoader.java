package com.redstone;

import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.event.player.AttackEntityCallback;
import net.fabricmc.fabric.api.event.player.PlayerBlockBreakEvents;
import net.fabricmc.fabric.api.event.player.UseBlockCallback;
import net.fabricmc.fabric.api.event.player.UseEntityCallback;
import net.fabricmc.fabric.api.event.player.UseItemCallback;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.minecraft.commands.Commands;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.Style;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.item.ItemStack;
import com.redstone.proxy.DartBlockProxy;
import com.redstone.proxy.RecipeRegistry;
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
     *
     * Checks in order:
     * 1. DART_SCRIPT_PATH system property (set by Gradle JVM args)
     * 2. DART_SCRIPT_PATH environment variable (set by CLI)
     * 3. Standard search paths relative to run directory
     */
    private static String getScriptPath() {
        // First check for system property (used by redstone CLI via Gradle)
        String propPath = System.getProperty("DART_SCRIPT_PATH");
        if (propPath != null && !propPath.isEmpty()) {
            File f = new File(propPath);
            if (f.exists()) {
                LOGGER.info("[{}] Using script path from system property DART_SCRIPT_PATH: {}", MOD_ID, propPath);
                return f.getAbsolutePath();
            } else {
                LOGGER.warn("[{}] DART_SCRIPT_PATH property set but file not found: {}", MOD_ID, propPath);
            }
        }

        // Then check for environment variable (used by redstone CLI)
        String envPath = System.getenv("DART_SCRIPT_PATH");
        if (envPath != null && !envPath.isEmpty()) {
            File f = new File(envPath);
            if (f.exists()) {
                LOGGER.info("[{}] Using script path from DART_SCRIPT_PATH env var: {}", MOD_ID, envPath);
                return f.getAbsolutePath();
            } else {
                LOGGER.warn("[{}] DART_SCRIPT_PATH env var set but file not found: {}", MOD_ID, envPath);
            }
        }

        // Look for dart_mc in several locations
        // Prefer the package structure (dart_mc/lib/dart_mc.dart) over single file
        String[] searchPaths = {
            "mods/dart_mc/lib/dart_mc.dart",  // Package structure
            "mods/dart_mc.dart",               // Single file
            "dart_mc/lib/dart_mc.dart",
            "dart_mc.dart",
            "config/dart_mc.dart"
        };

        String runDir = System.getProperty("user.dir");
        for (String path : searchPaths) {
            File f = new File(runDir, path);
            if (f.exists()) {
                return f.getAbsolutePath();
            }
        }

        // Default path
        return Path.of(runDir, "mods", "dart_mc", "lib", "dart_mc.dart").toAbsolutePath().toString();
    }

    @Override
    public void onInitialize() {
        System.out.println("===== DART BRIDGE INIT START =====");
        LOGGER.info("[{}] Initializing Dart Bridge mod...", MOD_ID);

        // Initialize Redstone menu types
        RedstoneMenuTypes.initialize();

        boolean libLoaded = DartBridge.isLibraryLoaded();
        System.out.println("===== Native library loaded: " + libLoaded + " =====");
        LOGGER.info("[{}] Native library loaded: {}", MOD_ID, libLoaded);

        if (!libLoaded) {
            LOGGER.error("[{}] Native library not loaded, Dart Bridge will be disabled", MOD_ID);
            return;
        }

        // Initialize Dart VM NOW during mod initialization (before registry freeze)
        // This is critical - block registration must happen during onInitialize()
        String scriptPath = getScriptPath();
        System.out.println("===== Script path: " + scriptPath + " =====");
        LOGGER.info("[{}] Script path: {}", MOD_ID, scriptPath);

        File scriptFile = new File(scriptPath);
        boolean scriptExists = scriptFile.exists();
        System.out.println("===== Script exists: " + scriptExists + " =====");
        LOGGER.info("[{}] Script exists: {}", MOD_ID, scriptExists);

        if (!scriptExists) {
            LOGGER.error("[{}] Dart script not found at: {}", MOD_ID, scriptPath);
            LOGGER.error("[{}] Please place your dart_mc.dart file in the mods folder", MOD_ID);
        } else {
            // Initialize Dart VM synchronously during mod init
            // This allows Dart to register blocks before the registry freezes
            System.out.println("===== Calling DartBridge.safeInit =====");
            boolean initResult = DartBridge.safeInit(scriptPath);
            System.out.println("===== Init result: " + initResult + " =====");
            LOGGER.info("[{}] Init result: {}", MOD_ID, initResult);
            if (!initResult) {
                LOGGER.error("[{}] Failed to initialize Dart VM!", MOD_ID);
            } else {
                LOGGER.info("[{}] Dart VM initialized successfully!", MOD_ID);
            }
        }
        System.out.println("===== DART BRIDGE INIT END =====");

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

        // Player join event - send welcome message and dispatch to Dart
        ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> {
            ServerPlayer player = handler.getPlayer();

            // Dispatch to Dart
            if (DartBridge.isInitialized()) {
                DartBridge.dispatchPlayerJoin(player.getId());

                // Send welcome message
                String url = DartBridge.getServiceUrl();

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

        // Player leave event
        ServerPlayConnectionEvents.DISCONNECT.register((handler, server) -> {
            if (DartBridge.isInitialized()) {
                DartBridge.dispatchPlayerLeave(handler.getPlayer().getId());
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
            if (state.getBlock() instanceof com.redstone.proxy.DartBlockProxy proxyBlock) {
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

            // Skip if this is a Dart proxy block - it has its own handler via DartBlockProxy.useWithoutItem()
            // The proxy block returns ActionResult ordinals (0=success), not EventResult (0=cancel)
            var blockState = world.getBlockState(pos);
            if (blockState.getBlock() instanceof DartBlockProxy) {
                return InteractionResult.PASS;
            }

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

        // Register player attack entity event
        AttackEntityCallback.EVENT.register((player, world, hand, entity, hitResult) -> {
            if (!DartBridge.isInitialized()) return InteractionResult.PASS;

            boolean allow = DartBridge.dispatchPlayerAttackEntity(player.getId(), entity.getId());
            return allow ? InteractionResult.PASS : InteractionResult.FAIL;
        });

        // Register item use event (right-click with item in air)
        UseItemCallback.EVENT.register((player, world, hand) -> {
            if (!DartBridge.isInitialized()) return InteractionResult.PASS;

            ItemStack stack = player.getItemInHand(hand);
            if (stack.isEmpty()) return InteractionResult.PASS;

            String itemId = BuiltInRegistries.ITEM.getKey(stack.getItem()).toString();
            int handValue = (hand == InteractionHand.MAIN_HAND) ? 0 : 1;

            boolean allow = DartBridge.dispatchItemUse(player.getId(), itemId, stack.getCount(), handValue);
            if (allow) {
                return InteractionResult.PASS;
            } else {
                return InteractionResult.FAIL;
            }
        });

        // Register item use on entity event
        UseEntityCallback.EVENT.register((player, world, hand, entity, hitResult) -> {
            if (!DartBridge.isInitialized()) return InteractionResult.PASS;

            ItemStack stack = player.getItemInHand(hand);
            String itemId = stack.isEmpty() ? "minecraft:air" : BuiltInRegistries.ITEM.getKey(stack.getItem()).toString();
            int handValue = (hand == InteractionHand.MAIN_HAND) ? 0 : 1;

            int result = DartBridge.dispatchItemUseOnEntity(player.getId(), itemId, stack.getCount(), handValue, entity.getId());
            return result == 0 ? InteractionResult.FAIL : InteractionResult.PASS;
        });

        // Register server lifecycle events
        ServerLifecycleEvents.SERVER_STARTING.register(server -> {
            if (DartBridge.isInitialized()) {
                DartBridge.dispatchServerStarting();
            }
        });

        ServerLifecycleEvents.SERVER_STARTED.register(server -> {
            if (DartBridge.isInitialized()) {
                DartBridge.dispatchServerStarted();
            }

            // Inject Dart recipes after server has fully started
            // This ensures recipes are available for crafting
            LOGGER.info("[{}] Injecting Dart recipes on server start...", MOD_ID);
            RecipeRegistry.injectRecipes(server);
        });

        // Also inject recipes after data pack reload (e.g., /reload command)
        ServerLifecycleEvents.END_DATA_PACK_RELOAD.register((server, resourceManager, success) -> {
            if (success) {
                LOGGER.info("[{}] Data pack reload complete, re-injecting Dart recipes...", MOD_ID);
                // Reset the field search so we find the new RecipeManager's field
                RecipeRegistry.resetFieldSearch();
                RecipeRegistry.injectRecipes(server);
            } else {
                LOGGER.warn("[{}] Data pack reload failed, skipping recipe injection", MOD_ID);
            }
        });

        ServerLifecycleEvents.SERVER_STOPPING.register(server -> {
            if (DartBridge.isInitialized()) {
                DartBridge.dispatchServerStopping();
            }
        });

        LOGGER.info("[{}] Dart Bridge mod initialized!", MOD_ID);
    }
}
