package com.redstone;

import com.redstone.flutter.TestFlutterScreen;
import com.redstone.proxy.EntityProxyRegistry;
import com.redstone.render.DartEntityRenderer;
import com.redstone.render.EntityModelRegistry;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandManager;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayConnectionEvents;
import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;
import net.fabricmc.fabric.api.client.screen.v1.ScreenEvents;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.screens.TitleScreen;
import net.minecraft.client.renderer.entity.NoopRenderer;
import net.minecraft.resources.Identifier;
import net.minecraft.world.Difficulty;
import net.minecraft.world.flag.FeatureFlags;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.LevelSettings;
import net.minecraft.world.level.WorldDataConfiguration;
import net.minecraft.world.level.gamerules.GameRules;
import net.minecraft.world.level.levelgen.WorldOptions;
import net.minecraft.world.level.levelgen.presets.WorldPresets;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Client-side mod initializer that registers entity renderers.
 *
 * This class is responsible for:
 * - Registering entity renderers for all Dart-defined custom entities
 *
 * Without proper renderer registration, entities will cause NullPointerException
 * when the client tries to render them.
 *
 * Currently uses NoopRenderer (invisible) for all custom entities.
 * TODO: Implement proper renderers with cow/zombie models for visible entities.
 */
@Environment(EnvType.CLIENT)
public class DartModClientLoader implements ClientModInitializer {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartModClientLoader");

