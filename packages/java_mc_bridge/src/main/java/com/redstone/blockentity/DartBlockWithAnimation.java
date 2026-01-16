package com.redstone.blockentity;

import com.redstone.proxy.DartBlockProxy;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.EntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityTicker;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Block that has an animated model rendered via a block entity.
 *
 * Extends DartBlockProxy with EntityBlock implementation to support
 * animated block rendering using the AnimatedBlockEntity and AnimatedBlockRenderer.
 *
 * Unlike regular blocks, animated blocks render their model through the
 * block entity renderer which applies transformations (rotation, translation, scale)
 * each frame for smooth animation.
 */
public class DartBlockWithAnimation extends DartBlockProxy implements EntityBlock {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBlockWithAnimation");

    /** The full block ID (namespace:path) for looking up our BlockEntityType. */
    private final String blockId;

    /** Handler ID for the Dart block (used for callbacks). */
    private final int dartHandlerId;

    /** Cached BlockEntityType for this block. */
    private BlockEntityType<AnimatedBlockEntity> blockEntityType;

    public DartBlockWithAnimation(Properties settings, long handlerId, Object blockSettings, String blockId) {
        super(settings, handlerId, blockSettings);
        this.blockId = blockId;
        this.dartHandlerId = (int) handlerId;
    }

    /**
     * Get the BlockEntityType for this block.
     * Caches the result after first lookup.
     */
    private BlockEntityType<AnimatedBlockEntity> getBlockEntityType() {
        if (blockEntityType == null) {
            blockEntityType = AnimatedBlockEntityType.getType(blockId);
            if (blockEntityType == null) {
                LOGGER.error("No AnimatedBlockEntityType registered for block {}", blockId);
            }
        }
        return blockEntityType;
    }

    // ========================================================================
    // EntityBlock implementation
    // ========================================================================

    @Override
    public @Nullable BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
        BlockEntityType<AnimatedBlockEntity> type = getBlockEntityType();
        if (type == null) {
            LOGGER.error("Cannot create animated block entity: no BlockEntityType for {}", blockId);
            return null;
        }

        return new AnimatedBlockEntity(type, pos, state, dartHandlerId);
    }

    @Override
    public @Nullable <T extends BlockEntity> BlockEntityTicker<T> getTicker(Level level, BlockState state,
                                                                             BlockEntityType<T> type) {
        // Tick on both client and server side for animation
        // Client-side ticking is required for smooth animation
        BlockEntityType<AnimatedBlockEntity> ourType = getBlockEntityType();
        if (ourType != null && type == ourType) {
            return (BlockEntityTicker<T>) (lvl, pos, st, be) ->
                AnimatedBlockEntity.tick(lvl, pos, st, (AnimatedBlockEntity) be);
        }

        return null;
    }

    // ========================================================================
    // Render shape override
    // ========================================================================

    @Override
    protected RenderShape getRenderShape(BlockState state) {
        // Use INVISIBLE to prevent Minecraft's static block renderer from rendering the block.
        // This prevents double-rendering (z-fighting) since AnimatedBlockRenderer handles all rendering.
        // The model is still loaded and available via BlockModelShaper - RenderShape.INVISIBLE only
        // prevents the default rendering pipeline from drawing the block, it doesn't affect model loading.
        return RenderShape.INVISIBLE;
    }
}
