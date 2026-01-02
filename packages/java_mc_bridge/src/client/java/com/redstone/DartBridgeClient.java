package com.redstone;

import com.mojang.blaze3d.pipeline.RenderTarget;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.Minecraft;
import net.minecraft.client.Screenshot;
import net.minecraft.network.chat.Component;
import com.redstone.blockentity.DartBlockEntityMenu;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.nio.ByteBuffer;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Client-side bridge for Dart/Flutter integration.
 *
 * This class manages the Flutter client runtime which runs on the render thread.
 * It provides:
 * - Flutter engine initialization and lifecycle
 * - Flutter rendering for GUI screens
 * - Input event forwarding to Flutter
 * - Visual testing utilities (screenshots, camera positioning)
 *
 * The client runtime is separate from the server runtime (DartBridge).
 * Server runtime handles game logic; client runtime handles Flutter UI.
 */
@Environment(EnvType.CLIENT)
public class DartBridgeClient {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBridgeClient");

    // Flag indicating if the client runtime is initialized (thread-safe)
    private static final AtomicBoolean clientInitialized = new AtomicBoolean(false);

    // Cached container progress values (updated on render thread, read from any thread)
    private static volatile float cachedLitProgress = 0.0f;
    private static volatile float cachedBurnProgress = 0.0f;
    private static volatile boolean cachedIsLit = false;
    private static volatile int cachedContainerMenuId = -1;

    // ==========================================================================
    // Client Runtime Native Methods (Flutter Engine)
    // ==========================================================================

    /**
     * Initialize the Flutter client runtime.
     *
     * @param assetsPath Path to flutter_assets/ directory
     * @param icuDataPath Path to icudtl.dat file
     * @param aotLibraryPath Path to AOT library (can be empty for JIT mode)
     * @param enableRendering true to enable Flutter rendering (always true for client)
     * @return true if initialization succeeded
     */
    private static native boolean initClient(String assetsPath, String icuDataPath,
                                             String aotLibraryPath, boolean enableRendering);

    /**
     * Shutdown the Flutter client runtime and clean up resources.
     */
    private static native void shutdownClient();

    /**
     * Capture the classloader from the current thread.
     * This MUST be called from the render thread (which uses KnotClassLoader)
     * so that subsequent JNI calls from other threads can load classes correctly.
     *
     * @return true if successfully captured, false on failure
     */
    private static native boolean captureClassloader();

    /**
     * Process Flutter engine tasks - pumps the Flutter event loop.
     * Must be called on the same thread that initialized the engine (render thread).
     */
    private static native void processClientTasks();

    // ==========================================================================
    // Flutter Rendering Native Methods
    // ==========================================================================

    /**
     * Get the latest frame pixels from Flutter rendering.
     * Returns a direct ByteBuffer with RGBA pixel data.
     * The buffer is only valid until the next call to getFramePixels().
     */
    public static native ByteBuffer getFramePixels();

    /**
     * Get the width of the current Flutter frame.
     */
    public static native int getFrameWidth();

    /**
     * Get the height of the current Flutter frame.
     */
    public static native int getFrameHeight();

    /**
     * Check if Flutter has rendered a new frame since the last check.
     */
    public static native boolean hasNewFrame();

    // ==========================================================================
    // OpenGL Rendering Native Methods
    // ==========================================================================

    /**
     * Get the OpenGL texture ID for Flutter's rendered output.
     * Returns 0 if OpenGL rendering is not enabled or no texture exists.
     * When non-zero, this texture can be bound directly in Minecraft's render loop.
     */
    public static native int getFlutterTextureId();

    /**
     * Get the width of the Flutter texture in pixels.
     */
    public static native int getFlutterTextureWidth();

    /**
     * Get the height of the Flutter texture in pixels.
     */
    public static native int getFlutterTextureHeight();

