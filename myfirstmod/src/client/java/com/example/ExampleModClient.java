package com.example;

import com.example.block.menu.ModMenuTypes;
import com.example.dartbridge.DartContainerScreen;
import com.example.dartbridge.DartEntityRenderer;
import com.example.dartbridge.proxy.DartEntityProxy;
import com.example.dartbridge.proxy.EntityProxyRegistry;
import com.example.screen.TechFabricatorScreen;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;
import net.minecraft.client.gui.screens.MenuScreens;
import net.minecraft.world.entity.EntityType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ExampleModClient implements ClientModInitializer {
	private static final Logger LOGGER = LoggerFactory.getLogger("ExampleModClient");

	@Override
	public void onInitializeClient() {
		// Register screens for menus
		MenuScreens.register(ModMenuTypes.TECH_FABRICATOR_MENU, TechFabricatorScreen::new);
		MenuScreens.register(ModMenuTypes.DART_CONTAINER_MENU, DartContainerScreen::new);

		// Register entity renderers for Dart proxy entities
		registerDartEntityRenderers();
	}

	private void registerDartEntityRenderers() {
		// Get all registered Dart entity handler IDs and register renderers
		long[] handlerIds = EntityProxyRegistry.getAllHandlerIds();
		LOGGER.info("Registering renderers for {} Dart entities", handlerIds.length);

		for (long handlerId : handlerIds) {
			EntityType<DartEntityProxy> entityType = EntityProxyRegistry.getEntityType(handlerId);
			if (entityType != null) {
				// Use our custom DartEntityRenderer (humanoid with zombie texture)
				EntityRendererRegistry.register(entityType, DartEntityRenderer::new);
				LOGGER.info("Registered renderer for Dart entity with handler ID {}", handlerId);
			}
		}
	}
}
