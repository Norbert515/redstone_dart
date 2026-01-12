package com.redstone.mixin;

import com.mojang.blaze3d.platform.DisplayData;
import com.mojang.blaze3d.platform.ScreenManager;
import com.mojang.blaze3d.platform.Window;
import com.mojang.blaze3d.platform.WindowEventHandler;
import org.lwjgl.glfw.GLFW;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Mixin to prevent window focus stealing when running in background mode.
 *
 * When BACKGROUND_MODE system property is set, this sets GLFW_FOCUS_ON_SHOW to false
 * before the window is created, preventing Minecraft from stealing focus on startup.
 */
@Mixin(Window.class)
public class WindowMixin {

    /**
     * Inject at the start of the Window constructor, before glfwCreateWindow is called.
     * We inject right after glfwDefaultWindowHints() to set our focus hint.
     */
    @Inject(
        method = "<init>",
        at = @At(
            value = "INVOKE",
            target = "Lorg/lwjgl/glfw/GLFW;glfwDefaultWindowHints()V",
            shift = At.Shift.AFTER
        )
    )
    private void onWindowInit(
            WindowEventHandler windowEventHandler,
            ScreenManager screenManager,
            DisplayData displayData,
            String string,
            String string2,
            CallbackInfo ci) {

        // Check if background mode is enabled via system property
        String backgroundMode = System.getProperty("BACKGROUND_MODE");
        if ("true".equalsIgnoreCase(backgroundMode)) {
            // Set multiple hints to prevent focus stealing:
            // GLFW_FOCUS_ON_SHOW (0x0002000C) = false - prevents focus when glfwShowWindow is called
            // GLFW_FOCUSED (0x00020001) = false - window doesn't get focus when created
            GLFW.glfwWindowHint(GLFW.GLFW_FOCUS_ON_SHOW, GLFW.GLFW_FALSE);
            GLFW.glfwWindowHint(GLFW.GLFW_FOCUSED, GLFW.GLFW_FALSE);
            System.out.println("[redstone] Background mode: window focus stealing disabled (FOCUS_ON_SHOW=false, FOCUSED=false)");
        }
    }
}