    /**
     * Check if hardware-accelerated rendering is enabled.
     * On macOS, this means Metal (via IOSurface). On Windows/Linux, this means OpenGL.
     * When true, use getFlutterTextureId() to get the texture directly.
     * When false, use getFramePixels() to get the software-rendered buffer.
     */
    public static native boolean isOpenGLRenderer();

    /**
     * Check if Metal rendering is being used (macOS only).
     * Metal textures are shared via IOSurface and use GL_TEXTURE_RECTANGLE.
     * Returns false on Windows/Linux (which use regular OpenGL).
     */
    public static native boolean isMetalRenderer();

    /**
     * Enable or disable hardware-accelerated rendering.
     * Must be called BEFORE initClient() to take effect.
     * On macOS, this controls Metal rendering. On Windows/Linux, this controls OpenGL.
     *
     * @param enabled true to use hardware rendering, false for software rendering
     */
    public static native void setOpenGLEnabled(boolean enabled);

    /**
     * Send window metrics to Flutter (call when window/screen resizes).
     * @param width Screen width in GUI coordinates
     * @param height Screen height in GUI coordinates
     * @param pixelRatio The GUI scale factor (e.g., 2.0 for Retina)
     */
    public static native void sendWindowMetrics(int width, int height, double pixelRatio);

    /**
     * Send a pointer/mouse event to Flutter.
     * @param phase Pointer phase: 0=cancel, 1=up, 2=down, 3=move, 4=add, 5=remove, 6=hover
     * @param x X coordinate in pixels
     * @param y Y coordinate in pixels
     * @param buttons Button state bitmask (1=primary, 2=secondary, 4=middle)
     */
    public static native void sendPointerEvent(int phase, double x, double y, long buttons);

    /**
     * Send a keyboard event to Flutter.
     * @param type Event type: 0=down, 1=up, 2=repeat
     * @param physicalKey Physical key code
     * @param logicalKey Logical key code
     * @param characters The character(s) produced by the key (can be null)
     * @param modifiers Modifier key state bitmask
     */
    public static native void sendKeyEvent(int type, long physicalKey, long logicalKey, String characters, int modifiers);

    // ==========================================================================
    // Client Runtime Public Methods
    // ==========================================================================

    /**
     * Safely initialize the Flutter client runtime.
     *
     * This should be called from DartModClientLoader.onInitializeClient(),
     * AFTER the server runtime has been initialized.
     *
     * @param assetsPath Path to flutter_assets/ directory
     * @param icuDataPath Path to icudtl.dat file
     * @param aotLibraryPath Path to AOT library (can be empty/null for JIT mode)
     * @return true if initialization succeeded
     */
    public static boolean safeInitClientRuntime(String assetsPath, String icuDataPath, String aotLibraryPath) {
        if (clientInitialized.get()) {
            LOGGER.warn("Client runtime already initialized");
            return true;
        }

        try {
            LOGGER.info("Initializing Flutter client runtime with assets: {}", assetsPath);
            LOGGER.info("ICU data path: {}", icuDataPath);
            LOGGER.info("AOT library path: {}", aotLibraryPath != null && !aotLibraryPath.isEmpty() ? aotLibraryPath : "(JIT mode)");

            boolean success = initClient(
                assetsPath,
                icuDataPath,
                aotLibraryPath != null ? aotLibraryPath : "",
                true  // Always enable rendering on client
            );
            clientInitialized.set(success);

            if (success) {
                LOGGER.info("Flutter client runtime initialized successfully");

                // Capture the classloader from this thread (render thread)
                // This is critical so that JNI calls from Flutter thread can find our classes
                boolean classloaderCaptured = captureClassloader();
                if (classloaderCaptured) {
                    LOGGER.info("Classloader captured successfully for cross-thread JNI access");
                } else {
                    LOGGER.warn("Failed to capture classloader - JNI calls from Flutter thread may fail");
                }
            } else {
                LOGGER.error("Flutter client runtime initialization returned false");
            }
            return success;
        } catch (Exception e) {
            LOGGER.error("Exception during client runtime initialization: {}", e.getMessage(), e);
            return false;
        }
    }

