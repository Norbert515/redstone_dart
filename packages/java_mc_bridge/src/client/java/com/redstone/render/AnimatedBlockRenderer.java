package com.redstone.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import com.redstone.blockentity.AnimatedBlockEntity;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.ItemBlockRenderTypes;
import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.block.ModelBlockRenderer;
import net.minecraft.client.renderer.block.model.BlockStateModel;
import net.minecraft.client.renderer.blockentity.BlockEntityRenderer;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.renderer.feature.ModelFeatureRenderer;
import net.minecraft.client.renderer.state.CameraRenderState;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.util.Mth;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.Vec3;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Renderer for animated block entities.
 *
 * This renderer applies interpolated animation transforms (rotation, translation, scale)
 * to the block's model using PoseStack, then renders the block model.
 *
 * Smooth animation is achieved by interpolating between previous and current tick
 * values using partialTick.
 */
@Environment(EnvType.CLIENT)
public class AnimatedBlockRenderer implements BlockEntityRenderer<AnimatedBlockEntity, AnimatedBlockRenderState> {
    private static final Logger LOGGER = LoggerFactory.getLogger("AnimatedBlockRenderer");

    public AnimatedBlockRenderer(BlockEntityRendererProvider.Context context) {
        // No special initialization needed
    }

    @Override
    public AnimatedBlockRenderState createRenderState() {
        return new AnimatedBlockRenderState();
    }

    private static int extractLogCounter = 0;

    @Override
    public void extractRenderState(
        AnimatedBlockEntity entity,
        AnimatedBlockRenderState state,
        float partialTick,
        Vec3 cameraPos,
        ModelFeatureRenderer.@Nullable CrumblingOverlay crumblingOverlay
    ) {
        // Call super to extract base state (position, block state, light coords)
        BlockEntityRenderer.super.extractRenderState(entity, state, partialTick, cameraPos, crumblingOverlay);

        // Debug: Log level and light info
        if (extractLogCounter++ % 100 == 0) {
            int manualLightCoords = entity.getLevel() != null
                ? net.minecraft.client.renderer.LevelRenderer.getLightColor(entity.getLevel(), entity.getBlockPos())
                : -1;
            String levelType = entity.getLevel() != null ? entity.getLevel().getClass().getSimpleName() : "null";
            int skyLight = entity.getLevel() != null ? entity.getLevel().getBrightness(net.minecraft.world.level.LightLayer.SKY, entity.getBlockPos()) : -1;
            int blockLight = entity.getLevel() != null ? entity.getLevel().getBrightness(net.minecraft.world.level.LightLayer.BLOCK, entity.getBlockPos()) : -1;
            LOGGER.warn("extractRenderState: levelType={}, pos={}, state.lightCoords={}, manualLight={}, sky={}, block={}",
                levelType,
                entity.getBlockPos(),
                state.lightCoords,
                manualLightCoords,
                skyLight,
                blockLight);
        }

        // Extract current animation state
        state.rotationX = entity.getRotationX();
        state.rotationY = entity.getRotationY();
        state.rotationZ = entity.getRotationZ();
        state.translateX = entity.getTranslateX();
        state.translateY = entity.getTranslateY();
        state.translateZ = entity.getTranslateZ();
        state.scaleX = entity.getScaleX();
        state.scaleY = entity.getScaleY();
        state.scaleZ = entity.getScaleZ();
        state.pivotX = entity.getPivotX();
        state.pivotY = entity.getPivotY();
        state.pivotZ = entity.getPivotZ();

        // Extract previous tick state for interpolation
        state.oRotationX = entity.getORotationX();
        state.oRotationY = entity.getORotationY();
        state.oRotationZ = entity.getORotationZ();
        state.oTranslateX = entity.getOTranslateX();
        state.oTranslateY = entity.getOTranslateY();
        state.oTranslateZ = entity.getOTranslateZ();
        state.oScaleX = entity.getOScaleX();
        state.oScaleY = entity.getOScaleY();
        state.oScaleZ = entity.getOScaleZ();

        // Store partial tick for interpolation in submit()
        state.partialTick = partialTick;

        // Store handler ID for potential future use
        state.handlerId = entity.getHandlerId();
    }

    private static int submitLogCounter = 0;

