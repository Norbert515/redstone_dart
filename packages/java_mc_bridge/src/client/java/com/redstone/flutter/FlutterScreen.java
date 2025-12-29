package com.redstone.flutter;

import com.mojang.blaze3d.platform.NativeImage;
import com.redstone.DartBridgeClient;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.input.MouseButtonEvent;
import net.minecraft.client.renderer.RenderPipelines;
import net.minecraft.client.renderer.texture.DynamicTexture;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import org.lwjgl.system.MemoryUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.ByteBuffer;

/**
 * A Minecraft Screen that displays Flutter-rendered content.
 * Flutter renders to a pixel buffer which is uploaded to a dynamic texture.
 */
@Environment(EnvType.CLIENT)
public class FlutterScreen extends Screen {
    private static final Logger LOGGER = LoggerFactory.getLogger("FlutterScreen");

    // Unique identifier for the Flutter texture
    private static final Identifier FLUTTER_TEXTURE_ID = Identifier.fromNamespaceAndPath("redstone", "flutter_screen");

    private DynamicTexture dynamicTexture = null;
    private NativeImage nativeImage = null;
    private int textureWidth = 0;
    private int textureHeight = 0;
    private boolean flutterInitialized = false;

    // Flutter pointer phases (must match FlutterPointerPhase enum)
    private static final int PHASE_CANCEL = 0;
    private static final int PHASE_UP = 1;
    private static final int PHASE_DOWN = 2;
    private static final int PHASE_MOVE = 3;
    private static final int PHASE_ADD = 4;
    private static final int PHASE_REMOVE = 5;
    private static final int PHASE_HOVER = 6;

    // Mouse button masks
    private static final long BUTTON_PRIMARY = 1;
    private static final long BUTTON_SECONDARY = 2;
    private static final long BUTTON_MIDDLE = 4;

    private long currentButtons = 0;
    private boolean pointerAdded = false;

    public FlutterScreen(Component title) {
        super(title);
    }

    /**
     * Returns true to use the in-game UI background style (dark gradient overlay).
     * This gives the same look as inventory/crafting screens.
     */
    @Override
    public boolean isInGameUi() {
        return true;
    }

    /**
     * Returns false so the game continues running while the screen is open.
     */
    @Override
    public boolean isPauseScreen() {
        return false;
    }

    @Override
    protected void init() {
        super.init();

        // Initialize Flutter if not already
        if (!flutterInitialized && !DartBridgeClient.isFlutterInitialized()) {
            String assetsPath = getFlutterAssetsPath();
            String icuPath = getFlutterIcuPath();

            if (assetsPath != null && icuPath != null) {
                flutterInitialized = DartBridgeClient.initFlutter(assetsPath, icuPath);
                if (flutterInitialized) {
                    LOGGER.info("Flutter initialized successfully");
                } else {
                    LOGGER.error("Failed to initialize Flutter");
                }
            } else {
                LOGGER.warn("Flutter assets or ICU path not provided");
            }
        } else {
            flutterInitialized = DartBridgeClient.isFlutterInitialized();
        }

        // Notify Flutter of screen size with pixel ratio for sharp rendering
        if (flutterInitialized) {
            // Flutter needs to render at framebuffer resolution
            // this.width/height are GUI coordinates, multiply by guiScale for framebuffer pixels
            var window = this.minecraft.getWindow();
            int guiScale = window.getGuiScale();
            DartBridgeClient.resizeFlutter(this.width, this.height, (double) guiScale);
        }
    }

    /**
     * Override this to provide the path to Flutter assets.
     */
    protected String getFlutterAssetsPath() {
        return null; // Subclasses should override
    }

    /**
     * Override this to provide the path to ICU data.
     */
    protected String getFlutterIcuPath() {
        return null; // Subclasses should override
    }