    /**
     * Shutdown the Flutter client runtime and clean up resources.
     */
    public static void safeShutdownClientRuntime() {
        if (!clientInitialized.get()) return;

        try {
            shutdownClient();
            clientInitialized.set(false);
            LOGGER.info("Flutter client runtime shut down");
        } catch (Exception e) {
            LOGGER.error("Exception during client runtime shutdown: {}", e.getMessage());
        }
    }

    /**
     * Process Flutter client tasks - pumps the Flutter event loop.
     * Should be called each client tick on the render thread.
     */
    public static void safeProcessClientTasks() {
        if (!clientInitialized.get()) return;
        try {
            processClientTasks();
        } catch (Exception e) {
            LOGGER.error("Exception during client task processing: {}", e.getMessage());
        }
    }

    /**
     * Check if the client runtime is initialized.
     */
    public static boolean isClientInitialized() {
        return clientInitialized.get();
    }

    // ==========================================================================
    // Network Packet Methods (Client-side)
    // ==========================================================================

    /**
     * Dispatch a packet received from the server to the client Dart/Flutter runtime.
     * Called by ClientPacketHandler when a packet is received from the server.
     *
     * @param packetType The packet type ID
     * @param data The packet payload data
     */
    private static native void dispatchServerPacketNative(int packetType, byte[] data);

    /**
     * Register a callback for sending packets to the server.
     * The callback signature is: void callback(int packetType, byte[] data)
     */
    private static native void registerClientSendPacketCallback();

    // Packet send callback handler
    private static ClientPacketSendHandler packetSendHandler = null;

    // Slot positions update handler (Flutter -> Java)
    private static SlotPositionsUpdateHandler slotPositionsHandler = null;

    @FunctionalInterface
    public interface ClientPacketSendHandler {
        void sendPacket(int packetType, byte[] data);
    }

    @FunctionalInterface
    public interface SlotPositionsUpdateHandler {
        void onUpdate(int menuId, int[] data);
    }

    /**
     * Set the handler for slot position updates from Flutter.
     */
    public static void setSlotPositionsHandler(SlotPositionsUpdateHandler handler) {
        slotPositionsHandler = handler;
    }

    /**
     * Called from native code when Flutter reports slot positions.
     * Data format: [slotIndex, x, y, width, height, slotIndex, x, y, width, height, ...]
     */
    @SuppressWarnings("unused") // Called from native code via JNI
    public static void onSlotPositionsUpdate(int menuId, int[] data) {
        if (slotPositionsHandler != null) {
            slotPositionsHandler.onUpdate(menuId, data);
        }
    }

    /**
     * Called from Dart via JNI when Flutter reports slot positions.
     * Data format: comma-separated "slotIndex,x,y,width,height,slotIndex,x,y,width,height,..."
     */
    @SuppressWarnings("unused") // Called from Dart via JNI
    public static void onSlotPositionsUpdateFromString(int menuId, String dataStr) {
        LOGGER.info("[DartBridgeClient] onSlotPositionsUpdateFromString called: menuId={}, dataStr length={}",
            menuId, dataStr != null ? dataStr.length() : "null");

        if (dataStr == null || dataStr.isEmpty()) {
            onSlotPositionsUpdate(menuId, new int[0]);
            return;
        }

        String[] parts = dataStr.split(",");
        int[] data = new int[parts.length];
        for (int i = 0; i < parts.length; i++) {
            data[i] = Integer.parseInt(parts[i].trim());
        }
        LOGGER.info("[DartBridgeClient] Parsed {} slot position values for menu {}", data.length, menuId);
        onSlotPositionsUpdate(menuId, data);
    }

