package com.example.dartbridge;

import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.network.protocol.game.ClientboundSetActionBarTextPacket;
import net.minecraft.network.protocol.game.ClientboundSetTitleTextPacket;
import net.minecraft.network.protocol.game.ClientboundSetSubtitleTextPacket;
import net.minecraft.network.protocol.game.ClientboundSetTitlesAnimationPacket;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.effect.MobEffect;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;
import net.minecraft.world.food.FoodData;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.entity.item.ItemEntity;
import net.minecraft.world.entity.EquipmentSlot;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.io.File;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.FileOutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * JNI interface to the native Dart bridge.
 *
 * This class provides the Java interface to the native C++ library
 * that manages the Dart VM and event dispatch.
 */
public class DartBridge {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBridge");
    private static boolean initialized = false;
    private static boolean libraryLoaded = false;
    private static MinecraftServer serverInstance = null;

    static {
        try {
            loadNativeLibrary();
            libraryLoaded = true;
            LOGGER.info("Native library loaded successfully");
        } catch (UnsatisfiedLinkError e) {
            LOGGER.error("Failed to load native library: {}", e.getMessage());
            LOGGER.error("Make sure dart_mc_bridge native library is available");
        }
    }

    private static void loadNativeLibrary() {
        String osName = System.getProperty("os.name").toLowerCase();
        String libName;
        String libResource;

        if (osName.contains("mac")) {
            libName = "dart_mc_bridge.dylib";
            libResource = "/natives/macos/" + libName;
        } else if (osName.contains("win")) {
            libName = "dart_mc_bridge.dll";
            libResource = "/natives/windows/" + libName;
        } else {
            libName = "libdart_mc_bridge.so";
            libResource = "/natives/linux/" + libName;
        }

        // First try to load from java.library.path
        try {
            System.loadLibrary("dart_mc_bridge");
            LOGGER.info("Loaded dart_mc_bridge from java.library.path");
            return;
        } catch (UnsatisfiedLinkError e) {
            LOGGER.debug("Could not load from java.library.path, trying embedded resource");
        }

        // Try to extract from JAR resources
        try (InputStream in = DartBridge.class.getResourceAsStream(libResource)) {
            if (in != null) {
                Path tempDir = Files.createTempDirectory("dart_mc_bridge");
                File tempLib = new File(tempDir.toFile(), libName);
                tempLib.deleteOnExit();
                tempDir.toFile().deleteOnExit();

                try (OutputStream out = new FileOutputStream(tempLib)) {
                    byte[] buffer = new byte[8192];
                    int bytesRead;
                    while ((bytesRead = in.read(buffer)) != -1) {
                        out.write(buffer, 0, bytesRead);
                    }
                }

                System.load(tempLib.getAbsolutePath());
                LOGGER.info("Loaded dart_mc_bridge from embedded resource");
                return;
            }
        } catch (Exception e) {
            LOGGER.debug("Could not load from embedded resource: {}", e.getMessage());
        }

        // Last resort: try absolute path in run directory
        String runDir = System.getProperty("user.dir");
        String[] searchPaths = {
            runDir + "/natives/" + libName,
            runDir + "/" + libName,
            runDir + "/mods/natives/" + libName
        };

        for (String path : searchPaths) {
            File f = new File(path);
            if (f.exists()) {
                System.load(f.getAbsolutePath());
                LOGGER.info("Loaded dart_mc_bridge from: {}", path);
                return;
            }
        }

        // If nothing works, throw error
        throw new UnsatisfiedLinkError("Could not find dart_mc_bridge native library");
    }

    // Native methods
    private static native boolean init(String scriptPath);
    private static native void shutdown();
    private static native void tick();
    private static native int onBlockBreak(int x, int y, int z, long playerId);
    private static native int onBlockInteract(int x, int y, int z, long playerId, int hand);
    private static native void onTick(long tick);
    private static native void setSendChatCallback();

    // Proxy block native methods - called by DartBlockProxy
    public static native boolean onProxyBlockBreak(long handlerId, long worldId, int x, int y, int z, long playerId);
    public static native int onProxyBlockUse(long handlerId, long worldId, int x, int y, int z, long playerId, int hand);

    // Service URL for hot reload/debugging
    private static native String getDartServiceUrl();

    // Chat message handler (called from native code)
    private static ChatMessageHandler chatHandler = null;

    @FunctionalInterface
    public interface ChatMessageHandler {
        void sendMessage(long playerId, String message);
    }

    /**
     * Set the handler for chat messages from Dart.
     */
    public static void setChatMessageHandler(ChatMessageHandler handler) {
        chatHandler = handler;
        if (libraryLoaded) {
            setSendChatCallback();
            LOGGER.info("Chat message handler registered");
        }
    }

    /**
     * Called from native code when Dart wants to send a chat message.
     */
    @SuppressWarnings("unused") // Called from native code
    private static void onChatMessage(long playerId, String message) {
        if (chatHandler != null) {
            chatHandler.sendMessage(playerId, message);
        } else {
            LOGGER.warn("Chat message received but no handler registered: {}", message);
        }
    }

    /**
     * Initialize the Dart VM with the given script file.
     *
     * @param scriptPath Path to the Dart script (.dart file)
     * @return true if initialization succeeded
     */
    public static boolean safeInit(String scriptPath) {
        if (!libraryLoaded) {
            LOGGER.error("Cannot initialize: native library not loaded");
            return false;
        }

        if (initialized) {
            LOGGER.warn("Dart VM already initialized");
            return true;
        }

        try {
            LOGGER.info("Initializing Dart VM with script: {}", scriptPath);
            initialized = init(scriptPath);
            if (initialized) {
                LOGGER.info("Dart VM initialized successfully");
            } else {
                LOGGER.error("Dart VM initialization returned false");
            }
            return initialized;
        } catch (Exception e) {
            LOGGER.error("Exception during Dart VM initialization: {}", e.getMessage());
            return false;
        }
    }

    /**
     * Shutdown the Dart VM and clean up resources.
     */
    public static void safeShutdown() {
        if (!initialized) return;

        try {
            shutdown();
            initialized = false;
            LOGGER.info("Dart VM shut down");
        } catch (Exception e) {
            LOGGER.error("Exception during Dart VM shutdown: {}", e.getMessage());
        }
    }

    /**
     * Process Dart async tasks. Should be called each game tick.
     */
    public static void safeTick() {
        if (!initialized) return;
        try {
            tick();
        } catch (Exception e) {
            LOGGER.error("Exception during tick: {}", e.getMessage());
        }
    }

    /**
     * Check if the bridge is initialized.
     */
    public static boolean isInitialized() {
        return initialized;
    }

    /**
     * Check if the native library is loaded.
     */
    public static boolean isLibraryLoaded() {
        return libraryLoaded;
    }

