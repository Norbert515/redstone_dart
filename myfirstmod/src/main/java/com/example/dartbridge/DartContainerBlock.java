package com.example.dartbridge;

import net.minecraft.world.SimpleContainer;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.SimpleMenuProvider;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;

/**
 * A block that opens a Dart-controlled container screen when right-clicked.
 *
 * This block demonstrates how to integrate Dart container screens with Minecraft.
 * When a player right-clicks this block:
 * 1. Server creates a DartContainerMenu with a SimpleContainer
 * 2. Network packet is sent to client
 * 3. Client opens DartContainerScreen
 * 4. Dart receives callbacks to render the background and manage slots
 *
 * The container has 9 slots (3x3 grid) that can hold any item.
 * Items are stored in a SimpleContainer that exists only while the menu is open.
 */
public class DartContainerBlock extends Block {
    private static final int SLOT_COUNT = 9;

    public DartContainerBlock(Properties properties) {
        super(properties);
    }

    @Override
    protected InteractionResult useWithoutItem(BlockState state, Level level, BlockPos pos,
                                                Player player, BlockHitResult hit) {
        if (!level.isClientSide() && player instanceof ServerPlayer serverPlayer) {
            // Create a new container for this interaction
            SimpleContainer container = new SimpleContainer(SLOT_COUNT);

            // Open the menu with 3 rows x 3 columns (9 slots)
            serverPlayer.openMenu(new SimpleMenuProvider(
                (containerId, playerInventory, p) ->
                    new DartContainerMenu(containerId, playerInventory, container, 3, 3, null),
                Component.literal("Dart Container")
            ));
        }
        return InteractionResult.SUCCESS;
    }
}
