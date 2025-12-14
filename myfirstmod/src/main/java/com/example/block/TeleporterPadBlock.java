package com.example.block;

import com.example.ExampleMod;
import com.example.block.entity.ModBlockEntities;
import com.example.block.entity.TeleporterPadBlockEntity;
import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.InsideBlockEffectApplier;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Teleporter Pad Block
 *
 * How to use:
 * 1. Right-click with Ender Pearl to start linking
 * 2. Right-click another Teleporter Pad with Ender Pearl to complete the link
 * 3. Step on either pad to teleport to the other!
 * 4. Right-click with empty hand to see link status
 * 5. Sneak + right-click to unlink
 */
public class TeleporterPadBlock extends BaseEntityBlock {

    private static final VoxelShape SHAPE = Block.box(0, 0, 0, 16, 2, 16);
    private static final Map<UUID, BlockPos> linkingPlayers = new HashMap<>();
    private static final Map<UUID, Long> teleportCooldowns = new HashMap<>();
    private static final long COOLDOWN_MS = 2000;

    public static final MapCodec<TeleporterPadBlock> CODEC = simpleCodec(TeleporterPadBlock::new);

    public TeleporterPadBlock(Properties properties) {
        super(properties);
    }

    @Override
    protected MapCodec<? extends BaseEntityBlock> codec() {
        return CODEC;
    }

