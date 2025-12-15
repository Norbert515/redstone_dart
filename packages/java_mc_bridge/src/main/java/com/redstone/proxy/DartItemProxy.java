package com.redstone.proxy;

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

        // TODO: Dispatch to Dart via DartBridge when callback system is ready
        // For now, just pass through
        LOGGER.debug("DartItemProxy.use called for handler ID: {}", handlerId);
        return InteractionResult.PASS;
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        if (context.getLevel().isClientSide()) {
            return InteractionResult.SUCCESS;
        }

        // TODO: Dispatch to Dart via DartBridge when callback system is ready
        LOGGER.debug("DartItemProxy.useOn called for handler ID: {}", handlerId);
        return InteractionResult.PASS;
    }

    @Override
    public InteractionResult interactLivingEntity(ItemStack stack, Player player, LivingEntity target, InteractionHand hand) {
        if (player.level().isClientSide()) {
            return InteractionResult.SUCCESS;
        }

        // TODO: Dispatch to Dart via DartBridge when callback system is ready
        LOGGER.debug("DartItemProxy.interactLivingEntity called for handler ID: {}", handlerId);
        return InteractionResult.PASS;
    }
}
