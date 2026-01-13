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
 * Block entity type registration for Flutter display block entities.
 *
 * This class manages per-block BlockEntityType registrations for Flutter displays.
 * Each block that displays Flutter content gets its own BlockEntityType.
 */
public class FlutterDisplayBlockEntityType {
    private static final Logger LOGGER = LoggerFactory.getLogger("FlutterDisplayBlockEntityType");

    /**
     * Map of block ID to its BlockEntityType.
     */
    private static final Map<String, BlockEntityType<FlutterDisplayBlockEntity>> TYPES = new HashMap<>();

    /**
     * Register a BlockEntityType for a Flutter display block.
     *
     * @param blockId The full block ID (namespace:path)
     * @param block The Block instance to associate with this type
     * @return The registered BlockEntityType
     */
    public static BlockEntityType<FlutterDisplayBlockEntity> registerForBlock(String blockId, Block block) {
        if (TYPES.containsKey(blockId)) {
            LOGGER.warn("FlutterDisplayBlockEntityType already registered for {}", blockId);
            return TYPES.get(blockId);
        }

        // Parse block ID into namespace and path
        String[] parts = blockId.split(":");
        String namespace = parts[0];
        String path = parts[1] + "_flutter_display_entity";

        LOGGER.info("Registering FlutterDisplayBlockEntityType for {}", blockId);

        // Create the BlockEntityType with this specific block
        final BlockEntityType<FlutterDisplayBlockEntity>[] typeHolder = new BlockEntityType[1];

        BlockEntityType<FlutterDisplayBlockEntity> type = Registry.register(
            BuiltInRegistries.BLOCK_ENTITY_TYPE,
            Identifier.fromNamespaceAndPath(namespace, path),
            FabricBlockEntityTypeBuilder.create(
                (pos, state) -> new FlutterDisplayBlockEntity(typeHolder[0], pos, state),
                block
            ).build()
        );

        typeHolder[0] = type;
        TYPES.put(blockId, type);

        LOGGER.info("Registered FlutterDisplayBlockEntityType {} for block {}", namespace + ":" + path, blockId);
        return type;
    }

    /**
     * Get the BlockEntityType for a specific Flutter display block.
     *
     * @param blockId The full block ID (namespace:path)
     * @return The BlockEntityType, or null if not registered
     */
    public static BlockEntityType<FlutterDisplayBlockEntity> getType(String blockId) {
        return TYPES.get(blockId);
    }

    /**
     * Check if a block has a registered FlutterDisplayBlockEntityType.
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
    public static Iterable<BlockEntityType<FlutterDisplayBlockEntity>> getAllTypes() {
        return TYPES.values();
    }

    /**
     * Get the number of registered types.
     */
    public static int getCount() {
        return TYPES.size();
    }
}
