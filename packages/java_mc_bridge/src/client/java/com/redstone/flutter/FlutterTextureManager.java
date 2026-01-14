package com.redstone.flutter;

import com.mojang.blaze3d.platform.NativeImage;
import com.redstone.DartBridgeClient;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.texture.DynamicTexture;
import net.minecraft.client.renderer.texture.TextureManager;
import net.minecraft.resources.Identifier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Manages textures for Flutter surfaces that can be used in the 3D world.
 *
 * This manager wraps Flutter's rendered frames as Minecraft textures that can be
 * bound and rendered on block faces, entities, or other 3D geometry.
 *
 * Supports:
 * - surfaceId=0: The main Flutter surface (FlutterScreen)
 * - surfaceId>0: Additional surfaces created via createSurface() (multi-surface API)
 *
 * Multi-surface support (surfaceId > 0) uses the native multi-surface renderer
 * which manages independent Flutter engine instances with IOSurface-backed textures.
 */
@Environment(EnvType.CLIENT)
public class FlutterTextureManager implements AutoCloseable {
    private static final Logger LOGGER = LoggerFactory.getLogger("FlutterTextureManager");

    private static FlutterTextureManager instance;

    private final TextureManager textureManager;
    private final Map<Long, FlutterSurfaceTexture> surfaces = new ConcurrentHashMap<>();

    // Track if multi-surface system is initialized
    private static boolean multiSurfaceInitialized = false;

    private FlutterTextureManager(TextureManager textureManager) {
        this.textureManager = textureManager;
    }

    /**
     * Get the singleton instance.
     */
    public static FlutterTextureManager getInstance() {
        if (instance == null) {
            Minecraft mc = Minecraft.getInstance();
            if (mc != null && mc.getTextureManager() != null) {
                instance = new FlutterTextureManager(mc.getTextureManager());
            }
        }
        return instance;
    }

    /**
     * Initialize the multi-surface system.
     * Should be called after the main Flutter client is initialized.
     *
     * @return true if initialization succeeded
     */
    public static boolean initMultiSurface() {
        LOGGER.info("initMultiSurface() called, current state: {}", multiSurfaceInitialized);
        if (multiSurfaceInitialized) {
            return true;
        }
        try {
            LOGGER.info("Calling DartBridgeClient.multiSurfaceInit()...");
            multiSurfaceInitialized = DartBridgeClient.multiSurfaceInit();
            if (multiSurfaceInitialized) {
                LOGGER.info("Multi-surface system initialized successfully!");
            } else {
                LOGGER.warn("Failed to initialize multi-surface system (native returned false)");
            }
            return multiSurfaceInitialized;
        } catch (UnsatisfiedLinkError e) {
            LOGGER.warn("Multi-surface API not available (native methods not found)", e);
            return false;
        }
    }

    /**
     * Shutdown the multi-surface system.
     */
    public static void shutdownMultiSurface() {
        if (!multiSurfaceInitialized) {
            return;
        }
        try {
            DartBridgeClient.multiSurfaceShutdown();
            multiSurfaceInitialized = false;
            LOGGER.info("Multi-surface system shutdown");
        } catch (UnsatisfiedLinkError e) {
            LOGGER.warn("Multi-surface API not available during shutdown");
        }
    }

    /**
     * Create a new Flutter surface with the specified dimensions.
     *
     * @param width        Surface width in pixels
     * @param height       Surface height in pixels
     * @param initialRoute Optional initial route (can be null)
     * @return Surface ID (> 0) on success, 0 on failure
     */
    public long createSurface(int width, int height, String initialRoute) {
        if (!multiSurfaceInitialized && !initMultiSurface()) {
            LOGGER.warn("Cannot create surface: multi-surface system not initialized");
            return 0;
        }

        try {
            long surfaceId = DartBridgeClient.createSurface(width, height, initialRoute);
            if (surfaceId > 0) {
                LOGGER.info("Created Flutter surface {} ({}x{})", surfaceId, width, height);
            }
            return surfaceId;
        } catch (UnsatisfiedLinkError e) {
            LOGGER.error("Multi-surface API not available", e);
            return 0;
        }
    }

    /**
     * Destroy a Flutter surface and release all resources.
     *
     * @param surfaceId The surface ID
     */
    public void destroySurface(long surfaceId) {
        // Remove from our texture map
        FlutterSurfaceTexture texture = surfaces.remove(surfaceId);
        if (texture != null) {
            texture.close();
        }

        // Destroy native surface
        if (surfaceId > 0) {
            try {
                DartBridgeClient.destroySurface(surfaceId);
                LOGGER.info("Destroyed Flutter surface {}", surfaceId);
            } catch (UnsatisfiedLinkError e) {
                LOGGER.warn("Multi-surface API not available during destroy");
            }
        }
    }

