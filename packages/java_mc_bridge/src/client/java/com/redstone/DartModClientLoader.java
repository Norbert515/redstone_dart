package com.redstone;

import com.redstone.flutter.FlutterScreen;
import net.minecraft.network.chat.Component;
import com.redstone.proxy.EntityProxyRegistry;
import com.redstone.render.DartEntityRenderer;
import com.redstone.render.EntityModelRegistry;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandManager;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientLifecycleEvents;
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

import java.io.File;
import java.nio.file.Path;

/**
 * Client-side mod initializer that manages the Flutter client runtime.
 *
 * This class is responsible for:
 * - Initializing the Flutter client runtime (with rendering enabled)
 * - Processing Flutter client tasks each tick
 * - Registering entity renderers for all Dart-defined custom entities
 * - Managing visual test mode for automated testing
 *
 * The client runtime is initialized AFTER the server runtime (DartModLoader).
 * This separation allows:
 * - Dedicated servers to run without Flutter
 * - Client-only code to be properly isolated
 * - Flutter rendering to run on the render thread
 */
@Environment(EnvType.CLIENT)
public class DartModClientLoader implements ClientModInitializer {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartModClientLoader");

    // ==========================================================================
    // Path Helper Methods for Flutter Client Runtime
    // ==========================================================================

    /**
     * Get the path to the Flutter assets directory.
     *
     * Checks in order:
     * 1. FLUTTER_ASSETS_PATH system property (set by Gradle JVM args)
     * 2. FLUTTER_ASSETS_PATH environment variable (set by CLI)
     * 3. Standard search paths relative to run directory
     */
    private static String getFlutterAssetsPath() {
        // First check for system property (used by redstone CLI via Gradle)
        String propPath = System.getProperty("FLUTTER_ASSETS_PATH");
        if (propPath != null && !propPath.isEmpty()) {
            File f = new File(propPath);
            if (f.exists() && f.isDirectory()) {
                LOGGER.info("[DartModClientLoader] Using assets path from system property FLUTTER_ASSETS_PATH: {}", propPath);
                return f.getAbsolutePath();
            } else {
                LOGGER.warn("[DartModClientLoader] FLUTTER_ASSETS_PATH property set but directory not found: {}", propPath);
            }
        }

        // Then check for environment variable (used by redstone CLI)
        String envPath = System.getenv("FLUTTER_ASSETS_PATH");
        if (envPath != null && !envPath.isEmpty()) {
            File f = new File(envPath);
            if (f.exists() && f.isDirectory()) {
                LOGGER.info("[DartModClientLoader] Using assets path from FLUTTER_ASSETS_PATH env var: {}", envPath);
                return f.getAbsolutePath();
            } else {
                LOGGER.warn("[DartModClientLoader] FLUTTER_ASSETS_PATH env var set but directory not found: {}", envPath);
            }
        }

        // Look for flutter_assets in several locations
        String[] searchPaths = {
            "mods/dart_mc/flutter_assets",     // Standard mod location
            "mods/flutter_assets",              // Alternative location
            "flutter_assets",                   // Current directory
            "config/flutter_assets"             // Config directory
        };

        String runDir = System.getProperty("user.dir");
        for (String path : searchPaths) {
            File f = new File(runDir, path);
            if (f.exists() && f.isDirectory()) {
                return f.getAbsolutePath();
            }
        }

        // Default path
        return Path.of(runDir, "mods", "dart_mc", "flutter_assets").toAbsolutePath().toString();
    }