    @Override
    public void submit(
        AnimatedBlockRenderState state,
        PoseStack poseStack,
        SubmitNodeCollector submitNodeCollector,
        CameraRenderState cameraRenderState
    ) {
        // Log once per 100 calls to avoid spam
        if (submitLogCounter++ % 100 == 0) {
            LOGGER.warn("AnimatedBlockRenderer.submit() called, state.blockState={}", state.blockState);
        }

        BlockState blockState = state.blockState;
        if (blockState == null || blockState.isAir()) {
            return;
        }

        // Note: We don't skip based on getRenderShape() here because animated blocks
        // use RenderShape.INVISIBLE to prevent the default block renderer from rendering
        // the static model. We render the model ourselves with animation transforms applied.

        poseStack.pushPose();

        // Interpolate all animation values for smooth animation between ticks
        float rotX = Mth.lerp(state.partialTick, state.oRotationX, state.rotationX);
        float rotY = Mth.lerp(state.partialTick, state.oRotationY, state.rotationY);
        float rotZ = Mth.lerp(state.partialTick, state.oRotationZ, state.rotationZ);
        float transX = Mth.lerp(state.partialTick, state.oTranslateX, state.translateX);
        float transY = Mth.lerp(state.partialTick, state.oTranslateY, state.translateY);
        float transZ = Mth.lerp(state.partialTick, state.oTranslateZ, state.translateZ);
        float scaleX = Mth.lerp(state.partialTick, state.oScaleX, state.scaleX);
        float scaleY = Mth.lerp(state.partialTick, state.oScaleY, state.scaleY);
        float scaleZ = Mth.lerp(state.partialTick, state.oScaleZ, state.scaleZ);

        // Apply translation first (before rotation/scale)
        poseStack.translate(transX, transY, transZ);

        // Move to pivot point for rotation and scaling
        poseStack.translate(state.pivotX, state.pivotY, state.pivotZ);

        // Apply rotations (Y, X, Z order - standard Euler angles)
        if (rotY != 0) {
            poseStack.mulPose(Axis.YP.rotationDegrees(rotY));
        }
        if (rotX != 0) {
            poseStack.mulPose(Axis.XP.rotationDegrees(rotX));
        }
        if (rotZ != 0) {
            poseStack.mulPose(Axis.ZP.rotationDegrees(rotZ));
        }

        // Apply scale
        if (scaleX != 1 || scaleY != 1 || scaleZ != 1) {
            poseStack.scale(scaleX, scaleY, scaleZ);
        }

        // Move back from pivot point
        poseStack.translate(-state.pivotX, -state.pivotY, -state.pivotZ);

        // Render the block model with transforms applied
        renderBlockModel(state, poseStack, submitNodeCollector);

        poseStack.popPose();
    }

    /**
     * Render the block model using Minecraft's block rendering system.
     * The PoseStack already has all animation transforms applied.
     *
     * Note: Even though our blocks use RenderShape.INVISIBLE (to prevent double-rendering),
     * the model is still loaded and available via BlockModelShaper. RenderShape only affects
     * the default rendering pipeline, not model loading. The model cache is populated for
     * all blocks that have blockstate/model JSON files.
     */
    private void renderBlockModel(
        AnimatedBlockRenderState state,
        PoseStack poseStack,
        SubmitNodeCollector submitNodeCollector
    ) {
        Minecraft minecraft = Minecraft.getInstance();
        BlockRenderDispatcher blockRenderer = minecraft.getBlockRenderer();
        BlockState blockState = state.blockState;

        // Get the block's model directly from BlockModelShaper
        // This works even for RenderShape.INVISIBLE blocks since the model cache
        // is populated based on blockstate/model JSON files, not RenderShape.
        BlockStateModel model = blockRenderer.getBlockModelShaper().getBlockModel(blockState);
        if (model == null) {
            LOGGER.warn("No model found for animated block state: {}", blockState);
            return;
        }

        // Debug: Log model info (WARN level to ensure visibility)
        BlockStateModel missingModel = minecraft.getModelManager().getMissingBlockStateModel();
        int color = minecraft.getBlockColors().getColor(blockState, null, null, 0);
        float r = (color >> 16 & 0xFF) / 255.0f;
        float g = (color >> 8 & 0xFF) / 255.0f;
        float b = (color & 0xFF) / 255.0f;
        LOGGER.warn("AnimatedBlockRenderer DEBUG: block={} model={} missing={} color=0x{} rgb=[{},{},{}] lightCoords={}",
            blockState, model.getClass().getSimpleName(), model == missingModel,
            Integer.toHexString(color), r, g, b, state.lightCoords);

        // Get the render type for this block
        var renderType = ItemBlockRenderTypes.getRenderType(blockState);

        // RGB already calculated above for debug logging

        // Submit custom geometry to render the block model
        // This uses the static renderModel method from ModelBlockRenderer
        submitNodeCollector.submitCustomGeometry(
            poseStack,
            renderType,
            (pose, vertexConsumer) -> {
                ModelBlockRenderer.renderModel(
                    pose,
                    vertexConsumer,
                    model,
                    r, g, b,
                    state.lightCoords,
                    OverlayTexture.NO_OVERLAY
                );
            }
        );
    }

    @Override
    public int getViewDistance() {
        // Render animated blocks from further away for better visibility
        return 64;
    }

    @Override
    public boolean shouldRenderOffScreen() {
        // Always render even when block is technically off-screen
        // (animations might move the model into view)
        return true;
    }
}
