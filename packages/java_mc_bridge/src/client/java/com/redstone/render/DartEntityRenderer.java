package com.redstone.render;

import com.mojang.blaze3d.vertex.PoseStack;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.model.EntityModel;
import net.minecraft.client.model.animal.cow.CowModel;
import net.minecraft.client.model.geom.ModelLayers;
import net.minecraft.client.model.monster.zombie.ZombieModel;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.MobRenderer;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.AgeableMob;
import net.minecraft.world.entity.Mob;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Generic entity renderer for Dart-defined entities.
 *
 * This renderer can use different base models (humanoid, quadruped, etc.)
 * and apply custom textures. It supports rendering entities with various
 * model types configured via EntityModelRegistry.
 *
 * Model types:
 * - "humanoid" - Uses ZombieModel (bipedal humanoid)
 * - "quadruped" - Uses CowModel (four-legged animal)
 * - "simple" / default - Uses ZombieModel as fallback
 *
 * @param <T> The entity type (must extend Mob)
 */
@Environment(EnvType.CLIENT)
public class DartEntityRenderer<T extends Mob> extends MobRenderer<T, DartEntityRenderState, EntityModel<DartEntityRenderState>> {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartEntityRenderer");

    // Default textures for fallback
    private static final Identifier DEFAULT_ZOMBIE_TEXTURE =
        Identifier.withDefaultNamespace("textures/entity/zombie/zombie.png");
    private static final Identifier DEFAULT_COW_TEXTURE =
        Identifier.withDefaultNamespace("textures/entity/cow/temperate_cow.png");

    private final Identifier texture;
    private final float scale;
    private final String modelType;

    /**
     * Create a renderer with default texture based on model type.
     */
    public DartEntityRenderer(EntityRendererProvider.Context context, String modelType, float scale) {
        this(context, modelType, null, scale);
    }

    /**
     * Create a renderer with a specific texture.
     */
    @SuppressWarnings("unchecked")
    public DartEntityRenderer(EntityRendererProvider.Context context, String modelType, Identifier texture, float scale) {
        super(context, createModel(context, modelType), 0.5f * scale);
        this.modelType = modelType != null ? modelType : "humanoid";
        this.scale = scale;
        this.texture = texture != null ? texture : getDefaultTexture(this.modelType);

        LOGGER.info("Created DartEntityRenderer with modelType={}, texture={}, scale={}",
            this.modelType, this.texture, this.scale);
    }

    /**
     * Create the appropriate model based on the model type.
     */
    @SuppressWarnings("unchecked")
    private static EntityModel<DartEntityRenderState> createModel(EntityRendererProvider.Context context, String modelType) {
        if (modelType == null) {
            modelType = "humanoid";
        }

        return switch (modelType.toLowerCase()) {
            case "quadruped" -> (EntityModel<DartEntityRenderState>) (Object) new CowModel(context.bakeLayer(ModelLayers.COW));
            case "humanoid", "simple" -> (EntityModel<DartEntityRenderState>) (Object) new ZombieModel(context.bakeLayer(ModelLayers.ZOMBIE));
            default -> {
                LOGGER.warn("Unknown model type '{}', using humanoid", modelType);
                yield (EntityModel<DartEntityRenderState>) (Object) new ZombieModel(context.bakeLayer(ModelLayers.ZOMBIE));
            }
        };
    }

    /**
     * Get the default texture for a model type.
     */
    private static Identifier getDefaultTexture(String modelType) {
        return switch (modelType.toLowerCase()) {
            case "quadruped" -> DEFAULT_COW_TEXTURE;
            default -> DEFAULT_ZOMBIE_TEXTURE;
        };
    }

    @Override
    public DartEntityRenderState createRenderState() {
        return new DartEntityRenderState();
    }

    @Override
    public void extractRenderState(T entity, DartEntityRenderState state, float partialTick) {
        super.extractRenderState(entity, state, partialTick);
        // For ageable entities (animals), set the baby state - required for CowModel/QuadrupedModel
        if (entity instanceof AgeableMob ageable) {
            state.baby = ageable.isBaby();
        }
    }

    @Override
    public Identifier getTextureLocation(DartEntityRenderState state) {
        return texture;
    }

    @Override
    protected void scale(DartEntityRenderState state, PoseStack poseStack) {
        poseStack.scale(scale, scale, scale);
    }

    /**
     * Factory method to create a renderer from EntityModelRegistry configuration.
     *
     * @param context The renderer provider context
     * @param handlerId The handler ID to look up configuration
     * @return A configured DartEntityRenderer, or null if no config exists
     */
    public static <T extends Mob> DartEntityRenderer<T> fromConfig(
            EntityRendererProvider.Context context, long handlerId) {
        EntityModelRegistry.EntityRenderConfig config = EntityModelRegistry.getConfig(handlerId);
        if (config == null) {
            return null;
        }

        return new DartEntityRenderer<>(
            context,
            config.modelType(),
            config.texture(),
            config.scale()
        );
    }

    /**
     * Create a humanoid (zombie-like) renderer with the specified texture and scale.
     */
    public static <T extends Mob> DartEntityRenderer<T> humanoid(
            EntityRendererProvider.Context context, Identifier texture, float scale) {
        return new DartEntityRenderer<>(context, "humanoid", texture, scale);
    }

    /**
     * Create a quadruped (cow-like) renderer with the specified texture and scale.
     */
    public static <T extends Mob> DartEntityRenderer<T> quadruped(
            EntityRendererProvider.Context context, Identifier texture, float scale) {
        return new DartEntityRenderer<>(context, "quadruped", texture, scale);
    }
}
