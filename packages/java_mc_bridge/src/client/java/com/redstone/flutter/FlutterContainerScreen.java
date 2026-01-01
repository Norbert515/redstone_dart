package com.redstone.flutter;

import com.redstone.DartBridgeClient;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.renderer.RenderPipelines;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.ClickType;
import net.minecraft.world.inventory.Slot;
import net.minecraft.world.item.ItemStack;
import net.minecraft.core.component.DataComponents;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.gui.screens.inventory.tooltip.ClientTooltipComponent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * A FlutterScreen that integrates with Minecraft's container/inventory system.
 *
 * Flutter renders the UI (slot backgrounds, etc.), and this screen renders
 * Minecraft items on top at the positions reported by Flutter.
 */
@Environment(EnvType.CLIENT)
public class FlutterContainerScreen<T extends AbstractContainerMenu> extends FlutterScreen {
    private static final Logger LOGGER = LoggerFactory.getLogger("FlutterContainerScreen");

    // Slot highlight sprites (same as vanilla AbstractContainerScreen)
    private static final Identifier SLOT_HIGHLIGHT_BACK_SPRITE = Identifier.withDefaultNamespace("container/slot_highlight_back");
    private static final Identifier SLOT_HIGHLIGHT_FRONT_SPRITE = Identifier.withDefaultNamespace("container/slot_highlight_front");

    protected final T menu;
    private final Map<Integer, SlotRect> slotPositions = new HashMap<>();
    private int hoveredSlotIndex = -1;

    // Slot rectangle in GUI coordinates
    private record SlotRect(int x, int y, int width, int height) {
        boolean contains(double mouseX, double mouseY) {
            return mouseX >= x && mouseX < x + width && mouseY >= y && mouseY < y + height;
        }
    }

    public FlutterContainerScreen(T menu, Component title) {
        super(title);
        this.menu = menu;
    }

    @Override
    protected void init() {
        super.init();

        // Register for slot position updates
        DartBridgeClient.setSlotPositionsHandler((menuId, data) -> {
            // Ensure we're on the render thread
            if (minecraft != null && !minecraft.isSameThread()) {
                minecraft.execute(() -> updateSlotPositions(menuId, data));
            } else {
                updateSlotPositions(menuId, data);
            }
        });

        LOGGER.info("[FlutterContainerScreen] Initialized with menu containerId={}", menu.containerId);
    }

    private void updateSlotPositions(int menuId, int[] data) {
        // Only process if this is our menu
        if (menuId != menu.containerId) return;

        slotPositions.clear();

        // Parse data: [slotIndex, x, y, width, height, ...]
        // Positions are in physical pixels, need to convert to GUI coordinates
        int guiScale = minecraft.getWindow().getGuiScale();

        for (int i = 0; i + 4 < data.length; i += 5) {
            int slotIndex = data[i];
            int x = data[i + 1] / guiScale;
            int y = data[i + 2] / guiScale;
            int width = data[i + 3] / guiScale;
            int height = data[i + 4] / guiScale;

            slotPositions.put(slotIndex, new SlotRect(x, y, width, height));
        }

        LOGGER.debug("[FlutterContainerScreen] Updated {} slot positions", slotPositions.size());
    }

    @Override
    public void render(GuiGraphics guiGraphics, int mouseX, int mouseY, float partialTick) {
        // 1. Render Flutter content (slot backgrounds, UI chrome)
        super.render(guiGraphics, mouseX, mouseY, partialTick);

        // 2. Update hovered slot
        hoveredSlotIndex = findSlotAt(mouseX, mouseY);

        // 3. Render items at slot positions
        renderSlotItems(guiGraphics, mouseX, mouseY);

        // 4. Render carried item following cursor
        renderCarriedItem(guiGraphics, mouseX, mouseY);

        // 5. Render tooltip for hovered slot
        renderSlotTooltip(guiGraphics, mouseX, mouseY);
    }

