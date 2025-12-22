package com.redstone;

import com.redstone.proxy.EntityProxyRegistry;
import com.redstone.render.DartEntityRenderer;
import com.redstone.render.EntityModelRegistry;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;
import net.minecraft.client.renderer.entity.NoopRenderer;
import net.minecraft.resources.Identifier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Client-side mod initializer that registers entity renderers.
 *
 * This class is responsible for:
 * - Registering entity renderers for all Dart-defined custom entities
 *
 * Without proper renderer registration, entities will cause NullPointerException
 * when the client tries to render them.
 *
 * Currently uses NoopRenderer (invisible) for all custom entities.
 * TODO: Implement proper renderers with cow/zombie models for visible entities.
 */
@Environment(EnvType.CLIENT)
public class DartModClientLoader implements ClientModInitializer {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartModClientLoader");

    @Override
    public void onInitializeClient() {
        LOGGER.info("[DartModClientLoader] Setting up entity renderer callback...");

        // Register a callback to be notified when entities are registered.
        // This handles the case where Dart registers entities AFTER client init.
        EntityProxyRegistry.setRegistrationCallback((entityType, handlerId) -> {
            int baseType = EntityProxyRegistry.getBaseType(handlerId);
            String baseTypeName = switch (baseType) {
                case EntityProxyRegistry.BASE_TYPE_ANIMAL -> "animal";
                case EntityProxyRegistry.BASE_TYPE_MONSTER -> "monster";
                case EntityProxyRegistry.BASE_TYPE_PROJECTILE -> "projectile";
                default -> "mob";
            };

            // Check if there's a model configuration for this entity
            EntityProxyRegistry.EntityModelConfig modelConfig = EntityProxyRegistry.getModelConfig(handlerId);
            if (modelConfig != null) {
                // Register model config to client-side registry for renderer access
                EntityModelRegistry.registerConfig(
                    handlerId,
                    modelConfig.modelType(),
                    modelConfig.texturePath(),
                    modelConfig.scale()
                );

                LOGGER.info("[DartModClientLoader] Registering DartEntityRenderer for {} entity (handler: {}, model: {}, texture: {})",
                    baseTypeName, handlerId, modelConfig.modelType(), modelConfig.texturePath());

                // Use DartEntityRenderer with the configured model and texture
                @SuppressWarnings("unchecked")
                var mobEntityType = (net.minecraft.world.entity.EntityType<net.minecraft.world.entity.Mob>) entityType;
                EntityRendererRegistry.register(mobEntityType, context -> {
                    Identifier texture = Identifier.tryParse(modelConfig.texturePath());
                    if (texture == null) {
                        texture = Identifier.withDefaultNamespace(modelConfig.texturePath());
                    }
                    return new DartEntityRenderer<>(context, modelConfig.modelType(), texture, modelConfig.scale());
                });
            } else {
                LOGGER.info("[DartModClientLoader] Registering NoopRenderer for {} entity (handler: {}) - no model config",
                    baseTypeName, handlerId);
                // No model config - use NoopRenderer (invisible entity)
                EntityRendererRegistry.register(entityType, NoopRenderer::new);
            }
        });

        LOGGER.info("[DartModClientLoader] Entity renderer callback registered!");
    }
}
