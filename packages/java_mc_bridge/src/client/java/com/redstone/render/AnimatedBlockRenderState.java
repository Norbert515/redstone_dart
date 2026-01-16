package com.redstone.render;

import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.renderer.blockentity.state.BlockEntityRenderState;

/**
 * Render state for animated block entities.
 *
 * This class holds all data needed to render an animated block during the render phase.
 * Data is extracted from the block entity in extractRenderState() and then used in submit().
 *
 * Animation values include both current and previous tick values to enable smooth
 * interpolation using partialTick for sub-tick rendering.
 */
@Environment(EnvType.CLIENT)
public class AnimatedBlockRenderState extends BlockEntityRenderState {
    // Current rotation values (in degrees)
    public float rotationX;
    public float rotationY;
    public float rotationZ;

    // Current translation values (in blocks)
    public float translateX;
    public float translateY;
    public float translateZ;

    // Current scale values (1.0 = normal size)
    public float scaleX = 1;
    public float scaleY = 1;
    public float scaleZ = 1;

    // Pivot point for rotation/scale (0-1, relative to block)
    public float pivotX = 0.5f;
    public float pivotY = 0.5f;
    public float pivotZ = 0.5f;

    // Previous tick rotation values (for interpolation)
    public float oRotationX;
    public float oRotationY;
    public float oRotationZ;

    // Previous tick translation values (for interpolation)
    public float oTranslateX;
    public float oTranslateY;
    public float oTranslateZ;

    // Previous tick scale values (for interpolation)
    public float oScaleX = 1;
    public float oScaleY = 1;
    public float oScaleZ = 1;

    // Partial tick for interpolation (0.0 to 1.0)
    public float partialTick;

    // Handler ID for the Dart-side block entity
    public int handlerId;
}
