package com.redstone;

import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.Container;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.Slot;
import net.minecraft.world.item.ItemStack;

/**
 * A slot that delegates mayPlace and mayPickup decisions to Dart handlers.
 */
public class DartSlot extends Slot {
    private final long menuId;
    private final int dartSlotIndex;

    public DartSlot(Container container, int slotIndex, int x, int y, long menuId, int dartSlotIndex) {
        super(container, slotIndex, x, y);
        this.menuId = menuId;
        this.dartSlotIndex = dartSlotIndex;
    }

    @Override
    public boolean mayPlace(ItemStack stack) {
        if (DartBridge.isInitialized()) {
            String itemData = DartBridge.serializeItemStack(stack);
            return DartBridge.dispatchContainerMayPlace(menuId, dartSlotIndex, itemData);
        }
        return super.mayPlace(stack);
    }

    @Override
    public boolean mayPickup(Player player) {
        if (DartBridge.isInitialized()) {
            return DartBridge.dispatchContainerMayPickup(menuId, dartSlotIndex);
        }
        return super.mayPickup(player);
    }

    /**
     * Get the menu ID this slot belongs to.
     */
    public long getMenuId() {
        return menuId;
    }

    /**
     * Get the Dart-side slot index.
     */
    public int getDartSlotIndex() {
        return dartSlotIndex;
    }
}
