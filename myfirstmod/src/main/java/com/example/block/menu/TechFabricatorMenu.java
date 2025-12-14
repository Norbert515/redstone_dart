package com.example.block.menu;

import com.example.block.entity.TechFabricatorBlockEntity;
import net.minecraft.world.Container;
import net.minecraft.world.SimpleContainer;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.MenuType;
import net.minecraft.world.inventory.Slot;
import net.minecraft.world.item.ItemStack;

/**
 * Menu (ScreenHandler) for the Tech Fabricator.
 * Manages the GUI slots and item transfer logic.
 */
public class TechFabricatorMenu extends AbstractContainerMenu {

    private final Container container;

    // Client-side constructor (called when receiving from server)
    public TechFabricatorMenu(int containerId, Inventory playerInventory) {
        this(containerId, playerInventory, new SimpleContainer(10));
    }

    // Server-side constructor (called when opening)
    public TechFabricatorMenu(int containerId, Inventory playerInventory, Container container) {
        super(ModMenuTypes.TECH_FABRICATOR_MENU, containerId);
        checkContainerSize(container, 10);
        this.container = container;
        container.startOpen(playerInventory.player);

        // Add 3x3 input grid (slots 0-8)
        // Positioned in the left area of the GUI
        for (int row = 0; row < 3; row++) {
            for (int col = 0; col < 3; col++) {
                this.addSlot(new Slot(container, col + row * 3, 30 + col * 18, 17 + row * 18));
            }
        }

        // Add output slot (slot 9) - positioned on the right
        this.addSlot(new OutputSlot(container, 9, 124, 35));

        // Add player inventory slots (27 slots)
        for (int row = 0; row < 3; row++) {
            for (int col = 0; col < 9; col++) {
                this.addSlot(new Slot(playerInventory, col + row * 9 + 9, 8 + col * 18, 84 + row * 18));
            }
        }

        // Add player hotbar slots (9 slots)
        for (int col = 0; col < 9; col++) {
            this.addSlot(new Slot(playerInventory, col, 8 + col * 18, 142));
        }
    }

    @Override
    public boolean stillValid(Player player) {
        return container.stillValid(player);
    }

    // Handle shift-clicking items between slots
    @Override
    public ItemStack quickMoveStack(Player player, int index) {
        ItemStack result = ItemStack.EMPTY;
        Slot slot = this.slots.get(index);

        if (slot != null && slot.hasItem()) {
            ItemStack slotStack = slot.getItem();
            result = slotStack.copy();

            // If clicking in the fabricator slots (0-9)
            if (index < 10) {
                // Move to player inventory
                if (!this.moveItemStackTo(slotStack, 10, 46, true)) {
                    return ItemStack.EMPTY;
                }
            }
            // If clicking in player inventory (10-36) or hotbar (37-45)
            else {
                // Try to move to input slots (0-8), not output
                if (!this.moveItemStackTo(slotStack, 0, 9, false)) {
                    // If inventory, try hotbar
                    if (index < 37) {
                        if (!this.moveItemStackTo(slotStack, 37, 46, false)) {
                            return ItemStack.EMPTY;
                        }
                    }
                    // If hotbar, try inventory
                    else {
                        if (!this.moveItemStackTo(slotStack, 10, 37, false)) {
                            return ItemStack.EMPTY;
                        }
                    }
                }
            }

            if (slotStack.isEmpty()) {
                slot.set(ItemStack.EMPTY);
            } else {
                slot.setChanged();
            }

            if (slotStack.getCount() == result.getCount()) {
                return ItemStack.EMPTY;
            }

            slot.onTake(player, slotStack);
        }

        return result;
    }

    @Override
    public void removed(Player player) {
        super.removed(player);
        container.stopOpen(player);
    }

    // Output slot that doesn't accept items (only for taking)
    private static class OutputSlot extends Slot {
        public OutputSlot(Container container, int index, int x, int y) {
            super(container, index, x, y);
        }

        @Override
        public boolean mayPlace(ItemStack stack) {
            return false; // Can't place items in output slot
        }
    }
}
