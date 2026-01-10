package com.redstone;

import com.redstone.blockentity.DartBlockEntityMenu;
import com.redstone.blockentity.DartChestMenu;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.world.flag.FeatureFlags;
import net.minecraft.world.inventory.MenuType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Menu types for the Redstone/Dart bridge.
 * These are registered under the "redstone" namespace.
 */
public class RedstoneMenuTypes {
    private static final Logger LOGGER = LoggerFactory.getLogger("RedstoneMenuTypes");
    public static final String NAMESPACE = "redstone";

    /**
     * Menu type for custom Dart containers (chest-like, grid-based).
     */
    public static final MenuType<DartContainerMenu> DART_CONTAINER_MENU = Registry.register(
            BuiltInRegistries.MENU,
            Identifier.fromNamespaceAndPath(NAMESPACE, "dart_container"),
            new MenuType<>(DartContainerMenu::new, FeatureFlags.VANILLA_SET)
    );

    /**
     * Menu type for Dart block entity menus (furnace-like, with processing).
     * Uses a simple constructor that creates empty container/data on client side.
     */
    public static final MenuType<DartBlockEntityMenu> DART_BLOCK_ENTITY_MENU = Registry.register(
            BuiltInRegistries.MENU,
            Identifier.fromNamespaceAndPath(NAMESPACE, "dart_block_entity"),
            new MenuType<>(DartBlockEntityMenu::new, FeatureFlags.VANILLA_SET)
    );

    /**
     * Menu type for Dart chest-like block entities (grid-based with ContainerData).
     * Used for block entities with larger inventories (e.g., 27 slots like a chest).
     * Unlike DART_BLOCK_ENTITY_MENU (furnace-style), this supports dynamic grid sizes.
     */
    public static final MenuType<DartChestMenu> DART_CHEST_MENU = Registry.register(
            BuiltInRegistries.MENU,
            Identifier.fromNamespaceAndPath(NAMESPACE, "dart_chest"),
            new MenuType<>(DartChestMenu::new, FeatureFlags.VANILLA_SET)
    );

    /**
     * Initialize menu types. Call this during mod initialization.
     */
    public static void initialize() {
        // Menu types are registered when the class is loaded
        LOGGER.info("Redstone menu types registered");
    }
}