    @Override
    public void render(GuiGraphics guiGraphics, int mouseX, int mouseY, float partialTick) {
        // Call super.render() first - this renders the Minecraft background
        // (dark gradient overlay because isInGameUi() returns true)
        super.render(guiGraphics, mouseX, mouseY, partialTick);

        if (!flutterInitialized) {
            // Draw placeholder text if Flutter not initialized
            guiGraphics.drawCenteredString(
                this.font,
                "Flutter not initialized",
                this.width / 2,
                this.height / 2,
                0xFFFFFF
            );
            return;
        }

        // Check if Flutter has a new frame
        if (DartBridgeClient.flutterHasNewFrame()) {
            updateTexture();
        }

        // Render the Flutter texture with alpha blending
        if (dynamicTexture != null && textureWidth > 0 && textureHeight > 0) {
            renderFlutterTexture(guiGraphics);
        } else {
            // Flutter is initialized but no frame yet
            guiGraphics.drawCenteredString(
                this.font,
                "Waiting for Flutter frame...",
                this.width / 2,
                this.height / 2,
                0xFFFFFF
            );
        }
    }

    private void updateTexture() {
        ByteBuffer pixels = DartBridgeClient.getFlutterPixels();
        if (pixels == null) return;

        int newWidth = DartBridgeClient.getFlutterWidth();
        int newHeight = DartBridgeClient.getFlutterHeight();

        if (newWidth <= 0 || newHeight <= 0) return;

        // Check if we need to recreate the texture (size changed)
        if (newWidth != textureWidth || newHeight != textureHeight) {
            cleanupTexture();
            createTexture(newWidth, newHeight);
        }

        if (nativeImage == null) return;

        // Copy pixel data from Flutter buffer to NativeImage
        // Flutter uses RGBA format, which matches NativeImage.Format.RGBA
        long srcAddress = MemoryUtil.memAddress(pixels);
        long dstAddress = nativeImage.getPointer();
        long size = (long) newWidth * newHeight * 4; // 4 bytes per pixel (RGBA)
        MemoryUtil.memCopy(srcAddress, dstAddress, size);

        // Upload to GPU
        dynamicTexture.upload();
    }

    private void createTexture(int width, int height) {
        textureWidth = width;
        textureHeight = height;

        // Create NativeImage with RGBA format
        nativeImage = new NativeImage(width, height, false);

        // Create DynamicTexture from the NativeImage
        dynamicTexture = new DynamicTexture(() -> "flutter_screen", nativeImage);

        // Register the texture with Minecraft's texture manager
        this.minecraft.getTextureManager().register(FLUTTER_TEXTURE_ID, dynamicTexture);

        LOGGER.debug("Created Flutter texture: {}x{}", width, height);
    }

    private void cleanupTexture() {
        if (dynamicTexture != null) {
            // Unregister from texture manager
            this.minecraft.getTextureManager().release(FLUTTER_TEXTURE_ID);
            dynamicTexture = null;
        }
        // Note: DynamicTexture.close() also closes the NativeImage
        nativeImage = null;
        textureWidth = 0;
        textureHeight = 0;
    }

    private void renderFlutterTexture(GuiGraphics guiGraphics) {
        // Draw the Flutter texture at 1:1 pixel ratio for sharp rendering
        // Flutter renders at pixel_ratio * screen_size, so we need to render at framebuffer resolution
        var window = this.minecraft.getWindow();
        int guiScale = window.getGuiScale();

        // Save the current pose and apply inverse GUI scale to render at framebuffer pixels
        guiGraphics.pose().pushMatrix();
        guiGraphics.pose().scale(1.0f / guiScale, 1.0f / guiScale);

        // Now coordinates are in framebuffer pixels - blit the texture at 1:1
        guiGraphics.blit(
            RenderPipelines.GUI_TEXTURED,
            FLUTTER_TEXTURE_ID,
            0, 0,                           // dest x, y (framebuffer pixels)
            0.0f, 0.0f,                     // src UV offset
            textureWidth, textureHeight,    // dest size (full texture size = framebuffer size)
            textureWidth, textureHeight,    // src region size
            textureWidth, textureHeight     // texture size
        );

        guiGraphics.pose().popMatrix();
    }

    @Override
    public void resize(int width, int height) {
        super.resize(width, height);
        if (flutterInitialized) {
            // Flutter needs to render at framebuffer resolution
            var window = this.minecraft.getWindow();
            int guiScale = window.getGuiScale();
            DartBridgeClient.resizeFlutter(width, height, (double) guiScale);
        }
    }

