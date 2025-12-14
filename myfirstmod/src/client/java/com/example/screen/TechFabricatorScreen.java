package com.example.screen;

import com.example.block.menu.TechFabricatorMenu;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.inventory.AbstractContainerScreen;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.player.Inventory;

/**
 * Screen (GUI) for the Tech Fabricator.
 * Renders the custom GUI texture and handles display.
 */
public class TechFabricatorScreen extends AbstractContainerScreen<TechFabricatorMenu> {

    // Use vanilla dispenser texture as placeholder (has 3x3 grid layout)
    private static final Identifier TEXTURE = Identifier.withDefaultNamespace("textures/gui/container/dispenser.png");

    public TechFabricatorScreen(TechFabricatorMenu menu, Inventory playerInventory, Component title) {
        super(menu, playerInventory, title);
        this.imageWidth = 176;
        this.imageHeight = 166;
    }

    @Override
    protected void init() {
        super.init();
        this.titleLabelX = (this.imageWidth - this.font.width(this.title)) / 2;
    }

    @Override
    protected void renderBg(GuiGraphics graphics, float partialTick, int mouseX, int mouseY) {
        int x = (this.width - this.imageWidth) / 2;
        int y = (this.height - this.imageHeight) / 2;

        // Use the blit signature: blit(Identifier, x, y, width, height, u, v, uWidth, vHeight)
        // where u, v, uWidth, vHeight are floats for UV coordinates
        graphics.blit(TEXTURE, x, y, this.imageWidth, this.imageHeight, 0.0f, 0.0f, 176.0f/256.0f, 166.0f/256.0f);
    }

    @Override
    public void render(GuiGraphics graphics, int mouseX, int mouseY, float partialTick) {
        this.renderBackground(graphics, mouseX, mouseY, partialTick);
        super.render(graphics, mouseX, mouseY, partialTick);
        this.renderTooltip(graphics, mouseX, mouseY);
    }
}