    /**
     * Set the handler for sending packets from Dart to the server.
     */
    public static void setPacketSendHandler(ClientPacketSendHandler handler) {
        packetSendHandler = handler;
        if (clientInitialized.get()) {
            registerClientSendPacketCallback();
            LOGGER.info("Client packet send handler registered");
        }
    }

    /**
     * Called from native code when Dart wants to send a packet to the server.
     */
    @SuppressWarnings("unused") // Called from native code
    private static void onSendPacketToServer(int packetType, byte[] data) {
        if (packetSendHandler != null) {
            packetSendHandler.sendPacket(packetType, data);
        } else {
            LOGGER.warn("Client packet send requested but no handler registered");
        }
    }

    /**
     * Public method to dispatch a packet from server to client Dart runtime.
     *
     * @param packetType The packet type ID
     * @param data The packet payload data
     */
    public static void dispatchServerPacket(int packetType, byte[] data) {
        if (!clientInitialized.get()) {
            LOGGER.warn("Cannot dispatch server packet: Client runtime not initialized");
            return;
        }
        try {
            dispatchServerPacketNative(packetType, data);
        } catch (Exception e) {
            LOGGER.error("Exception dispatching server packet: {}", e.getMessage());
        }
    }

    // ==========================================================================
    // Legacy Methods (deprecated - for backwards compatibility)
    // ==========================================================================

    /**
     * Initialize the Flutter engine for client-side use (with rendering enabled).
     *
     * @deprecated Use safeInitClientRuntime() instead
     * @param assetsPath Path to flutter_assets/ directory
     * @param icuDataPath Path to icudtl.dat file
     * @param aotLibraryPath Path to AOT library (can be empty/null for JIT mode)
     * @return true if initialization succeeded
     */
    @Deprecated
    public static boolean safeInitClient(String assetsPath, String icuDataPath, String aotLibraryPath) {
        LOGGER.info("Initializing Flutter engine for client (rendering enabled)");
        // Delegate to the new client runtime initialization
        return safeInitClientRuntime(assetsPath, icuDataPath, aotLibraryPath);
    }

    // Visual test mode flag - when true, client will auto-join test world
    private static boolean visualTestMode = false;

    // Flag to prevent multiple attempts to join test world
    private static boolean hasAttemptedJoinTestWorld = false;

    // Client tick counter for test synchronization
    private static long clientTick = 0;

    // Callback for client tick events (called from Dart)
    private static ClientTickCallback clientTickCallback = null;

    // Callback for client ready events (world loaded)
    private static Runnable clientReadyCallback = null;

    /**
     * Functional interface for client tick callbacks.
     */
    @FunctionalInterface
    public interface ClientTickCallback {
        void onTick(long tick);
    }

    /**
     * Increment the client tick counter and notify callbacks.
     * Called from ClientTickEvents.END_CLIENT_TICK.
     */
    public static void onClientTick() {
        clientTick++;

        // Update cached container values on every tick (thread-safe for Flutter)
        updateCachedContainerProgress();

        if (clientTickCallback != null) {
            clientTickCallback.onTick(clientTick);
        }
    }

    /**
     * Called when the client is ready (world loaded).
     */
    public static void onClientReady() {
        LOGGER.info("Client ready - world loaded");
        if (clientReadyCallback != null) {
            clientReadyCallback.run();
        }
    }

    /**
     * Get the current client tick.
     */
    public static long getClientTick() {
        return clientTick;
    }

    /**
     * Set the client tick callback (called from native code).
     */
    public static void setClientTickCallback(ClientTickCallback callback) {
        clientTickCallback = callback;
    }

    /**
     * Set the client ready callback (called from native code).
     */
    public static void setClientReadyCallback(Runnable callback) {
        clientReadyCallback = callback;
    }