    /**
     * Get the path to the ICU data file (icudtl.dat).
     *
     * Checks in order:
     * 1. ICU_DATA_PATH system property
     * 2. ICU_DATA_PATH environment variable
     * 3. Standard search paths relative to run directory
     */
    private static String getIcuDataPath() {
        // First check for system property
        String propPath = System.getProperty("ICU_DATA_PATH");
        if (propPath != null && !propPath.isEmpty()) {
            File f = new File(propPath);
            if (f.exists()) {
                LOGGER.info("[DartModClientLoader] Using ICU data path from system property ICU_DATA_PATH: {}", propPath);
                return f.getAbsolutePath();
            } else {
                LOGGER.warn("[DartModClientLoader] ICU_DATA_PATH property set but file not found: {}", propPath);
            }
        }

        // Then check for environment variable
        String envPath = System.getenv("ICU_DATA_PATH");
        if (envPath != null && !envPath.isEmpty()) {
            File f = new File(envPath);
            if (f.exists()) {
                LOGGER.info("[DartModClientLoader] Using ICU data path from ICU_DATA_PATH env var: {}", envPath);
                return f.getAbsolutePath();
            } else {
                LOGGER.warn("[DartModClientLoader] ICU_DATA_PATH env var set but file not found: {}", envPath);
            }
        }

        // Look for icudtl.dat in several locations
        String[] searchPaths = {
            "mods/dart_mc/icudtl.dat",
            "mods/icudtl.dat",
            "natives/icudtl.dat",
            "icudtl.dat"
        };

        String runDir = System.getProperty("user.dir");
        for (String path : searchPaths) {
            File f = new File(runDir, path);
            if (f.exists()) {
                return f.getAbsolutePath();
            }
        }

        // Default path
        return Path.of(runDir, "mods", "dart_mc", "icudtl.dat").toAbsolutePath().toString();
    }

    /**
     * Get the path to the AOT library (optional, for release mode).
     *
     * @return Path to AOT library, or empty string if not found (JIT mode)
     */
    private static String getAotLibraryPath() {
        // First check for system property
        String propPath = System.getProperty("AOT_LIBRARY_PATH");
        if (propPath != null && !propPath.isEmpty()) {
            File f = new File(propPath);
            if (f.exists()) {
                LOGGER.info("[DartModClientLoader] Using AOT library from system property AOT_LIBRARY_PATH: {}", propPath);
                return f.getAbsolutePath();
            }
        }

        // Then check for environment variable
        String envPath = System.getenv("AOT_LIBRARY_PATH");
        if (envPath != null && !envPath.isEmpty()) {
            File f = new File(envPath);
            if (f.exists()) {
                LOGGER.info("[DartModClientLoader] Using AOT library from AOT_LIBRARY_PATH env var: {}", envPath);
                return f.getAbsolutePath();
            }
        }

        // Determine platform-specific library name
        String osName = System.getProperty("os.name").toLowerCase();
        String libName;
        if (osName.contains("mac")) {
            libName = "libapp.dylib";
        } else if (osName.contains("win")) {
            libName = "app.dll";
        } else {
            libName = "libapp.so";
        }

        // Look for AOT library in several locations
        String[] searchPaths = {
            "mods/dart_mc/" + libName,
            "mods/" + libName,
            "natives/" + libName
        };

        String runDir = System.getProperty("user.dir");
        for (String path : searchPaths) {
            File f = new File(runDir, path);
            if (f.exists()) {
                LOGGER.info("[DartModClientLoader] Found AOT library: {}", f.getAbsolutePath());
                return f.getAbsolutePath();
            }
        }

        // No AOT library found - will run in JIT mode
        LOGGER.info("[DartModClientLoader] No AOT library found, will run in JIT mode");
        return "";
    }

