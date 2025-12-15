package com.example.dartbridge;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.resources.Identifier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Client-side extension of DartBridge for GUI operations.
 * This class handles all client-only functionality like screens and rendering.
 */
public class DartBridgeClient {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBridgeClient");

    // Storage for GuiGraphics during render cycle
    private static final Map<Long, GuiGraphics> currentGraphics = new ConcurrentHashMap<>();

    public static void setCurrentGuiGraphics(long screenId, GuiGraphics graphics) {
        currentGraphics.put(screenId, graphics);
    }

    public static void clearCurrentGuiGraphics(long screenId) {
        currentGraphics.remove(screenId);
    }

    // --------------------------------------------------------------------------
    // Screen Management APIs (called from Dart)
    // --------------------------------------------------------------------------

    /**
     * Create and show a new Dart-controlled screen.
     * @param title The title of the screen
     * @return The screen ID for future reference
     */
    public static long createAndShowScreen(String title) {
        DartScreen screen = new DartScreen(title);
        long screenId = screen.getScreenId();

        Minecraft.getInstance().execute(() -> {
            Minecraft.getInstance().setScreen(screen);
        });

        return screenId;
    }

    /**
     * Close a Dart-controlled screen by ID.
     */
    public static void closeScreen(long screenId) {
        DartScreen screen = DartScreen.getById(screenId);
        if (screen != null) {
            Minecraft.getInstance().execute(() -> {
                screen.onClose();
            });
        }
    }

    /**
     * Get the width of a screen.
     */
    public static int getScreenWidth(long screenId) {
        DartScreen screen = DartScreen.getById(screenId);
        return screen != null ? screen.width : 0;
    }

    /**
     * Get the height of a screen.
     */
    public static int getScreenHeight(long screenId) {
        DartScreen screen = DartScreen.getById(screenId);
        return screen != null ? screen.height : 0;
    }

    // --------------------------------------------------------------------------
    // GuiGraphics Drawing Operations (called from Dart during render)
    // --------------------------------------------------------------------------

    /**
     * Draw a string at the specified position.
     * @param shadow If true, draw with shadow (good for dark backgrounds). If false, no shadow (good for light backgrounds).
     */
    public static void guiDrawString(long screenId, String text, int x, int y, int color, boolean shadow) {
        GuiGraphics graphics = currentGraphics.get(screenId);
        if (graphics != null) {
            graphics.drawString(Minecraft.getInstance().font, text, x, y, color, shadow);
        }
    }

    /**
     * Draw a centered string at the specified position.
     * @param shadow If true, draw with shadow (good for dark backgrounds). If false, no shadow (good for light backgrounds).
     */
    public static void guiDrawCenteredString(long screenId, String text, int centerX, int y, int color, boolean shadow) {
        GuiGraphics graphics = currentGraphics.get(screenId);
        if (graphics != null) {
            if (shadow) {
                graphics.drawCenteredString(Minecraft.getInstance().font, text, centerX, y, color);
            } else {
                // drawCenteredString always draws with shadow, so we manually center
                int textWidth = Minecraft.getInstance().font.width(text);
                graphics.drawString(Minecraft.getInstance().font, text, centerX - textWidth / 2, y, color, false);
            }
        }
    }

    /**
     * Fill a rectangle with a solid color.
     */
    public static void guiFill(long screenId, int x1, int y1, int x2, int y2, int color) {
        GuiGraphics graphics = currentGraphics.get(screenId);
        if (graphics != null) {
            graphics.fill(x1, y1, x2, y2, color);
        }
    }

    /**
     * Fill a rectangle with a vertical gradient.
     */
    public static void guiFillGradient(long screenId, int x1, int y1, int x2, int y2, int colorTop, int colorBottom) {
        GuiGraphics graphics = currentGraphics.get(screenId);
        if (graphics != null) {
            graphics.fillGradient(x1, y1, x2, y2, colorTop, colorBottom);
        }
    }

    /**
     * Draw a texture (blit) at the specified position.
     * @param texture The texture resource location (e.g., "minecraft:textures/gui/widgets.png")
     * @param x The x position to draw at
     * @param y The y position to draw at
     * @param width The width to draw
     * @param height The height to draw
     * @param u The u texture coordinate (0.0-1.0 normalized)
     * @param v The v texture coordinate (0.0-1.0 normalized)
     * @param uWidth The width in texture UV space (0.0-1.0 normalized)
     * @param vHeight The height in texture UV space (0.0-1.0 normalized)
     */
    public static void guiBlit(long screenId, String texture, int x, int y, int width, int height, float u, float v, float uWidth, float vHeight) {
        GuiGraphics graphics = currentGraphics.get(screenId);
        if (graphics != null) {
            Identifier textureId = Identifier.parse(texture);
            graphics.blit(textureId, x, y, width, height, u, v, uWidth, vHeight);
        }
    }

    /**
     * Draw a horizontal line.
     */
    public static void guiHLine(long screenId, int x1, int x2, int y, int color) {
        GuiGraphics graphics = currentGraphics.get(screenId);
        if (graphics != null) {
            graphics.hLine(x1, x2, y, color);
        }
    }

    /**
     * Draw a vertical line.
     */
    public static void guiVLine(long screenId, int x, int y1, int y2, int color) {
        GuiGraphics graphics = currentGraphics.get(screenId);
        if (graphics != null) {
            graphics.vLine(x, y1, y2, color);
        }
    }