    /**
     * Take a screenshot and save it with the specified filename.
     *
     * @param filename The filename (without extension) for the screenshot
     * @return The absolute path to the saved screenshot file, or null on failure
     */
    public static String takeScreenshot(String filename) {
        Minecraft mc = Minecraft.getInstance();

        if (mc.level == null) {
            LOGGER.warn("Cannot take screenshot - no world loaded");
            return null;
        }

        // Create screenshots directory
        File screenshotsDir = new File(mc.gameDirectory, "screenshots");
        if (!screenshotsDir.exists()) {
            screenshotsDir.mkdirs();
        }

        String fullFilename = filename + ".png";
        File targetFile = new File(screenshotsDir, fullFilename);

        // Use a latch to wait for the async screenshot operation
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<String> resultPath = new AtomicReference<>(null);

        // Must be called from render thread
        if (!mc.isSameThread()) {
            mc.execute(() -> {
                captureScreenshot(mc, targetFile, fullFilename, latch, resultPath);
            });
        } else {
            captureScreenshot(mc, targetFile, fullFilename, latch, resultPath);
        }

        // Wait for screenshot to complete (with timeout)
        try {
            if (!latch.await(5, TimeUnit.SECONDS)) {
                LOGGER.warn("Screenshot timed out");
                return null;
            }
        } catch (InterruptedException e) {
            LOGGER.warn("Screenshot interrupted", e);
            return null;
        }

        return resultPath.get();
    }

    private static void captureScreenshot(Minecraft mc, File targetFile, String fullFilename,
                                          CountDownLatch latch, AtomicReference<String> resultPath) {
        try {
            RenderTarget renderTarget = mc.getMainRenderTarget();

            // Use the 5-argument version: (File dir, String filename, RenderTarget, int downscale, Consumer)
            Screenshot.grab(
                mc.gameDirectory,
                fullFilename,
                renderTarget,
                1,  // No downscaling
                component -> {
                    // Screenshot completed
                    if (targetFile.exists()) {
                        resultPath.set(targetFile.getAbsolutePath());
                        LOGGER.info("Screenshot saved: {}", targetFile.getAbsolutePath());
                    } else {
                        LOGGER.warn("Screenshot file not found after save");
                    }
                    latch.countDown();
                }
            );
        } catch (Exception e) {
            LOGGER.error("Failed to take screenshot", e);
            latch.countDown();
        }
    }

    /**
     * Position the camera (player) at the specified coordinates with rotation.
     *
     * @param x     X coordinate
     * @param y     Y coordinate
     * @param z     Z coordinate
     * @param yaw   Horizontal rotation (0 = south, 90 = west, 180/-180 = north, -90 = east)
     * @param pitch Vertical rotation (-90 = up, 0 = horizon, 90 = down)
     */
    public static void positionCamera(double x, double y, double z, float yaw, float pitch) {
        Minecraft mc = Minecraft.getInstance();

        if (mc.player == null) {
            LOGGER.warn("Cannot position camera - no player");
            return;
        }

        if (!mc.isSameThread()) {
            mc.execute(() -> {
                setPlayerPosition(mc, x, y, z, yaw, pitch);
            });
        } else {
            setPlayerPosition(mc, x, y, z, yaw, pitch);
        }
    }

    private static void setPlayerPosition(Minecraft mc, double x, double y, double z, float yaw, float pitch) {
        if (mc.player != null) {
            mc.player.setPos(x, y, z);
            mc.player.setYRot(yaw);
            mc.player.setXRot(pitch);

            // Also update old values to prevent interpolation glitches
            mc.player.xo = x;
            mc.player.yo = y;
            mc.player.zo = z;
            mc.player.yRotO = yaw;
            mc.player.xRotO = pitch;

            LOGGER.debug("Camera positioned at ({}, {}, {}) yaw={} pitch={}", x, y, z, yaw, pitch);
        }
    }