    /**
     * Get the texture location (ResourceLocation) for a Flutter surface.
     * The texture will be updated automatically from Flutter's rendered output.
     *
     * @param surfaceId The Flutter surface ID (0 for main surface)
     * @return The Identifier for binding the texture, or null if not available
     */
    public Identifier getTextureLocation(long surfaceId) {
        FlutterSurfaceTexture surface = getOrCreateSurface(surfaceId);
        if (surface != null) {
            surface.updateFromFlutter();
            return surface.location;
        }
        return null;
    }

    /**
     * Check if a surface has valid texture data.
     */
    public boolean hasValidTexture(long surfaceId) {
        FlutterSurfaceTexture surface = surfaces.get(surfaceId);
        return surface != null && surface.hasValidData;
    }

    /**
     * Get the width of a Flutter surface texture.
     */
    public int getTextureWidth(long surfaceId) {
        FlutterSurfaceTexture surface = surfaces.get(surfaceId);
        return surface != null ? surface.width : 0;
    }

    /**
     * Get the height of a Flutter surface texture.
     */
    public int getTextureHeight(long surfaceId) {
        FlutterSurfaceTexture surface = surfaces.get(surfaceId);
        return surface != null ? surface.height : 0;
    }

    /**
     * Force an update of a surface texture from Flutter.
     */
    public void forceUpdate(long surfaceId) {
        FlutterSurfaceTexture surface = surfaces.get(surfaceId);
        if (surface != null) {
            surface.forceUpdate = true;
            surface.updateFromFlutter();
        }
    }

    private FlutterSurfaceTexture getOrCreateSurface(long surfaceId) {
        return surfaces.computeIfAbsent(surfaceId, id -> {
            // surfaceId 0 = main Flutter surface
            // surfaceId > 0 = multi-surface surfaces (must be created via createSurface())
            if (id > 0 && !multiSurfaceInitialized) {
                LOGGER.warn("Multi-surface system not initialized for surface {}", id);
                return null;
            }
            FlutterSurfaceTexture surface = new FlutterSurfaceTexture(id);
            // Force initial update to populate the texture
            surface.forceUpdate = true;
            return surface;
        });
    }

    @Override
    public void close() {
        // Destroy all multi-surface surfaces first
        for (Long surfaceId : surfaces.keySet()) {
            if (surfaceId > 0) {
                try {
                    DartBridgeClient.destroySurface(surfaceId);
                } catch (UnsatisfiedLinkError e) {
                    // Ignore - native library may already be unloaded
                }
            }
        }

        // Close all texture wrappers
        for (FlutterSurfaceTexture surface : surfaces.values()) {
            if (surface != null) {
                surface.close();
            }
        }
        surfaces.clear();

        // Shutdown multi-surface system
        shutdownMultiSurface();

        instance = null;
    }

    /**
     * Represents a single Flutter surface as a Minecraft texture.
     */
    @Environment(EnvType.CLIENT)
    private class FlutterSurfaceTexture implements AutoCloseable {
        final long surfaceId;
        final Identifier location;
        DynamicTexture texture;
        int width;
        int height;
        boolean hasValidData = false;
        boolean forceUpdate = false;

        FlutterSurfaceTexture(long surfaceId) {
            this.surfaceId = surfaceId;
            // Use textures/ prefix to match Minecraft's texture lookup expectations
            this.location = Identifier.fromNamespaceAndPath("redstone", "textures/flutter/surface_" + surfaceId + ".png");
            LOGGER.info("Created FlutterSurfaceTexture for surface {} at {}", surfaceId, location);
        }

        void updateFromFlutter() {
            if (!DartBridgeClient.isClientInitialized()) {
                return;
            }

            // Different paths for main surface (0) vs multi-surface (>0)
            if (surfaceId == 0) {
                updateFromMainSurface();
            } else {
                updateFromMultiSurface();
            }
        }

