package com.example.block.entity;

import com.example.block.ModBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import net.minecraft.network.protocol.Packet;
import net.minecraft.network.protocol.game.ClientGamePacketListener;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import org.jetbrains.annotations.Nullable;

/**
 * Block entity for the Teleporter Pad.
 * Stores the linked destination position.
 */
public class TeleporterPadBlockEntity extends BlockEntity {

    @Nullable
    private BlockPos linkedPos = null;

    public TeleporterPadBlockEntity(BlockPos pos, BlockState state) {
        super(ModBlockEntities.TELEPORTER_PAD_ENTITY, pos, state);
    }

    @Nullable
    public BlockPos getLinkedPos() {
        return linkedPos;
    }

    public void setLinkedPos(@Nullable BlockPos pos) {
        this.linkedPos = pos;
        setChanged();
    }

    public boolean isLinked() {
        return linkedPos != null;
    }

    public void clearLink() {
        this.linkedPos = null;
        setChanged();
    }

    // Save data using 1.21.11 ValueOutput API
    @Override
    protected void saveAdditional(ValueOutput output) {
        super.saveAdditional(output);

        if (linkedPos != null) {
            output.putInt("LinkedX", linkedPos.getX());
            output.putInt("LinkedY", linkedPos.getY());
            output.putInt("LinkedZ", linkedPos.getZ());
            output.putBoolean("HasLink", true);
        } else {
            output.putBoolean("HasLink", false);
        }
    }

    // Load data using 1.21.11 ValueInput API
    @Override
    protected void loadAdditional(ValueInput input) {
        super.loadAdditional(input);

        if (input.getBooleanOr("HasLink", false)) {
            int x = input.getIntOr("LinkedX", 0);
            int y = input.getIntOr("LinkedY", 0);
            int z = input.getIntOr("LinkedZ", 0);
            linkedPos = new BlockPos(x, y, z);
        } else {
            linkedPos = null;
        }
    }

    // Clean up linked pad when this block entity is removed
    @Override
    public void setRemoved() {
        if (linkedPos != null && level != null && !level.isClientSide()) {
            BlockEntity otherBe = level.getBlockEntity(linkedPos);
            if (otherBe instanceof TeleporterPadBlockEntity otherPad) {
                otherPad.linkedPos = null;
                otherPad.setChanged();
            }
        }
        super.setRemoved();
    }

    @Nullable
    @Override
    public Packet<ClientGamePacketListener> getUpdatePacket() {
        return ClientboundBlockEntityDataPacket.create(this);
    }
}