    /**
     * Look at a specific block position from the current player position.
     *
     * @param targetX X coordinate to look at
     * @param targetY Y coordinate to look at
     * @param targetZ Z coordinate to look at
     */
    public static void lookAt(double targetX, double targetY, double targetZ) {
        Minecraft mc = Minecraft.getInstance();

        if (mc.player == null) {
            LOGGER.warn("Cannot look at target - no player");
            return;
        }

        if (!mc.isSameThread()) {
            mc.execute(() -> {
                calculateAndSetLookAt(mc, targetX, targetY, targetZ);
            });
        } else {
            calculateAndSetLookAt(mc, targetX, targetY, targetZ);
        }
    }

    private static void calculateAndSetLookAt(Minecraft mc, double targetX, double targetY, double targetZ) {
        if (mc.player == null) return;

        double dx = targetX - mc.player.getX();
        double dy = targetY - mc.player.getEyeY();
        double dz = targetZ - mc.player.getZ();

        double horizontalDist = Math.sqrt(dx * dx + dz * dz);
        float yaw = (float) Math.toDegrees(Math.atan2(-dx, dz));
        float pitch = (float) Math.toDegrees(-Math.atan2(dy, horizontalDist));

        mc.player.setYRot(yaw);
        mc.player.setXRot(pitch);
        mc.player.yRotO = yaw;
        mc.player.xRotO = pitch;

        LOGGER.debug("Looking at ({}, {}, {}) yaw={} pitch={}", targetX, targetY, targetZ, yaw, pitch);
    }

    /**
     * Get the window width.
     */
    public static int getWindowWidth() {
        return Minecraft.getInstance().getWindow().getWidth();
    }

    /**
     * Get the window height.
     */
    public static int getWindowHeight() {
        return Minecraft.getInstance().getWindow().getHeight();
    }

    /**
     * Check if the client is ready (has a player and world).
     */
    public static boolean isClientReady() {
        Minecraft mc = Minecraft.getInstance();
        return mc.player != null && mc.level != null;
    }

    /**
     * Get the screenshots directory path.
     */
    public static String getScreenshotsDirectory() {
        Minecraft mc = Minecraft.getInstance();
        File screenshotsDir = new File(mc.gameDirectory, "screenshots");
        return screenshotsDir.getAbsolutePath();
    }

    /**
     * Enable or disable visual test mode.
     * When enabled, the client will automatically join a test world on startup.
     *
     * @param enabled Whether to enable visual test mode
     */
    public static void setVisualTestMode(boolean enabled) {
        visualTestMode = enabled;
        LOGGER.info("Visual test mode: {}", enabled);
    }

    /**
     * Check if visual test mode is enabled.
     */
    public static boolean isVisualTestMode() {
        return visualTestMode;
    }

    /**
     * Check if the client has already attempted to join the test world.
     */
    public static boolean hasAttemptedJoinTestWorld() {
        return hasAttemptedJoinTestWorld;
    }

    /**
     * Mark that the client has attempted to join the test world.
     */
    public static void markJoinTestWorldAttempted() {
        hasAttemptedJoinTestWorld = true;
    }

    // ==========================================================================
    // Container Screen Event Dispatch (native methods)
    // ==========================================================================

    /**
     * Dispatch container screen open event to Dart.
     * Called from FlutterContainerScreen.init().
     *
     * @param menuId The container menu ID
     * @param slotCount The number of slots in the container
     */
    public static native void dispatchContainerScreenOpen(int menuId, int slotCount);

    /**
     * Dispatch container screen close event to Dart.
     * Called from FlutterContainerScreen.removed().
     *
     * @param menuId The container menu ID
     */
    public static native void dispatchContainerScreenClose(int menuId);

    // ==========================================================================
    // Client-side Container Menu Query Methods
    // ==========================================================================