        /**
         * Update from the main Flutter surface (surfaceId = 0).
         *
         * Note: We always try to get pixels when forceUpdate is true, because
         * hasNewFrame() is consumed by FlutterScreen and we may miss the flag.
         * The pixel data is still valid even after the frame flag is cleared.
         */
        private void updateFromMainSurface() {
            // For force updates, skip the hasNewFrame check since it may have been
            // consumed by FlutterScreen. The pixels are still valid.
            boolean shouldUpdate = forceUpdate;

            // If not forcing, check for new frame
            if (!shouldUpdate) {
                // Note: hasNewFrame() consumes the flag, so we may miss frames
                // that FlutterScreen already processed. For entity rendering,
                // we rely on forceUpdate for initial population.
                shouldUpdate = DartBridgeClient.hasNewFrame();
            }

            if (!shouldUpdate) {
                return;
            }

            LOGGER.info("updateFromMainSurface: attempting to get frame data (forceUpdate was {})", forceUpdate);
            forceUpdate = false;

            int frameWidth = DartBridgeClient.getFrameWidth();
            int frameHeight = DartBridgeClient.getFrameHeight();

            LOGGER.info("updateFromMainSurface: frame dimensions = {}x{}", frameWidth, frameHeight);

            if (frameWidth <= 0 || frameHeight <= 0) {
                LOGGER.warn("Invalid frame dimensions: {}x{} - Flutter may not be rendering", frameWidth, frameHeight);
                return;
            }

            ByteBuffer pixels = DartBridgeClient.getFramePixels();
            if (pixels == null) {
                LOGGER.warn("No pixel data available from Flutter (null buffer)");
                return;
            }
            if (!pixels.hasRemaining()) {
                LOGGER.warn("No pixel data available from Flutter (empty buffer)");
                return;
            }

            LOGGER.info("updateFromMainSurface: got {}x{} frame with {} bytes, updating texture",
                frameWidth, frameHeight, pixels.remaining());
            updateTextureFromPixels(pixels, frameWidth, frameHeight);
        }

        /**
         * Update from a multi-surface Flutter surface (surfaceId > 0).
         */
        private void updateFromMultiSurface() {
            if (!multiSurfaceInitialized) {
                return;
            }

            try {
                // Check if there's a new frame (or force update requested)
                if (!forceUpdate && !DartBridgeClient.surfaceHasNewFrame(surfaceId)) {
                    return;
                }
                forceUpdate = false;

                // Get pixel data from native
                ByteBuffer pixels = DartBridgeClient.getSurfacePixels(surfaceId);
                if (pixels == null || !pixels.hasRemaining()) {
                    return;
                }

                int frameWidth = DartBridgeClient.getSurfacePixelWidth(surfaceId);
                int frameHeight = DartBridgeClient.getSurfacePixelHeight(surfaceId);

                if (frameWidth <= 0 || frameHeight <= 0) {
                    return;
                }

                updateTextureFromPixels(pixels, frameWidth, frameHeight);
            } catch (UnsatisfiedLinkError e) {
                LOGGER.warn("Multi-surface API not available during update");
            }
        }

        /**
         * Update the texture from pixel data.
         */
        private void updateTextureFromPixels(ByteBuffer pixels, int frameWidth, int frameHeight) {
            // Reset buffer position to start
            pixels.rewind();

            // Recreate texture if size changed
            if (texture == null || width != frameWidth || height != frameHeight) {
                if (texture != null) {
                    textureManager.release(location);
                    texture.close();
                }

                texture = new DynamicTexture("FlutterSurface" + surfaceId, frameWidth, frameHeight, true);
                textureManager.register(location, texture);
                width = frameWidth;
                height = frameHeight;
                LOGGER.info("Created Flutter texture {}x{} for surface {}", width, height, surfaceId);
            }

            // Copy pixel data to texture
            NativeImage image = texture.getPixels();
            if (image != null) {
                int pixelCount = width * height;
                int copied = 0;

                // Debug: log first few pixels to determine format
                for (int i = 0; i < pixelCount && pixels.remaining() >= 4; i++) {
                    int x = i % width;
                    int y = i / width;

                    // Read 4 bytes - we need to figure out the format
                    int b0 = pixels.get() & 0xFF;
                    int b1 = pixels.get() & 0xFF;
                    int b2 = pixels.get() & 0xFF;
                    int b3 = pixels.get() & 0xFF;

                    // Debug first 10 pixels
                    if (i < 10) {
                        LOGGER.info("Pixel {} at ({},{}): bytes=[{}, {}, {}, {}]", i, x, y, b0, b1, b2, b3);
                    }

                    // Try BGRA format (common on macOS Metal):
                    // b0=B, b1=G, b2=R, b3=A
                    int b = b0;
                    int g = b1;
                    int r = b2;
                    int a = b3;

                    // Pack as ABGR (Minecraft's internal format)
                    // Use actual alpha value for transparency support
                    int color = (a << 24) | (b << 16) | (g << 8) | r;
                    image.setPixel(x, y, color);
                    copied++;
                }

                LOGGER.info("Copied {} pixels to texture, uploading...", copied);
                texture.upload();
                hasValidData = true;
                LOGGER.info("Texture upload complete for surface {}", surfaceId);
            } else {
                LOGGER.warn("NativeImage is null for texture!");
            }
        }

        @Override
        public void close() {
            if (texture != null) {
                textureManager.release(location);
                texture.close();
                texture = null;
            }
            hasValidData = false;
        }
    }
}
