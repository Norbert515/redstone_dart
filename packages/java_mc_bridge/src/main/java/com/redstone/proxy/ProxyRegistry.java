package com.redstone.proxy;

import net.fabricmc.fabric.api.itemgroup.v1.ItemGroupEvents;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.CreativeModeTabs;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.state.BlockBehaviour;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Registry for Dart-defined proxy blocks.
 *
 * This registry manages the lifecycle of proxy blocks and provides
 * methods for registering new blocks from Dart code.
 *
 * The registration process is two-phase:
 * 1. createBlock() - Called from Dart to reserve a handler ID and store block settings
 * 2. registerBlock() - Called from Dart to register the block with Minecraft's registry
 *
 * This two-phase approach is needed because Minecraft requires a ResourceKey during
 * block construction, but we don't know the block's namespace:path until registration.
 */
public class ProxyRegistry {
    private static final Logger LOGGER = LoggerFactory.getLogger("ProxyRegistry");
    private static final Map<Long, DartBlockProxy> blocks = new HashMap<>();
    private static final Map<Long, BlockSettings> pendingSettings = new HashMap<>();
    private static long nextHandlerId = 1;

    /**
     * Holds block settings between createBlock() and registerBlock() calls.
     */
    private record BlockSettings(float hardness, float resistance, boolean requiresTool) {}

    /**
     * Create a new DartBlockProxy with the given settings.
     * Returns the handler ID that links to this block.
     *
     * Called from Dart via JNI during the first phase of block registration.
     *
     * @param hardness Block hardness (time to break). Use -1 for unbreakable.
     * @param resistance Explosion resistance.
     * @param requiresTool Whether the block requires the correct tool to drop items.
     * @return The handler ID to use when registering the block.
     */
    public static long createBlock(float hardness, float resistance, boolean requiresTool) {
        long handlerId = nextHandlerId++;

        // Store settings for use during registerBlock()
        pendingSettings.put(handlerId, new BlockSettings(hardness, resistance, requiresTool));

        LOGGER.info("Prepared DartBlockProxy slot with handler ID: {}", handlerId);
        return handlerId;
    }

    /**
     * Register the block with Minecraft's registry.
     * Must be called during mod initialization before registry freeze.
     *
     * Called from Dart via JNI during the second phase of block registration.
     *
     * @param handlerId The handler ID returned by createBlock().
     * @param namespace The block namespace (e.g., "dartmod").
     * @param path The block path (e.g., "example_block").
     * @return true if registration succeeded, false otherwise.
     */
    public static boolean registerBlock(long handlerId, String namespace, String path) {
        BlockSettings settings = pendingSettings.get(handlerId);
        if (settings == null) {
            LOGGER.error("Cannot register block: handler ID {} not found (createBlock not called?)", handlerId);
            return false;
        }

        try {
            // Create resource keys
            ResourceKey<net.minecraft.world.level.block.Block> blockKey = ResourceKey.create(
                Registries.BLOCK,
                Identifier.fromNamespaceAndPath(namespace, path)
            );
            ResourceKey<Item> itemKey = ResourceKey.create(
                Registries.ITEM,
                Identifier.fromNamespaceAndPath(namespace, path)
            );

            // Create block properties with the settings from createBlock()
            BlockBehaviour.Properties properties = BlockBehaviour.Properties.of()
                .strength(settings.hardness(), settings.resistance())
                .setId(blockKey);

            if (settings.requiresTool()) {
                properties = properties.requiresCorrectToolForDrops();
            }

            DartBlockProxy block = new DartBlockProxy(properties, handlerId);
            blocks.put(handlerId, block);
            pendingSettings.remove(handlerId); // Clean up pending settings

            // Register the block
            Registry.register(BuiltInRegistries.BLOCK, blockKey, block);

            // Also register a BlockItem so it appears in creative inventory
            BlockItem blockItem = new BlockItem(block,
                new Item.Properties().setId(itemKey).useBlockDescriptionPrefix());
            Registry.register(BuiltInRegistries.ITEM, itemKey, blockItem);

            // Add to Building Blocks creative tab
            ItemGroupEvents.modifyEntriesEvent(CreativeModeTabs.BUILDING_BLOCKS).register(entries -> {
                entries.accept(blockItem);
            });

            LOGGER.info("Registered block: {}:{} with handler ID {}", namespace, path, handlerId);
            return true;
        } catch (Exception e) {
            LOGGER.error("Failed to register block {}:{}: {}", namespace, path, e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Get a block by its handler ID.
     */
    public static DartBlockProxy getBlock(long handlerId) {
        return blocks.get(handlerId);
    }

    /**
     * Get all registered handler IDs.
     */
    public static long[] getAllHandlerIds() {
        return blocks.keySet().stream().mapToLong(Long::longValue).toArray();
    }

    /**
     * Get the number of registered blocks.
     */
    public static int getBlockCount() {
        return blocks.size();
    }
}
