package com.example.dartbridge.proxy;

import com.example.dartbridge.DartBridge;
import net.minecraft.core.BlockPos;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;
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

    public DartBlockProxy(Properties settings, long dartHandlerId) {
        super(settings);
        this.dartHandlerId = dartHandlerId;
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
}
