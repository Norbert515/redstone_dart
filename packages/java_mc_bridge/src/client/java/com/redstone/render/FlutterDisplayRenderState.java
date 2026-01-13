package com.redstone.render;

import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.renderer.entity.state.DisplayEntityRenderState;

/**
 * Client-side render state for Flutter display entities.
 *
 * Extends DisplayEntityRenderState to get all the base Display rendering
 * functionality (billboard mode, transformations, interpolation, etc.)
 * and adds Flutter-specific state (surface ID, display dimensions).
 */
@Environment(EnvType.CLIENT)
public class FlutterDisplayRenderState extends DisplayEntityRenderState {

    /**
     * The Flutter surface ID to render.
     * Surface 0 is typically the main Flutter surface.
     * This may be updated by the renderer when a surface is created for a route.
     */
    public long surfaceId;

    /**
     * The display width in world units (meters).
     */
    public float displayWidth;

    /**
     * The display height in world units (meters).
     */
    public float displayHeight;

    /**
     * The Flutter route for this display.
     * Empty string means use the main Flutter surface.
     * Non-empty route causes the renderer to create a dedicated surface.
     */
    public String route = "";

    /**
     * The entity ID, used by the renderer for surface caching.
     */
    public int entityId;

    /**
     * Whether this render state has valid sub-state data.
     * Required by DisplayEntityRenderState.
     */
    @Override
    public boolean hasSubState() {
        return displayWidth > 0 && displayHeight > 0;
    }
}
