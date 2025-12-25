package com.redstone.proxy;

import com.redstone.DartBridge;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * A proxy item that delegates behavior to Dart code.
 *
 * Each instance of this class represents a single Dart-defined item type.
 * The handlerId links to the Dart-side CustomItem instance.
 */
public class DartItemProxy extends Item {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartItemProxy");
    private final long handlerId;

    public DartItemProxy(Properties properties, long handlerId) {
        super(properties);
        this.handlerId = handlerId;
    }

    public long getHandlerId() {
        return handlerId;
    }

    @Override
    public InteractionResult use(Level level, Player player, InteractionHand hand) {
        if (level.isClientSide()) {
            return InteractionResult.SUCCESS;
        }

        if (!DartBridge.isInitialized()) {
            return InteractionResult.PASS;
        }

        // Dispatch to Dart via DartBridge
        // Return values: 0=SUCCESS, 1=CONSUME_PARTIAL, 2=CONSUME, 3=FAIL, 4=PASS
        int result = DartBridge.onProxyItemUse(
            handlerId,
            level.hashCode(),
            player.getId(),
            hand.ordinal()
        );
        return mapResult(result);
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        if (context.getLevel().isClientSide()) {
            return InteractionResult.SUCCESS;
        }

        if (!DartBridge.isInitialized()) {
            return InteractionResult.PASS;
        }

        // Dispatch to Dart via DartBridge
        // Return values: 0=SUCCESS, 1=CONSUME_PARTIAL, 2=CONSUME, 3=FAIL, 4=PASS
        int result = DartBridge.onProxyItemUseOnBlock(
            handlerId,
            context.getLevel().hashCode(),
            context.getClickedPos().getX(),
            context.getClickedPos().getY(),
            context.getClickedPos().getZ(),
            context.getPlayer() != null ? context.getPlayer().getId() : -1,
            context.getHand().ordinal()
        );
        return mapResult(result);
    }

    @Override
    public InteractionResult interactLivingEntity(ItemStack stack, Player player, LivingEntity target, InteractionHand hand) {
        if (player.level().isClientSide()) {
            return InteractionResult.SUCCESS;
        }

        if (!DartBridge.isInitialized()) {
            return InteractionResult.PASS;
        }

        // Dispatch to Dart via DartBridge
        // Return values: 0=SUCCESS, 1=CONSUME_PARTIAL, 2=CONSUME, 3=FAIL, 4=PASS
        int result = DartBridge.onProxyItemUseOnEntity(
            handlerId,
            player.level().hashCode(),
            target.getId(),
            player.getId(),
            hand.ordinal()
        );
        return mapResult(result);
    }

    @Override
    public void postHurtEnemy(ItemStack stack, LivingEntity target, LivingEntity attacker) {
        if (!attacker.level().isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyItemAttackEntity(
                handlerId,
                attacker.level().hashCode(),
                attacker.getId(),
                target.getId()
            );
        }
        super.postHurtEnemy(stack, target, attacker);
    }

    /**
     * Map Dart ItemActionResult ordinal to Minecraft InteractionResult.
     * Dart returns: 0=SUCCESS, 1=CONSUME_PARTIAL, 2=CONSUME, 3=FAIL, 4=PASS
     *
     * Note: MC 1.21+ uses a sealed interface for InteractionResult.
     * CONSUME_PARTIAL doesn't exist, so we map it to CONSUME.
     */
    private static InteractionResult mapResult(int ordinal) {
        return switch (ordinal) {
            case 0 -> InteractionResult.SUCCESS;
            case 1 -> InteractionResult.CONSUME;  // CONSUME_PARTIAL -> CONSUME (doesn't exist in MC 1.21+)
            case 2 -> InteractionResult.CONSUME;
            case 3 -> InteractionResult.FAIL;
            default -> InteractionResult.PASS;
        };
    }
}
