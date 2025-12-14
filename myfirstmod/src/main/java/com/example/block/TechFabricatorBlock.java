package com.example.block;

import com.example.block.entity.TechFabricatorBlockEntity;
import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;
import org.jetbrains.annotations.Nullable;

/**
 * Tech Fabricator - A high-tech crafting station for creating Lucky Blocks and Teleporter Pads.
 * Right-click to open the crafting GUI.
 */
public class TechFabricatorBlock extends BaseEntityBlock {

    public static final MapCodec<TechFabricatorBlock> CODEC = simpleCodec(TechFabricatorBlock::new);

    public TechFabricatorBlock(Properties properties) {
        super(properties);
    }

    @Override
    protected MapCodec<? extends BaseEntityBlock> codec() {
        return CODEC;
    }

    @Nullable
    @Override
    public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
        return new TechFabricatorBlockEntity(pos, state);
    }

    @Override
    protected RenderShape getRenderShape(BlockState state) {
        return RenderShape.MODEL;
    }

    // Open GUI when right-clicked
    @Override
    protected InteractionResult useWithoutItem(BlockState state, Level world, BlockPos pos,
                                                Player player, BlockHitResult hit) {
        if (!world.isClientSide()) {
            BlockEntity be = world.getBlockEntity(pos);
            if (be instanceof TechFabricatorBlockEntity fabricator) {
                player.openMenu(fabricator);
            }
        }
        return InteractionResult.SUCCESS;
    }

    // Drop items when block is broken
    @Override
    protected void affectNeighborsAfterRemoval(BlockState state, net.minecraft.server.level.ServerLevel world,
                                                BlockPos pos, boolean movedByPiston) {
        // Items are dropped by the block entity's setRemoved method
        super.affectNeighborsAfterRemoval(state, world, pos, movedByPiston);
    }
}
