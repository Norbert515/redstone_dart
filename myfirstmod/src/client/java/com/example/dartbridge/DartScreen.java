package com.example.dartbridge;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractWidget;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.input.CharacterEvent;
import net.minecraft.client.input.KeyEvent;
import net.minecraft.client.input.MouseButtonEvent;
import net.minecraft.network.chat.Component;

import java.util.HashMap;
import java.util.Map;

/**
 * A Screen subclass that delegates all lifecycle and events to Dart via DartBridge native methods.
 * This allows Dart code to control and render custom GUI screens in Minecraft.
 */
public class DartScreen extends Screen {
    private final long screenId;
    private static long nextScreenId = 1;
    private static final Map<Long, DartScreen> screens = new HashMap<>();

    // Widget management
    private final Map<Long, AbstractWidget> widgets = new HashMap<>();
    private static long nextWidgetId = 1;

    public DartScreen(String title) {
        super(Component.literal(title));
        this.screenId = nextScreenId++;
        screens.put(screenId, this);
    }

    public long getScreenId() {
        return screenId;
    }

    public static DartScreen getById(long id) {
        return screens.get(id);
    }

    // ===========================================================================
    // Widget Management
    // ===========================================================================

    /**
     * Add a button widget to this screen.
     * @return Widget ID for callbacks
     */
    public long addButton(int x, int y, int width, int height, String text) {
        long widgetId = nextWidgetId++;
        Button button = Button.builder(Component.literal(text), btn -> {
            DartBridge.dispatchWidgetPressed(screenId, widgetId);
        }).bounds(x, y, width, height).build();

        this.addRenderableWidget(button);
        widgets.put(widgetId, button);
        return widgetId;
    }

    /**
     * Add an edit box (text field) widget to this screen.
     * @return Widget ID for callbacks
     */
    public long addEditBox(int x, int y, int width, int height, String placeholder) {
        long widgetId = nextWidgetId++;
        EditBox editBox = new EditBox(this.font, x, y, width, height, Component.literal(placeholder));
        editBox.setResponder(text -> {
            DartBridge.dispatchWidgetTextChanged(screenId, widgetId, text);
        });

        this.addRenderableWidget(editBox);
        widgets.put(widgetId, editBox);
        return widgetId;
    }

    /**
     * Remove a widget from this screen.
     */
    public void removeWidget(long widgetId) {
        AbstractWidget widget = widgets.remove(widgetId);
        if (widget != null) {
            this.removeWidget(widget);
        }
    }

    /**
     * Get the text value of an EditBox widget.
     */
    public String getEditBoxValue(long widgetId) {
        AbstractWidget widget = widgets.get(widgetId);
        if (widget instanceof EditBox editBox) {
            return editBox.getValue();
        }
        return "";
    }

    /**
     * Set the text value of an EditBox widget.
     */
    public void setEditBoxValue(long widgetId, String value) {
        AbstractWidget widget = widgets.get(widgetId);
        if (widget instanceof EditBox editBox) {
            editBox.setValue(value);
        }
    }

    /**
     * Set widget visibility.
     */
    public void setWidgetVisible(long widgetId, boolean visible) {
        AbstractWidget widget = widgets.get(widgetId);
        if (widget != null) {
            widget.visible = visible;
        }
    }

    /**
     * Set widget active state.
     */
    public void setWidgetActive(long widgetId, boolean active) {
        AbstractWidget widget = widgets.get(widgetId);
        if (widget != null) {
            widget.active = active;
        }
    }

    // Lifecycle - delegate to Dart
    @Override
    protected void init() {
        super.init();
        DartBridge.dispatchScreenInit(screenId, width, height);
    }

    @Override
    public void tick() {
        super.tick();
        DartBridge.dispatchScreenTick(screenId);
    }

    @Override
    public void render(GuiGraphics graphics, int mouseX, int mouseY, float partialTick) {
        // Let Dart draw background/panel first
        DartBridgeClient.setCurrentGuiGraphics(screenId, graphics);
        DartBridge.dispatchScreenRender(screenId, mouseX, mouseY, partialTick);
        DartBridgeClient.clearCurrentGuiGraphics(screenId);
        // Then render widgets on top
        super.render(graphics, mouseX, mouseY, partialTick);
    }

    @Override
    public void removed() {
        super.removed();
        screens.remove(screenId);
    }

    @Override
    public void onClose() {
        DartBridge.dispatchScreenClose(screenId);
        super.onClose();
    }

    // Input events - delegate to Dart, return true if handled
    @Override
    public boolean keyPressed(KeyEvent keyEvent) {
        if (DartBridge.dispatchScreenKeyPressed(screenId, keyEvent.key(), keyEvent.scancode(), keyEvent.modifiers())) {
            return true;
        }
        return super.keyPressed(keyEvent);
    }

    @Override
    public boolean keyReleased(KeyEvent keyEvent) {
        if (DartBridge.dispatchScreenKeyReleased(screenId, keyEvent.key(), keyEvent.scancode(), keyEvent.modifiers())) {
            return true;
        }
        return super.keyReleased(keyEvent);
    }

    @Override
    public boolean charTyped(CharacterEvent characterEvent) {
        if (DartBridge.dispatchScreenCharTyped(screenId, characterEvent.codepoint(), characterEvent.modifiers())) {
            return true;
        }
        return super.charTyped(characterEvent);
    }

    @Override
    public boolean mouseClicked(MouseButtonEvent mouseButtonEvent, boolean bl) {
        if (DartBridge.dispatchScreenMouseClicked(screenId, mouseButtonEvent.x(), mouseButtonEvent.y(), mouseButtonEvent.button())) {
            return true;
        }
        return super.mouseClicked(mouseButtonEvent, bl);
    }

    @Override
    public boolean mouseReleased(MouseButtonEvent mouseButtonEvent) {
        if (DartBridge.dispatchScreenMouseReleased(screenId, mouseButtonEvent.x(), mouseButtonEvent.y(), mouseButtonEvent.button())) {
            return true;
        }
        return super.mouseReleased(mouseButtonEvent);
    }

    @Override
    public boolean mouseDragged(MouseButtonEvent mouseButtonEvent, double dragX, double dragY) {
        if (DartBridge.dispatchScreenMouseDragged(screenId, mouseButtonEvent.x(), mouseButtonEvent.y(), mouseButtonEvent.button(), dragX, dragY)) {
            return true;
        }
        return super.mouseDragged(mouseButtonEvent, dragX, dragY);
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double deltaX, double deltaY) {
        if (DartBridge.dispatchScreenMouseScrolled(screenId, mouseX, mouseY, deltaX, deltaY)) {
            return true;
        }
        return super.mouseScrolled(mouseX, mouseY, deltaX, deltaY);
    }

    @Override
    public boolean isPauseScreen() {
        return false;
    }
}