    @Override
    public void onInitializeClient() {
        LOGGER.info("[DartModClientLoader] Setting up entity renderer callback...");

        // Register a callback to be notified when entities are registered.
        // This handles the case where Dart registers entities AFTER client init.
        EntityProxyRegistry.setRegistrationCallback((entityType, handlerId) -> {
            int baseType = EntityProxyRegistry.getBaseType(handlerId);
            String baseTypeName = switch (baseType) {
                case EntityProxyRegistry.BASE_TYPE_ANIMAL -> "animal";
                case EntityProxyRegistry.BASE_TYPE_MONSTER -> "monster";
                case EntityProxyRegistry.BASE_TYPE_PROJECTILE -> "projectile";
                default -> "mob";
            };

            // Check if there's a model configuration for this entity
            EntityProxyRegistry.EntityModelConfig modelConfig = EntityProxyRegistry.getModelConfig(handlerId);
            if (modelConfig != null) {
                // Register model config to client-side registry for renderer access
                EntityModelRegistry.registerConfig(
                    handlerId,
                    modelConfig.modelType(),
                    modelConfig.texturePath(),
                    modelConfig.scale()
                );

                LOGGER.info("[DartModClientLoader] Registering DartEntityRenderer for {} entity (handler: {}, model: {}, texture: {})",
                    baseTypeName, handlerId, modelConfig.modelType(), modelConfig.texturePath());

                // Use DartEntityRenderer with the configured model and texture
                @SuppressWarnings("unchecked")
                var mobEntityType = (net.minecraft.world.entity.EntityType<net.minecraft.world.entity.Mob>) entityType;
                // Get the entity's namespace to use as default for texture paths
                String entityNamespace = net.minecraft.core.registries.BuiltInRegistries.ENTITY_TYPE.getKey(entityType).getNamespace();
                EntityRendererRegistry.register(mobEntityType, context -> {
                    Identifier texture = Identifier.tryParse(modelConfig.texturePath());
                    if (texture == null) {
                        // Use entity's namespace instead of minecraft: when texture path has no namespace
                        texture = Identifier.fromNamespaceAndPath(entityNamespace, modelConfig.texturePath());
                    }
                    return new DartEntityRenderer<>(context, modelConfig.modelType(), texture, modelConfig.scale());
                });
            } else {
                LOGGER.info("[DartModClientLoader] Registering NoopRenderer for {} entity (handler: {}) - no model config",
                    baseTypeName, handlerId);
                // No model config - use NoopRenderer (invisible entity)
                EntityRendererRegistry.register(entityType, NoopRenderer::new);
            }
        });

        LOGGER.info("[DartModClientLoader] Entity renderer callback registered!");

        // Process any entities that were already registered BEFORE the callback was set up.
        // This handles the timing issue where Dart registers entities during DartModLoader.onInitialize()
        // which runs BEFORE DartModClientLoader.onInitializeClient().
        processAlreadyRegisteredEntities();

        // Register client tick event for test synchronization
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            DartBridgeClient.onClientTick();
        });

        // Register client ready event (when player joins world)
        ClientPlayConnectionEvents.JOIN.register((handler, sender, client) -> {
            // Delay the ready callback to ensure world is fully loaded
            client.execute(() -> {
                DartBridgeClient.onClientReady();
            });
        });

        LOGGER.info("[DartModClientLoader] Client tick and ready events registered!");

        // Register screen event for visual test mode auto-join
        ScreenEvents.AFTER_INIT.register((client, screen, scaledWidth, scaledHeight) -> {
            if (screen instanceof TitleScreen
                && DartBridgeClient.isVisualTestMode()
                && !DartBridgeClient.hasAttemptedJoinTestWorld()) {

                DartBridgeClient.markJoinTestWorldAttempted();
                LOGGER.info("[DartModClientLoader] Visual test mode detected - auto-joining test world...");
                client.execute(() -> autoJoinTestWorld(client));
            }
        });

        LOGGER.info("[DartModClientLoader] Visual test mode screen events registered!");

        // Register /fluttertest command to open Flutter test screen
        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> {
            dispatcher.register(ClientCommandManager.literal("fluttertest")
                .executes(context -> {
                    Minecraft client = Minecraft.getInstance();
                    client.execute(() -> {
                        // Paths to Flutter assets - hardcoded for testing
                        // user.dir is minecraft/run, need to go up to redstone_dart root
                        String projectRoot = System.getProperty("user.dir");
                        // From minecraft/run -> example_mod -> example -> redstone_dart -> packages
                        // That's: ../../../../packages/
                        String assetsPath = projectRoot + "/../../../../packages/flutter_embedder_poc/flutter_app/build/flutter_assets";
                        String icuPath = projectRoot + "/../../../../packages/flutter_embedder_poc/deps/FlutterEmbedder.framework/Resources/icudtl.dat";

                        // Resolve to canonical path to clean up the ../.. sequences
                        try {
                            assetsPath = new java.io.File(assetsPath).getCanonicalPath();
                            icuPath = new java.io.File(icuPath).getCanonicalPath();
                        } catch (java.io.IOException e) {
                            LOGGER.error("[DartModClientLoader] Failed to resolve paths", e);
                        }

                        LOGGER.info("[DartModClientLoader] Opening Flutter test screen");
                        LOGGER.info("[DartModClientLoader] Project root (user.dir): {}", projectRoot);
                        LOGGER.info("[DartModClientLoader] Assets path: {}", assetsPath);
                        LOGGER.info("[DartModClientLoader] ICU path: {}", icuPath);

                        // Build renderer path
                        String rendererPath = projectRoot + "/../../../../packages/flutter_renderer/build/flutter_renderer";
                        try {
                            rendererPath = new java.io.File(rendererPath).getCanonicalPath();
                        } catch (java.io.IOException e) {
                            LOGGER.error("[DartModClientLoader] Failed to resolve renderer path", e);
                        }
                        LOGGER.info("[DartModClientLoader] Renderer path: {}", rendererPath);

                        // Verify paths exist
                        java.io.File assetsFile = new java.io.File(assetsPath);
                        java.io.File icuFile = new java.io.File(icuPath);
                        java.io.File rendererFile = new java.io.File(rendererPath);
                        LOGGER.info("[DartModClientLoader] Assets exist: {}", assetsFile.exists());
                        LOGGER.info("[DartModClientLoader] ICU exists: {}", icuFile.exists());
                        LOGGER.info("[DartModClientLoader] Renderer exists: {}", rendererFile.exists());

                        // Set the Flutter renderer path before opening the screen
                        DartBridgeClient.setFlutterRendererPath(rendererPath);

                        client.setScreen(new TestFlutterScreen(assetsPath, icuPath));
                    });
                    return 1;
                })
            );
        });

        LOGGER.info("[DartModClientLoader] /fluttertest command registered!");
    }

    private static final String TEST_WORLD_NAME = "dart_visual_test";

    /**
     * Process entities that were already registered before the callback was set up.
     * This handles the timing issue where Dart registers entities during DartModLoader.onInitialize()
     * which runs BEFORE DartModClientLoader.onInitializeClient().
     */
    private void processAlreadyRegisteredEntities() {
        long[] handlerIds = EntityProxyRegistry.getAllHandlerIds();
        LOGGER.info("[DartModClientLoader] Processing {} already-registered entities", handlerIds.length);

        for (long handlerId : handlerIds) {
            var entityType = EntityProxyRegistry.getEntityType(handlerId);
            if (entityType == null) {
                LOGGER.warn("[DartModClientLoader] No EntityType found for handler {}", handlerId);
                continue;
            }

            int baseType = EntityProxyRegistry.getBaseType(handlerId);
            String baseTypeName = switch (baseType) {
                case EntityProxyRegistry.BASE_TYPE_ANIMAL -> "animal";
                case EntityProxyRegistry.BASE_TYPE_MONSTER -> "monster";
                case EntityProxyRegistry.BASE_TYPE_PROJECTILE -> "projectile";
                default -> "mob";
            };

            // Check if there's a model configuration for this entity
            EntityProxyRegistry.EntityModelConfig modelConfig = EntityProxyRegistry.getModelConfig(handlerId);
            if (modelConfig != null) {
                // Register model config to client-side registry for renderer access
                EntityModelRegistry.registerConfig(
                    handlerId,
                    modelConfig.modelType(),
                    modelConfig.texturePath(),
                    modelConfig.scale()
                );

                LOGGER.info("[DartModClientLoader] Registering DartEntityRenderer for already-registered {} entity (handler: {}, model: {}, texture: {})",
                    baseTypeName, handlerId, modelConfig.modelType(), modelConfig.texturePath());

                // Use DartEntityRenderer with the configured model and texture
                @SuppressWarnings("unchecked")
                var mobEntityType = (net.minecraft.world.entity.EntityType<net.minecraft.world.entity.Mob>) entityType;
                // Get the entity's namespace to use as default for texture paths
                String entityNamespace = net.minecraft.core.registries.BuiltInRegistries.ENTITY_TYPE.getKey(entityType).getNamespace();
                EntityRendererRegistry.register(mobEntityType, context -> {
                    Identifier texture = Identifier.tryParse(modelConfig.texturePath());
                    if (texture == null) {
                        // Use entity's namespace instead of minecraft: when texture path has no namespace
                        texture = Identifier.fromNamespaceAndPath(entityNamespace, modelConfig.texturePath());
                    }
                    return new DartEntityRenderer<>(context, modelConfig.modelType(), texture, modelConfig.scale());
                });
            } else {
                LOGGER.info("[DartModClientLoader] Registering NoopRenderer for already-registered {} entity (handler: {}) - no model config",
                    baseTypeName, handlerId);
                // No model config - use NoopRenderer (invisible entity)
                EntityRendererRegistry.register(entityType, NoopRenderer::new);
            }
        }
    }

    /**
     * Automatically join or create a test world for visual testing.
     */
    private void autoJoinTestWorld(Minecraft client) {
        if (client.getLevelSource().levelExists(TEST_WORLD_NAME)) {
            LOGGER.info("[DartModClientLoader] Loading existing test world: {}", TEST_WORLD_NAME);
            client.createWorldOpenFlows().openWorld(TEST_WORLD_NAME,
                () -> client.setScreen(new TitleScreen()));
        } else {
            LOGGER.info("[DartModClientLoader] Creating new flat test world: {}", TEST_WORLD_NAME);
            createFlatTestWorld(client, TEST_WORLD_NAME);
        }
    }

    /**
     * Create a flat creative world for visual testing.
     */
    private void createFlatTestWorld(Minecraft client, String worldName) {
        // Create level settings for creative mode flat world
        LevelSettings levelSettings = new LevelSettings(
            worldName,
            GameType.CREATIVE,
            false,  // not hardcore
            Difficulty.PEACEFUL,
            true,   // allow commands
            new GameRules(FeatureFlags.DEFAULT_FLAGS),
            WorldDataConfiguration.DEFAULT
        );

        // Create world with flat preset
        WorldOptions worldOptions = new WorldOptions(
            12345L,  // fixed seed for consistency
            false,   // no structures
            false    // no bonus chest
        );

        client.createWorldOpenFlows().createFreshLevel(
            worldName,
            levelSettings,
            worldOptions,
            WorldPresets::createFlatWorldDimensions,
            new TitleScreen()
        );
    }
}
