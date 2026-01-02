package com.redstone.blockentity;

import com.redstone.DartBridge;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.protocol.Packet;
import net.minecraft.network.protocol.game.ClientGamePacketListener;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Base block entity that delegates to Dart.
 *
 * Each instance is linked to a Dart-side BlockEntity handler via handlerId.
 * The blockPosHash provides a unique identifier for the block position.
 */
public class DartBlockEntity extends BlockEntity {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBlockEntity");

    /** Handler ID linking to the Dart-side block entity type handler. */
    protected final int handlerId;

    /** Hash of the block position for unique identification. */
    protected final long blockPosHash;

    /** Custom data stored as JSON string, persisted to NBT. */
    protected String customDataJson = "{}";

    public DartBlockEntity(BlockEntityType<?> type, BlockPos pos, BlockState state, int handlerId) {
        super(type, pos, state);
        this.handlerId = handlerId;
        this.blockPosHash = posToHash(pos);
    }

    /**
     * Get the handler ID for this block entity.
     */
    public int getHandlerId() {
        return handlerId;
    }

    /**
     * Get the block position hash.
     */
    public long getBlockPosHash() {
        return blockPosHash;
    }

    /**
     * Convert a BlockPos to a unique long hash.
     * Uses bit packing: X (21 bits) | Z (21 bits) | Y (22 bits)
     */
    public static long posToHash(BlockPos pos) {
        // Pack x, y, z into a single long
        // X and Z can be -30,000,000 to 30,000,000, so need ~26 bits each signed
        // Y is -64 to 319 in modern MC, but can be up to -2048 to 2047 in data packs
        // Use the same encoding as BlockPos.asLong()
        return pos.asLong();
    }

    /**
     * Convert a hash back to a BlockPos.
     */
    public static BlockPos hashToPos(long hash) {
        return BlockPos.of(hash);
    }

    @Override
    protected void loadAdditional(ValueInput valueInput) {
        super.loadAdditional(valueInput);

        // Load custom data from NBT
        this.customDataJson = valueInput.getStringOr("DartData", "{}");

        // Notify Dart that this block entity was loaded
        if (DartBridge.isInitialized()) {
            try {
                DartBridge.onBlockEntityLoad(handlerId, blockPosHash, customDataJson);
            } catch (Exception e) {
                LOGGER.error("Error notifying Dart of block entity load: {}", e.getMessage());
            }
        }
    }

    @Override
    protected void saveAdditional(ValueOutput valueOutput) {
        super.saveAdditional(valueOutput);

        // Get custom data from Dart before saving
        if (DartBridge.isInitialized()) {
            try {
                String dartData = DartBridge.onBlockEntitySave(handlerId, blockPosHash);
                if (dartData != null && !dartData.isEmpty()) {
                    this.customDataJson = dartData;
                }
            } catch (Exception e) {
                LOGGER.error("Error getting block entity data from Dart: {}", e.getMessage());
            }
        }

        // Save custom data to NBT
        valueOutput.putString("DartData", customDataJson);
    }

    @Override
    public CompoundTag getUpdateTag(HolderLookup.Provider registries) {
        // Include custom data in the update tag for client sync
        CompoundTag tag = super.getUpdateTag(registries);
        tag.putString("DartData", customDataJson);
        return tag;
    }

    @Override
    public Packet<ClientGamePacketListener> getUpdatePacket() {
        // Send block entity data to clients when block updates
        return ClientboundBlockEntityDataPacket.create(this);
    }

    @Override
    public void setRemoved() {
        super.setRemoved();

        // Notify Dart that this block entity was removed
        if (DartBridge.isInitialized()) {
            try {
                DartBridge.onBlockEntityRemoved(handlerId, blockPosHash);
            } catch (Exception e) {
                LOGGER.error("Error notifying Dart of block entity removal: {}", e.getMessage());
            }
        }
    }

    /**
     * Get the custom data JSON.
     */
    public String getCustomDataJson() {
        return customDataJson;
    }

    /**
     * Set the custom data JSON.
     */
    public void setCustomDataJson(String json) {
        this.customDataJson = json;
        setChanged();
    }
}
