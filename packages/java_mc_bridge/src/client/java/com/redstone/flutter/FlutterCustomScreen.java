package com.redstone.flutter;

import com.redstone.DartBridgeClient;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.input.KeyEvent;
import net.minecraft.client.input.MouseButtonEvent;
import net.minecraft.network.chat.Component;
import org.lwjgl.glfw.GLFW;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * A Minecraft screen that renders Flutter content.
 * Used for custom (non-container) screens.
 *
 * This extends FlutterScreen to inherit all Flutter rendering and input handling.
 * The main additions are:
 * - Screen ID and type tracking for Dart communication
 * - Custom close behavior that notifies DartBridgeClient
 */
@Environment(EnvType.CLIENT)
public class FlutterCustomScreen extends FlutterScreen {
    private static final Logger LOGGER = LoggerFactory.getLogger("FlutterCustomScreen");

    private final int screenId;
    private final String screenType;

    public FlutterCustomScreen(int screenId, String screenType) {
        super(Component.literal(screenType));
        this.screenId = screenId;
        this.screenType = screenType;
        LOGGER.info("[FlutterCustomScreen] Created with id={}, type={}", screenId, screenType);
    }

    @Override
    protected void init() {
        super.init();

        // Send window metrics on init
        int guiScale = (int) minecraft.getWindow().getGuiScale();
        DartBridgeClient.sendWindowMetrics(
            width * guiScale,
            height * guiScale,
            (double) guiScale
        );

        LOGGER.info("[FlutterCustomScreen] Initialized: {}x{} @{}x scale", width, height, guiScale);
    }

    @Override
    public void render(GuiGraphics guiGraphics, int mouseX, int mouseY, float partialTick) {
        // Process Flutter tasks every frame
        DartBridgeClient.safeProcessClientTasks();

        // Render Flutter content via parent class
        super.render(guiGraphics, mouseX, mouseY, partialTick);
    }

    @Override
    public boolean keyPressed(KeyEvent keyEvent) {
        // Forward to Flutter via parent class first
        boolean handled = super.keyPressed(keyEvent);

        // Also send to DartBridgeClient for explicit key event handling
        DartBridgeClient.sendKeyEvent(0, keyEvent.key(), keyEvent.key(), null, keyEvent.modifiers());

        // Allow ESC to close
        if (keyEvent.key() == GLFW.GLFW_KEY_ESCAPE) {
            onClose();
            return true;
        }

        return handled;
    }

    @Override
    public boolean mouseClicked(MouseButtonEvent event, boolean bl) {
        // Forward to Flutter via parent class
        return super.mouseClicked(event, bl);
    }

    @Override
    public boolean mouseReleased(MouseButtonEvent event) {
        // Forward to Flutter via parent class
        return super.mouseReleased(event);
    }

    @Override
    public boolean mouseDragged(MouseButtonEvent event, double dragX, double dragY) {
        // Forward to Flutter via parent class
        return super.mouseDragged(event, dragX, dragY);
    }

    @Override
    public void onClose() {
        LOGGER.info("[FlutterCustomScreen] onClose called for screen id={}, type={}", screenId, screenType);

        // Notify DartBridgeClient that this screen is closing
        // This will dispatch the close event to Dart
        DartBridgeClient.closeCustomScreen();

        // Call parent to clean up Flutter resources
        super.onClose();
    }

    @Override
    public void removed() {
        LOGGER.info("[FlutterCustomScreen] Removed: id={}, type={}", screenId, screenType);
        super.removed();
    }

    /**
     * Get the screen ID.
     * @return The unique screen instance ID
     */
    public int getScreenId() {
        return screenId;
    }

    /**
     * Get the screen type.
     * @return The screen type identifier
     */
    public String getScreenType() {
        return screenType;
    }
}