    /**
     * Draw a rectangle border (outline).
     */
    public static void guiRenderOutline(long screenId, int x, int y, int width, int height, int color) {
        GuiGraphics graphics = currentGraphics.get(screenId);
        if (graphics != null) {
            graphics.renderOutline(x, y, width, height, color);
        }
    }

    /**
     * Get the width of a string in pixels.
     */
    public static int guiGetStringWidth(String text) {
        return Minecraft.getInstance().font.width(text);
    }

    /**
     * Get the height of the font in pixels.
     */
    public static int guiGetFontHeight() {
        return Minecraft.getInstance().font.lineHeight;
    }

    /**
     * Draw a sprite from the GUI sprite atlas.
     * This is the proper way to render slot backgrounds and other GUI elements.
     * @param sprite The sprite identifier (e.g., "container/slot")
     * @param x The x position
     * @param y The y position
     * @param width The width to draw
     * @param height The height to draw
     */
    public static void guiBlitSprite(long screenId, String sprite, int x, int y, int width, int height) {
        GuiGraphics graphics = currentGraphics.get(screenId);
        if (graphics != null) {
            Identifier spriteId = Identifier.parse(sprite);
            graphics.blitSprite(net.minecraft.client.renderer.RenderPipelines.GUI_TEXTURED, spriteId, x, y, width, height);
        }
    }

    // --------------------------------------------------------------------------
    // Widget Management APIs (called from Dart)
    // --------------------------------------------------------------------------

    /**
     * Add a button widget to a screen.
     * @return Widget ID for callbacks
     */
    public static long addButton(long screenId, int x, int y, int width, int height, String text) {
        DartScreen screen = DartScreen.getById(screenId);
        if (screen != null) {
            return screen.addButton(x, y, width, height, text);
        }
        return -1;
    }

    /**
     * Add an edit box (text field) widget to a screen.
     * @return Widget ID for callbacks
     */
    public static long addEditBox(long screenId, int x, int y, int width, int height, String placeholder) {
        DartScreen screen = DartScreen.getById(screenId);
        if (screen != null) {
            return screen.addEditBox(x, y, width, height, placeholder);
        }
        return -1;
    }

    /**
     * Remove a widget from a screen.
     */
    public static void removeWidget(long screenId, long widgetId) {
        DartScreen screen = DartScreen.getById(screenId);
        if (screen != null) {
            screen.removeWidget(widgetId);
        }
    }

    /**
     * Get the text value of an EditBox widget.
     */
    public static String getEditBoxValue(long screenId, long widgetId) {
        DartScreen screen = DartScreen.getById(screenId);
        if (screen != null) {
            return screen.getEditBoxValue(widgetId);
        }
        return "";
    }

    /**
     * Set the text value of an EditBox widget.
     */
    public static void setEditBoxValue(long screenId, long widgetId, String value) {
        DartScreen screen = DartScreen.getById(screenId);
        if (screen != null) {
            screen.setEditBoxValue(widgetId, value);
        }
    }

    /**
     * Set widget visibility.
     */
    public static void setWidgetVisible(long screenId, long widgetId, boolean visible) {
        DartScreen screen = DartScreen.getById(screenId);
        if (screen != null) {
            screen.setWidgetVisible(widgetId, visible);
        }
    }

    /**
     * Set widget active state.
     */
    public static void setWidgetActive(long screenId, long widgetId, boolean active) {
        DartScreen screen = DartScreen.getById(screenId);
        if (screen != null) {
            screen.setWidgetActive(widgetId, active);
        }
    }

    // --------------------------------------------------------------------------
    // Container Screen APIs (called from Dart)
    // --------------------------------------------------------------------------

    /**
     * Add a slot to a container screen at screen coordinates.
     * @param screenId The container screen ID
     * @param slotIndex The container slot index (0 to containerSlotCount-1)
     * @param x Screen X coordinate for the slot
     * @param y Screen Y coordinate for the slot
     */
    public static void addContainerSlot(long screenId, int slotIndex, int x, int y) {
        DartContainerScreen screen = DartContainerScreen.getById(screenId);
        if (screen != null) {
            screen.getMenu().addContainerSlot(slotIndex, x, y);
        }
    }

    /**
     * Add player inventory slots at the standard position.
     * @param screenId The container screen ID
     * @param startX X coordinate for the first slot
     * @param startY Y coordinate for the main inventory
     */
    public static void addPlayerInventorySlots(long screenId, int startX, int startY) {
        DartContainerScreen screen = DartContainerScreen.getById(screenId);
        if (screen != null && Minecraft.getInstance().player != null) {
            screen.getMenu().addPlayerInventorySlots(Minecraft.getInstance().player.getInventory(), startX, startY);
        }
    }

    /**
     * Set the size of a container screen.
     * @param screenId The container screen ID
     * @param width The image width (GUI panel width)
     * @param height The image height (GUI panel height)
     */
    public static void setContainerSize(long screenId, int width, int height) {
        DartContainerScreen screen = DartContainerScreen.getById(screenId);
        if (screen != null) {
            screen.setSize(width, height);
        }
    }

    /**
     * Get the container slot count for a container screen.
     * @param screenId The container screen ID
     * @return The number of container slots
     */
    public static int getContainerSlotCount(long screenId) {
        DartContainerScreen screen = DartContainerScreen.getById(screenId);
        if (screen != null) {
            return screen.getMenu().getContainerSlotCount();
        }
        return 0;
    }
}