    @Nullable
    @Override
    public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
        return new TeleporterPadBlockEntity(pos, state);
    }

    @Override
    protected RenderShape getRenderShape(BlockState state) {
        return RenderShape.MODEL;
    }

    @Override
    protected VoxelShape getShape(BlockState state, BlockGetter world, BlockPos pos, CollisionContext context) {
        return SHAPE;
    }

    // Handle right-click with item
    @Override
    protected InteractionResult useItemOn(ItemStack stack, BlockState state, Level world, BlockPos pos,
                                           Player player, InteractionHand hand, BlockHitResult hit) {
        if (world.isClientSide()) {
            return InteractionResult.SUCCESS;
        }

        BlockEntity be = world.getBlockEntity(pos);
        if (!(be instanceof TeleporterPadBlockEntity padEntity)) {
            return InteractionResult.PASS;
        }

        // Ender Pearl - start/complete linking
        if (stack.is(Items.ENDER_PEARL)) {
            UUID playerId = player.getUUID();

            if (linkingPlayers.containsKey(playerId)) {
                BlockPos firstPos = linkingPlayers.get(playerId);

                if (firstPos.equals(pos)) {
                    player.displayClientMessage(Component.literal("Cannot link a pad to itself!"), true);
                    return InteractionResult.FAIL;
                }

                BlockEntity firstBe = world.getBlockEntity(firstPos);
                if (firstBe instanceof TeleporterPadBlockEntity firstPad) {
                    firstPad.setLinkedPos(pos);
                    padEntity.setLinkedPos(firstPos);

                    if (!player.getAbilities().instabuild) {
                        stack.shrink(1);
                    }

                    linkingPlayers.remove(playerId);
                    player.displayClientMessage(Component.literal("Teleporter pads linked!"), true);
                    world.playSound(null, pos, SoundEvents.ENDERMAN_TELEPORT, SoundSource.BLOCKS, 1.0f, 1.5f);

                    ExampleMod.LOGGER.info("Linked teleporter pads at {} and {}", firstPos, pos);
                } else {
                    player.displayClientMessage(Component.literal("First pad no longer exists!"), true);
                    linkingPlayers.remove(playerId);
                }
            } else {
                linkingPlayers.put(playerId, pos);
                player.displayClientMessage(
                        Component.literal("First pad selected. Right-click another pad with Ender Pearl to link."),
                        true);
                world.playSound(null, pos, SoundEvents.EXPERIENCE_ORB_PICKUP, SoundSource.BLOCKS, 1.0f, 1.0f);
            }

            return InteractionResult.SUCCESS;
        }

        return InteractionResult.PASS;
    }

    // Handle right-click with empty hand
    @Override
    protected InteractionResult useWithoutItem(BlockState state, Level world, BlockPos pos,
                                                Player player, BlockHitResult hit) {
        if (world.isClientSide()) {
            return InteractionResult.SUCCESS;
        }

        BlockEntity be = world.getBlockEntity(pos);
        if (!(be instanceof TeleporterPadBlockEntity padEntity)) {
            return InteractionResult.PASS;
        }

        if (player.isShiftKeyDown()) {
            if (padEntity.isLinked()) {
                BlockPos linkedPos = padEntity.getLinkedPos();
                if (linkedPos != null) {
                    BlockEntity otherBe = world.getBlockEntity(linkedPos);
                    if (otherBe instanceof TeleporterPadBlockEntity otherPad) {
                        otherPad.clearLink();
                    }
                }
                padEntity.clearLink();
                player.displayClientMessage(Component.literal("Teleporter unlinked!"), true);
                world.playSound(null, pos, SoundEvents.CHAIN_BREAK, SoundSource.BLOCKS, 1.0f, 1.0f);
            } else {
                player.displayClientMessage(Component.literal("This pad is not linked."), true);
            }
        } else {
            if (padEntity.isLinked()) {
                BlockPos linked = padEntity.getLinkedPos();
                player.displayClientMessage(
                        Component.literal("Linked to: " + linked.getX() + ", " + linked.getY() + ", " + linked.getZ()),
                        true);
            } else {
                player.displayClientMessage(
                        Component.literal("Not linked. Use Ender Pearl to link to another pad."),
                        true);
            }
        }

        return InteractionResult.SUCCESS;
    }

    // Teleport when entity steps on the pad - new 1.21.11 signature
    @Override
    protected void entityInside(BlockState state, Level world, BlockPos pos, Entity entity,
                                 InsideBlockEffectApplier effectApplier, boolean movedByPiston) {
        if (world.isClientSide() || !(entity instanceof Player player)) {
            return;
        }

        BlockEntity be = world.getBlockEntity(pos);
        if (!(be instanceof TeleporterPadBlockEntity padEntity) || !padEntity.isLinked()) {
            return;
        }

        UUID playerId = player.getUUID();
        long currentTime = System.currentTimeMillis();
        Long lastTeleport = teleportCooldowns.get(playerId);

        if (lastTeleport != null && (currentTime - lastTeleport) < COOLDOWN_MS) {
            return;
        }

        BlockPos targetPos = padEntity.getLinkedPos();
        if (targetPos == null) return;

        BlockState targetState = world.getBlockState(targetPos);
        if (!targetState.is(ModBlocks.TELEPORTER_PAD)) {
            player.displayClientMessage(Component.literal("Destination pad was destroyed!"), true);
            padEntity.clearLink();
            return;
        }

        teleportCooldowns.put(playerId, currentTime);

        double targetX = targetPos.getX() + 0.5;
        double targetY = targetPos.getY() + 0.2;
        double targetZ = targetPos.getZ() + 0.5;

        player.teleportTo(targetX, targetY, targetZ);

        world.playSound(null, pos, SoundEvents.ENDERMAN_TELEPORT, SoundSource.PLAYERS, 1.0f, 1.0f);
        world.playSound(null, targetPos, SoundEvents.ENDERMAN_TELEPORT, SoundSource.PLAYERS, 1.0f, 1.0f);

        if (world instanceof ServerLevel serverWorld) {
            serverWorld.sendParticles(
                    net.minecraft.core.particles.ParticleTypes.PORTAL,
                    pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5,
                    30, 0.5, 0.5, 0.5, 0.1
            );
            serverWorld.sendParticles(
                    net.minecraft.core.particles.ParticleTypes.PORTAL,
                    targetX, targetY + 0.5, targetZ,
                    30, 0.5, 0.5, 0.5, 0.1
            );
        }

        ExampleMod.LOGGER.info("Teleported {} from {} to {}", player.getName().getString(), pos, targetPos);
    }

    // Called when neighbors are affected after removal - clean up linked pads
    @Override
    protected void affectNeighborsAfterRemoval(BlockState state, ServerLevel world, BlockPos pos, boolean movedByPiston) {
        // This is called after the block is removed, so we can't access the block entity
        // The cleanup is handled in the block entity itself via setRemoved()
        super.affectNeighborsAfterRemoval(state, world, pos, movedByPiston);
    }
}
