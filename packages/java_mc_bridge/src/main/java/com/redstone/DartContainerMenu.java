package com.redstone;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.ClickType;
import net.minecraft.world.inventory.Slot;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.SimpleContainer;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

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
    private final String containerTypeId;  // The registered container type ID (e.g., "mymod:diamond_chest")
    private final int rows;
    private final int columns;

    /**
     * Client-side constructor - creates with empty container.
     * Called when the client receives the menu from the server.
     */
    public DartContainerMenu(int containerId, Inventory playerInventory) {
        this(containerId, playerInventory, 3, 9); // Default 3x9 = 27 slots like a chest
    }

    /**
     * Client-side constructor with rows and columns.
     */
    public DartContainerMenu(int containerId, Inventory playerInventory, int rows, int columns) {
        this(containerId, playerInventory, new SimpleContainer(rows * columns), rows, columns, null);
    }

    /**
     * Server-side constructor with ContainerDef.
     * This is used when opening a container from Dart.
     */
    public DartContainerMenu(int containerId, Inventory playerInventory, ContainerDef def, String containerTypeId) {
        this(containerId, playerInventory, new SimpleContainer(def.getSlotCount()), def.rows, def.columns, containerTypeId);
    }

    /**
     * Full constructor with all parameters.
     */
    public DartContainerMenu(int containerId, Inventory playerInventory, SimpleContainer container,
                             int rows, int columns, String containerTypeId) {
        super(RedstoneMenuTypes.DART_CONTAINER_MENU, containerId);
        this.menuId = nextMenuId++;
        this.container = container;
        this.rows = rows;
        this.columns = columns;
        this.containerSlotCount = rows * columns;
        this.containerTypeId = containerTypeId;
        menus.put(menuId, this);

        // Calculate slot positions to center the grid
        // Standard inventory slot is 18x18 pixels
        // Image width for standard chest-like containers is 176 pixels
        int imageWidth = 176;
        int gridWidth = columns * 18;
        int startX = (imageWidth - gridWidth) / 2;
        int startY = 17;

        // Add container slots in a grid
        // Uses DartSlot to enable mayPlace/mayPickup callbacks to Dart
        for (int row = 0; row < rows; row++) {
            for (int col = 0; col < columns; col++) {
                int index = col + row * columns;
                addSlot(new DartSlot(container, index, startX + col * 18, startY + row * 18, menuId, index));
            }
        }

        // Calculate Y position for player inventory based on container rows
        // Standard layout: container slots, then 4 pixel gap, then player inventory
        int playerInvY = startY + (rows * 18) + 14;

        // Add player inventory slots
        addPlayerInventorySlots(playerInventory, 8, playerInvY);
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
     * Get the container type ID (e.g., "mymod:diamond_chest").
     * May be null for legacy menus opened without a type ID.
     */
    public String getContainerTypeId() {
        return containerTypeId;
    }

    /**
     * Get the number of rows.
     */
    public int getRows() {
        return rows;
    }

    /**
     * Get the number of columns.
     */
    public int getColumns() {
        return columns;
    }

    /**
     * Look up a menu by ID.
     */
    public static DartContainerMenu getById(long id) {
        return menus.get(id);
    }

    /**
     * Add a slot to the container at screen coordinates.
     * Uses DartSlot to enable mayPlace/mayPickup callbacks to Dart.
     * @param slotIndex The container slot index (0 to containerSlotCount-1)
     * @param x Screen X coordinate for the slot
     * @param y Screen Y coordinate for the slot
     */
    public void addContainerSlot(int slotIndex, int x, int y) {
        if (slotIndex >= 0 && slotIndex < containerSlotCount) {
            addSlot(new DartSlot(container, slotIndex, x, y, menuId, slotIndex));
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

    @Override
    public void clicked(int slotIndex, int button, ClickType clickType, Player player) {
        if (DartBridge.isInitialized()) {
            String carriedItem = DartBridge.serializeItemStack(getCarried());
            int result = DartBridge.dispatchContainerSlotClick(menuId, slotIndex, button, clickType.ordinal(), carriedItem);
            if (result == -1) {
                return; // Dart handled it, skip default
            }
        }
        super.clicked(slotIndex, button, clickType, player);
    }

    // ==========================================================================
    // Static Helper Methods (called from native code via JNI)
    // ==========================================================================

    /**
     * Get item from container slot.
     * Called from native code.
     * @return "itemId:count:damage:maxDamage" or empty string
     */
    @SuppressWarnings("unused") // Called from native
    public static String getContainerItemImpl(long menuId, int slotIndex) {
        DartContainerMenu menu = menus.get(menuId);
        if (menu == null) return "";
        if (slotIndex < 0 || slotIndex >= menu.slots.size()) return "";

        Slot slot = menu.slots.get(slotIndex);
        ItemStack stack = slot.getItem();
        return DartBridge.serializeItemStack(stack);
    }

    /**
     * Set item in container slot.
     * Called from native code.
     */
    @SuppressWarnings("unused") // Called from native
    public static void setContainerItemImpl(long menuId, int slotIndex, String itemId, int count) {
        DartContainerMenu menu = menus.get(menuId);
        if (menu == null) return;
        if (slotIndex < 0 || slotIndex >= menu.slots.size()) return;

        ItemStack stack;
        if (itemId == null || itemId.isEmpty() || itemId.equals("minecraft:air") || count <= 0) {
            stack = ItemStack.EMPTY;
        } else {
            Optional<Item> itemOpt = BuiltInRegistries.ITEM.getOptional(Identifier.parse(itemId));
            if (itemOpt.isEmpty()) return;
            stack = new ItemStack(itemOpt.get(), count);
        }

        menu.slots.get(slotIndex).set(stack);
    }

    /**
     * Get the total slot count for a menu.
     * Called from native code.
     */
    @SuppressWarnings("unused") // Called from native
    public static int getContainerSlotCountImpl(long menuId) {
        DartContainerMenu menu = menus.get(menuId);
        if (menu == null) return 0;
        return menu.slots.size();
    }

    /**
     * Clear a container slot.
     * Called from native code.
     */
    @SuppressWarnings("unused") // Called from native
    public static void clearContainerSlotImpl(long menuId, int slotIndex) {
        DartContainerMenu menu = menus.get(menuId);
        if (menu == null) return;
        if (slotIndex < 0 || slotIndex >= menu.slots.size()) return;

        menu.slots.get(slotIndex).set(ItemStack.EMPTY);
    }
}
