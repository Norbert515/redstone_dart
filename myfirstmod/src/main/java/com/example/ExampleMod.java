package com.example;

import com.example.block.ModBlocks;
import com.example.block.entity.ModBlockEntities;
import com.example.block.menu.ModMenuTypes;
import net.fabricmc.api.ModInitializer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ExampleMod implements ModInitializer {
	public static final String MOD_ID = "modid";

	// This logger is used to write text to the console and the log file.
	// It is considered best practice to use your mod id as the logger's name.
	// That way, it's clear which mod wrote info, warnings, and errors.
	public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

	@Override
	public void onInitialize() {
		// This code runs as soon as Minecraft is in a mod-load-ready state.
		// However, some things (like resources) may still be uninitialized.
		// Proceed with mild caution.

		LOGGER.info("Hello Fabric world!");

		// Initialize our custom blocks, block entities, and menus
		ModBlocks.initialize();
		ModBlockEntities.initialize();
		ModMenuTypes.initialize();

		LOGGER.info("Lucky Block, Teleporter Pad, and Tech Fabricator loaded!");
	}
}