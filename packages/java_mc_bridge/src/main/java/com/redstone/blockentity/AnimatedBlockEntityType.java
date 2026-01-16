package com.redstone.blockentity;

import net.fabricmc.fabric.api.object.builder.v1.block.entity.FabricBlockEntityTypeBuilder;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntityType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Block entity type registration for animated block entities.
 *
 * This class manages per-block BlockEntityType registrations for animated blocks.
 * Each block that has an animation gets its own BlockEntityType.
 */
public class AnimatedBlockEntityType {
    private static final Logger LOGGER = LoggerFactory.getLogger("AnimatedBlockEntityType");

    /**
     * Map of block ID to its BlockEntityType.
     */
    private static final Map<String, BlockEntityType<AnimatedBlockEntity>> TYPES = new HashMap<>();

    /**
     * Register a BlockEntityType for an animated block.
     *
     * @param blockId The full block ID (namespace:path)
     * @param block The Block instance to associate with this type
     * @param handlerId The Dart handler ID for this block entity
     * @return The registered BlockEntityType
     */
    public static BlockEntityType<AnimatedBlockEntity> registerForBlock(
            String blockId,
            Block block,
            int handlerId) {

        if (TYPES.containsKey(blockId)) {
            LOGGER.warn("AnimatedBlockEntityType already registered for {}", blockId);
            return TYPES.get(blockId);
        }

        // Parse block ID into namespace and path
        String[] parts = blockId.split(":");
        String namespace = parts[0];
        String path = parts[1] + "_animated_entity";

        LOGGER.info("Registering AnimatedBlockEntityType for {} (handler={})", blockId, handlerId);

        // Create the BlockEntityType with this specific block
        final BlockEntityType<AnimatedBlockEntity>[] typeHolder = new BlockEntityType[1];
        final int finalHandlerId = handlerId;

        BlockEntityType<AnimatedBlockEntity> type = Registry.register(
            BuiltInRegistries.BLOCK_ENTITY_TYPE,
            Identifier.fromNamespaceAndPath(namespace, path),
            FabricBlockEntityTypeBuilder.create(
                (pos, state) -> new AnimatedBlockEntity(typeHolder[0], pos, state, finalHandlerId),
                block
            ).build()
        );

        typeHolder[0] = type;
        TYPES.put(blockId, type);

        LOGGER.info("Registered AnimatedBlockEntityType {} for block {}", namespace + ":" + path, blockId);
        return type;
    }

    /**
     * Get the BlockEntityType for a specific animated block.
     *
     * @param blockId The full block ID (namespace:path)
     * @return The BlockEntityType, or null if not registered
     */
    public static BlockEntityType<AnimatedBlockEntity> getType(String blockId) {
        return TYPES.get(blockId);
    }

    /**
     * Check if a block has a registered AnimatedBlockEntityType.
     *
     * @param blockId The full block ID (namespace:path)
     * @return true if a type is registered for this block
     */
    public static boolean hasType(String blockId) {
        return TYPES.containsKey(blockId);
    }

    /**
     * Get all registered block IDs.
     */
    public static Iterable<String> getAllBlockIds() {
        return TYPES.keySet();
    }

    /**
     * Get all registered block entity types.
     */
    public static Iterable<BlockEntityType<AnimatedBlockEntity>> getAllTypes() {
        return TYPES.values();
    }

    /**
     * Get the number of registered types.
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
