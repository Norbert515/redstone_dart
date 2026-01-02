package com.redstone.blockentity;

import com.redstone.DartBridge;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.inventory.ContainerData;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Block entity with furnace-style processing support.
 *
 * Extends DartBlockEntityWithInventory with processing state (lit time, cooking progress)
 * and ContainerData for syncing to clients.
 */
public class DartProcessingBlockEntity extends DartBlockEntityWithInventory {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartProcessingBlockEntity");

    // Processing state - 4 values synced via ContainerData
    public static final int DATA_LIT_TIME = 0;
    public static final int DATA_LIT_DURATION = 1;
    public static final int DATA_COOKING_PROGRESS = 2;
    public static final int DATA_COOKING_TOTAL_TIME = 3;
    public static final int NUM_DATA_VALUES = 4;

    /** Current remaining burn time (ticks). */
    protected int litTime = 0;

    /** Total burn duration of current fuel (for progress calculation). */
    protected int litDuration = 0;

    /** Current cooking progress (ticks). */
    protected int cookingProgress = 0;

    /** Total cooking time required (ticks). */
    protected int cookingTotalTime = 200; // Default 10 seconds (200 ticks)

    /** ContainerData for syncing processing state to client GUI. */
    protected final ContainerData containerData = new ContainerData() {
        @Override
        public int get(int index) {
            // First try to get from Dart if initialized
            if (DartBridge.isInitialized()) {
                try {
                    return DartBridge.getBlockEntityDataSlot(handlerId, blockPosHash, index);
                } catch (Exception e) {
                    // Fall through to local values
                }
            }

            // Use local values
            return switch (index) {
                case DATA_LIT_TIME -> litTime;
                case DATA_LIT_DURATION -> litDuration;
                case DATA_COOKING_PROGRESS -> cookingProgress;
                case DATA_COOKING_TOTAL_TIME -> cookingTotalTime;
                default -> 0;
            };
        }

        @Override
        public void set(int index, int value) {
            // First try to set in Dart if initialized
            if (DartBridge.isInitialized()) {
                try {
                    DartBridge.setBlockEntityDataSlot(handlerId, blockPosHash, index, value);
                } catch (Exception e) {
                    // Fall through to local values
                }
            }

            // Update local values
            switch (index) {
                case DATA_LIT_TIME -> litTime = value;
                case DATA_LIT_DURATION -> litDuration = value;
                case DATA_COOKING_PROGRESS -> cookingProgress = value;
                case DATA_COOKING_TOTAL_TIME -> cookingTotalTime = value;
            }
        }

        @Override
        public int getCount() {
            return NUM_DATA_VALUES;
        }
    };

    public DartProcessingBlockEntity(BlockEntityType<?> type, BlockPos pos, BlockState state,
                                     int handlerId, int inventorySize, Component displayName) {
        super(type, pos, state, handlerId, inventorySize, displayName);
    }

    // ========================================================================
    // Processing state accessors
    // ========================================================================

    public int getLitTime() {
        return litTime;
    }

    public void setLitTime(int litTime) {
        this.litTime = litTime;
    }

    public int getLitDuration() {
        return litDuration;
    }

    public void setLitDuration(int litDuration) {
        this.litDuration = litDuration;
    }

    public int getCookingProgress() {
        return cookingProgress;
    }

    public void setCookingProgress(int cookingProgress) {
        this.cookingProgress = cookingProgress;
    }

    public int getCookingTotalTime() {
        return cookingTotalTime;
    }

    public void setCookingTotalTime(int cookingTotalTime) {
        this.cookingTotalTime = cookingTotalTime;
    }

    public boolean isLit() {
        return litTime > 0;
    }

    /**
     * Get the ContainerData for menu synchronization.
     */
    public ContainerData getContainerData() {
        return containerData;
    }

    // ========================================================================
    // MenuProvider implementation
    // ========================================================================

    @Override
    public net.minecraft.world.inventory.AbstractContainerMenu createMenu(
            int containerId,
            net.minecraft.world.entity.player.Inventory playerInventory,
            net.minecraft.world.entity.player.Player player) {
        // Create the block entity menu with our container (inventory) and data (progress)
        return new DartBlockEntityMenu(containerId, playerInventory, this, this.containerData);
    }

    // ========================================================================
    // Tick handling
    // ========================================================================

    /**
     * Server tick method - called each game tick for this block entity.
     * Delegates to Dart for processing logic.
     */
    public static void serverTick(Level level, BlockPos pos, BlockState state,
                                  DartProcessingBlockEntity blockEntity) {
        if (level.isClientSide()) {
            return;
        }

        if (DartBridge.isInitialized()) {
            try {
                DartBridge.onBlockEntityTick(blockEntity.handlerId, blockEntity.blockPosHash);
            } catch (Exception e) {
                LOGGER.error("Error during block entity tick: {}", e.getMessage());
            }
        }
    }

    // ========================================================================
    // Persistence
    // ========================================================================

    @Override
    protected void loadAdditional(ValueInput valueInput) {
        super.loadAdditional(valueInput);

        // Load processing state
        this.litTime = valueInput.getShortOr("LitTime", (short) 0);
        this.litDuration = valueInput.getShortOr("LitDuration", (short) 0);
        this.cookingProgress = valueInput.getShortOr("CookingProgress", (short) 0);
        this.cookingTotalTime = valueInput.getShortOr("CookingTotalTime", (short) 200);
    }

    @Override
    protected void saveAdditional(ValueOutput valueOutput) {
        super.saveAdditional(valueOutput);

        // Save processing state
        valueOutput.putShort("LitTime", (short) litTime);
        valueOutput.putShort("LitDuration", (short) litDuration);
        valueOutput.putShort("CookingProgress", (short) cookingProgress);
        valueOutput.putShort("CookingTotalTime", (short) cookingTotalTime);
    }
}
