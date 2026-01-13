package com.redstone.entity;

import net.fabricmc.fabric.api.object.builder.v1.entity.FabricEntityTypeBuilder;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.entity.EntityDimensions;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Registers the Flutter display entity type with Minecraft/Fabric.
 *
 * The FlutterDisplayEntity extends Display (like BlockDisplay, TextDisplay, ItemDisplay)
 * and renders Flutter UI content as a floating rectangle in the world.
 */
public class FlutterDisplayEntityTypes {
    private static final Logger LOGGER = LoggerFactory.getLogger("FlutterDisplayEntityTypes");

    public static final Identifier FLUTTER_DISPLAY_ID = Identifier.fromNamespaceAndPath("redstone", "flutter_display");

    /**
     * The Flutter display entity type.
     *
     * Properties:
     * - MISC category (not a mob, doesn't despawn)
     * - No loot table
     * - Zero size (Display entities use culling box, not collision)
     * - 10 chunk tracking range (same as other Display entities)
     * - Update interval 1 (same as other Display entities)
     */
    public static EntityType<FlutterDisplayEntity> FLUTTER_DISPLAY;

    private static boolean initialized = false;

    /**
     * Register the Flutter display entity type.
     * Must be called during mod initialization before registries freeze.
     */
    public static void initialize() {
        if (initialized) {
            LOGGER.warn("FlutterDisplayEntityTypes.initialize() called multiple times");
            return;
        }

        LOGGER.info("Registering Flutter display entity type...");

        // Create resource key for the entity type
        ResourceKey<EntityType<?>> key = ResourceKey.create(
            Registries.ENTITY_TYPE,
            FLUTTER_DISPLAY_ID
        );

        // Build the entity type using FabricEntityTypeBuilder
        // Using create() instead of createMob() since Display is not a Mob
        FLUTTER_DISPLAY = FabricEntityTypeBuilder.<FlutterDisplayEntity>create(
                MobCategory.MISC,
                FlutterDisplayEntity::new
            )
            .dimensions(EntityDimensions.fixed(0.0f, 0.0f))  // Zero size (uses culling box)
            .trackRangeChunks(10)  // Same as vanilla Display entities
            .trackedUpdateRate(1)  // Same as vanilla Display entities
            .build(key);

        // Register with Minecraft's entity type registry
        Registry.register(BuiltInRegistries.ENTITY_TYPE, FLUTTER_DISPLAY_ID, FLUTTER_DISPLAY);

        initialized = true;
        LOGGER.info("Flutter display entity type registered successfully");
    }

    /**
     * Check if the entity types have been initialized.
     */
    public static boolean isInitialized() {
        return initialized;
    }
}
