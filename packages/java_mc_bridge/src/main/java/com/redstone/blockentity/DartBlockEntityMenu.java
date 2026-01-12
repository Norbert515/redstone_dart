package com.redstone.blockentity;

import com.redstone.RedstoneMenuTypes;
import net.minecraft.world.Container;
import net.minecraft.world.SimpleContainer;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.ContainerData;
import net.minecraft.world.inventory.SimpleContainerData;
import net.minecraft.world.inventory.Slot;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Generic container menu for all Dart block entities.
 *
 * This unified menu supports:
 * - Dynamic inventory sizes (1 slot to 54+ slots)
 * - Grid-based slot layout (9 columns, variable rows)
 * - Dynamic ContainerData synchronization
 *
 * The menu is block-type agnostic - it doesn't care whether the underlying
 * block entity is a chest, furnace, or any other type. All UI rendering
 * and slot semantics are handled by Flutter/Dart.
 *
 * Implements {@link DartMenuProvider} to support unified ContainerData access
 * from client-side caching code.
 */
public class DartBlockEntityMenu extends AbstractContainerMenu implements DartMenuProvider {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBlockEntityMenu");

    /** Standard number of columns in the grid (like a chest). */
    private static final int COLUMNS = 9;

    /** Standard container width in pixels. */
    private static final int IMAGE_WIDTH = 176;

    /** The block entity's container (inventory). */
    private final Container container;

    /** Container data for syncing custom state to client. */
    private final ContainerData data;

    /** Reference to the level. */
    protected final Level level;

    /** Number of rows in the container grid. */
    private final int rows;

    /** Total slots in the container (rows * COLUMNS). */
    private final int containerSlotCount;

    // Player inventory slot indices (calculated based on container size)
    private final int invSlotStart;
    private final int invSlotEnd;
    private final int hotbarSlotStart;
    private final int hotbarSlotEnd;

    // ========================================================================
    // Constructors
    // ========================================================================

    /**
     * Client-side constructor - creates with empty container and data.
     * Called when the client receives the menu packet from the server.
     * Default to 3 rows * 9 columns (27 slots) like a standard chest.
     */
    public DartBlockEntityMenu(int containerId, Inventory playerInventory) {
        this(containerId, playerInventory, new SimpleContainer(27), new SimpleContainerData(4));
    }

    /**
     * Server-side constructor - creates with actual block entity container and data.
     * Called when opening the menu on the server.
     *
     * @param containerId The container ID assigned by the server
     * @param playerInventory The player's inventory
     * @param container The block entity's container (its inventory)
     * @param data The ContainerData for state synchronization
     */
    public DartBlockEntityMenu(int containerId, Inventory playerInventory, Container container, ContainerData data) {
        super(RedstoneMenuTypes.DART_BLOCK_ENTITY_MENU, containerId);

        // Calculate rows from container size (round up to handle non-multiples of 9)
        int inventorySize = container.getContainerSize();
        this.rows = (inventorySize + COLUMNS - 1) / COLUMNS;
        this.containerSlotCount = inventorySize;

        checkContainerSize(container, inventorySize);
        // Use the data's own count for flexibility
        checkContainerDataCount(data, data.getCount());

        this.container = container;
        this.data = data;
        this.level = playerInventory.player.level();

        // Calculate slot index ranges for quick move
        this.invSlotStart = containerSlotCount;
        this.invSlotEnd = containerSlotCount + 27; // 3 rows * 9 columns
        this.hotbarSlotStart = invSlotEnd;
        this.hotbarSlotEnd = hotbarSlotStart + 9;

        // Calculate slot positions to center the grid
        // Standard slot is 18x18 pixels
        int gridWidth = COLUMNS * 18;
        int startX = (IMAGE_WIDTH - gridWidth) / 2;
        int startY = 17;

        // Add container slots in a grid
        for (int row = 0; row < rows; row++) {
            for (int col = 0; col < COLUMNS; col++) {
                int index = col + row * COLUMNS;
                if (index < inventorySize) {
                    this.addSlot(new Slot(container, index, startX + col * 18, startY + row * 18));
                }
            }
        }

        // Calculate Y position for player inventory based on container rows
        // Standard layout: container slots, then 14 pixel gap, then player inventory
        int playerInvY = startY + (rows * 18) + 14;

        // Add player inventory and hotbar slots
        addPlayerInventorySlots(playerInventory, 8, playerInvY);

        // Register container data for automatic synchronization to client
        this.addDataSlots(data);

        // Notify container that it's being opened
        this.container.startOpen(playerInventory.player);

        LOGGER.debug("DartBlockEntityMenu created: containerId={}, rows={}, columns={}, slots={}, dataSlots={}",
                     containerId, rows, COLUMNS, containerSlotCount, data.getCount());
    }

