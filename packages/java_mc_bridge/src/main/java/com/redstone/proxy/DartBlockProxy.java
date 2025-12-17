package com.redstone.proxy;

import com.redstone.DartBridge;
import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.RandomSource;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.InsideBlockEffectApplier;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.redstone.Orientation;
import net.minecraft.world.phys.BlockHitResult;
import org.jetbrains.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * A Block proxy that delegates all behavior to Dart.
 *
 * Each instance of this class represents a single Dart-defined block type.
 * The dartHandlerId links to the Dart-side CustomBlock instance.
 */
public class DartBlockProxy extends Block {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBlockProxy");
    private final long dartHandlerId;
    private final boolean ticksRandomly;

    public DartBlockProxy(Properties settings, long dartHandlerId, Object blockSettings) {
        super(settings);
        this.dartHandlerId = dartHandlerId;
        // Extract ticksRandomly from the record if available
        boolean ticksRandomlyValue = false;
        if (blockSettings != null) {
            try {
                var method = blockSettings.getClass().getMethod("ticksRandomly");
                ticksRandomlyValue = (Boolean) method.invoke(blockSettings);
            } catch (Exception e) {
                // Keep default value
            }
        }
        this.ticksRandomly = ticksRandomlyValue;
    }

    public long getDartHandlerId() {
        return dartHandlerId;
    }

    @Override
    public BlockState playerWillDestroy(Level level, BlockPos pos, BlockState state, Player player) {
        // Delegate to Dart
        if (DartBridge.isInitialized()) {
            DartBridge.onProxyBlockBreak(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                player.getId()
            );
        }
        return super.playerWillDestroy(level, pos, state, player);
    }

    @Override
    protected InteractionResult useWithoutItem(BlockState state, Level level, BlockPos pos,
                                                Player player, BlockHitResult hit) {
        LOGGER.info("useWithoutItem called! pos={}, clientSide={}, dartInit={}",
            pos, level.isClientSide(), DartBridge.isInitialized());

        // Only run on server side
        if (level.isClientSide()) {
            return InteractionResult.SUCCESS;
        }

        if (!DartBridge.isInitialized()) {
            LOGGER.warn("DartBridge not initialized! libraryLoaded={}", DartBridge.isLibraryLoaded());
            return InteractionResult.PASS;
        }

        LOGGER.info("Calling Dart onProxyBlockUse with handlerId={}", dartHandlerId);
        int result = DartBridge.onProxyBlockUse(
            dartHandlerId,
            level.hashCode(),
            pos.getX(),
            pos.getY(),
            pos.getZ(),
            player.getId(),
            0  // hand ordinal - simplified for now
        );
        LOGGER.info("Dart returned result={}", result);

        // Map result ordinal to InteractionResult
        // In 1.21+, InteractionResult is simplified
        return switch (result) {
            case 0 -> InteractionResult.SUCCESS;        // success, arm swings
            case 1, 2 -> InteractionResult.CONSUME;     // consume variants
            case 3 -> InteractionResult.PASS;           // no interaction
            case 4 -> InteractionResult.FAIL;           // interaction failed
            default -> InteractionResult.PASS;
        };
    }

    @Override
    public void stepOn(Level level, BlockPos pos, BlockState state, Entity entity) {
        // Only run on server side
        if (!level.isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyBlockSteppedOn(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                entity.getId()
            );
        }
        super.stepOn(level, pos, state, entity);
    }

    @Override
    public void fallOn(Level level, BlockState state, BlockPos pos, Entity entity, double fallDistance) {
        // Only run on server side
        if (!level.isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyBlockFallenUpon(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                entity.getId(),
                (float) fallDistance
            );
        }
        super.fallOn(level, state, pos, entity, fallDistance);
    }

    @Override
    protected void randomTick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random) {
        if (DartBridge.isInitialized()) {
            DartBridge.onProxyBlockRandomTick(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ()
            );
        }
        super.randomTick(state, level, pos, random);
    }

    @Override
    protected void onPlace(BlockState state, Level level, BlockPos pos, BlockState oldState, boolean movedByPiston) {
        // Only run on server side and only if block type changed
        if (!level.isClientSide() && !state.is(oldState.getBlock()) && DartBridge.isInitialized()) {
            // Get the player who placed it (may be null if placed by automation)
            // For now, we pass 0 as playerId when unknown
            DartBridge.onProxyBlockPlaced(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                0  // playerId - would need state context to get
            );
        }
        super.onPlace(state, level, pos, oldState, movedByPiston);
    }

    @Override
    protected void affectNeighborsAfterRemoval(BlockState state, ServerLevel level, BlockPos pos, boolean movedByPiston) {
        // Notify Dart that this block was removed
        if (DartBridge.isInitialized()) {
            DartBridge.onProxyBlockRemoved(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ()
            );
        }
        super.affectNeighborsAfterRemoval(state, level, pos, movedByPiston);
    }

    @Override
    protected void neighborChanged(BlockState state, Level level, BlockPos pos, Block neighborBlock, @Nullable Orientation orientation, boolean movedByPiston) {
        // Only run on server side
        if (!level.isClientSide() && DartBridge.isInitialized()) {
            // Since we no longer have neighborPos, pass the block's own position
            // The orientation can be used to determine the direction of the change
            DartBridge.onProxyBlockNeighborChanged(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                pos.getX(),  // neighborPos no longer available in new API
                pos.getY(),
                pos.getZ()
            );
        }
        super.neighborChanged(state, level, pos, neighborBlock, orientation, movedByPiston);
    }

    @Override
    protected void entityInside(BlockState state, Level level, BlockPos pos, Entity entity, InsideBlockEffectApplier applier, boolean intersects) {
        // Only run on server side
        if (!level.isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyBlockEntityInside(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                entity.getId()
            );
        }
        super.entityInside(state, level, pos, entity, applier, intersects);
    }
}