    /**
     * Get the Dart VM service URL for hot reload/debugging.
     *
     * @return The service URL (e.g., "http://127.0.0.1:5858/") or null if not initialized.
     */
    public static String getServiceUrl() {
        if (!initialized) return null;
        try {
            return getDartServiceUrl();
        } catch (Exception e) {
            LOGGER.error("Exception getting Dart service URL: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Dispatch a block break event to Dart handlers.
     *
     * @return 1 to allow the break, 0 to cancel
     */
    public static int dispatchBlockBreak(int x, int y, int z, long playerId) {
        if (!initialized) return 1;
        try {
            return onBlockBreak(x, y, z, playerId);
        } catch (Exception e) {
            LOGGER.error("Exception during block break dispatch: {}", e.getMessage());
            return 1;
        }
    }

    /**
     * Dispatch a block interact event to Dart handlers.
     *
     * @return 1 to allow the interaction, 0 to cancel
     */
    public static int dispatchBlockInteract(int x, int y, int z, long playerId, int hand) {
        if (!initialized) return 1;
        try {
            return onBlockInteract(x, y, z, playerId, hand);
        } catch (Exception e) {
            LOGGER.error("Exception during block interact dispatch: {}", e.getMessage());
            return 1;
        }
    }

    /**
     * Dispatch a tick event to Dart handlers.
     */
    public static void dispatchTick(long tick) {
        if (!initialized) return;
        try {
            onTick(tick);
        } catch (Exception e) {
            LOGGER.error("Exception during tick dispatch: {}", e.getMessage());
        }
    }

    // ==========================================================================
    // New Event Dispatch Methods (Native)
    // ==========================================================================

    private static native void onPlayerJoin(int playerId);
    private static native void onPlayerLeave(int playerId);
    private static native void onPlayerRespawn(int playerId, boolean endConquered);
    private static native String onPlayerDeath(int playerId, String damageSource);
    private static native boolean onEntityDamage(int entityId, String damageSource, double amount);
    private static native void onEntityDeath(int entityId, String damageSource);
    private static native boolean onPlayerAttackEntity(int playerId, int targetId);
    private static native String onPlayerChat(int playerId, String message);
    private static native boolean onPlayerCommand(int playerId, String command);
    private static native boolean onItemUse(int playerId, String itemId, int count, int hand);
    private static native int onItemUseOnBlock(int playerId, String itemId, int count, int hand, int x, int y, int z, int face);
    private static native int onItemUseOnEntity(int playerId, String itemId, int count, int hand, int targetId);
    private static native boolean onBlockPlace(int playerId, int x, int y, int z, String blockId);
    private static native boolean onPlayerPickupItem(int playerId, int itemEntityId);
    private static native boolean onPlayerDropItem(int playerId, String itemId, int count);
    private static native void onServerStarting();
    private static native void onServerStarted();
    private static native void onServerStopping();

    // ==========================================================================
    // New Event Dispatch Public Methods
    // ==========================================================================

    /**
     * Dispatch a player join event to Dart handlers.
     */
    public static void dispatchPlayerJoin(int playerId) {
        if (!initialized) return;
        try {
            onPlayerJoin(playerId);
        } catch (Exception e) {
            LOGGER.error("Exception during player join dispatch: {}", e.getMessage());
        }
    }

    /**
     * Dispatch a player leave event to Dart handlers.
     */
    public static void dispatchPlayerLeave(int playerId) {
        if (!initialized) return;
        try {
            onPlayerLeave(playerId);
        } catch (Exception e) {
            LOGGER.error("Exception during player leave dispatch: {}", e.getMessage());
        }
    }

    /**
     * Dispatch a player respawn event to Dart handlers.
     */
    public static void dispatchPlayerRespawn(int playerId, boolean endConquered) {
        if (!initialized) return;
        try {
            onPlayerRespawn(playerId, endConquered);
        } catch (Exception e) {
            LOGGER.error("Exception during player respawn dispatch: {}", e.getMessage());
        }
    }

    /**
     * Dispatch a player death event to Dart handlers.
     * @return Custom death message or null for default
     */
    public static String dispatchPlayerDeath(int playerId, String damageSource) {
        if (!initialized) return null;
        try {
            return onPlayerDeath(playerId, damageSource);
        } catch (Exception e) {
            LOGGER.error("Exception during player death dispatch: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Dispatch an entity damage event to Dart handlers.
     * @return true to allow damage, false to cancel
     */
    public static boolean dispatchEntityDamage(int entityId, String damageSource, double amount) {
        if (!initialized) return true;
        try {
            return onEntityDamage(entityId, damageSource, amount);
        } catch (Exception e) {
            LOGGER.error("Exception during entity damage dispatch: {}", e.getMessage());
            return true;
        }
    }

    /**
     * Dispatch an entity death event to Dart handlers.
     */
    public static void dispatchEntityDeath(int entityId, String damageSource) {
        if (!initialized) return;
        try {
            onEntityDeath(entityId, damageSource);
        } catch (Exception e) {
            LOGGER.error("Exception during entity death dispatch: {}", e.getMessage());
        }
    }

    /**
     * Dispatch a player attack entity event to Dart handlers.
     * @return true to allow attack, false to cancel
     */
    public static boolean dispatchPlayerAttackEntity(int playerId, int targetId) {
        if (!initialized) return true;
        try {
            return onPlayerAttackEntity(playerId, targetId);
        } catch (Exception e) {
            LOGGER.error("Exception during player attack entity dispatch: {}", e.getMessage());
            return true;
        }
    }

    /**
     * Dispatch a player chat event to Dart handlers.
     * @return Modified message, original message to pass through, or null to cancel
     */
    public static String dispatchPlayerChat(int playerId, String message) {
        if (!initialized) return message;
        try {
            return onPlayerChat(playerId, message);
        } catch (Exception e) {
            LOGGER.error("Exception during player chat dispatch: {}", e.getMessage());
            return message;
        }
    }

    /**
     * Dispatch a player command event to Dart handlers.
     * @return true to allow command, false to cancel
     */
    public static boolean dispatchPlayerCommand(int playerId, String command) {
        if (!initialized) return true;
        try {
            return onPlayerCommand(playerId, command);
        } catch (Exception e) {
            LOGGER.error("Exception during player command dispatch: {}", e.getMessage());
            return true;
        }
    }

    /**
     * Dispatch an item use event to Dart handlers.
     * @return true to allow use, false to cancel
     */
    public static boolean dispatchItemUse(int playerId, String itemId, int count, int hand) {
        if (!initialized) return true;
        try {
            return onItemUse(playerId, itemId, count, hand);
        } catch (Exception e) {
            LOGGER.error("Exception during item use dispatch: {}", e.getMessage());
            return true;
        }
    }

    /**
     * Dispatch an item use on block event to Dart handlers.
     * @return EventResult value (0=cancel, 1=allow)
     */
    public static int dispatchItemUseOnBlock(int playerId, String itemId, int count, int hand, int x, int y, int z, int face) {
        if (!initialized) return 1;
        try {
            return onItemUseOnBlock(playerId, itemId, count, hand, x, y, z, face);
        } catch (Exception e) {
            LOGGER.error("Exception during item use on block dispatch: {}", e.getMessage());
            return 1;
        }
    }

    /**
     * Dispatch an item use on entity event to Dart handlers.
     * @return EventResult value (0=cancel, 1=allow)
     */
    public static int dispatchItemUseOnEntity(int playerId, String itemId, int count, int hand, int targetId) {
        if (!initialized) return 1;
        try {
            return onItemUseOnEntity(playerId, itemId, count, hand, targetId);
        } catch (Exception e) {
            LOGGER.error("Exception during item use on entity dispatch: {}", e.getMessage());
            return 1;
        }
    }

    /**
     * Dispatch a block place event to Dart handlers.
     * @return true to allow placement, false to cancel
     */
    public static boolean dispatchBlockPlace(int playerId, int x, int y, int z, String blockId) {
        if (!initialized) return true;
        try {
            return onBlockPlace(playerId, x, y, z, blockId);
        } catch (Exception e) {
            LOGGER.error("Exception during block place dispatch: {}", e.getMessage());
            return true;
        }
    }

    /**
     * Dispatch a player pickup item event to Dart handlers.
     * @return true to allow pickup, false to cancel
     */
    public static boolean dispatchPlayerPickupItem(int playerId, int itemEntityId) {
        if (!initialized) return true;
        try {
            return onPlayerPickupItem(playerId, itemEntityId);
        } catch (Exception e) {
            LOGGER.error("Exception during player pickup item dispatch: {}", e.getMessage());
            return true;
        }
    }

    /**
     * Dispatch a player drop item event to Dart handlers.
     * @return true to allow drop, false to cancel
     */
    public static boolean dispatchPlayerDropItem(int playerId, String itemId, int count) {
        if (!initialized) return true;
        try {
            return onPlayerDropItem(playerId, itemId, count);
        } catch (Exception e) {
            LOGGER.error("Exception during player drop item dispatch: {}", e.getMessage());
            return true;
        }
    }

    /**
     * Dispatch a server starting event to Dart handlers.
     */
    public static void dispatchServerStarting() {
        if (!initialized) return;
        try {
            onServerStarting();
        } catch (Exception e) {
            LOGGER.error("Exception during server starting dispatch: {}", e.getMessage());
        }
    }

    /**
     * Dispatch a server started event to Dart handlers.
     */
    public static void dispatchServerStarted() {
        if (!initialized) return;
        try {
            onServerStarted();
        } catch (Exception e) {
            LOGGER.error("Exception during server started dispatch: {}", e.getMessage());
        }
    }

    /**
     * Dispatch a server stopping event to Dart handlers.
     */
    public static void dispatchServerStopping() {
        if (!initialized) return;
        try {
            onServerStopping();
        } catch (Exception e) {
            LOGGER.error("Exception during server stopping dispatch: {}", e.getMessage());
        }
    }

    // ==========================================================================
    // Server Instance Management
    // ==========================================================================

    /**
     * Set the server instance. Should be called when the server starts.
     */
    public static void setServerInstance(MinecraftServer server) {
        serverInstance = server;
    }

    /**
     * Get the server instance.
     */
    public static MinecraftServer getServerInstance() {
        return serverInstance;
    }

    // ==========================================================================
    // World Block Manipulation APIs
    // ==========================================================================

    /**
     * Get the block ID at a position in the world.
     * @param dimension Dimension ID (e.g., "minecraft:overworld")
     * @param x, y, z Block position coordinates
     * @return Block ID string (e.g., "minecraft:stone") or "minecraft:air" if invalid
     */
    public static String getBlockId(String dimension, int x, int y, int z) {
        if (serverInstance == null) return "minecraft:air";

        ServerLevel level = getServerLevel(dimension);
        if (level == null) return "minecraft:air";

        BlockPos pos = new BlockPos(x, y, z);
        BlockState state = level.getBlockState(pos);
        return state.getBlock().builtInRegistryHolder().key().identifier().toString();
    }

    /**
     * Set a block at a position in the world.
     * @param dimension Dimension ID
     * @param x, y, z Block position coordinates
     * @param blockId Block ID string (e.g., "minecraft:stone")
     * @return true if successful
     */
    public static boolean setBlock(String dimension, int x, int y, int z, String blockId) {
        if (serverInstance == null) return false;

        ServerLevel level = getServerLevel(dimension);
        if (level == null) return false;

        BlockPos pos = new BlockPos(x, y, z);
        Block block = BuiltInRegistries.BLOCK.getValue(Identifier.parse(blockId));
        return level.setBlock(pos, block.defaultBlockState(), 3);
    }

    /**
     * Check if a position contains air.
     */
    public static boolean isAirBlock(String dimension, int x, int y, int z) {
        if (serverInstance == null) return true;

        ServerLevel level = getServerLevel(dimension);
        if (level == null) return true;

        BlockPos pos = new BlockPos(x, y, z);
        return level.getBlockState(pos).isAir();
    }

    /**
     * Helper to get ServerLevel by dimension ID.
     */
    private static ServerLevel getServerLevel(String dimension) {
        if (serverInstance == null) return null;

        Identifier dimId = Identifier.parse(dimension);
        ResourceKey<Level> key = ResourceKey.create(Registries.DIMENSION, dimId);
        return serverInstance.getLevel(key);
    }

    // ==========================================================================
    // Player API Helper Methods
    // ==========================================================================

    /**
     * Get a ServerPlayer by entity ID.
     */
    private static ServerPlayer getPlayerById(int playerId) {
        if (serverInstance == null) return null;

        for (ServerPlayer player : serverInstance.getPlayerList().getPlayers()) {
            if (player.getId() == playerId) {
                return player;
            }
        }
        return null;
    }

    // --------------------------------------------------------------------------
    // Position & Movement
    // --------------------------------------------------------------------------

    public static double getPlayerX(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.getX() : 0.0;
    }

    public static double getPlayerY(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.getY() : 0.0;
    }

    public static double getPlayerZ(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.getZ() : 0.0;
    }

    public static double getPlayerYaw(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.getYRot() : 0.0;
    }

    public static double getPlayerPitch(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.getXRot() : 0.0;
    }

    public static void teleportPlayer(int playerId, double x, double y, double z, float yaw, float pitch) {
        ServerPlayer player = getPlayerById(playerId);
        if (player != null) {
            ServerLevel level = (ServerLevel) player.level();
            player.teleportTo(level, x, y, z, java.util.Set.of(), yaw, pitch, true);
        }
    }

    // --------------------------------------------------------------------------
    // Health & Food
    // --------------------------------------------------------------------------

    public static double getPlayerHealth(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.getHealth() : 0.0;
    }

    public static void setPlayerHealth(int playerId, float health) {
        ServerPlayer player = getPlayerById(playerId);
        if (player != null) {
            player.setHealth(health);
        }
    }

    public static double getPlayerMaxHealth(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.getMaxHealth() : 20.0;
    }

    public static int getPlayerFoodLevel(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.getFoodData().getFoodLevel() : 0;
    }

    public static void setPlayerFoodLevel(int playerId, int level) {
        ServerPlayer player = getPlayerById(playerId);
        if (player != null) {
            player.getFoodData().setFoodLevel(level);
        }
    }

    public static double getPlayerSaturation(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.getFoodData().getSaturationLevel() : 0.0;
    }

    public static void setPlayerSaturation(int playerId, float saturation) {
        ServerPlayer player = getPlayerById(playerId);
        if (player != null) {
            player.getFoodData().setSaturation(saturation);
        }
    }

    // --------------------------------------------------------------------------
    // Game Mode
    // --------------------------------------------------------------------------

    public static int getPlayerGameMode(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return 0;

        GameType gameType = player.gameMode.getGameModeForPlayer();
        return switch (gameType) {
            case SURVIVAL -> 0;
            case CREATIVE -> 1;
            case ADVENTURE -> 2;
            case SPECTATOR -> 3;
        };
    }

    public static void setPlayerGameMode(int playerId, int mode) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return;

        GameType gameType = switch (mode) {
            case 1 -> GameType.CREATIVE;
            case 2 -> GameType.ADVENTURE;
            case 3 -> GameType.SPECTATOR;
            default -> GameType.SURVIVAL;
        };

        player.setGameMode(gameType);
    }

    // --------------------------------------------------------------------------
    // Experience
    // --------------------------------------------------------------------------

    public static int getPlayerExperienceLevel(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.experienceLevel : 0;
    }

    public static void setPlayerExperienceLevel(int playerId, int level) {
        ServerPlayer player = getPlayerById(playerId);
        if (player != null) {
            player.setExperienceLevels(level);
        }
    }

    public static int getPlayerTotalExperience(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.totalExperience : 0;
    }

    public static void givePlayerExperience(int playerId, int amount) {
        ServerPlayer player = getPlayerById(playerId);
        if (player != null) {
            player.giveExperiencePoints(amount);
        }
    }

    // --------------------------------------------------------------------------
    // Communication
    // --------------------------------------------------------------------------

    public static void sendPlayerMessage(int playerId, String message) {
        ServerPlayer player = getPlayerById(playerId);
        if (player != null) {
            player.sendSystemMessage(Component.literal(message));
        }
    }

    public static void sendPlayerActionBar(int playerId, String message) {
        ServerPlayer player = getPlayerById(playerId);
        if (player != null) {
            player.connection.send(new ClientboundSetActionBarTextPacket(Component.literal(message)));
        }
    }

    public static void sendPlayerTitle(int playerId, String title, String subtitle, int fadeIn, int stay, int fadeOut) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return;

        // Set timing
        player.connection.send(new ClientboundSetTitlesAnimationPacket(fadeIn, stay, fadeOut));

        // Set subtitle if provided
        if (subtitle != null && !subtitle.isEmpty()) {
            player.connection.send(new ClientboundSetSubtitleTextPacket(Component.literal(subtitle)));
        }

        // Set title (must be last to trigger display)
        player.connection.send(new ClientboundSetTitleTextPacket(Component.literal(title)));
    }

    // --------------------------------------------------------------------------
    // Player Info
    // --------------------------------------------------------------------------

    public static String getPlayerName(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.getName().getString() : null;
    }

    public static String getPlayerUuid(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null ? player.getUUID().toString() : null;
    }

    public static boolean isPlayerOnGround(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null && player.onGround();
    }

    public static boolean isPlayerSneaking(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null && player.isShiftKeyDown();
    }

    public static boolean isPlayerSprinting(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null && player.isSprinting();
    }

    public static boolean isPlayerSwimming(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null && player.isSwimming();
    }

    public static boolean isPlayerFlying(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        return player != null && player.getAbilities().flying;
    }

    // --------------------------------------------------------------------------
    // Player Lookup
    // --------------------------------------------------------------------------

    public static int getPlayerCount() {
        if (serverInstance == null) return 0;
        return serverInstance.getPlayerList().getPlayers().size();
    }

    public static int getPlayerIdByIndex(int index) {
        if (serverInstance == null) return -1;

        List<ServerPlayer> players = serverInstance.getPlayerList().getPlayers();
        if (index < 0 || index >= players.size()) return -1;

        return players.get(index).getId();
    }

    public static int getPlayerIdByName(String name) {
        if (serverInstance == null || name == null) return -1;

        ServerPlayer player = serverInstance.getPlayerList().getPlayerByName(name);
        return player != null ? player.getId() : -1;
    }

    public static int getPlayerIdByUuid(String uuidStr) {
        if (serverInstance == null || uuidStr == null) return -1;

        try {
            UUID uuid = UUID.fromString(uuidStr);
            ServerPlayer player = serverInstance.getPlayerList().getPlayer(uuid);
            return player != null ? player.getId() : -1;
        } catch (IllegalArgumentException e) {
            LOGGER.warn("Invalid UUID format: {}", uuidStr);
            return -1;
        }
    }

    // ==========================================================================
    // Entity API Helper Methods
    // ==========================================================================

    /**
     * Get an Entity by ID from any loaded level.
     */
    private static Entity getEntityById(int entityId) {
        if (serverInstance == null) return null;

        for (ServerLevel level : serverInstance.getAllLevels()) {
            Entity entity = level.getEntity(entityId);
            if (entity != null) {
                return entity;
            }
        }
        return null;
    }

    // --------------------------------------------------------------------------
    // Entity Type Information
    // --------------------------------------------------------------------------

    public static String getEntityType(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity == null) return null;
        return BuiltInRegistries.ENTITY_TYPE.getKey(entity.getType()).toString();
    }

    public static boolean isLivingEntity(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity instanceof LivingEntity;
    }

    public static boolean isMobEntity(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity instanceof Mob;
    }

    public static boolean isPlayerEntity(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity instanceof Player;
    }

    // --------------------------------------------------------------------------
    // Entity Position & Movement
    // --------------------------------------------------------------------------

    public static double getEntityX(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null ? entity.getX() : 0.0;
    }

    public static double getEntityY(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null ? entity.getY() : 0.0;
    }

    public static double getEntityZ(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null ? entity.getZ() : 0.0;
    }

    public static void setEntityPosition(int entityId, double x, double y, double z) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            entity.setPos(x, y, z);
        }
    }

    public static double getEntityVelocityX(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null ? entity.getDeltaMovement().x : 0.0;
    }

    public static double getEntityVelocityY(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null ? entity.getDeltaMovement().y : 0.0;
    }

    public static double getEntityVelocityZ(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null ? entity.getDeltaMovement().z : 0.0;
    }

    public static void setEntityVelocity(int entityId, double x, double y, double z) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            entity.setDeltaMovement(x, y, z);
            entity.hurtMarked = true; // Sync to clients
        }
    }

    public static double getEntityYaw(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null ? entity.getYRot() : 0.0;
    }

    public static double getEntityPitch(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null ? entity.getXRot() : 0.0;
    }

    public static void teleportEntity(int entityId, double x, double y, double z, float yaw, float pitch) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            entity.teleportTo(x, y, z);
            entity.setYRot(yaw);
            entity.setXRot(pitch);
        }
    }

    // --------------------------------------------------------------------------
    // Entity State Flags
    // --------------------------------------------------------------------------

    public static boolean isEntityOnGround(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null && entity.onGround();
    }

    public static boolean isEntityInWater(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null && entity.isInWater();
    }

    public static boolean isEntityOnFire(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null && entity.isOnFire();
    }

    public static void setEntityOnFire(int entityId, int seconds) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            entity.igniteForSeconds(seconds);
        }
    }

    public static void extinguishEntity(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            entity.clearFire();
        }
    }

    public static boolean isEntitySneaking(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null && entity.isShiftKeyDown();
    }

    public static boolean isEntitySprinting(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null && entity.isSprinting();
    }

    public static boolean isEntityInvisible(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null && entity.isInvisible();
    }

    public static void setEntityInvisible(int entityId, boolean invisible) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            entity.setInvisible(invisible);
        }
    }

    public static boolean isEntityGlowing(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null && entity.isCurrentlyGlowing();
    }

    public static void setEntityGlowing(int entityId, boolean glowing) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            entity.setGlowingTag(glowing);
        }
    }

    public static boolean entityHasNoGravity(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null && entity.isNoGravity();
    }

    public static void setEntityNoGravity(int entityId, boolean noGravity) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            entity.setNoGravity(noGravity);
        }
    }

    // --------------------------------------------------------------------------
    // Entity Custom Name
    // --------------------------------------------------------------------------

    public static String getEntityCustomName(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity == null || !entity.hasCustomName()) return null;
        return entity.getCustomName().getString();
    }

    public static void setEntityCustomName(int entityId, String name) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            if (name == null || name.isEmpty()) {
                entity.setCustomName(null);
            } else {
                entity.setCustomName(Component.literal(name));
            }
        }
    }

    public static boolean isEntityCustomNameVisible(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null && entity.isCustomNameVisible();
    }

    public static void setEntityCustomNameVisible(int entityId, boolean visible) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            entity.setCustomNameVisible(visible);
        }
    }

    public static int getEntityTicksExisted(int entityId) {
        Entity entity = getEntityById(entityId);
        return entity != null ? entity.tickCount : 0;
    }

    // --------------------------------------------------------------------------
    // Entity Actions
    // --------------------------------------------------------------------------

    public static void removeEntity(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            // Use discard() for simple removal, kill() requires ServerLevel in new API
            entity.discard();
        }
    }

    public static void discardEntity(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity != null) {
            entity.discard();
        }
    }

    // --------------------------------------------------------------------------
    // Entity Tags
    // --------------------------------------------------------------------------

    public static String getEntityTags(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity == null) return "";
        Set<String> tags = entity.getTags();
        return String.join(",", tags);
    }

    public static boolean addEntityTag(int entityId, String tag) {
        Entity entity = getEntityById(entityId);
        if (entity == null || tag == null) return false;
        return entity.addTag(tag);
    }

    public static boolean removeEntityTag(int entityId, String tag) {
        Entity entity = getEntityById(entityId);
        if (entity == null || tag == null) return false;
        return entity.removeTag(tag);
    }

    // --------------------------------------------------------------------------
    // Living Entity - Health
    // --------------------------------------------------------------------------

    public static double getLivingEntityHealth(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof LivingEntity living) {
            return living.getHealth();
        }
        return 0.0;
    }

    public static void setLivingEntityHealth(int entityId, float health) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof LivingEntity living) {
            living.setHealth(health);
        }
    }

    public static double getLivingEntityMaxHealth(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof LivingEntity living) {
            return living.getMaxHealth();
        }
        return 0.0;
    }

    public static boolean isLivingEntityDead(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof LivingEntity living) {
            return living.isDeadOrDying();
        }
        return false;
    }

    public static double getLivingEntityArmor(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof LivingEntity living) {
            return living.getArmorValue();
        }
        return 0.0;
    }

    public static void hurtEntity(int entityId, double amount) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof LivingEntity living) {
            living.hurt(living.damageSources().generic(), (float) amount);
        }
    }

    // --------------------------------------------------------------------------
    // Living Entity - Status Effects
    // --------------------------------------------------------------------------

    public static void addEntityEffect(int entityId, String effectId, int duration, int amplifier, boolean ambient, boolean showParticles) {
        Entity entity = getEntityById(entityId);
        if (!(entity instanceof LivingEntity living)) return;

        Optional<MobEffect> effectOpt = BuiltInRegistries.MOB_EFFECT.getOptional(Identifier.parse(effectId));
        if (effectOpt.isEmpty()) return;

        MobEffect effect = effectOpt.get();
        MobEffectInstance instance = new MobEffectInstance(
            BuiltInRegistries.MOB_EFFECT.wrapAsHolder(effect),
            duration,
            amplifier,
            ambient,
            showParticles
        );
        living.addEffect(instance);
    }

    public static void removeEntityEffect(int entityId, String effectId) {
        Entity entity = getEntityById(entityId);
        if (!(entity instanceof LivingEntity living)) return;

        Optional<MobEffect> effectOpt = BuiltInRegistries.MOB_EFFECT.getOptional(Identifier.parse(effectId));
        if (effectOpt.isEmpty()) return;

        living.removeEffect(BuiltInRegistries.MOB_EFFECT.wrapAsHolder(effectOpt.get()));
    }

    public static boolean entityHasEffect(int entityId, String effectId) {
        Entity entity = getEntityById(entityId);
        if (!(entity instanceof LivingEntity living)) return false;

        Optional<MobEffect> effectOpt = BuiltInRegistries.MOB_EFFECT.getOptional(Identifier.parse(effectId));
        if (effectOpt.isEmpty()) return false;

        return living.hasEffect(BuiltInRegistries.MOB_EFFECT.wrapAsHolder(effectOpt.get()));
    }

    public static void clearEntityEffects(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof LivingEntity living) {
            living.removeAllEffects();
        }
    }

    // --------------------------------------------------------------------------
    // Living Entity - Looking At
    // --------------------------------------------------------------------------

    public static int getLivingEntityLookingAt(int entityId) {
        // This requires raytracing - simplified version returns -1
        // Full implementation would use level.clip() or similar
        return -1;
    }

    // --------------------------------------------------------------------------
    // Mob Entity - AI
    // --------------------------------------------------------------------------

    public static boolean mobHasAI(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof Mob mob) {
            return !mob.isNoAi();
        }
        return false;
    }

    public static void setMobAI(int entityId, boolean hasAI) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof Mob mob) {
            mob.setNoAi(!hasAI);
        }
    }

    public static int getMobTarget(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof Mob mob) {
            LivingEntity target = mob.getTarget();
            return target != null ? target.getId() : -1;
        }
        return -1;
    }

    public static void setMobTarget(int entityId, int targetEntityId) {
        Entity entity = getEntityById(entityId);
        if (!(entity instanceof Mob mob)) return;

        if (targetEntityId < 0) {
            mob.setTarget(null);
        } else {
            Entity targetEntity = getEntityById(targetEntityId);
            if (targetEntity instanceof LivingEntity target) {
                mob.setTarget(target);
            }
        }
    }

    public static boolean isMobPersistent(int entityId) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof Mob mob) {
            return mob.isPersistenceRequired();
        }
        return false;
    }

    public static void setMobPersistent(int entityId, boolean persistent) {
        Entity entity = getEntityById(entityId);
        if (entity instanceof Mob mob) {
            if (persistent) {
                mob.setPersistenceRequired();
            }
            // Note: There's no way to un-persist an entity in vanilla MC
        }
    }

    // --------------------------------------------------------------------------
    // Entity Spawning
    // --------------------------------------------------------------------------

    public static int spawnEntity(String dimension, String entityType, double x, double y, double z) {
        if (serverInstance == null) return -1;

        ServerLevel level = getServerLevel(dimension);
        if (level == null) return -1;

        Optional<EntityType<?>> typeOpt = BuiltInRegistries.ENTITY_TYPE.getOptional(Identifier.parse(entityType));
        if (typeOpt.isEmpty()) return -1;

        Entity entity = typeOpt.get().create(level, net.minecraft.world.entity.EntitySpawnReason.COMMAND);
        if (entity == null) return -1;

        entity.setPos(x, y, z);
        level.addFreshEntity(entity);
        return entity.getId();
    }

    // --------------------------------------------------------------------------
    // Entity Queries
    // --------------------------------------------------------------------------

    public static String getEntitiesInBox(String dimension, double minX, double minY, double minZ, double maxX, double maxY, double maxZ) {
        if (serverInstance == null) return "";

        ServerLevel level = getServerLevel(dimension);
        if (level == null) return "";

        AABB box = new AABB(minX, minY, minZ, maxX, maxY, maxZ);
        List<Entity> entities = level.getEntities((Entity) null, box, e -> true);

        return entities.stream()
            .map(e -> String.valueOf(e.getId()))
            .collect(Collectors.joining(","));
    }

    public static String getEntitiesInRadius(String dimension, double x, double y, double z, double radius) {
        if (serverInstance == null) return "";

        ServerLevel level = getServerLevel(dimension);
        if (level == null) return "";

        AABB box = new AABB(x - radius, y - radius, z - radius, x + radius, y + radius, z + radius);
        Vec3 center = new Vec3(x, y, z);
        double radiusSq = radius * radius;

        List<Entity> entities = level.getEntities((Entity) null, box, e -> e.distanceToSqr(center) <= radiusSq);

        return entities.stream()
            .map(e -> String.valueOf(e.getId()))
            .collect(Collectors.joining(","));
    }

    public static String getEntitiesByType(String dimension, String entityType) {
        if (serverInstance == null) return "";

        ServerLevel level = getServerLevel(dimension);
        if (level == null) return "";

        Optional<EntityType<?>> typeOpt = BuiltInRegistries.ENTITY_TYPE.getOptional(Identifier.parse(entityType));
        if (typeOpt.isEmpty()) return "";

        List<Integer> ids = new ArrayList<>();
        for (Entity entity : level.getAllEntities()) {
            if (BuiltInRegistries.ENTITY_TYPE.getKey(entity.getType()).toString().equals(entityType)) {
                ids.add(entity.getId());
            }
        }

        return ids.stream()
            .map(String::valueOf)
            .collect(Collectors.joining(","));
    }

    // ==========================================================================
    // Item API Helper Methods
    // ==========================================================================

    /**
     * Get the max stack size for an item type.
     */
    public static int getItemMaxStackSize(String itemId) {
        Optional<Item> itemOpt = BuiltInRegistries.ITEM.getOptional(Identifier.parse(itemId));
        if (itemOpt.isEmpty()) return 64;
        return itemOpt.get().getDefaultMaxStackSize();
    }

    /**
     * Get the display name for an item type.
     */
    public static String getItemDisplayName(String itemId) {
        Optional<Item> itemOpt = BuiltInRegistries.ITEM.getOptional(Identifier.parse(itemId));
        if (itemOpt.isEmpty()) return itemId;
        // In newer MC versions, use getName() on ItemStack or use the translation key
        ItemStack stack = new ItemStack(itemOpt.get());
        return stack.getHoverName().getString();
    }

    // ==========================================================================
    // ItemStack Operations (with player/slot context)
    // ==========================================================================

    /**
     * Get damage value of an item stack in a player's inventory.
     */
    public static int getItemStackDamage(int playerId, int slot) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return 0;

        ItemStack stack = getPlayerInventoryStack(player, slot);
        return stack.getDamageValue();
    }

    /**
     * Get max damage of an item stack in a player's inventory.
     */
    public static int getItemStackMaxDamage(int playerId, int slot) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return 0;

        ItemStack stack = getPlayerInventoryStack(player, slot);
        return stack.getMaxDamage();
    }

    /**
     * Check if an item stack is damageable.
     */
    public static boolean isItemStackDamageable(int playerId, int slot) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return false;

        ItemStack stack = getPlayerInventoryStack(player, slot);
        return stack.isDamageableItem();
    }

    /**
     * Get the display name of an item stack.
     */
    public static String getItemStackDisplayName(int playerId, int slot) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return "";

        ItemStack stack = getPlayerInventoryStack(player, slot);
        return stack.getHoverName().getString();
    }

    // ==========================================================================
    // Player Inventory Operations
    // ==========================================================================

    /**
     * Helper to get an ItemStack from player inventory by slot.
     */
    private static ItemStack getPlayerInventoryStack(ServerPlayer player, int slot) {
        if (slot >= 0 && slot < 36) {
            // Main inventory (0-35)
            return player.getInventory().getItem(slot);
        } else if (slot >= 36 && slot < 40) {
            // Armor slots (36=feet, 37=legs, 38=chest, 39=head)
            // Use equipment slot accessor
            EquipmentSlot equipSlot = switch (slot) {
                case 36 -> EquipmentSlot.FEET;
                case 37 -> EquipmentSlot.LEGS;
                case 38 -> EquipmentSlot.CHEST;
                case 39 -> EquipmentSlot.HEAD;
                default -> null;
            };
            if (equipSlot != null) {
                return player.getItemBySlot(equipSlot);
            }
        } else if (slot == 40) {
            // Offhand
            return player.getItemBySlot(EquipmentSlot.OFFHAND);
        }
        return ItemStack.EMPTY;
    }

    /**
     * Helper to set an ItemStack in player inventory by slot.
     */
    private static void setPlayerInventoryStack(ServerPlayer player, int slot, ItemStack stack) {
        if (slot >= 0 && slot < 36) {
            // Main inventory (0-35)
            player.getInventory().setItem(slot, stack);
        } else if (slot >= 36 && slot < 40) {
            // Armor slots (36=feet, 37=legs, 38=chest, 39=head)
            // Map slot 36-39 to EquipmentSlot
            EquipmentSlot equipSlot = switch (slot) {
                case 36 -> EquipmentSlot.FEET;
                case 37 -> EquipmentSlot.LEGS;
                case 38 -> EquipmentSlot.CHEST;
                case 39 -> EquipmentSlot.HEAD;
                default -> null;
            };
            if (equipSlot != null) {
                player.setItemSlot(equipSlot, stack);
            }
        } else if (slot == 40) {
            // Offhand
            player.setItemSlot(EquipmentSlot.OFFHAND, stack);
        }
    }

    /**
     * Get item in a player's inventory slot.
     * @return "itemId:count" format, or empty string if slot is empty
     */
    public static String getPlayerInventoryItem(int playerId, int slot) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return "";

        ItemStack stack = getPlayerInventoryStack(player, slot);
        if (stack.isEmpty()) return "";

        String itemId = BuiltInRegistries.ITEM.getKey(stack.getItem()).toString();
        return itemId + ":" + stack.getCount();
    }

    /**
     * Set item in a player's inventory slot.
     */
    public static void setPlayerInventoryItem(int playerId, int slot, String itemId, int count) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return;

        ItemStack stack;
        if (itemId == null || itemId.isEmpty() || itemId.equals("minecraft:air") || count <= 0) {
            stack = ItemStack.EMPTY;
        } else {
            Optional<Item> itemOpt = BuiltInRegistries.ITEM.getOptional(Identifier.parse(itemId));
            if (itemOpt.isEmpty()) return;
            stack = new ItemStack(itemOpt.get(), count);
        }

        setPlayerInventoryStack(player, slot, stack);
    }

    /**
     * Clear a player's inventory slot.
     */
    public static void clearPlayerInventorySlot(int playerId, int slot) {
        setPlayerInventoryItem(playerId, slot, "minecraft:air", 0);
    }

    /**
     * Get the player's currently selected hotbar slot (0-8).
     * Note: Selected slot is managed by client, this returns a best-effort estimate.
     */
    public static int getPlayerSelectedSlot(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return 0;
        // In newer MC versions, selected slot is managed differently
        // Return 0 as default - actual slot tracking would need packet handling
        return 0;
    }

    /**
     * Set the player's selected hotbar slot (0-8).
     * Note: In newer MC versions, selected slot is typically managed by client
     */
    public static void setPlayerSelectedSlot(int playerId, int slot) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null || slot < 0 || slot > 8) return;
        // Selected slot is client-side, can't be set from server
        // This is intentionally a no-op
    }

    // ==========================================================================
    // Inventory Utilities
    // ==========================================================================

    /**
     * Find first slot containing the specified item.
     * @return slot index (0-40) or -1 if not found
     */
    public static int findPlayerInventoryItem(int playerId, String itemId) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return -1;

        Optional<Item> itemOpt = BuiltInRegistries.ITEM.getOptional(Identifier.parse(itemId));
        if (itemOpt.isEmpty()) return -1;
        Item targetItem = itemOpt.get();

        // Check all slots
        for (int slot = 0; slot <= 40; slot++) {
            ItemStack stack = getPlayerInventoryStack(player, slot);
            if (!stack.isEmpty() && stack.getItem() == targetItem) {
                return slot;
            }
        }
        return -1;
    }

    /**
     * Find first empty slot in player's inventory.
     * @return slot index (0-35, main inventory only) or -1 if full
     */
    public static int findPlayerEmptySlot(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return -1;

        // Only check main inventory (0-35)
        for (int slot = 0; slot < 36; slot++) {
            ItemStack stack = getPlayerInventoryStack(player, slot);
            if (stack.isEmpty()) {
                return slot;
            }
        }
        return -1;
    }

    /**
     * Count total items of type in player's inventory.
     */
    public static int countPlayerInventoryItem(int playerId, String itemId) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return 0;

        Optional<Item> itemOpt = BuiltInRegistries.ITEM.getOptional(Identifier.parse(itemId));
        if (itemOpt.isEmpty()) return 0;
        Item targetItem = itemOpt.get();

        int count = 0;
        for (int slot = 0; slot <= 40; slot++) {
            ItemStack stack = getPlayerInventoryStack(player, slot);
            if (!stack.isEmpty() && stack.getItem() == targetItem) {
                count += stack.getCount();
            }
        }
        return count;
    }

    /**
     * Give item to player (adds to inventory, drops excess).
     * @return true if at least some items were added
     */
    public static boolean givePlayerItem(int playerId, String itemId, int count) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null || count <= 0) return false;

        Optional<Item> itemOpt = BuiltInRegistries.ITEM.getOptional(Identifier.parse(itemId));
        if (itemOpt.isEmpty()) return false;

        ItemStack stack = new ItemStack(itemOpt.get(), count);
        boolean added = player.getInventory().add(stack);

        // If stack wasn't fully added, drop the remainder
        if (!stack.isEmpty()) {
            player.drop(stack, false);
        }

        return added || stack.isEmpty();
    }

    /**
     * Remove items from player's inventory.
     * @return number of items actually removed
     */
    public static int removePlayerItem(int playerId, String itemId, int count) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null || count <= 0) return 0;

        Optional<Item> itemOpt = BuiltInRegistries.ITEM.getOptional(Identifier.parse(itemId));
        if (itemOpt.isEmpty()) return 0;
        Item targetItem = itemOpt.get();

        int remaining = count;
        for (int slot = 0; slot <= 40 && remaining > 0; slot++) {
            ItemStack stack = getPlayerInventoryStack(player, slot);
            if (!stack.isEmpty() && stack.getItem() == targetItem) {
                int toRemove = Math.min(remaining, stack.getCount());
                stack.shrink(toRemove);
                remaining -= toRemove;

                if (stack.isEmpty()) {
                    setPlayerInventoryStack(player, slot, ItemStack.EMPTY);
                }
            }
        }
        return count - remaining;
    }

    /**
     * Clear entire player inventory.
     */
    public static void clearPlayerInventory(int playerId) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return;
        player.getInventory().clearContent();
    }

    // ==========================================================================
    // Item Entity Operations
    // ==========================================================================

    /**
     * Drop an item in the world.
     * @return entity ID of the dropped item, or -1 on failure
     */
    public static int dropItem(String dimension, double x, double y, double z,
                               String itemId, int count, double vx, double vy, double vz) {
        if (serverInstance == null) return -1;

        ServerLevel level = getServerLevel(dimension);
        if (level == null) return -1;

        Optional<Item> itemOpt = BuiltInRegistries.ITEM.getOptional(Identifier.parse(itemId));
        if (itemOpt.isEmpty()) return -1;

        ItemStack stack = new ItemStack(itemOpt.get(), count);
        ItemEntity itemEntity = new ItemEntity(level, x, y, z, stack);
        itemEntity.setDeltaMovement(vx, vy, vz);

        level.addFreshEntity(itemEntity);
        return itemEntity.getId();
    }

    /**
     * Get the item stack of an item entity.
     * @return "itemId:count" format
     */
    public static String getItemEntityStack(int entityId) {
        Entity entity = getEntityById(entityId);
        if (!(entity instanceof ItemEntity itemEntity)) return "";

        ItemStack stack = itemEntity.getItem();
        if (stack.isEmpty()) return "";

        String itemId = BuiltInRegistries.ITEM.getKey(stack.getItem()).toString();
        return itemId + ":" + stack.getCount();
    }

    /**
     * Set the item stack of an item entity.
     */
    public static void setItemEntityStack(int entityId, String itemId, int count) {
        Entity entity = getEntityById(entityId);
        if (!(entity instanceof ItemEntity itemEntity)) return;

        Optional<Item> itemOpt = BuiltInRegistries.ITEM.getOptional(Identifier.parse(itemId));
        if (itemOpt.isEmpty()) return;

        itemEntity.setItem(new ItemStack(itemOpt.get(), count));
    }

    /**
     * Get the pickup delay of an item entity.
     */
    public static int getItemEntityPickupDelay(int entityId) {
        Entity entity = getEntityById(entityId);
        if (!(entity instanceof ItemEntity itemEntity)) return 0;
        // ItemEntity doesn't expose pickupDelay directly, but we can check if it can be picked up
        // The default pickup delay is stored in a private field, so we return 0 as a simplification
        return 0;
    }

    /**
     * Set the pickup delay of an item entity.
     */
    public static void setItemEntityPickupDelay(int entityId, int ticks) {
        Entity entity = getEntityById(entityId);
        if (!(entity instanceof ItemEntity itemEntity)) return;
        itemEntity.setPickUpDelay(ticks);
    }

    /**
     * Get the age of an item entity.
     */
    public static int getItemEntityAge(int entityId) {
        Entity entity = getEntityById(entityId);
        if (!(entity instanceof ItemEntity itemEntity)) return 0;
        // ItemEntity stores age privately, we can get ticks existed instead
        return entity.tickCount;
    }

    /**
     * Set the age of an item entity.
     */
    public static void setItemEntityAge(int entityId, int ticks) {
        Entity entity = getEntityById(entityId);
        if (!(entity instanceof ItemEntity itemEntity)) return;
        // We can't directly set age, but we can manipulate tickCount indirectly
        // This is a limitation - Minecraft doesn't expose a setter for item age
    }

    // ==========================================================================
    // World Utility APIs
    // ==========================================================================

    // --------------------------------------------------------------------------
    // Time
    // --------------------------------------------------------------------------

    /**
     * Get the time of day (0-24000) in a dimension.
     */
    public static long getTimeOfDay(String dimension) {
        if (serverInstance == null) return 0;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return 0;
        return level.getDayTime() % 24000;
    }

    /**
     * Set the time of day in a dimension.
     */
    public static void setTimeOfDay(String dimension, long time) {
        if (serverInstance == null) return;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return;
        // Calculate the new time preserving the day count
        long currentDayTime = level.getDayTime();
        long currentDay = currentDayTime / 24000;
        long newTime = currentDay * 24000 + (time % 24000);
        level.setDayTime(newTime);
    }

    /**
     * Get the full game time (total ticks since world creation).
     */
    public static long getGameTime(String dimension) {
        if (serverInstance == null) return 0;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return 0;
        return level.getGameTime();
    }

    /**
     * Get the current day count.
     */
    public static long getDayCount(String dimension) {
        if (serverInstance == null) return 0;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return 0;
        return level.getDayTime() / 24000;
    }

    // --------------------------------------------------------------------------
    // Weather
    // --------------------------------------------------------------------------

    /**
     * Get current weather: 0=clear, 1=rain, 2=thunder.
     */
    public static int getWeather(String dimension) {
        if (serverInstance == null) return 0;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return 0;
        if (level.isThundering()) return 2;
        if (level.isRaining()) return 1;
        return 0;
    }

    /**
     * Set weather with duration.
     * @param weather 0=clear, 1=rain, 2=thunder
     * @param duration Duration in ticks
     */
    public static void setWeather(String dimension, int weather, int duration) {
        if (serverInstance == null) return;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return;

        switch (weather) {
            case 0 -> { // Clear
                level.setWeatherParameters(duration, 0, false, false);
            }
            case 1 -> { // Rain
                level.setWeatherParameters(0, duration, true, false);
            }
            case 2 -> { // Thunder
                level.setWeatherParameters(0, duration, true, true);
            }
        }
    }

    /**
     * Check if it's raining.
     */
    public static boolean isRaining(String dimension) {
        if (serverInstance == null) return false;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return false;
        return level.isRaining();
    }

    /**
     * Check if it's thundering.
     */
    public static boolean isThundering(String dimension) {
        if (serverInstance == null) return false;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return false;
        return level.isThundering();
    }

    // --------------------------------------------------------------------------
    // Sounds
    // --------------------------------------------------------------------------

    /**
     * Play a sound at a position.
     */
    public static void playSound(String dimension, double x, double y, double z,
                                 String sound, String category, float volume, float pitch) {
        if (serverInstance == null) return;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return;

        Optional<net.minecraft.sounds.SoundEvent> soundEventOpt = BuiltInRegistries.SOUND_EVENT.getOptional(Identifier.parse(sound));
        if (soundEventOpt.isEmpty()) return;
        net.minecraft.sounds.SoundEvent soundEvent = soundEventOpt.get();

        net.minecraft.sounds.SoundSource soundCategory = switch (category) {
            case "music" -> net.minecraft.sounds.SoundSource.MUSIC;
            case "record" -> net.minecraft.sounds.SoundSource.RECORDS;
            case "weather" -> net.minecraft.sounds.SoundSource.WEATHER;
            case "block" -> net.minecraft.sounds.SoundSource.BLOCKS;
            case "hostile" -> net.minecraft.sounds.SoundSource.HOSTILE;
            case "neutral" -> net.minecraft.sounds.SoundSource.NEUTRAL;
            case "player" -> net.minecraft.sounds.SoundSource.PLAYERS;
            case "ambient" -> net.minecraft.sounds.SoundSource.AMBIENT;
            case "voice" -> net.minecraft.sounds.SoundSource.VOICE;
            default -> net.minecraft.sounds.SoundSource.MASTER;
        };

        level.playSound(null, x, y, z, soundEvent, soundCategory, volume, pitch);
    }

    /**
     * Play a sound to a specific player.
     */
    public static void playSoundToPlayer(int playerId, String sound, String category,
                                         float volume, float pitch) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return;

        Optional<net.minecraft.sounds.SoundEvent> soundEventOpt = BuiltInRegistries.SOUND_EVENT.getOptional(Identifier.parse(sound));
        if (soundEventOpt.isEmpty()) return;
        net.minecraft.sounds.SoundEvent soundEvent = soundEventOpt.get();

        net.minecraft.sounds.SoundSource soundCategory = switch (category) {
            case "music" -> net.minecraft.sounds.SoundSource.MUSIC;
            case "record" -> net.minecraft.sounds.SoundSource.RECORDS;
            case "weather" -> net.minecraft.sounds.SoundSource.WEATHER;
            case "block" -> net.minecraft.sounds.SoundSource.BLOCKS;
            case "hostile" -> net.minecraft.sounds.SoundSource.HOSTILE;
            case "neutral" -> net.minecraft.sounds.SoundSource.NEUTRAL;
            case "player" -> net.minecraft.sounds.SoundSource.PLAYERS;
            case "ambient" -> net.minecraft.sounds.SoundSource.AMBIENT;
            case "voice" -> net.minecraft.sounds.SoundSource.VOICE;
            default -> net.minecraft.sounds.SoundSource.MASTER;
        };

        // Use playSound instead of playNotifySound which doesn't exist in newer versions
        ServerLevel level = (ServerLevel) player.level();
        level.playSound(null, player.getX(), player.getY(), player.getZ(), soundEvent, soundCategory, volume, pitch);
    }

    // --------------------------------------------------------------------------
    // Particles
    // --------------------------------------------------------------------------

    /**
     * Spawn particles at a position.
     */
    public static void spawnParticles(String dimension, String particle,
                                      double x, double y, double z,
                                      int count, double dx, double dy, double dz, double speed) {
        if (serverInstance == null) return;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return;

        Optional<net.minecraft.core.particles.ParticleType<?>> particleTypeOpt =
            BuiltInRegistries.PARTICLE_TYPE.getOptional(Identifier.parse(particle));
        if (particleTypeOpt.isEmpty()) return;
        net.minecraft.core.particles.ParticleType<?> particleType = particleTypeOpt.get();

        // Most particle types are simple particles
        if (particleType instanceof net.minecraft.core.particles.SimpleParticleType simpleType) {
            level.sendParticles(simpleType, x, y, z, count, dx, dy, dz, speed);
        }
    }

    /**
     * Spawn particles to a specific player.
     */
    public static void spawnParticlesToPlayer(int playerId, String particle,
                                              double x, double y, double z,
                                              int count, double dx, double dy, double dz, double speed) {
        ServerPlayer player = getPlayerById(playerId);
        if (player == null) return;

        Optional<net.minecraft.core.particles.ParticleType<?>> particleTypeOpt =
            BuiltInRegistries.PARTICLE_TYPE.getOptional(Identifier.parse(particle));
        if (particleTypeOpt.isEmpty()) return;
        net.minecraft.core.particles.ParticleType<?> particleType = particleTypeOpt.get();

        if (particleType instanceof net.minecraft.core.particles.SimpleParticleType simpleType) {
            ServerLevel level = (ServerLevel) player.level();
            // sendParticles signature: (ServerPlayer, ParticleOptions, boolean force, boolean alwaysRender, x, y, z, count, dx, dy, dz, speed)
            level.sendParticles(player, simpleType, true, true, x, y, z, count, dx, dy, dz, speed);
        }
    }

    // --------------------------------------------------------------------------
    // Explosions
    // --------------------------------------------------------------------------

    /**
     * Create an explosion.
     * @param mode 0=none, 1=destroy, 2=destroyDecay
     */
    public static void createExplosion(String dimension, double x, double y, double z,
                                       float power, boolean fire, int mode, int sourceEntityId) {
        if (serverInstance == null) return;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return;

        Entity source = sourceEntityId >= 0 ? getEntityById(sourceEntityId) : null;

        Level.ExplosionInteraction interaction = switch (mode) {
            case 0 -> Level.ExplosionInteraction.NONE;
            case 2 -> Level.ExplosionInteraction.TNT;
            default -> Level.ExplosionInteraction.BLOCK;
        };

        level.explode(source, x, y, z, power, fire, interaction);
    }

    // --------------------------------------------------------------------------
    // Lightning
    // --------------------------------------------------------------------------

    /**
     * Spawn a lightning bolt.
     * @return Entity ID of the lightning bolt, or -1 on failure.
     */
    public static int spawnLightning(String dimension, double x, double y, double z, boolean damageOnly) {
        if (serverInstance == null) return -1;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return -1;

        net.minecraft.world.entity.LightningBolt lightning = EntityType.LIGHTNING_BOLT.create(level, net.minecraft.world.entity.EntitySpawnReason.COMMAND);
        if (lightning == null) return -1;

        lightning.setPos(x, y, z);
        lightning.setVisualOnly(damageOnly);
        level.addFreshEntity(lightning);
        return lightning.getId();
    }

    // --------------------------------------------------------------------------
    // World Border
    // --------------------------------------------------------------------------

    /**
     * Get world border center as "x,z" string.
     */
    public static String getWorldBorderCenter(String dimension) {
        if (serverInstance == null) return "";
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return "";

        net.minecraft.world.level.border.WorldBorder border = level.getWorldBorder();
        return border.getCenterX() + "," + border.getCenterZ();
    }

    /**
     * Set world border center.
     */
    public static void setWorldBorderCenter(String dimension, double x, double z) {
        if (serverInstance == null) return;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return;

        level.getWorldBorder().setCenter(x, z);
    }

    /**
     * Get world border size (diameter).
     */
    public static double getWorldBorderSize(String dimension) {
        if (serverInstance == null) return 60000000;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return 60000000;

        return level.getWorldBorder().getSize();
    }

    /**
     * Set world border size with optional transition time.
     */
    public static void setWorldBorderSize(String dimension, double size, long timeMillis) {
        if (serverInstance == null) return;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return;

        if (timeMillis <= 0) {
            level.getWorldBorder().setSize(size);
        } else {
            // In newer MC versions, lerpSizeBetween takes 4 args: oldSize, newSize, startTime, endTime
            // We use current game time as start and calculate end time
            long currentTime = level.getGameTime();
            long tickDuration = timeMillis / 50; // Convert ms to ticks
            level.getWorldBorder().lerpSizeBetween(level.getWorldBorder().getSize(), size, currentTime, currentTime + tickDuration);
        }
    }

    // --------------------------------------------------------------------------
    // Spawn Point
    // --------------------------------------------------------------------------

    /**
     * Get spawn point as "x,y,z" string.
     * Note: Spawn point API has changed significantly - this is a stub.
     */
    public static String getSpawnPoint(String dimension) {
        if (serverInstance == null) return "";
        // TODO: Spawn point API has changed in newer MC versions
        // Need to use RespawnData or similar new API
        LOGGER.debug("getSpawnPoint not fully implemented");
        return "0,64,0"; // Default fallback
    }

    /**
     * Set spawn point.
     * Note: Spawn point API has changed significantly - this is a stub.
     */
    public static void setSpawnPoint(String dimension, int x, int y, int z) {
        if (serverInstance == null) return;
        // TODO: Spawn point API has changed in newer MC versions
        // Need to use RespawnData or similar new API
        LOGGER.debug("setSpawnPoint not fully implemented for position: {}, {}, {}", x, y, z);
    }

    // --------------------------------------------------------------------------
    // Difficulty
    // --------------------------------------------------------------------------

    /**
     * Get game difficulty: 0=peaceful, 1=easy, 2=normal, 3=hard.
     */
    public static int getDifficulty() {
        if (serverInstance == null) return 2;
        return serverInstance.getWorldData().getDifficulty().getId();
    }

    /**
     * Set game difficulty.
     */
    public static void setDifficulty(int difficulty) {
        if (serverInstance == null) return;
        net.minecraft.world.Difficulty diff = switch (difficulty) {
            case 0 -> net.minecraft.world.Difficulty.PEACEFUL;
            case 1 -> net.minecraft.world.Difficulty.EASY;
            case 3 -> net.minecraft.world.Difficulty.HARD;
            default -> net.minecraft.world.Difficulty.NORMAL;
        };
        serverInstance.setDifficulty(diff, true);
    }

    // --------------------------------------------------------------------------
    // Game Rules
    // --------------------------------------------------------------------------

    /**
     * Get a game rule value.
     * Note: GameRules API has changed - this is a stub implementation.
     */
    public static String getGameRule(String dimension, String rule) {
        if (serverInstance == null) return "";
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return "";

        // TODO: GameRules API has changed in newer MC versions
        // For now, return empty string as a safe fallback
        // Full implementation would need to use the new GameRules API
        LOGGER.debug("getGameRule not fully implemented for rule: {}", rule);
        return "";
    }

    /**
     * Set a game rule value.
     * Note: GameRules API has changed - this is a stub implementation.
     */
    public static void setGameRule(String dimension, String rule, String value) {
        if (serverInstance == null) return;
        ServerLevel level = getServerLevel(dimension);
        if (level == null) return;

        // TODO: GameRules API has changed in newer MC versions
        // For now, log and skip
        LOGGER.debug("setGameRule not fully implemented for rule: {} = {}", rule, value);
    }

    // ==========================================================================
    // GUI / Screen APIs (Native Method Declarations)
    // ==========================================================================
    // Note: These methods are called from the client-side DartBridgeClient class.
    // The actual dispatch and GUI operations are in the client source set.

    // --------------------------------------------------------------------------
    // Screen Event Dispatch Methods
    // --------------------------------------------------------------------------

    public static void dispatchScreenInit(long screenId, int width, int height) {
        if (!initialized) return;
        try {
            onScreenInit(screenId, width, height);
        } catch (Exception e) {
            LOGGER.error("Exception during screen init dispatch: {}", e.getMessage());
        }
    }

    public static void dispatchScreenTick(long screenId) {
        if (!initialized) return;
        try {
            onScreenTick(screenId);
        } catch (Exception e) {
            LOGGER.error("Exception during screen tick dispatch: {}", e.getMessage());
        }
    }

    public static void dispatchScreenRender(long screenId, int mouseX, int mouseY, float partialTick) {
        if (!initialized) return;
        try {
            onScreenRender(screenId, mouseX, mouseY, partialTick);
        } catch (Exception e) {
            LOGGER.error("Exception during screen render dispatch: {}", e.getMessage());
        }
    }

    public static void dispatchScreenClose(long screenId) {
        if (!initialized) return;
        try {
            onScreenClose(screenId);
        } catch (Exception e) {
            LOGGER.error("Exception during screen close dispatch: {}", e.getMessage());
        }
    }

    public static boolean dispatchScreenKeyPressed(long screenId, int keyCode, int scanCode, int modifiers) {
        if (!initialized) return false;
        try {
            return onScreenKeyPressed(screenId, keyCode, scanCode, modifiers);
        } catch (Exception e) {
            LOGGER.error("Exception during screen key pressed dispatch: {}", e.getMessage());
            return false;
        }
    }

    public static boolean dispatchScreenKeyReleased(long screenId, int keyCode, int scanCode, int modifiers) {
        if (!initialized) return false;
        try {
            return onScreenKeyReleased(screenId, keyCode, scanCode, modifiers);
        } catch (Exception e) {
            LOGGER.error("Exception during screen key released dispatch: {}", e.getMessage());
            return false;
        }
    }

    public static boolean dispatchScreenCharTyped(long screenId, int codePoint, int modifiers) {
        if (!initialized) return false;
        try {
            return onScreenCharTyped(screenId, codePoint, modifiers);
        } catch (Exception e) {
            LOGGER.error("Exception during screen char typed dispatch: {}", e.getMessage());
            return false;
        }
    }

    public static boolean dispatchScreenMouseClicked(long screenId, double mouseX, double mouseY, int button) {
        if (!initialized) return false;
        try {
            return onScreenMouseClicked(screenId, mouseX, mouseY, button);
        } catch (Exception e) {
            LOGGER.error("Exception during screen mouse clicked dispatch: {}", e.getMessage());
            return false;
        }
    }

    public static boolean dispatchScreenMouseReleased(long screenId, double mouseX, double mouseY, int button) {
        if (!initialized) return false;
        try {
            return onScreenMouseReleased(screenId, mouseX, mouseY, button);
        } catch (Exception e) {
            LOGGER.error("Exception during screen mouse released dispatch: {}", e.getMessage());
            return false;
        }
    }

    public static boolean dispatchScreenMouseDragged(long screenId, double mouseX, double mouseY, int button, double dragX, double dragY) {
        if (!initialized) return false;
        try {
            return onScreenMouseDragged(screenId, mouseX, mouseY, button, dragX, dragY);
        } catch (Exception e) {
            LOGGER.error("Exception during screen mouse dragged dispatch: {}", e.getMessage());
            return false;
        }
    }

    public static boolean dispatchScreenMouseScrolled(long screenId, double mouseX, double mouseY, double deltaX, double deltaY) {
        if (!initialized) return false;
        try {
            return onScreenMouseScrolled(screenId, mouseX, mouseY, deltaX, deltaY);
        } catch (Exception e) {
            LOGGER.error("Exception during screen mouse scrolled dispatch: {}", e.getMessage());
            return false;
        }
    }

    // --------------------------------------------------------------------------
    // Screen Native Method Declarations
    // --------------------------------------------------------------------------

    private static native void onScreenInit(long screenId, int width, int height);
    private static native void onScreenTick(long screenId);
    private static native void onScreenRender(long screenId, int mouseX, int mouseY, float partialTick);
    private static native void onScreenClose(long screenId);
    private static native boolean onScreenKeyPressed(long screenId, int keyCode, int scanCode, int modifiers);
    private static native boolean onScreenKeyReleased(long screenId, int keyCode, int scanCode, int modifiers);
    private static native boolean onScreenCharTyped(long screenId, int codePoint, int modifiers);
    private static native boolean onScreenMouseClicked(long screenId, double mouseX, double mouseY, int button);
    private static native boolean onScreenMouseReleased(long screenId, double mouseX, double mouseY, int button);
    private static native boolean onScreenMouseDragged(long screenId, double mouseX, double mouseY, int button, double dragX, double dragY);
    private static native boolean onScreenMouseScrolled(long screenId, double mouseX, double mouseY, double deltaX, double deltaY);

    // --------------------------------------------------------------------------
    // Widget Event Dispatch Methods
    // --------------------------------------------------------------------------

    /**
     * Dispatch widget pressed event to Dart handlers.
     */
    public static void dispatchWidgetPressed(long screenId, long widgetId) {
        if (!initialized) return;
        try {
            onWidgetPressed(screenId, widgetId);
        } catch (Exception e) {
            LOGGER.error("Exception during widget pressed dispatch: {}", e.getMessage());
        }
    }

    /**
     * Dispatch widget text changed event to Dart handlers.
     */
    public static void dispatchWidgetTextChanged(long screenId, long widgetId, String text) {
        if (!initialized) return;
        try {
            onWidgetTextChanged(screenId, widgetId, text);
        } catch (Exception e) {
            LOGGER.error("Exception during widget text changed dispatch: {}", e.getMessage());
        }
    }

    // --------------------------------------------------------------------------
    // Widget Native Method Declarations
    // --------------------------------------------------------------------------

    private static native void onWidgetPressed(long screenId, long widgetId);
    private static native void onWidgetTextChanged(long screenId, long widgetId, String text);

    // ==========================================================================
    // Container Screen APIs
    // ==========================================================================

    // --------------------------------------------------------------------------
    // Container Screen Event Dispatch Methods
    // --------------------------------------------------------------------------

    /**
     * Dispatch container screen init event to Dart handlers.
     */
    public static void dispatchContainerScreenInit(long screenId, int width, int height,
                                                    int leftPos, int topPos, int imageWidth, int imageHeight) {
        if (!initialized) return;
        try {
            onContainerScreenInit(screenId, width, height, leftPos, topPos, imageWidth, imageHeight);
        } catch (Exception e) {
            LOGGER.error("Exception during container screen init dispatch: {}", e.getMessage());
        }
    }

    /**
     * Dispatch container screen render background event to Dart handlers.
     */
    public static void dispatchContainerScreenRenderBg(long screenId, int mouseX, int mouseY,
                                                        float partialTick, int leftPos, int topPos) {
        if (!initialized) return;
        try {
            onContainerScreenRenderBg(screenId, mouseX, mouseY, partialTick, leftPos, topPos);
        } catch (Exception e) {
            LOGGER.error("Exception during container screen render bg dispatch: {}", e.getMessage());
        }
    }

    /**
     * Dispatch container screen close event to Dart handlers.
     */
    public static void dispatchContainerScreenClose(long screenId) {
        if (!initialized) return;
        try {
            onContainerScreenClose(screenId);
        } catch (Exception e) {
            LOGGER.error("Exception during container screen close dispatch: {}", e.getMessage());
        }
    }

    // --------------------------------------------------------------------------
    // Container Screen Native Method Declarations
    // --------------------------------------------------------------------------

    private static native void onContainerScreenInit(long screenId, int width, int height,
                                                      int leftPos, int topPos, int imageWidth, int imageHeight);
    private static native void onContainerScreenRenderBg(long screenId, int mouseX, int mouseY,
                                                          float partialTick, int leftPos, int topPos);
    private static native void onContainerScreenClose(long screenId);
}
