package com.redstone.render;

import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.renderer.blockentity.state.BlockEntityRenderState;
import net.minecraft.core.Direction;

/**
 * Render state for Flutter display block entities.
 *
 * This class holds all data needed to render a Flutter display during the render phase.
 * Data is extracted from the block entity in extractRenderState() and then used in submit().
 */
@Environment(EnvType.CLIENT)
public class FlutterBlockRenderState extends BlockEntityRenderState {
    /**
     * Flutter surface ID to render.
     */
    public long surfaceId;

    /**
     * Grid position X (0 = left).
     */
    public int gridX;

    /**
     * Grid position Y (0 = top).
     */
    public int gridY;

    /**
     * Total grid width.
     */
    public int gridWidth;

    /**
     * Total grid height.
     */
    public int gridHeight;

    /**
     * Which block face displays the content.
     */
    public Direction facing;

    /**
     * Whether to use fullbright lighting.
     */
    public boolean emissive;
}
