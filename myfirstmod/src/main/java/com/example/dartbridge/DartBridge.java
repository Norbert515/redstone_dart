package com.example.dartbridge;

import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.io.File;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.FileOutputStream;
import java.nio.file.Files;
import java.nio.file.Path;

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
}
