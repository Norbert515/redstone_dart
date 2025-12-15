package com.example.dartbridge;

import com.example.block.menu.ModMenuTypes;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.Slot;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.SimpleContainer;

import java.util.HashMap;
import java.util.Map;

/**
 * A container menu that delegates to Dart for custom inventory GUIs.
 *
 * This menu allows Dart code to define custom inventory screens with
 * real item slots that support proper item transfer and synchronization.
 */
public class DartContainerMenu extends AbstractContainerMenu {
    private static long nextMenuId = 1;
    private static final Map<Long, DartContainerMenu> menus = new HashMap<>();

    private final long menuId;
    private final SimpleContainer container;
    private final int containerSlotCount;

    /**
     * Client-side constructor - creates with empty container.
     * Called when the client receives the menu from the server.
     */
    public DartContainerMenu(int containerId, Inventory playerInventory) {
        this(containerId, playerInventory, 27); // Default 27 slots like a chest
    }

    /**
     * Client-side constructor with slot count.
     */
    public DartContainerMenu(int containerId, Inventory playerInventory, int slotCount) {
        this(containerId, playerInventory, new SimpleContainer(slotCount), slotCount);
    }

    /**
     * Server-side constructor with existing container.
     */
    public DartContainerMenu(int containerId, Inventory playerInventory, SimpleContainer container, int slotCount) {
        super(ModMenuTypes.DART_CONTAINER_MENU, containerId);
        this.menuId = nextMenuId++;
        this.container = container;
        this.containerSlotCount = slotCount;
        menus.put(menuId, this);

        // Add container slots in a 3x3 grid (centered at x=62)
        for (int row = 0; row < 3; row++) {
            for (int col = 0; col < 3; col++) {
                int index = col + row * 3;
                if (index < slotCount) {
                    addSlot(new Slot(container, index, 62 + col * 18, 17 + row * 18));
                }
            }
        }

        // Add player inventory slots
        addPlayerInventorySlots(playerInventory, 8, 84);
    }

    /**
     * Get this menu's unique ID for Dart callbacks.
     */
    public long getMenuId() {
        return menuId;
    }

    /**
     * Get the container slot count.
     */
    public int getContainerSlotCount() {
        return containerSlotCount;
    }

    /**
     * Look up a menu by ID.
     */
    public static DartContainerMenu getById(long id) {
        return menus.get(id);
    }

    /**
     * Add a slot to the container at screen coordinates.
     * @param slotIndex The container slot index (0 to containerSlotCount-1)
     * @param x Screen X coordinate for the slot
     * @param y Screen Y coordinate for the slot
     */
    public void addContainerSlot(int slotIndex, int x, int y) {
        if (slotIndex >= 0 && slotIndex < containerSlotCount) {
            addSlot(new Slot(container, slotIndex, x, y));
        }
    }

    /**
     * Add player inventory slots at the standard position.
     * @param playerInventory The player's inventory
     * @param startX X coordinate for the first slot
     * @param startY Y coordinate for the main inventory (hotbar will be 58 pixels below)
     */
    public void addPlayerInventorySlots(Inventory playerInventory, int startX, int startY) {
        // Main inventory (3 rows of 9)
        for (int row = 0; row < 3; row++) {
            for (int col = 0; col < 9; col++) {
                addSlot(new Slot(playerInventory, col + row * 9 + 9, startX + col * 18, startY + row * 18));
            }
        }

        // Hotbar (1 row of 9)
        for (int col = 0; col < 9; col++) {
            addSlot(new Slot(playerInventory, col, startX + col * 18, startY + 58));
        }
    }

    @Override
    public ItemStack quickMoveStack(Player player, int slotIndex) {
        ItemStack result = ItemStack.EMPTY;
        Slot slot = this.slots.get(slotIndex);

        if (slot != null && slot.hasItem()) {
            ItemStack slotStack = slot.getItem();
            result = slotStack.copy();

            // If clicking container slot, try to move to player inventory
            if (slotIndex < containerSlotCount) {
                if (!this.moveItemStackTo(slotStack, containerSlotCount, this.slots.size(), true)) {
                    return ItemStack.EMPTY;
                }
            } else {
                // If clicking player inventory, try to move to container
                if (!this.moveItemStackTo(slotStack, 0, containerSlotCount, false)) {
                    return ItemStack.EMPTY;
                }
            }

            if (slotStack.isEmpty()) {
                slot.set(ItemStack.EMPTY);
            } else {
                slot.setChanged();
            }
        }

        return result;
    }

    @Override
    public boolean stillValid(Player player) {
        return true;
    }

    @Override
    public void removed(Player player) {
        super.removed(player);
        menus.remove(menuId);
    }
}
