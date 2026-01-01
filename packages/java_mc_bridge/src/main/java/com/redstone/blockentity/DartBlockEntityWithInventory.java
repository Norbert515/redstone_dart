package com.redstone.blockentity;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.NonNullList;
import net.minecraft.network.chat.Component;
import net.minecraft.world.Container;
import net.minecraft.world.ContainerHelper;
import net.minecraft.world.MenuProvider;
import net.minecraft.world.WorldlyContainer;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Block entity with inventory support.
 *
 * Extends DartBlockEntity with Container and WorldlyContainer implementations
 * for hopper/pipe interaction.
 */
public class DartBlockEntityWithInventory extends DartBlockEntity implements Container, WorldlyContainer, MenuProvider {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBlockEntityWithInventory");

    /** Inventory slots. */
    protected NonNullList<ItemStack> items;

    /** Slot indices for each face direction (for WorldlyContainer). */
    private int[] allSlots;

    /** Display name for the container. */
    protected Component displayName;

    public DartBlockEntityWithInventory(BlockEntityType<?> type, BlockPos pos, BlockState state,
                                        int handlerId, int inventorySize, Component displayName) {
        super(type, pos, state, handlerId);
        this.items = NonNullList.withSize(inventorySize, ItemStack.EMPTY);
        this.displayName = displayName;

        // Create array of all slot indices
        this.allSlots = new int[inventorySize];
        for (int i = 0; i < inventorySize; i++) {
            this.allSlots[i] = i;
        }
    }

    // ========================================================================
    // Container implementation
    // ========================================================================

    @Override
    public int getContainerSize() {
        return items.size();
    }

    @Override
    public boolean isEmpty() {
        for (ItemStack stack : items) {
            if (!stack.isEmpty()) {
                return false;
            }
        }
        return true;
    }

    @Override
    public ItemStack getItem(int slot) {
        if (slot < 0 || slot >= items.size()) {
            return ItemStack.EMPTY;
        }
        return items.get(slot);
    }

    @Override
    public ItemStack removeItem(int slot, int amount) {
        ItemStack result = ContainerHelper.removeItem(items, slot, amount);
        if (!result.isEmpty()) {
            setChanged();
        }
        return result;
    }

    @Override
    public ItemStack removeItemNoUpdate(int slot) {
        return ContainerHelper.takeItem(items, slot);
    }

    @Override
    public void setItem(int slot, ItemStack stack) {
        if (slot < 0 || slot >= items.size()) {
            return;
        }
        items.set(slot, stack);
        stack.limitSize(getMaxStackSize(stack));
        setChanged();
    }

    @Override
    public boolean stillValid(Player player) {
        return Container.stillValidBlockEntity(this, player);
    }

    @Override
    public void clearContent() {
        items.clear();
        setChanged();
    }

    // ========================================================================
    // WorldlyContainer implementation (for hopper interaction)
    // ========================================================================

    @Override
    public int[] getSlotsForFace(Direction side) {
        // By default, allow access to all slots from any direction
        return allSlots;
    }

    @Override
    public boolean canPlaceItemThroughFace(int slot, ItemStack stack, @Nullable Direction direction) {
        return canPlaceItem(slot, stack);
    }

    @Override
    public boolean canTakeItemThroughFace(int slot, ItemStack stack, Direction direction) {
        return true;
    }

    // ========================================================================
    // MenuProvider implementation
    // ========================================================================

    @Override
    public Component getDisplayName() {
        return displayName;
    }

    @Override
    public @Nullable AbstractContainerMenu createMenu(int containerId, Inventory playerInventory, Player player) {
        // Subclasses should override this to provide their specific menu
        return null;
    }

    // ========================================================================
    // Persistence
    // ========================================================================

    @Override
    protected void loadAdditional(ValueInput valueInput) {
        super.loadAdditional(valueInput);

        // Load inventory
        this.items = NonNullList.withSize(getContainerSize(), ItemStack.EMPTY);
        ContainerHelper.loadAllItems(valueInput, this.items);
    }

    @Override
    protected void saveAdditional(ValueOutput valueOutput) {
        super.saveAdditional(valueOutput);

        // Save inventory
        ContainerHelper.saveAllItems(valueOutput, this.items);
    }

    // ========================================================================
    // Helper methods
    // ========================================================================

    /**
     * Get the items list directly.
     */
    protected NonNullList<ItemStack> getItems() {
        return items;
    }

    /**
     * Set the items list directly.
     */
    protected void setItems(NonNullList<ItemStack> items) {
        this.items = items;
    }
}