    @Override
    public boolean mouseClicked(MouseButtonEvent event, boolean bl) {
        LOGGER.info("[FlutterScreen] mouseClicked: x={}, y={}, button={}, flutterInitialized={}", event.x(), event.y(), event.button(), flutterInitialized);
        if (flutterInitialized) {
            double mouseX = event.x();
            double mouseY = event.y();
            int button = event.button();

            currentButtons |= getButtonMask(button);

            if (!pointerAdded) {
                DartBridgeClient.sendFlutterPointerEvent(PHASE_ADD, mouseX, mouseY, 0);
                pointerAdded = true;
            }

            DartBridgeClient.sendFlutterPointerEvent(PHASE_DOWN, mouseX, mouseY, currentButtons);
            return true; // Consume the event - Flutter handled it
        }
        return super.mouseClicked(event, bl);
    }

    @Override
    public boolean mouseReleased(MouseButtonEvent event) {
        LOGGER.info("[FlutterScreen] mouseReleased: x={}, y={}, button={}", event.x(), event.y(), event.button());
        if (flutterInitialized) {
            double mouseX = event.x();
            double mouseY = event.y();
            int button = event.button();

            currentButtons &= ~getButtonMask(button);
            DartBridgeClient.sendFlutterPointerEvent(PHASE_UP, mouseX, mouseY, currentButtons);
            return true; // Consume the event - Flutter handled it
        }
        return super.mouseReleased(event);
    }

    @Override
    public void mouseMoved(double mouseX, double mouseY) {
        if (flutterInitialized) {
            if (!pointerAdded) {
                LOGGER.info("[FlutterScreen] Pointer ADD: x={}, y={}", mouseX, mouseY);
                DartBridgeClient.sendFlutterPointerEvent(PHASE_ADD, mouseX, mouseY, 0);
                pointerAdded = true;
                // Don't send HOVER on the same frame as ADD - let Flutter process ADD first
                super.mouseMoved(mouseX, mouseY);
                return;
            }

            if (currentButtons != 0) {
                DartBridgeClient.sendFlutterPointerEvent(PHASE_MOVE, mouseX, mouseY, currentButtons);
            } else {
                DartBridgeClient.sendFlutterPointerEvent(PHASE_HOVER, mouseX, mouseY, 0);
            }
        }
        super.mouseMoved(mouseX, mouseY);
    }

    @Override
    public boolean mouseDragged(MouseButtonEvent event, double dragX, double dragY) {
        if (flutterInitialized) {
            DartBridgeClient.sendFlutterPointerEvent(PHASE_MOVE, event.x(), event.y(), currentButtons);
            return true; // Consume the event - Flutter handled it
        }
        return super.mouseDragged(event, dragX, dragY);
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double horizontalAmount, double verticalAmount) {
        if (flutterInitialized) {
            // Convert to Flutter scroll units (typically pixels)
            // The multiplier may need adjustment based on Flutter's expectations
            DartBridgeClient.sendFlutterScrollEvent(mouseX, mouseY, horizontalAmount * 100, -verticalAmount * 100);
            return true; // Consume the event - Flutter handled it
        }
        return super.mouseScrolled(mouseX, mouseY, horizontalAmount, verticalAmount);
    }

    private long getButtonMask(int button) {
        return switch (button) {
            case 0 -> BUTTON_PRIMARY;
            case 1 -> BUTTON_SECONDARY;
            case 2 -> BUTTON_MIDDLE;
            default -> 0;
        };
    }

    @Override
    public void removed() {
        super.removed();

        // Send pointer remove event
        if (flutterInitialized && pointerAdded) {
            DartBridgeClient.sendFlutterPointerEvent(PHASE_REMOVE, 0, 0, 0);
            pointerAdded = false;
        }

        // Clean up texture
        cleanupTexture();
    }

    @Override
    public void onClose() {
        super.onClose();
        // Note: We don't shutdown Flutter here as other screens might use it
    }

    /**
     * Call this to explicitly shutdown Flutter when it's no longer needed.
     * This should typically be called when the game is closing or when
     * Flutter functionality is completely done.
     */
    public static void shutdownFlutter() {
        if (DartBridgeClient.isFlutterInitialized()) {
            DartBridgeClient.shutdownFlutter();
            LOGGER.info("Flutter shutdown complete");
        }
    }
}
