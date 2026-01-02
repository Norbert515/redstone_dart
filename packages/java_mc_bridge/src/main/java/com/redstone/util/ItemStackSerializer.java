package com.redstone.util;

import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.world.item.ItemStack;

/**
 * Utility for serializing ItemStacks to/from strings.
 *
 * Shared between client and server code for consistent serialization format.
 *
 * Format: "namespace:item_name:count:damage:maxDamage"
 * Examples:
 * - "minecraft:diamond:1:0:0" (non-damageable)
 * - "minecraft:diamond_pickaxe:1:50:1561" (damageable)
 */
public class ItemStackSerializer {

    /**
     * Serialize an ItemStack to a string format.
     *
     * @param stack The ItemStack to serialize
     * @return "itemId:count:damage:maxDamage" or empty string if empty
     */
    public static String serialize(ItemStack stack) {
        if (stack == null || stack.isEmpty()) {
            return "";
        }
        String itemId = BuiltInRegistries.ITEM.getKey(stack.getItem()).toString();
        int damage = stack.isDamageableItem() ? stack.getDamageValue() : 0;
        int maxDamage = stack.getMaxDamage();
        return itemId + ":" + stack.getCount() + ":" + damage + ":" + maxDamage;
    }

    /**
     * Parse a serialized ItemStack string.
     *
     * @param data The serialized string
     * @return The ItemStack, or EMPTY if the string is empty or invalid
     */
    public static ItemStack deserialize(String data) {
        if (data == null || data.isEmpty()) {
            return ItemStack.EMPTY;
        }

        // Parse "namespace:item_name:count:damage:maxDamage" format
        String[] parts = data.split(":");
        if (parts.length < 3) {
            return ItemStack.EMPTY;
        }

        // Reconstruct item ID (namespace:item_name)
        String itemId = parts[0] + ":" + parts[1];

        int count = 1;
        if (parts.length > 2) {
            try {
                count = Integer.parseInt(parts[2]);
            } catch (NumberFormatException e) {
                count = 1;
            }
        }

        // Look up item from registry
        var item = BuiltInRegistries.ITEM.getValue(Identifier.parse(itemId));
        ItemStack stack = new ItemStack(item, count);

        // Apply damage if present and item is damageable
        if (parts.length > 3 && stack.isDamageableItem()) {
            try {
                int damage = Integer.parseInt(parts[3]);
                stack.setDamageValue(damage);
            } catch (NumberFormatException e) {
                // Ignore invalid damage value
            }
        }

        return stack;
    }
}
