package com.redstone.blockentity;

import com.redstone.RedstoneMenuTypes;
import net.minecraft.util.Mth;
import net.minecraft.world.Container;
import net.minecraft.world.SimpleContainer;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.ContainerData;
import net.minecraft.world.inventory.FurnaceResultSlot;
import net.minecraft.world.inventory.SimpleContainerData;
import net.minecraft.world.inventory.Slot;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.Level;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Container menu for block entities with processing (furnace-like) behavior.
 *
 * This menu syncs:
 * - 3 inventory slots (input, fuel, output) - like a furnace
 * - 4 data values (lit time, lit duration, cooking progress, cooking total) via ContainerData
 *
 * The ContainerData is automatically synced to the client via addDataSlots(),
 * enabling progress bars and other visual indicators in the GUI.
 */
public class DartBlockEntityMenu extends AbstractContainerMenu {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBlockEntityMenu");

    // Slot indices (matching vanilla furnace layout)
    public static final int INGREDIENT_SLOT = 0;
    public static final int FUEL_SLOT = 1;
    public static final int RESULT_SLOT = 2;
    public static final int SLOT_COUNT = 3;

    // Player inventory slot ranges
    private static final int INV_SLOT_START = 3;
    private static final int INV_SLOT_END = 30;
    private static final int USE_ROW_SLOT_START = 30;
    private static final int USE_ROW_SLOT_END = 39;

    /** The block entity's container (inventory). */
    private final Container container;

    /** Container data for syncing processing state (lit time, progress, etc). */
    private final ContainerData data;

    /** Reference to the level for fuel checks. */
    protected final Level level;

    // ========================================================================
    // Constructors
    // ========================================================================

    /**
     * Client-side constructor - creates with empty container and data.
     * Called when the client receives the menu packet from the server.
     */
    public DartBlockEntityMenu(int containerId, Inventory playerInventory) {
        this(containerId, playerInventory, new SimpleContainer(SLOT_COUNT), new SimpleContainerData(4));
    }

    /**
     * Server-side constructor - creates with actual block entity container and data.
     * Called when opening the menu on the server.
     *
     * @param containerId The container ID assigned by the server
     * @param playerInventory The player's inventory
     * @param container The block entity's container (its inventory)
     * @param data The ContainerData for processing state synchronization
     */
    public DartBlockEntityMenu(int containerId, Inventory playerInventory, Container container, ContainerData data) {
        super(RedstoneMenuTypes.DART_BLOCK_ENTITY_MENU, containerId);

        checkContainerSize(container, SLOT_COUNT);
        checkContainerDataCount(data, 4);

        this.container = container;
        this.data = data;
        this.level = playerInventory.player.level();

        // Add block entity slots (furnace layout: input at 56,17, fuel at 56,53, output at 116,35)
        this.addSlot(new Slot(container, INGREDIENT_SLOT, 56, 17));
        this.addSlot(new DartFuelSlot(this, container, FUEL_SLOT, 56, 53));
        this.addSlot(new FurnaceResultSlot(playerInventory.player, container, RESULT_SLOT, 116, 35));

        // Add player inventory and hotbar slots
        this.addStandardInventorySlots(playerInventory, 8, 84);

        // Register container data for automatic synchronization to client
        // This is the key to making progress bars work!
        this.addDataSlots(data);

        LOGGER.debug("DartBlockEntityMenu created with containerId={}", containerId);
    }

    // ========================================================================
    // Progress accessors (for client GUI rendering)
    // ========================================================================

    /**
     * Get the burn progress (0.0 to 1.0) for the flame icon.
     * This indicates how much fuel is remaining.
     */
    public float getLitProgress() {
        int litDuration = this.data.get(1); // DATA_LIT_DURATION
        if (litDuration == 0) {
            litDuration = 200; // Default value
        }
        return Mth.clamp((float) this.data.get(0) / litDuration, 0.0F, 1.0F);
    }

    /**
     * Get the cooking progress (0.0 to 1.0) for the arrow icon.
     * This indicates how close the item is to being fully cooked.
     */
    public float getBurnProgress() {
        int cookingProgress = this.data.get(2); // DATA_COOKING_PROGRESS
        int cookingTotal = this.data.get(3);    // DATA_COOKING_TOTAL_TIME
        return cookingTotal != 0 && cookingProgress != 0
                ? Mth.clamp((float) cookingProgress / cookingTotal, 0.0F, 1.0F)
                : 0.0F;
    }

