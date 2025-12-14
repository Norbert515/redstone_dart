package com.example.dartbridge;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.inventory.AbstractContainerScreen;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.player.Inventory;

import java.util.HashMap;
import java.util.Map;

/**
 * A container screen that delegates rendering to Dart.
 *
 * This screen allows Dart code to render custom backgrounds for inventory GUIs
 * while letting Minecraft handle the actual slot rendering and item synchronization.
 */
public class DartContainerScreen extends AbstractContainerScreen<DartContainerMenu> {
    private static final Map<Long, DartContainerScreen> screens = new HashMap<>();
    private final long screenId;

    public DartContainerScreen(DartContainerMenu menu, Inventory playerInventory, Component title) {
        super(menu, playerInventory, title);
        this.screenId = menu.getMenuId();
        screens.put(screenId, this);

        // Default size - can be changed from Dart
        this.imageWidth = 176;
        this.imageHeight = 166;
    }

    /**
     * Get this screen's unique ID for Dart callbacks.
     */
    public long getScreenId() {
        return screenId;
    }

    /**
     * Look up a screen by ID.
     */
    public static DartContainerScreen getById(long id) {
        return screens.get(id);
    }

    /**
     * Set the size of this screen.
     * @param width The image width (GUI panel width)
     * @param height The image height (GUI panel height)
     */
    public void setSize(int width, int height) {
        this.imageWidth = width;
        this.imageHeight = height;
    }

    @Override
    protected void init() {
        super.init();
        // Dispatch to Dart with all the positioning info needed
        DartBridge.dispatchContainerScreenInit(
            screenId, width, height, leftPos, topPos, imageWidth, imageHeight
        );
    }

    @Override
    protected void renderBg(GuiGraphics graphics, float partialTick, int mouseX, int mouseY) {
        // Let Dart render the background
        DartBridgeClient.setCurrentGuiGraphics(screenId, graphics);
        DartBridge.dispatchContainerScreenRenderBg(screenId, mouseX, mouseY, partialTick, leftPos, topPos);
        DartBridgeClient.clearCurrentGuiGraphics(screenId);
    }

    @Override
    public void render(GuiGraphics graphics, int mouseX, int mouseY, float partialTick) {
        // Render background (calls renderBg which delegates to Dart)
        super.render(graphics, mouseX, mouseY, partialTick);
        // Render tooltips
        this.renderTooltip(graphics, mouseX, mouseY);
    }

    @Override
    protected void renderLabels(GuiGraphics graphics, int mouseX, int mouseY) {
        // Don't render default labels - Dart handles all text rendering
        // The default implementation draws title and player inventory label
    }

    @Override
    public void removed() {
        super.removed();
        screens.remove(screenId);
        DartBridge.dispatchContainerScreenClose(screenId);
    }
}
