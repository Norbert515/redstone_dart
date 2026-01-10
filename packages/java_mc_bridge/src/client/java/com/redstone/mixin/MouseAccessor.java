package com.redstone.mixin;

import net.minecraft.client.MouseHandler;
import net.minecraft.client.input.MouseButtonInfo;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.gen.Invoker;

/**
 * Mixin accessor for MouseHandler to expose protected methods for input simulation.
 * Updated for Minecraft 1.21.11 which uses MouseButtonInfo objects.
 */
@Mixin(MouseHandler.class)
public interface MouseAccessor {
    /**
     * Invoke the onButton method to simulate mouse button press/release events.
     *
     * @param window The GLFW window handle
     * @param mouseButtonInfo The MouseButtonInfo containing button and modifiers
     * @param action The action (1=press, 0=release)
     */
    @Invoker("onButton")
    void invokeOnButton(long window, MouseButtonInfo mouseButtonInfo, int action);

    /**
     * Invoke the onMove method to simulate cursor movement events.
     *
     * @param window The GLFW window handle
     * @param x The X coordinate in screen pixels
     * @param y The Y coordinate in screen pixels
     */
    @Invoker("onMove")
    void invokeOnMove(long window, double x, double y);

    /**
     * Invoke the onScroll method to simulate mouse wheel scroll events.
     *
     * @param window The GLFW window handle
     * @param horizontal The horizontal scroll amount
     * @param vertical The vertical scroll amount
     */
    @Invoker("onScroll")
    void invokeOnScroll(long window, double horizontal, double vertical);
}