    /**
     * Check if the furnace is currently burning fuel.
     */
    public boolean isLit() {
        return this.data.get(0) > 0; // DATA_LIT_TIME > 0
    }

    /**
     * Get a specific data value by index.
     * Index 0: litTime, 1: litDuration, 2: cookingProgress, 3: cookingTotalTime
     */
    public int getDataValue(int index) {
        return this.data.get(index);
    }

    // ========================================================================
    // Fuel checking
    // ========================================================================

    /**
     * Check if an item is valid fuel.
     * Uses the level's fuel values registry.
     */
    public boolean isFuel(ItemStack itemStack) {
        return this.level.fuelValues().isFuel(itemStack);
    }

    // ========================================================================
    // AbstractContainerMenu implementation
    // ========================================================================

    @Override
    public boolean stillValid(Player player) {
        return this.container.stillValid(player);
    }

    @Override
    public ItemStack quickMoveStack(Player player, int slotIndex) {
        ItemStack result = ItemStack.EMPTY;
        Slot slot = this.slots.get(slotIndex);

        if (slot != null && slot.hasItem()) {
            ItemStack slotStack = slot.getItem();
            result = slotStack.copy();

            // Output slot (2) -> move to player inventory
            if (slotIndex == RESULT_SLOT) {
                if (!this.moveItemStackTo(slotStack, INV_SLOT_START, USE_ROW_SLOT_END, true)) {
                    return ItemStack.EMPTY;
                }
                slot.onQuickCraft(slotStack, result);
            }
            // Input or fuel slot (0-1) -> move to player inventory
            else if (slotIndex == INGREDIENT_SLOT || slotIndex == FUEL_SLOT) {
                if (!this.moveItemStackTo(slotStack, INV_SLOT_START, USE_ROW_SLOT_END, false)) {
                    return ItemStack.EMPTY;
                }
            }
            // Player inventory slots -> try to move to block entity slots
            else if (slotIndex >= INV_SLOT_START) {
                // Try fuel slot first if it's valid fuel
                if (this.isFuel(slotStack)) {
                    if (!this.moveItemStackTo(slotStack, FUEL_SLOT, FUEL_SLOT + 1, false)) {
                        // If fuel slot is full, try input slot
                        if (!this.moveItemStackTo(slotStack, INGREDIENT_SLOT, INGREDIENT_SLOT + 1, false)) {
                            // Move between inventory sections
                            if (slotIndex < INV_SLOT_END) {
                                if (!this.moveItemStackTo(slotStack, USE_ROW_SLOT_START, USE_ROW_SLOT_END, false)) {
                                    return ItemStack.EMPTY;
                                }
                            } else {
                                if (!this.moveItemStackTo(slotStack, INV_SLOT_START, INV_SLOT_END, false)) {
                                    return ItemStack.EMPTY;
                                }
                            }
                        }
                    }
                }
                // Not fuel - try input slot
                else {
                    if (!this.moveItemStackTo(slotStack, INGREDIENT_SLOT, INGREDIENT_SLOT + 1, false)) {
                        // Move between inventory sections
                        if (slotIndex < INV_SLOT_END) {
                            if (!this.moveItemStackTo(slotStack, USE_ROW_SLOT_START, USE_ROW_SLOT_END, false)) {
                                return ItemStack.EMPTY;
                            }
                        } else {
                            if (!this.moveItemStackTo(slotStack, INV_SLOT_START, INV_SLOT_END, false)) {
                                return ItemStack.EMPTY;
                            }
                        }
                    }
                }
            }

            if (slotStack.isEmpty()) {
                slot.setByPlayer(ItemStack.EMPTY);
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

    // ========================================================================
    // Fuel slot (inner class)
    // ========================================================================

    /**
     * Slot that only accepts fuel items (and empty buckets for lava bucket swapping).
     */
    public static class DartFuelSlot extends Slot {
        private final DartBlockEntityMenu menu;

        public DartFuelSlot(DartBlockEntityMenu menu, Container container, int slot, int x, int y) {
            super(container, slot, x, y);
            this.menu = menu;
        }

        @Override
        public boolean mayPlace(ItemStack itemStack) {
            return this.menu.isFuel(itemStack) || isBucket(itemStack);
        }

        @Override
        public int getMaxStackSize(ItemStack itemStack) {
            return isBucket(itemStack) ? 1 : super.getMaxStackSize(itemStack);
        }

        public static boolean isBucket(ItemStack itemStack) {
            return itemStack.is(Items.BUCKET);
        }
    }
}
