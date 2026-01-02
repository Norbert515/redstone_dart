package com.redstone.blockentity;

import net.fabricmc.fabric.api.object.builder.v1.block.entity.FabricBlockEntityTypeBuilder;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntityType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Block entity type registration for Dart block entities.
 *
 * This class manages per-block BlockEntityType registrations. Each block that
 * needs a block entity gets its own BlockEntityType associated with that specific block.
 * This is required because Minecraft validates that a BlockEntity's type is valid
 * for the block it's placed in.
 */
public class DartBlockEntityType {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBlockEntityType");

    /**
     * Map of block ID (e.g., "mymod:furnace") to its BlockEntityType.
     * Each block with a block entity gets its own type.
     */
    private static final Map<String, BlockEntityType<DartProcessingBlockEntity>> TYPES = new HashMap<>();

    /**
     * Register a BlockEntityType for a specific block.
     * This must be called during block registration, after the Block is created
     * but before any BlockEntities are created for it.
     *
     * @param blockId The full block ID (namespace:path)
     * @param block The Block instance to associate with this type
     * @param handlerId The Dart handler ID for block entities of this type
     * @param inventorySize Number of inventory slots
     * @param containerTitle Display title for the container
     * @return The registered BlockEntityType
     */
    public static BlockEntityType<DartProcessingBlockEntity> registerForBlock(
            String blockId,
            Block block,
            int handlerId,
            int inventorySize,
            String containerTitle) {

        if (TYPES.containsKey(blockId)) {
            LOGGER.warn("BlockEntityType already registered for {}", blockId);
            return TYPES.get(blockId);
        }

        // Parse block ID into namespace and path
        String[] parts = blockId.split(":");
        String namespace = parts[0];
        String path = parts[1] + "_entity";

        LOGGER.info("Registering BlockEntityType for {} (handler={}, inventory={})",
            blockId, handlerId, inventorySize);

        // Create the BlockEntityType with this specific block
        // We need to use a holder for the type reference in the factory lambda
        final BlockEntityType<DartProcessingBlockEntity>[] typeHolder = new BlockEntityType[1];

        BlockEntityType<DartProcessingBlockEntity> type = Registry.register(
            BuiltInRegistries.BLOCK_ENTITY_TYPE,
            Identifier.fromNamespaceAndPath(namespace, path),
            FabricBlockEntityTypeBuilder.create(
                (pos, state) -> new DartProcessingBlockEntity(
                    typeHolder[0],
                    pos,
                    state,
                    handlerId,
                    inventorySize,
                    Component.literal(containerTitle)
                ),
                block
            ).build()
        );

        typeHolder[0] = type;
        TYPES.put(blockId, type);

        LOGGER.info("Registered BlockEntityType {} for block {}", namespace + ":" + path, blockId);
        return type;
    }

    /**
     * Get the BlockEntityType for a specific block.
     *
     * @param blockId The full block ID (namespace:path)
     * @return The BlockEntityType, or null if not registered
     */
    public static BlockEntityType<DartProcessingBlockEntity> getType(String blockId) {
        return TYPES.get(blockId);
    }

    /**
     * Check if a block has a registered BlockEntityType.
     *
     * @param blockId The full block ID (namespace:path)
     * @return true if a type is registered for this block
     */
    public static boolean hasType(String blockId) {
        return TYPES.containsKey(blockId);
    }

    /**
     * Get the number of registered block entity types.
     */
    public static int getCount() {
        return TYPES.size();
    }

    /**
     * Clear all registered types. Used for testing.
     */
    public static void clear() {
        TYPES.clear();
    }
}
