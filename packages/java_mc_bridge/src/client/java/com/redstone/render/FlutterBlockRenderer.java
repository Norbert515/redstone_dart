package com.redstone.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import com.redstone.blockentity.FlutterDisplayBlockEntity;
import com.redstone.flutter.FlutterTextureManager;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.renderer.LightTexture;
import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.client.renderer.blockentity.BlockEntityRenderer;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.renderer.feature.ModelFeatureRenderer;
import net.minecraft.client.renderer.rendertype.RenderTypes;
import net.minecraft.client.renderer.state.CameraRenderState;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.core.Direction;
import net.minecraft.resources.Identifier;
import net.minecraft.world.phys.Vec3;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Renderer for Flutter display block entities.
 *
 * This renderer draws a textured quad on the specified block face showing
 * content from a Flutter surface. For multi-block displays, UV coordinates
 * are calculated based on the block's position in the grid.
 */
@Environment(EnvType.CLIENT)
public class FlutterBlockRenderer implements BlockEntityRenderer<FlutterDisplayBlockEntity, FlutterBlockRenderState> {
    private static final Logger LOGGER = LoggerFactory.getLogger("FlutterBlockRenderer");

    /**
     * Small offset to prevent z-fighting with block faces.
     */
    private static final float FACE_OFFSET = 0.001f;

    /**
     * Full brightness light value for emissive rendering.
     */
    private static final int FULL_BRIGHT = LightTexture.pack(15, 15);

    public FlutterBlockRenderer(BlockEntityRendererProvider.Context context) {
        // No special initialization needed
    }

    @Override
    public FlutterBlockRenderState createRenderState() {
        return new FlutterBlockRenderState();
    }

    @Override
    public void extractRenderState(
        FlutterDisplayBlockEntity entity,
        FlutterBlockRenderState state,
        float partialTick,
        Vec3 cameraPos,
        ModelFeatureRenderer.@Nullable CrumblingOverlay crumblingOverlay
    ) {
        // Call super to extract base state (position, block state, light coords)
        BlockEntityRenderer.super.extractRenderState(entity, state, partialTick, cameraPos, crumblingOverlay);

        // Extract Flutter display specific data
        state.surfaceId = entity.getSurfaceId();
        state.gridX = entity.getGridX();
        state.gridY = entity.getGridY();
        state.gridWidth = entity.getGridWidth();
        state.gridHeight = entity.getGridHeight();
        state.facing = entity.getFacing();
        state.emissive = entity.isEmissive();
    }

    @Override
    public void submit(
        FlutterBlockRenderState state,
        PoseStack poseStack,
        SubmitNodeCollector submitNodeCollector,
        CameraRenderState cameraRenderState
    ) {
        FlutterTextureManager textureManager = FlutterTextureManager.getInstance();
        if (textureManager == null) {
            return;
        }

        Identifier textureLocation = textureManager.getTextureLocation(state.surfaceId);
        if (textureLocation == null || !textureManager.hasValidTexture(state.surfaceId)) {
            // No texture available - could render a placeholder here
            return;
        }

        // Calculate UV coordinates based on grid position
        // For a 3x2 grid, block at (1, 0):
        //   u0 = 1/3 = 0.333, u1 = 2/3 = 0.666
        //   v0 = 0/2 = 0.0, v1 = 1/2 = 0.5
        float u0 = (float) state.gridX / state.gridWidth;
        float u1 = (float) (state.gridX + 1) / state.gridWidth;
        float v0 = (float) state.gridY / state.gridHeight;
        float v1 = (float) (state.gridY + 1) / state.gridHeight;

        // Get light value - either full bright or world lighting
        int light = state.emissive ? FULL_BRIGHT : state.lightCoords;

        // Submit the quad geometry
        poseStack.pushPose();

        // Move to block center
        poseStack.translate(0.5f, 0.5f, 0.5f);

        // Rotate based on facing direction
        rotateForFacing(poseStack, state.facing);

        // Submit custom geometry for the textured quad
        submitNodeCollector.submitCustomGeometry(
            poseStack,
            RenderTypes.entityTranslucentEmissive(textureLocation),
            (pose, vertexConsumer) -> renderFaceQuad(pose, vertexConsumer, light, u0, v0, u1, v1)
        );

        poseStack.popPose();
    }