    /**
     * Add player inventory slots (main inventory + hotbar).
     */
    private void addPlayerInventorySlots(Inventory playerInventory, int startX, int startY) {
        // Main inventory (3 rows of 9)
        for (int row = 0; row < 3; row++) {
            for (int col = 0; col < 9; col++) {
                this.addSlot(new Slot(playerInventory, col + row * 9 + 9,
                                      startX + col * 18, startY + row * 18));
            }
        }

        // Hotbar (1 row of 9, 4 pixels below main inventory = 58 pixel offset)
        for (int col = 0; col < 9; col++) {
            this.addSlot(new Slot(playerInventory, col, startX + col * 18, startY + 58));
        }
    }

    @Override
    public void removed(Player player) {
        super.removed(player);
        this.container.stopOpen(player);
    }

    // ========================================================================
    // Data accessors (for client GUI rendering)
    // ========================================================================

    /**
     * Get a specific data value by index.
     */
    @Override
    public int getDataValue(int index) {
        return this.data.get(index);
    }

    /**
     * Get the number of data slots in this container.
     */
    @Override
    public int getDataSlotCount() {
        return this.data.getCount();
    }

    /**
     * Get the number of rows in the container grid.
     */
    public int getRows() {
        return rows;
    }

    /**
     * Get the number of columns in the container grid.
     */
    public int getColumns() {
        return COLUMNS;
    }

    /**
     * Get the container slot count (actual inventory size).
     */
    public int getContainerSlotCount() {
        return containerSlotCount;
    }

    // ========================================================================
    // AbstractContainerMenu implementation
    // ========================================================================

    @Override
    public boolean stillValid(Player player) {
        return this.container.stillValid(player);
    }

    /**
     * Called when ContainerData changes are synced to the client.
     * We override this to push the changes to Dart via DartBridgeClient.
     */
    @Override
    public void setData(int index, int value) {
        super.setData(index, value);

        // Only push to Dart on client side
        if (this.level.isClientSide()) {
            LOGGER.debug("setData called: index={}, value={}, containerId={}", index, value, this.containerId);
            // Call DartBridgeClient via reflection to avoid compile-time dependency
            // on client-only code. DartBridgeClient is in src/client/ and not available on server.
            try {
                Class<?> clientBridge = Class.forName("com.redstone.DartBridgeClient");
                java.lang.reflect.Method dispatchMethod = clientBridge.getMethod(
                    "dispatchContainerDataChanged", int.class, int.class, int.class);
                dispatchMethod.invoke(null, this.containerId, index, value);
            } catch (ClassNotFoundException e) {
                // Expected on server - DartBridgeClient doesn't exist there
            } catch (Exception e) {
                LOGGER.warn("Failed to dispatch container data changed to Dart: {}", e.getMessage());
            }
        }
    }

    @Override
    public ItemStack quickMoveStack(Player player, int slotIndex) {
        ItemStack result = ItemStack.EMPTY;
        Slot slot = this.slots.get(slotIndex);

        if (slot != null && slot.hasItem()) {
            ItemStack slotStack = slot.getItem();
            result = slotStack.copy();

            // Container slot -> move to player inventory
            if (slotIndex < containerSlotCount) {
                if (!this.moveItemStackTo(slotStack, invSlotStart, hotbarSlotEnd, true)) {
                    return ItemStack.EMPTY;
                }
            }
            // Player inventory slot -> move to container
            else if (slotIndex < hotbarSlotEnd) {
                if (!this.moveItemStackTo(slotStack, 0, containerSlotCount, false)) {
                    // If container is full, move between inventory sections
                    if (slotIndex < invSlotEnd) {
                        // Main inventory -> hotbar
                        if (!this.moveItemStackTo(slotStack, hotbarSlotStart, hotbarSlotEnd, false)) {
                            return ItemStack.EMPTY;
                        }
                    } else {
                        // Hotbar -> main inventory
                        if (!this.moveItemStackTo(slotStack, invSlotStart, invSlotEnd, false)) {
                            return ItemStack.EMPTY;
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
}
