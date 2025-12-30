package com.redstone;

import net.fabricmc.api.EnvType;
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
import net.fabricmc.loader.api.FabricLoader;
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
import net.minecraft.world.level.storage.LevelResource;

/**
 * Fabric mod initializer that loads and manages the server-side Dart runtime.
 *
 * This class is responsible for:
 * - Initializing the server Dart runtime during mod initialization
 * - Processing registration queues (blocks, items, entities)
 * - Forwarding Minecraft events to Dart handlers
 * - Ticking the server runtime each game tick
 * - Shutting down the server runtime when the server stops
 *
 * Note: The client runtime (Flutter) is initialized separately in DartModClientLoader.
 * On dedicated servers, only this server runtime exists.
 */
public class DartModLoader implements ModInitializer {
    public static final String MOD_ID = "dart_bridge";
    private static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);
    private static long tickCounter = 0;
    private static MinecraftServer serverInstance = null;

    /**
     * Process all queued registrations from the native queue.
     * This is called after Dart has finished queueing registrations and must run
     * on the main/render thread where Minecraft registry operations are safe.
     */
    private static void processQueuedRegistrations() {
        int blocksRegistered = 0;
        int itemsRegistered = 0;
        int entitiesRegistered = 0;

        LOGGER.info("[{}] Processing queued registrations...", MOD_ID);

        // Process all queued block registrations
        while (DartBridge.hasPendingBlockRegistrations()) {
            Object[] blockReg = DartBridge.getNextBlockRegistration();
            if (blockReg == null) break;

            // Extract registration data from the array
            // Format: [handlerId, namespace, path, hardness, resistance, requiresTool,
            //          luminance, slipperiness, velocityMult, jumpVelocityMult,
            //          ticksRandomly, collidable, replaceable, burnable]
            long handlerId = (Long) blockReg[0];
            String namespace = (String) blockReg[1];
            String path = (String) blockReg[2];
            float hardness = (Float) blockReg[3];
            float resistance = (Float) blockReg[4];
            boolean requiresTool = (Boolean) blockReg[5];
            int luminance = (Integer) blockReg[6];
            double slipperiness = (Double) blockReg[7];
            double velocityMult = (Double) blockReg[8];
            double jumpVelocityMult = (Double) blockReg[9];
            boolean ticksRandomly = (Boolean) blockReg[10];
            boolean collidable = (Boolean) blockReg[11];
            boolean replaceable = (Boolean) blockReg[12];
            boolean burnable = (Boolean) blockReg[13];

            boolean success = com.redstone.proxy.ProxyRegistry.registerBlockWithHandlerId(
                handlerId, namespace, path, hardness, resistance, requiresTool,
                luminance, slipperiness, velocityMult, jumpVelocityMult,
                ticksRandomly, collidable, replaceable, burnable
            );

            if (success) {
                blocksRegistered++;
            } else {
                LOGGER.error("[{}] Failed to register queued block: {}:{}", MOD_ID, namespace, path);
            }
        }

        // Process all queued item registrations
        while (DartBridge.hasPendingItemRegistrations()) {
            Object[] itemReg = DartBridge.getNextItemRegistration();
            if (itemReg == null) break;

            // Extract registration data from the array
            // Format: [handlerId, namespace, path, maxStackSize, maxDamage, fireResistant,
            //          attackDamage, attackSpeed, attackKnockback]
            long handlerId = (Long) itemReg[0];
            String namespace = (String) itemReg[1];
            String path = (String) itemReg[2];
            int maxStackSize = (Integer) itemReg[3];
            int maxDamage = (Integer) itemReg[4];
            boolean fireResistant = (Boolean) itemReg[5];
            double attackDamage = (Double) itemReg[6];
            double attackSpeed = (Double) itemReg[7];
            double attackKnockback = (Double) itemReg[8];

            boolean success = com.redstone.proxy.ProxyRegistry.registerItemWithHandlerId(
                handlerId, namespace, path, maxStackSize, maxDamage, fireResistant,
                attackDamage, attackSpeed, attackKnockback
            );

            if (success) {
                itemsRegistered++;
            } else {
                LOGGER.error("[{}] Failed to register queued item: {}:{}", MOD_ID, namespace, path);
            }
        }

        // Process all queued entity registrations
        while (DartBridge.hasPendingEntityRegistrations()) {
            Object[] entityReg = DartBridge.getNextEntityRegistration();
            if (entityReg == null) break;

            // Extract registration data from the array
            // Format: [handlerId, namespace, path, width, height, maxHealth,
            //          movementSpeed, attackDamage, spawnGroup, baseType,
            //          breedingItem, modelType, texturePath, modelScale, goalsJson, targetGoalsJson]
            long handlerId = (Long) entityReg[0];
            String namespace = (String) entityReg[1];
            String path = (String) entityReg[2];
            double width = (Double) entityReg[3];
            double height = (Double) entityReg[4];
            double maxHealth = (Double) entityReg[5];
            double movementSpeed = (Double) entityReg[6];
            double attackDamage = (Double) entityReg[7];
            int spawnGroup = (Integer) entityReg[8];
            int baseType = (Integer) entityReg[9];
            String breedingItem = (String) entityReg[10];
            String modelType = (String) entityReg[11];
            String texturePath = (String) entityReg[12];
            double modelScale = (Double) entityReg[13];
            String goalsJson = (String) entityReg[14];
            String targetGoalsJson = (String) entityReg[15];

            boolean success = com.redstone.proxy.EntityProxyRegistry.registerEntityWithHandlerId(
                handlerId, namespace, path, width, height, maxHealth,
                movementSpeed, attackDamage, spawnGroup, baseType,
                breedingItem, modelType, texturePath, modelScale,
                goalsJson, targetGoalsJson
            );

            if (success) {
                entitiesRegistered++;
            } else {
                LOGGER.error("[{}] Failed to register queued entity: {}:{}", MOD_ID, namespace, path);
            }
        }

        LOGGER.info("[{}] Queued registrations complete: {} blocks, {} items, {} entities", MOD_ID, blocksRegistered, itemsRegistered, entitiesRegistered);
    }

    /**
     * Get the path to the server Dart kernel snapshot or script.
     *
     * Checks in order:
     * 1. DART_SERVER_SCRIPT system property (set by Gradle JVM args)
     * 2. DART_SERVER_SCRIPT environment variable (set by CLI)
     * 3. Standard search paths relative to run directory
     *
     * @return Path to the server Dart kernel blob or script
     */
    private static String getServerScriptPath() {
        // First check for system property (used by redstone CLI via Gradle)
        String propPath = System.getProperty("DART_SERVER_SCRIPT");
        if (propPath != null && !propPath.isEmpty()) {
            File f = new File(propPath);
            if (f.exists()) {
                LOGGER.info("[{}] Using server script from system property DART_SERVER_SCRIPT: {}", MOD_ID, propPath);
                return f.getAbsolutePath();
            } else {
                LOGGER.warn("[{}] DART_SERVER_SCRIPT property set but file not found: {}", MOD_ID, propPath);
            }
        }

        // Then check for environment variable (used by redstone CLI)
        String envPath = System.getenv("DART_SERVER_SCRIPT");
        if (envPath != null && !envPath.isEmpty()) {
            File f = new File(envPath);
            if (f.exists()) {
                LOGGER.info("[{}] Using server script from DART_SERVER_SCRIPT env var: {}", MOD_ID, envPath);
                return f.getAbsolutePath();
            } else {
                LOGGER.warn("[{}] DART_SERVER_SCRIPT env var set but file not found: {}", MOD_ID, envPath);
            }
        }

        // Look for server script in several locations
        // dart_dll compiles source files at runtime, so prefer .dart files
        String[] searchPaths = {
            "mods/dart_mc/lib/server/main.dart", // Server entry point (preferred)
            "mods/dart_mc/lib/main.dart",        // Legacy single-file script
            "lib/server/main.dart",              // Current directory
            "lib/main.dart",                     // Current directory
        };

        String runDir = System.getProperty("user.dir");
        for (String path : searchPaths) {
            File f = new File(runDir, path);
            if (f.exists()) {
                LOGGER.info("[{}] Found server script at: {}", MOD_ID, f.getAbsolutePath());
                return f.getAbsolutePath();
            }
        }

        // Default path - source file that dart_dll will compile at runtime
        return Path.of(runDir, "mods", "dart_mc", "lib", "server", "main.dart").toAbsolutePath().toString();
    }

    /**
     * Get the path to the package config file for Dart.
     *
     * @return Path to package_config.json, or empty string if not found
     */
    private static String getPackageConfigPath() {
        // First check for system property
        String propPath = System.getProperty("DART_PACKAGE_CONFIG");
        if (propPath != null && !propPath.isEmpty()) {
            File f = new File(propPath);
            if (f.exists()) {
                LOGGER.info("[{}] Using package config from system property DART_PACKAGE_CONFIG: {}", MOD_ID, propPath);
                return f.getAbsolutePath();
            }
        }

        // Then check for environment variable
        String envPath = System.getenv("DART_PACKAGE_CONFIG");
        if (envPath != null && !envPath.isEmpty()) {
            File f = new File(envPath);
            if (f.exists()) {
                LOGGER.info("[{}] Using package config from DART_PACKAGE_CONFIG env var: {}", MOD_ID, envPath);
                return f.getAbsolutePath();
            }
        }

        // Look for package config in several locations
        String[] searchPaths = {
            "mods/dart_mc/.dart_tool/package_config.json",
            ".dart_tool/package_config.json"
        };

        String runDir = System.getProperty("user.dir");
        for (String path : searchPaths) {
            File f = new File(runDir, path);
            if (f.exists()) {
                LOGGER.info("[{}] Found package config at: {}", MOD_ID, f.getAbsolutePath());
                return f.getAbsolutePath();
            }
        }

        // Not found - return empty string (kernel snapshots don't need this)
        return "";
    }

    @Override
    public void onInitialize() {
        System.out.println("===== DART BRIDGE INIT START =====");
        LOGGER.info("[{}] Initializing Dart Bridge mod (server runtime)...", MOD_ID);

        // Initialize Redstone menu types
        RedstoneMenuTypes.initialize();

        boolean libLoaded = DartBridge.isLibraryLoaded();
        System.out.println("===== Native library loaded: " + libLoaded + " =====");
        LOGGER.info("[{}] Native library loaded: {}", MOD_ID, libLoaded);

        if (!libLoaded) {
            LOGGER.error("[{}] Native library not loaded, Dart Bridge will be disabled", MOD_ID);
            return;
        }

        // Get server script path (Dart kernel snapshot or script)
        String serverScriptPath = getServerScriptPath();
        String packageConfigPath = getPackageConfigPath();

        System.out.println("===== Server script path: " + serverScriptPath + " =====");
        System.out.println("===== Package config path: " + (packageConfigPath.isEmpty() ? "(none)" : packageConfigPath) + " =====");
        LOGGER.info("[{}] Server script path: {}", MOD_ID, serverScriptPath);
        LOGGER.info("[{}] Package config path: {}", MOD_ID, packageConfigPath.isEmpty() ? "(none)" : packageConfigPath);

        File scriptFile = new File(serverScriptPath);
        boolean scriptExists = scriptFile.exists();

        System.out.println("===== Server script exists: " + scriptExists + " =====");
        LOGGER.info("[{}] Server script exists: {}", MOD_ID, scriptExists);

        if (!scriptExists) {
            LOGGER.error("[{}] Server script not found at: {}", MOD_ID, serverScriptPath);
            LOGGER.error("[{}] Server script not found. Make sure to run with --dual-runtime flag or ensure server_kernel.dill exists at: {}", MOD_ID, serverScriptPath);
            System.exit(1);
        } else {
            // Initialize the server Dart runtime
            boolean isClient = FabricLoader.getInstance().getEnvironmentType() == EnvType.CLIENT;
            System.out.println("===== Environment: " + (isClient ? "CLIENT" : "SERVER") + " =====");
            LOGGER.info("[{}] Environment: {}", MOD_ID, isClient ? "CLIENT" : "SERVER");

            System.out.println("===== Calling DartBridge.safeInitServerRuntime =====");
            boolean initResult = DartBridge.safeInitServerRuntime(serverScriptPath, packageConfigPath);
            System.out.println("===== Init result: " + initResult + " =====");
            LOGGER.info("[{}] Init result: {}", MOD_ID, initResult);

            if (!initResult) {
                LOGGER.error("[{}] Failed to initialize server Dart runtime!", MOD_ID);
                LOGGER.error("[{}] Exiting due to server runtime initialization failure.", MOD_ID);
                System.exit(1);
            } else {
                LOGGER.info("[{}] Server Dart runtime initialized successfully!", MOD_ID);

                // Signal to Dart that it's safe to register items/blocks now
                // This is critical - Dart's main() runs when the runtime starts,
                // but we need to wait until this point to register items/blocks
                // while registries are still open
                LOGGER.info("[{}] Signaling registry ready to Dart...", MOD_ID);
                DartBridge.signalRegistryReady();

                // Wait for Dart to finish queueing registrations
                LOGGER.info("[{}] Waiting for Dart to finish queueing registrations...", MOD_ID);
                int waitMs = 0;
                int maxWaitMs = 5000;  // 5 second timeout
                while (!DartBridge.areRegistrationsQueued() && waitMs < maxWaitMs) {
                    try {
                        Thread.sleep(50);
                        waitMs += 50;
                    } catch (InterruptedException e) {
                        break;
                    }
                }

                if (!DartBridge.areRegistrationsQueued()) {
                    LOGGER.warn("[{}] Dart did not signal registrations complete within timeout ({}ms)", MOD_ID, maxWaitMs);
                } else {
                    LOGGER.info("[{}] Dart finished queueing registrations after {}ms", MOD_ID, waitMs);
                }

                // Process all queued registrations ON THIS THREAD (main thread - safe!)
                processQueuedRegistrations();
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

        // Shutdown server Dart runtime when server stops
        ServerLifecycleEvents.SERVER_STOPPED.register(server -> {
            LOGGER.info("[{}] Server stopped, shutting down server Dart runtime...", MOD_ID);
            DartBridge.safeShutdownServerRuntime();
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

        // Register tick event - process server Dart async tasks and dispatch tick
        ServerTickEvents.END_SERVER_TICK.register(server -> {
            if (DartBridge.isInitialized()) {
                // First tick the server runtime to process pending async tasks
                DartBridge.safeTickServer();
                // Then dispatch the tick event to Dart handlers
                DartBridge.dispatchTick(tickCounter++);
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

            // Log the world folder name for CLI detection (used for Quick Play on restart)
            // getWorldPath(ROOT) returns path like "saves/World Name/." so we normalize and get parent's name
            Path worldPath = server.getWorldPath(LevelResource.ROOT).normalize();
            String worldName = worldPath.getFileName().toString();
            LOGGER.info("[redstone] Loaded world: {}", worldName);

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
