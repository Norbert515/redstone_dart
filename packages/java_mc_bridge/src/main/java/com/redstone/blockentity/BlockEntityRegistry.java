package com.redstone.blockentity;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Registry that maps block IDs to their block entity configurations.
 *
 * When a block is registered from Dart with a block entity, this registry
 * stores the mapping so that when the block is actually registered with
 * Minecraft, we know what block entity configuration to use.
 */
public class BlockEntityRegistry {
    private static final Logger LOGGER = LoggerFactory.getLogger("BlockEntityRegistry");

    /**
     * Configuration for a block entity type.
     */
    public record BlockEntityConfig(
        int handlerId,
        int inventorySize,
        String containerTitle,
        boolean ticks
    ) {}

    /**
     * Map of block ID (e.g., "mymod:furnace") to block entity configuration.
     */
    private static final Map<String, BlockEntityConfig> blockEntityConfigs = new HashMap<>();

    /**
     * Register a block entity configuration for a block.
     *
     * @param blockId The full block ID (namespace:path)
     * @param handlerId The Dart handler ID for this block entity
     * @param inventorySize Number of inventory slots
     * @param containerTitle Display title for the container
     * @param ticks Whether this block entity should tick
     */
    public static void registerBlockEntity(
            String blockId,
            int handlerId,
            int inventorySize,
            String containerTitle,
            boolean ticks) {

        BlockEntityConfig config = new BlockEntityConfig(handlerId, inventorySize, containerTitle, ticks);
        blockEntityConfigs.put(blockId, config);
        LOGGER.info("Registered block entity config for {}: handler={}, inventory={}, ticks={}",
            blockId, handlerId, inventorySize, ticks);
    }

    /**
     * Get the block entity configuration for a block.
     *
     * @param blockId The full block ID (namespace:path)
     * @return The configuration, or null if no block entity is registered for this block
     */
    public static BlockEntityConfig getConfig(String blockId) {
        return blockEntityConfigs.get(blockId);
    }

    /**
     * Check if a block has a registered block entity.
     *
     * @param blockId The full block ID (namespace:path)
     * @return true if this block has a block entity
     */
    public static boolean hasBlockEntity(String blockId) {
        return blockEntityConfigs.containsKey(blockId);
    }

    /**
     * Get all registered block entity configurations.
     *
     * @return Map of block IDs to their configurations
     */
    public static Map<String, BlockEntityConfig> getAllConfigs() {
        return new HashMap<>(blockEntityConfigs);
    }

    /**
     * Get the number of registered block entity types.
     */
    public static int getCount() {
        return blockEntityConfigs.size();
    }

    /**
     * Clear all registered block entity configurations.
     * Used for testing or world unload.
     */
    public static void clear() {
        blockEntityConfigs.clear();
    }
}
