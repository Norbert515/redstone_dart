package com.redstone.render;

import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.resources.Identifier;
import java.util.HashMap;
import java.util.Map;

/**
 * Registry for entity model configurations.
 *
 * This class stores model configurations (model type, texture, scale) for
 * custom entities defined from Dart. The client-side renderer uses this
 * registry to determine how to render each entity.
 */
@Environment(EnvType.CLIENT)
public class EntityModelRegistry {
    private static final Map<Long, EntityRenderConfig> renderConfigs = new HashMap<>();

    /**
     * Configuration for how to render an entity.
     *
     * @param modelType The base model type ("humanoid", "quadruped", "simple")
     * @param texture The texture identifier to use
     * @param scale The scale factor for rendering
     */
    public record EntityRenderConfig(String modelType, Identifier texture, float scale) {}

    /**
     * Register a render configuration for an entity.
     *
     * @param handlerId The handler ID of the entity
     * @param modelType The model type ("humanoid", "quadruped", "simple")
     * @param texturePath The texture path (e.g., "minecraft:textures/entity/zombie/zombie.png")
     * @param scale The scale factor for rendering
     */
    public static void registerConfig(long handlerId, String modelType, String texturePath, float scale) {
        Identifier textureId = Identifier.tryParse(texturePath);
        if (textureId == null) {
            // Fallback: try to parse with default namespace
            textureId = Identifier.withDefaultNamespace(texturePath);
        }
        renderConfigs.put(handlerId, new EntityRenderConfig(modelType, textureId, scale));
    }

    /**
     * Get the render configuration for an entity.
     *
     * @param handlerId The handler ID of the entity
     * @return The render configuration, or null if not registered
     */
    public static EntityRenderConfig getConfig(long handlerId) {
        return renderConfigs.get(handlerId);
    }

    /**
     * Check if a render configuration exists for an entity.
     *
     * @param handlerId The handler ID of the entity
     * @return true if a configuration exists, false otherwise
     */
    public static boolean hasConfig(long handlerId) {
        return renderConfigs.containsKey(handlerId);
    }
}
