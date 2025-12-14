package com.example;

import com.example.block.menu.ModMenuTypes;
import com.example.dartbridge.DartContainerScreen;
import com.example.screen.TechFabricatorScreen;
import net.fabricmc.api.ClientModInitializer;
import net.minecraft.client.gui.screens.MenuScreens;

public class ExampleModClient implements ClientModInitializer {
	@Override
	public void onInitializeClient() {
		// Register screens for menus
		MenuScreens.register(ModMenuTypes.TECH_FABRICATOR_MENU, TechFabricatorScreen::new);
		MenuScreens.register(ModMenuTypes.DART_CONTAINER_MENU, DartContainerScreen::new);
	}
}
