package com.redstone.blockentity;

import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.inventory.AbstractContainerScreen;
import net.minecraft.client.renderer.RenderPipelines;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.player.Inventory;

/**
 * Client-side screen for DartBlockEntityMenu.
 *
 * Renders a furnace-like GUI with:
 * - Input slot (top)
 * - Fuel slot (bottom left)
 * - Output slot (right)
 * - Burning flame progress indicator
 * - Cooking arrow progress indicator
 *
 * Progress values are automatically synced from the server via ContainerData.
 */
@Environment(EnvType.CLIENT)
public class DartBlockEntityScreen extends AbstractContainerScreen<DartBlockEntityMenu> {
    /** Background texture (uses vanilla furnace texture). */
    private static final Identifier TEXTURE = Identifier.withDefaultNamespace("textures/gui/container/furnace.png");

    /** Flame sprite for burning indicator. */
    private static final Identifier LIT_PROGRESS_SPRITE = Identifier.withDefaultNamespace("container/furnace/lit_progress");

    /** Arrow sprite for cooking progress. */
    private static final Identifier BURN_PROGRESS_SPRITE = Identifier.withDefaultNamespace("container/furnace/burn_progress");

    public DartBlockEntityScreen(DartBlockEntityMenu menu, Inventory playerInventory, Component title) {
        super(menu, playerInventory, title);
    }

    @Override
    protected void init() {
        super.init();
        // Center the title
        this.titleLabelX = (this.imageWidth - this.font.width(this.title)) / 2;
    }

    @Override
    protected void renderBg(GuiGraphics guiGraphics, float partialTick, int mouseX, int mouseY) {
        int x = this.leftPos;
        int y = this.topPos;

        // Draw the background texture
        guiGraphics.blit(RenderPipelines.GUI_TEXTURED, TEXTURE, x, y, 0.0F, 0.0F, this.imageWidth, this.imageHeight, 256, 256);

        // Draw the burning flame indicator
        if (this.menu.isLit()) {
            int flameHeight = 14;
            // getLitProgress returns 0.0-1.0, we need to draw from bottom to top
            int litProgress = Mth.ceil(this.menu.getLitProgress() * 13.0F) + 1;
            guiGraphics.blitSprite(
                    RenderPipelines.GUI_TEXTURED,
                    LIT_PROGRESS_SPRITE,
                    14, 14,                          // sprite total size
                    0, 14 - litProgress,             // source x, y (offset from top)
                    x + 56, y + 36 + 14 - litProgress, // dest x, y
                    14, litProgress                  // width, height to draw
            );
        }

        // Draw the cooking progress arrow
        int arrowWidth = 24;
        // getBurnProgress returns 0.0-1.0, we draw from left to right
        int cookProgress = Mth.ceil(this.menu.getBurnProgress() * 24.0F);
        guiGraphics.blitSprite(
                RenderPipelines.GUI_TEXTURED,
                BURN_PROGRESS_SPRITE,
                24, 16,                // sprite total size
                0, 0,                  // source x, y
                x + 79, y + 34,        // dest x, y
                cookProgress, 16       // width, height to draw
        );
    }

    @Override
    public void render(GuiGraphics guiGraphics, int mouseX, int mouseY, float partialTick) {
        super.render(guiGraphics, mouseX, mouseY, partialTick);
        this.renderTooltip(guiGraphics, mouseX, mouseY);
    }
}
