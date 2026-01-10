package com.redstone.mixin;

import net.minecraft.client.KeyboardHandler;
import net.minecraft.client.input.CharacterEvent;
import net.minecraft.client.input.KeyEvent;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.gen.Invoker;

/**
 * Mixin accessor for KeyboardHandler to expose protected methods for input simulation.
 * Updated for Minecraft 1.21.11 which uses KeyEvent and CharacterEvent objects.
 */
@Mixin(KeyboardHandler.class)
public interface KeyboardAccessor {
    /**
     * Invoke the keyPress method to simulate key press/release events.
     *
     * @param window The GLFW window handle
     * @param action The action (GLFW_PRESS, GLFW_RELEASE, or GLFW_REPEAT)
     * @param keyEvent The KeyEvent containing key code and modifiers
     */
    @Invoker("keyPress")
    void invokeKeyPress(long window, int action, KeyEvent keyEvent);

    /**
     * Invoke the charTyped method to simulate character input events.
     *
     * @param window The GLFW window handle
     * @param characterEvent The CharacterEvent containing the character
     */
    @Invoker("charTyped")
    void invokeCharTyped(long window, CharacterEvent characterEvent);
}
