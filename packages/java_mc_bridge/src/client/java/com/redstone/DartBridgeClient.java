package com.redstone;

import com.mojang.blaze3d.pipeline.RenderTarget;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.Minecraft;
import net.minecraft.client.Screenshot;
import net.minecraft.network.chat.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Client-side bridge for Dart test framework.
 *
 * Provides methods for visual testing such as taking screenshots
 * and positioning the camera. All methods are client-only and must
 * be called from the render thread.
 */
@Environment(EnvType.CLIENT)
public class DartBridgeClient {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBridgeClient");

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

    // ============================================================
    // Flutter Bridge Native Methods
    // ============================================================

    /**
     * Set the path to the Flutter renderer executable (subprocess).
     * This must be called before initFlutter.
     *
     * @param rendererPath Path to the flutter_renderer executable
     */
    public static native void setFlutterRendererPath(String rendererPath);

    /**
     * Initialize the Flutter engine with the given asset and ICU data paths.
     *
     * @param assetsPath Path to the Flutter assets directory
     * @param icuPath Path to the ICU data file
     * @return true if initialization succeeded, false otherwise
     */
    public static native boolean initFlutter(String assetsPath, String icuPath);

    /**
     * Shutdown the Flutter engine and release resources.
     */
    public static native void shutdownFlutter();

    /**
     * Notify Flutter of a window resize with pixel ratio for HiDPI support.
     *
     * @param width New width in pixels
     * @param height New height in pixels
     * @param pixelRatio The pixel ratio (e.g., 2.0 for Retina displays)
     */
    public static native void resizeFlutter(int width, int height, double pixelRatio);

    /**
     * Check if Flutter has rendered a new frame since the last call.
     *
     * @return true if a new frame is available
     */
    public static native boolean flutterHasNewFrame();

    /**
     * Get the Flutter pixel buffer (RGBA format).
     *
     * @return Direct ByteBuffer containing RGBA pixel data, or null if not available
     */
    public static native java.nio.ByteBuffer getFlutterPixels();

    /**
     * Get the width of the Flutter render surface.
     *
     * @return Width in pixels
     */
    public static native int getFlutterWidth();

    /**
     * Get the height of the Flutter render surface.
     *
     * @return Height in pixels
     */
    public static native int getFlutterHeight();

    /**
     * Send a pointer (mouse) event to Flutter.
     *
     * @param phase Pointer phase (0=down, 1=move, 2=add, 3=remove, 4=hover, 5=up)
     * @param x X coordinate in pixels
     * @param y Y coordinate in pixels
     * @param buttons Button mask (1=primary, 2=secondary, 4=middle)
     */
    public static native void sendFlutterPointerEvent(int phase, double x, double y, long buttons);

    /**
     * Send a scroll event to Flutter.
     *
     * @param x X coordinate of the scroll
     * @param y Y coordinate of the scroll
     * @param scrollX Horizontal scroll amount
     * @param scrollY Vertical scroll amount
     */
    public static native void sendFlutterScrollEvent(double x, double y, double scrollX, double scrollY);

    /**
     * Check if Flutter has been initialized.
     *
     * @return true if Flutter is initialized and ready
     */
    public static native boolean isFlutterInitialized();
}
