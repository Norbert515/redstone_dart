package com.example.block.menu;

import com.example.ExampleMod;
import com.example.dartbridge.DartContainerMenu;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.world.flag.FeatureFlags;
import net.minecraft.world.inventory.MenuType;

public class ModMenuTypes {

    public static final MenuType<TechFabricatorMenu> TECH_FABRICATOR_MENU = Registry.register(
            BuiltInRegistries.MENU,
            Identifier.fromNamespaceAndPath(ExampleMod.MOD_ID, "tech_fabricator"),
            new MenuType<>(TechFabricatorMenu::new, FeatureFlags.VANILLA_SET)
    );

    public static final MenuType<DartContainerMenu> DART_CONTAINER_MENU = Registry.register(
            BuiltInRegistries.MENU,
            Identifier.fromNamespaceAndPath(ExampleMod.MOD_ID, "dart_container"),
            new MenuType<>(DartContainerMenu::new, FeatureFlags.VANILLA_SET)
    );

    public static void initialize() {
        ExampleMod.LOGGER.info("Registering menu types...");
    }
}
