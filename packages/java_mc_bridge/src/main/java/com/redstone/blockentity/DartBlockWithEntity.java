package com.redstone.blockentity;

import com.redstone.proxy.DartBlockProxy;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.Containers;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.MenuProvider;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.EntityBlock;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityTicker;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Block that has an associated block entity.
 *
 * Extends DartBlockProxy with EntityBlock implementation to support
 * block entities with inventory and processing capabilities.
 */
public class DartBlockWithEntity extends DartBlockProxy implements EntityBlock {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBlockWithEntity");

    /** Handler ID for the block entity type (used when creating block entities). */
    private final int blockEntityHandlerId;

    /** Number of inventory slots. */
    private final int inventorySize;

    /** Display name for the container. */
    private final Component containerTitle;

    /** The full block ID (namespace:path) for looking up our BlockEntityType. */
    private final String blockId;

    /** Cached BlockEntityType for this block. */
    private BlockEntityType<DartProcessingBlockEntity> blockEntityType;

    public DartBlockWithEntity(Properties settings, long dartHandlerId, Object blockSettings,
                               int blockEntityHandlerId, int inventorySize, String containerTitle,
                               String blockId) {
        super(settings, dartHandlerId, blockSettings);
        this.blockEntityHandlerId = blockEntityHandlerId;
        this.inventorySize = inventorySize;
        this.containerTitle = Component.literal(containerTitle);
        this.blockId = blockId;
    }

    /**
     * Get the BlockEntityType for this block.
     * Caches the result after first lookup.
     */
    private BlockEntityType<DartProcessingBlockEntity> getBlockEntityType() {
        if (blockEntityType == null) {
            blockEntityType = DartBlockEntityType.getType(blockId);
            if (blockEntityType == null) {
                LOGGER.error("No BlockEntityType registered for block {}", blockId);
            }
        }
        return blockEntityType;
    }

    // ========================================================================
    // EntityBlock implementation
    // ========================================================================

    @Override
    public @Nullable BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
        BlockEntityType<DartProcessingBlockEntity> type = getBlockEntityType();
        if (type == null) {
            LOGGER.error("Cannot create block entity: no BlockEntityType for {}", blockId);
            return null;
        }

        return new DartProcessingBlockEntity(
            type,
            pos,
            state,
            blockEntityHandlerId,
            inventorySize,
            containerTitle
        );
    }

    @Override
    public @Nullable <T extends BlockEntity> BlockEntityTicker<T> getTicker(Level level, BlockState state,
                                                                             BlockEntityType<T> type) {
        // Only tick on server side
        if (level.isClientSide()) {
            return null;
        }

        // Return the server ticker if type matches our block's type
        BlockEntityType<DartProcessingBlockEntity> ourType = getBlockEntityType();
        if (ourType != null && type == ourType) {
            return (BlockEntityTicker<T>) (lvl, pos, st, be) ->
                DartProcessingBlockEntity.serverTick(lvl, pos, st, (DartProcessingBlockEntity) be);
        }

        return null;
    }

    // ========================================================================
    // Block lifecycle
    // ========================================================================

    @Override
    protected void affectNeighborsAfterRemoval(BlockState state, ServerLevel level, BlockPos pos, boolean movedByPiston) {
        // Drop inventory contents when block is broken
        BlockEntity blockEntity = level.getBlockEntity(pos);
        if (blockEntity instanceof DartBlockEntityWithInventory container) {
            Containers.dropContents(level, pos, container);
        }

        super.affectNeighborsAfterRemoval(state, level, pos, movedByPiston);
    }

    @Override
    protected InteractionResult useWithoutItem(BlockState state, Level level, BlockPos pos,
                                               Player player, BlockHitResult hit) {
        // On server side, try to open the container menu
        if (!level.isClientSide()) {
            BlockEntity blockEntity = level.getBlockEntity(pos);
            if (blockEntity instanceof MenuProvider menuProvider) {
                player.openMenu(menuProvider);
                return InteractionResult.CONSUME;
            }
        }

        return InteractionResult.SUCCESS;
    }

    // ========================================================================
    // Accessors
    // ========================================================================

    public int getBlockEntityHandlerId() {
        return blockEntityHandlerId;
    }

    public int getInventorySize() {
        return inventorySize;
    }

    public Component getContainerTitle() {
        return containerTitle;
    }
}
