package com.redstone;

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

    public static final MenuType<DartContainerMenu> DART_CONTAINER_MENU = Registry.register(
            BuiltInRegistries.MENU,
            Identifier.fromNamespaceAndPath(NAMESPACE, "dart_container"),
            new MenuType<>(DartContainerMenu::new, FeatureFlags.VANILLA_SET)
    );

    /**
     * Initialize menu types. Call this during mod initialization.
     */
    public static void initialize() {
        // Menu types are registered when the class is loaded
        LOGGER.info("Redstone menu types registered");
    }
}