    /**
     * Get a serialized item from the current container menu.
     * Called from native code via JNI.
     *
     * @param slotIndex The slot index in the container menu
     * @return Serialized item stack string, or empty string if not available
     */
    public static String getContainerSlotItem(int slotIndex) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null || mc.player.containerMenu == null) {
            return "";
        }
        var menu = mc.player.containerMenu;
        if (slotIndex < 0 || slotIndex >= menu.slots.size()) {
            return "";
        }
        net.minecraft.world.item.ItemStack stack = menu.slots.get(slotIndex).getItem();
        return com.redstone.util.ItemStackSerializer.serialize(stack);
    }

    /**
     * Get the current container menu's ID.
     * Returns the cached value that is updated on the render thread,
     * making it safe to call from any thread (including Flutter).
     *
     * @return The container ID, or -1 if no container is open
     */
    private static int menuIdCallCount = 0;
    public static int getContainerMenuId() {
        menuIdCallCount++;
        if (menuIdCallCount % 100 == 1) {  // Log every 100th call
            LOGGER.info("[DartBridgeClient] getContainerMenuId (call #{}) returning: {}, classLoader: {}",
                menuIdCallCount, cachedContainerMenuId, DartBridgeClient.class.getClassLoader());
        }
        return cachedContainerMenuId;
    }

    /**
     * Get the number of slots in the current container.
     *
     * @return The slot count, or 0 if no container is open
     */
    public static int getContainerSlotCount() {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null || mc.player.containerMenu == null) {
            return 0;
        }
        return mc.player.containerMenu.slots.size();
    }

    // ==========================================================================
    // Block Entity Container Progress Methods (for furnace-like UIs)
    // ==========================================================================

    /**
     * Get the lit progress (fuel remaining) as a normalized value (0.0-1.0).
     * Only works when the current container is a DartBlockEntityMenu.
     *
     * @return Lit progress 0.0-1.0, or 0.0 if not a block entity menu
     */
    public static float getContainerLitProgress() {
        return cachedLitProgress;
    }

    /**
     * Get the burn/cooking progress as a normalized value (0.0-1.0).
     * Only works when the current container is a DartBlockEntityMenu.
     *
     * @return Burn progress 0.0-1.0, or 0.0 if not a block entity menu
     */
    public static float getContainerBurnProgress() {
        return cachedBurnProgress;
    }

    /**
     * Check if the furnace is currently lit (burning fuel).
     * Only works when the current container is a DartBlockEntityMenu.
     *
     * @return true if lit, false otherwise
     */
    public static boolean isContainerLit() {
        return cachedIsLit;
    }

    /**
     * Update cached container progress values.
     * MUST be called from the render thread (e.g., during screen tick or render).
     * This allows Dart/Flutter to safely read progress values from any thread.
     */
    public static void updateCachedContainerProgress() {
        Minecraft mc = Minecraft.getInstance();
        if (mc != null && mc.player != null) {
            // Update cached menu ID
            int oldMenuId = cachedContainerMenuId;
            if (mc.player.containerMenu != null) {
                cachedContainerMenuId = mc.player.containerMenu.containerId;
            } else {
                cachedContainerMenuId = -1;
            }
            // Log when menu ID changes
            if (oldMenuId != cachedContainerMenuId) {
                LOGGER.info("[DartBridgeClient] cachedContainerMenuId changed: {} -> {}, classLoader: {}",
                    oldMenuId, cachedContainerMenuId, DartBridgeClient.class.getClassLoader());
            }

            // Update progress values
            if (mc.player.containerMenu instanceof DartBlockEntityMenu menu) {
                cachedLitProgress = menu.getLitProgress();
                cachedBurnProgress = menu.getBurnProgress();
                cachedIsLit = menu.isLit();
            } else {
                cachedLitProgress = 0.0f;
                cachedBurnProgress = 0.0f;
                cachedIsLit = false;
            }
        } else {
            cachedContainerMenuId = -1;
            cachedLitProgress = 0.0f;
            cachedBurnProgress = 0.0f;
            cachedIsLit = false;
        }
    }

}