    private void renderSlotItems(GuiGraphics guiGraphics, int mouseX, int mouseY) {
        for (var entry : slotPositions.entrySet()) {
            int slotIndex = entry.getKey();
            SlotRect rect = entry.getValue();

            // Get the slot from menu
            if (slotIndex >= 0 && slotIndex < menu.slots.size()) {
                Slot slot = menu.slots.get(slotIndex);
                ItemStack item = slot.getItem();

                // Render hover highlight back (before item)
                if (slotIndex == hoveredSlotIndex && slot.isHighlightable()) {
                    guiGraphics.blitSprite(RenderPipelines.GUI_TEXTURED, SLOT_HIGHLIGHT_BACK_SPRITE,
                            rect.x - 4, rect.y - 4, 24, 24);
                }

                // Render item (centered in slot - slots are 18x18, items are 16x16)
                int itemX = rect.x + 1;
                int itemY = rect.y + 1;

                if (!item.isEmpty()) {
                    guiGraphics.renderItem(item, itemX, itemY);
                    guiGraphics.renderItemDecorations(font, item, itemX, itemY);
                }

                // Render hover highlight front (after item)
                if (slotIndex == hoveredSlotIndex && slot.isHighlightable()) {
                    guiGraphics.blitSprite(RenderPipelines.GUI_TEXTURED, SLOT_HIGHLIGHT_FRONT_SPRITE,
                            rect.x - 4, rect.y - 4, 24, 24);
                }
            }
        }
    }

    private void renderCarriedItem(GuiGraphics guiGraphics, int mouseX, int mouseY) {
        ItemStack carried = menu.getCarried();
        if (!carried.isEmpty()) {
            guiGraphics.nextStratum(); // Render above everything
            guiGraphics.renderItem(carried, mouseX - 8, mouseY - 8);
            guiGraphics.renderItemDecorations(font, carried, mouseX - 8, mouseY - 8);
        }
    }

    private void renderSlotTooltip(GuiGraphics guiGraphics, int mouseX, int mouseY) {
        if (hoveredSlotIndex >= 0 && hoveredSlotIndex < menu.slots.size()) {
            ItemStack item = menu.slots.get(hoveredSlotIndex).getItem();
            if (!item.isEmpty() && menu.getCarried().isEmpty()) {
                // Use setTooltipForNextFrame like AbstractContainerScreen does
                List<Component> tooltipLines = Screen.getTooltipFromItem(minecraft, item);
                guiGraphics.setTooltipForNextFrame(
                    font, tooltipLines, item.getTooltipImage(), mouseX, mouseY, item.get(DataComponents.TOOLTIP_STYLE)
                );
            }
        }
    }

    private int findSlotAt(double mouseX, double mouseY) {
        for (var entry : slotPositions.entrySet()) {
            if (entry.getValue().contains(mouseX, mouseY)) {
                return entry.getKey();
            }
        }
        return -1;
    }

    @Override
    public boolean mouseClicked(net.minecraft.client.input.MouseButtonEvent event, boolean bl) {
        int slotIndex = findSlotAt(event.x(), event.y());

        if (slotIndex >= 0) {
            // Handle slot click via container menu
            // Use minecraft.hasShiftDown() to check for shift key
            ClickType clickType = minecraft.hasShiftDown() ? ClickType.QUICK_MOVE : ClickType.PICKUP;

            minecraft.gameMode.handleInventoryMouseClick(
                menu.containerId,
                slotIndex,
                event.button(),
                clickType,
                minecraft.player
            );

            return true;
        }

        // Let Flutter handle other clicks
        return super.mouseClicked(event, bl);
    }

    @Override
    public boolean mouseReleased(net.minecraft.client.input.MouseButtonEvent event) {
        // For now, let parent handle releases
        return super.mouseReleased(event);
    }

    @Override
    public void removed() {
        super.removed();

        // Clear slot positions handler when screen closes
        DartBridgeClient.setSlotPositionsHandler(null);
        slotPositions.clear();

        LOGGER.info("[FlutterContainerScreen] Removed");
    }

    /**
     * Get the container menu.
     */
    public T getMenu() {
        return menu;
    }

    /**
     * Check if a slot is hovered.
     */
    public boolean isSlotHovered(int slotIndex) {
        return slotIndex == hoveredSlotIndex;
    }

    /**
     * Get the currently hovered slot index, or -1 if none.
     */
    public int getHoveredSlotIndex() {
        return hoveredSlotIndex;
    }
}