    /**
     * Rotate the pose stack so the quad faces the correct direction.
     */
    private void rotateForFacing(PoseStack poseStack, Direction facing) {
        switch (facing) {
            case NORTH -> {
                // Default - quad faces north (negative Z)
                // No rotation needed, but move to front face
                poseStack.translate(0, 0, -0.5f - FACE_OFFSET);
            }
            case SOUTH -> {
                poseStack.mulPose(Axis.YP.rotationDegrees(180));
                poseStack.translate(0, 0, -0.5f - FACE_OFFSET);
            }
            case EAST -> {
                poseStack.mulPose(Axis.YP.rotationDegrees(-90));
                poseStack.translate(0, 0, -0.5f - FACE_OFFSET);
            }
            case WEST -> {
                poseStack.mulPose(Axis.YP.rotationDegrees(90));
                poseStack.translate(0, 0, -0.5f - FACE_OFFSET);
            }
            case UP -> {
                poseStack.mulPose(Axis.XP.rotationDegrees(-90));
                poseStack.translate(0, 0, -0.5f - FACE_OFFSET);
            }
            case DOWN -> {
                poseStack.mulPose(Axis.XP.rotationDegrees(90));
                poseStack.translate(0, 0, -0.5f - FACE_OFFSET);
            }
        }
    }

    /**
     * Render a quad on the block face with the given UV coordinates.
     * The quad is rendered in the XY plane at Z=0, facing -Z.
     */
    private void renderFaceQuad(
        PoseStack.Pose pose,
        VertexConsumer vertexConsumer,
        int light,
        float u0, float v0, float u1, float v1
    ) {
        // Quad corners (1x1 in XY plane, centered at origin)
        float minX = -0.5f;
        float maxX = 0.5f;
        float minY = -0.5f;
        float maxY = 0.5f;

        // Normal facing -Z (towards the camera for NORTH facing)
        float nx = 0, ny = 0, nz = -1;

        // Note: V coordinates are flipped (1-v) because Minecraft's texture origin
        // is top-left, but we want Flutter's bottom-left origin behavior
        float v0Flipped = 1 - v1;
        float v1Flipped = 1 - v0;

        // Render quad (counter-clockwise winding for front face)
        // Bottom-left
        vertexConsumer.addVertex(pose, minX, minY, 0)
            .setColor(0xFFFFFFFF)
            .setUv(u0, v1Flipped)
            .setOverlay(OverlayTexture.NO_OVERLAY)
            .setLight(light)
            .setNormal(pose, nx, ny, nz);

        // Bottom-right
        vertexConsumer.addVertex(pose, maxX, minY, 0)
            .setColor(0xFFFFFFFF)
            .setUv(u1, v1Flipped)
            .setOverlay(OverlayTexture.NO_OVERLAY)
            .setLight(light)
            .setNormal(pose, nx, ny, nz);

        // Top-right
        vertexConsumer.addVertex(pose, maxX, maxY, 0)
            .setColor(0xFFFFFFFF)
            .setUv(u1, v0Flipped)
            .setOverlay(OverlayTexture.NO_OVERLAY)
            .setLight(light)
            .setNormal(pose, nx, ny, nz);

        // Top-left
        vertexConsumer.addVertex(pose, minX, maxY, 0)
            .setColor(0xFFFFFFFF)
            .setUv(u0, v0Flipped)
            .setOverlay(OverlayTexture.NO_OVERLAY)
            .setLight(light)
            .setNormal(pose, nx, ny, nz);
    }

    @Override
    public int getViewDistance() {
        // Render at normal block entity distance
        return 64;
    }

    @Override
    public boolean shouldRenderOffScreen() {
        // Always render even when block is off screen (for multi-block displays)
        return true;
    }
}