    @Override
    public void onInitializeClient() {
        LOGGER.info("[DartModClientLoader] Initializing Flutter client runtime...");

        // Initialize Flutter client runtime
        // This runs AFTER DartModLoader.onInitialize() has initialized the server runtime
        initializeFlutterClientRuntime();

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

        // Register client tick event for Flutter task processing and test synchronization
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            // Process Flutter client tasks (pumps the Flutter event loop)
            DartBridgeClient.safeProcessClientTasks();
            // Also call the test synchronization tick
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
        // Flutter is already initialized by DartModClientLoader, so we just open the screen
        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> {
            dispatcher.register(ClientCommandManager.literal("fluttertest")
                .executes(context -> {
                    Minecraft client = Minecraft.getInstance();
                    client.execute(() -> {
                        LOGGER.info("[DartModClientLoader] Opening Flutter test screen");
                        LOGGER.info("[DartModClientLoader] Flutter client initialized: {}", DartBridgeClient.isClientInitialized());

                        // Open the FlutterScreen - it uses the already-initialized Flutter engine
                        client.setScreen(new FlutterScreen(Component.literal("Flutter Test")));
                    });
                    return 1;
                })
            );
        });

        LOGGER.info("[DartModClientLoader] /fluttertest command registered!");

        // Shutdown Flutter client runtime when the game is closing
        ClientLifecycleEvents.CLIENT_STOPPING.register(client -> {
            LOGGER.info("[DartModClientLoader] Client stopping, shutting down Flutter client runtime...");
            DartBridgeClient.safeShutdownClientRuntime();
        });

        LOGGER.info("[DartModClientLoader] Client shutdown hook registered!");
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

    // ==========================================================================
    // Flutter Client Runtime Initialization
    // ==========================================================================

    /**
     * Initialize the Flutter client runtime.
     *
     * This is called during onInitializeClient(), AFTER the server runtime
     * has been initialized by DartModLoader.onInitialize().
     *
     * The client runtime handles:
     * - Flutter rendering for GUI screens
     * - Input event forwarding to Flutter
     * - Flutter task processing each tick
     */
    private void initializeFlutterClientRuntime() {
        // Check if native library is loaded (required for Flutter)
        if (!DartBridge.isLibraryLoaded()) {
            LOGGER.warn("[DartModClientLoader] Native library not loaded, skipping Flutter client runtime initialization");
            return;
        }

        // Get Flutter asset paths
        String assetsPath = getFlutterAssetsPath();
        String icuDataPath = getIcuDataPath();
        String aotLibraryPath = getAotLibraryPath();

        LOGGER.info("[DartModClientLoader] Flutter assets path: {}", assetsPath);
        LOGGER.info("[DartModClientLoader] ICU data path: {}", icuDataPath);
        LOGGER.info("[DartModClientLoader] AOT library path: {}", aotLibraryPath.isEmpty() ? "(JIT mode)" : aotLibraryPath);

        // Check if assets exist
        File assetsDir = new File(assetsPath);
        File icuFile = new File(icuDataPath);
        boolean assetsExist = assetsDir.exists() && assetsDir.isDirectory();
        boolean icuExists = icuFile.exists();

        LOGGER.info("[DartModClientLoader] Flutter assets exist: {}", assetsExist);
        LOGGER.info("[DartModClientLoader] ICU data exists: {}", icuExists);

        if (!assetsExist) {
            LOGGER.warn("[DartModClientLoader] Flutter assets not found at: {}", assetsPath);
            LOGGER.warn("[DartModClientLoader] Flutter client runtime will not be initialized");
            LOGGER.warn("[DartModClientLoader] Flutter GUI screens will not be available");
            return;
        }

        if (!icuExists) {
            LOGGER.warn("[DartModClientLoader] ICU data file not found at: {}", icuDataPath);
            LOGGER.warn("[DartModClientLoader] Flutter client runtime will not be initialized");
            LOGGER.warn("[DartModClientLoader] Flutter GUI screens will not be available");
            return;
        }

        // Initialize Flutter client runtime
        boolean initResult = DartBridgeClient.safeInitClientRuntime(assetsPath, icuDataPath, aotLibraryPath);

        if (!initResult) {
            LOGGER.error("[DartModClientLoader] Failed to initialize Flutter client runtime!");
            LOGGER.error("[DartModClientLoader] Flutter GUI screens will not be available");
        } else {
            LOGGER.info("[DartModClientLoader] Flutter client runtime initialized successfully!");
        }
    }
}
