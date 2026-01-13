package com.redstone.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.redstone.DartBridgeClient;
import com.redstone.entity.FlutterDisplayEntity;
import com.redstone.flutter.FlutterTextureManager;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.client.renderer.entity.DisplayRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.rendertype.RenderTypes;
import net.minecraft.client.renderer.state.CameraRenderState;
import net.minecraft.client.renderer.texture.DynamicTexture;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.Display;
import org.joml.Matrix4f;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Renderer for Flutter display entities.
 *
 * Renders Flutter UI content as floating textured rectangles in the world.
 * Extends DisplayRenderer to get billboard mode support and transformation handling.
 *
 * The renderer uses the Flutter texture from DartBridgeClient (currently surface 0).
 * Multi-surface support will come from parallel infrastructure work.
 */
@Environment(EnvType.CLIENT)
public class FlutterDisplayRenderer extends DisplayRenderer<
    FlutterDisplayEntity,
    FlutterDisplayEntity.FlutterRenderState,
    FlutterDisplayRenderState
> {
    private static final Logger LOGGER = LoggerFactory.getLogger("FlutterDisplayRenderer");

    // Placeholder texture for when Flutter is not available
    private static final Identifier PLACEHOLDER_TEXTURE = Identifier.withDefaultNamespace("textures/misc/unknown_pack.png");

    // Flutter texture identifier - we'll register a dynamic texture here
    private static final Identifier FLUTTER_DISPLAY_TEXTURE = Identifier.fromNamespaceAndPath("redstone", "flutter_display");

    // Default surface resolution for route-based displays
    private static final int DEFAULT_SURFACE_WIDTH = 256;
    private static final int DEFAULT_SURFACE_HEIGHT = 256;

    // Cache of entity ID -> surface ID for entities with routes
    // This ensures we don't create duplicate surfaces for the same entity
    private static final Map<Integer, Long> entitySurfaceCache = new ConcurrentHashMap<>();

    public FlutterDisplayRenderer(EntityRendererProvider.Context context) {
        super(context);
        LOGGER.info("FlutterDisplayRenderer created");
    }

    /**
     * Get or create a surface for an entity with a route.
     * Returns 0 if no route is set (use main surface).
     */
    private long getOrCreateSurface(FlutterDisplayRenderState state) {
        String route = state.route;
        int entityId = state.entityId;

        // No route = use main surface (0)
        if (route == null || route.isEmpty()) {
            return 0;
        }

        // Check if we already have a surface for this entity
        Long existingSurface = entitySurfaceCache.get(entityId);
        if (existingSurface != null && existingSurface > 0) {
            // Verify the surface still exists
            if (DartBridgeClient.surfaceExists(existingSurface)) {
                return existingSurface;
            }
            // Surface was destroyed, remove from cache
            entitySurfaceCache.remove(entityId);
        }

        // Create a new surface for this route via FlutterTextureManager
        // This ensures multi-surface system is initialized before creating surfaces
        FlutterTextureManager manager = FlutterTextureManager.getInstance();
        if (manager == null) {
            LOGGER.warn("Failed to create surface: FlutterTextureManager not available");
            return 0;
        }

        long surfaceId = manager.createSurface(DEFAULT_SURFACE_WIDTH, DEFAULT_SURFACE_HEIGHT, route);
        if (surfaceId > 0) {
            LOGGER.info("Created surface {} for entity {} with route '{}'", surfaceId, entityId, route);
            entitySurfaceCache.put(entityId, surfaceId);
        } else {
            LOGGER.warn("Failed to create surface for entity {} with route '{}'", entityId, route);
        }

        return surfaceId;
    }

    /**
     * Clean up surface when entity is removed.
     * Should be called when entity is unloaded/destroyed.
     */
    public static void cleanupEntitySurface(int entityId) {
        Long surfaceId = entitySurfaceCache.remove(entityId);
        if (surfaceId != null && surfaceId > 0) {
            FlutterTextureManager manager = FlutterTextureManager.getInstance();
            if (manager != null) {
                manager.destroySurface(surfaceId);
            }
            LOGGER.info("Cleaned up surface {} for entity {}", surfaceId, entityId);
        }
    }

    @Override
    public FlutterDisplayRenderState createRenderState() {
        return new FlutterDisplayRenderState();
    }

    @Override
    public void extractRenderState(FlutterDisplayEntity entity, FlutterDisplayRenderState state, float partialTick) {
        super.extractRenderState(entity, state, partialTick);

        // Extract entity ID for surface caching
        state.entityId = entity.getId();

        // Extract Flutter-specific state
        FlutterDisplayEntity.FlutterRenderState flutterState = entity.flutterRenderState();
        if (flutterState != null) {
            state.surfaceId = flutterState.surfaceId();
            state.displayWidth = flutterState.displayWidth();
            state.displayHeight = flutterState.displayHeight();
            state.route = flutterState.route();
        } else {
            // Default values
            state.surfaceId = 0;
            state.displayWidth = 1.0f;
            state.displayHeight = 1.0f;
            state.route = "";
        }
    }

    @Override
    protected void submitInner(
        FlutterDisplayRenderState state,
        PoseStack poseStack,
        SubmitNodeCollector submitNodeCollector,
        int lightCoords,
        float partialTick
    ) {
        // Get or create surface for this entity's route
        long surfaceId = getOrCreateSurface(state);

        System.out.println("[FlutterDisplayRenderer] submitInner called! entityId=" + state.entityId +
            ", surfaceId=" + surfaceId + ", route='" + state.route + "'" +
            ", width=" + state.displayWidth + ", height=" + state.displayHeight);

        // Get the texture to render using the resolved surface ID
        Identifier texture = getFlutterTexture(surfaceId);
        System.out.println("[FlutterDisplayRenderer] Using texture: " + texture);

        // Calculate quad dimensions (centered at origin)
        float halfW = state.displayWidth / 2.0f;
        float halfH = state.displayHeight / 2.0f;

        // Submit custom geometry - a textured quad
        submitNodeCollector.submitCustomGeometry(
            poseStack,
            RenderTypes.entityTranslucent(texture),
            (pose, vertexConsumer) -> {
                Matrix4f matrix = pose.pose();

                // Render a quad facing forward (positive Z direction in entity local space)
                // After billboard rotation, this will face the camera
                // UV coordinates: (0,0) = top-left, (1,1) = bottom-right

                // Vertex order: bottom-left, bottom-right, top-right, top-left (counter-clockwise for front face)
                // Normal pointing toward viewer (0, 0, 1) after model transformation

                // Bottom-left vertex
                vertexConsumer.addVertex(matrix, -halfW, -halfH, 0.0f)
                    .setColor(255, 255, 255, 255)
                    .setUv(0.0f, 1.0f)  // Flip V for correct orientation
                    .setOverlay(OverlayTexture.NO_OVERLAY)
                    .setLight(lightCoords)
                    .setNormal(pose, 0.0f, 0.0f, 1.0f);

                // Bottom-right vertex
                vertexConsumer.addVertex(matrix, halfW, -halfH, 0.0f)
                    .setColor(255, 255, 255, 255)
                    .setUv(1.0f, 1.0f)
                    .setOverlay(OverlayTexture.NO_OVERLAY)
                    .setLight(lightCoords)
                    .setNormal(pose, 0.0f, 0.0f, 1.0f);

                // Top-right vertex
                vertexConsumer.addVertex(matrix, halfW, halfH, 0.0f)
                    .setColor(255, 255, 255, 255)
                    .setUv(1.0f, 0.0f)
                    .setOverlay(OverlayTexture.NO_OVERLAY)
                    .setLight(lightCoords)
                    .setNormal(pose, 0.0f, 0.0f, 1.0f);

                // Top-left vertex
                vertexConsumer.addVertex(matrix, -halfW, halfH, 0.0f)
                    .setColor(255, 255, 255, 255)
                    .setUv(0.0f, 0.0f)
                    .setOverlay(OverlayTexture.NO_OVERLAY)
                    .setLight(lightCoords)
                    .setNormal(pose, 0.0f, 0.0f, 1.0f);
            }
        );
    }

    /**
     * Get the texture identifier for a Flutter surface.
     *
     * Uses FlutterTextureManager to get a properly registered DynamicTexture
     * that is updated from Flutter's rendered output.
     *
     * @param surfaceId The Flutter surface ID
     * @return The texture identifier to use for rendering
     */
    private Identifier getFlutterTexture(long surfaceId) {
        // Check if Flutter client is initialized
        if (!DartBridgeClient.isClientInitialized()) {
            return PLACEHOLDER_TEXTURE;
        }

        // Use FlutterTextureManager to get a properly managed texture
        FlutterTextureManager manager = FlutterTextureManager.getInstance();
        if (manager == null) {
            return PLACEHOLDER_TEXTURE;
        }

        // Get the texture location - this will also trigger an update from Flutter
        Identifier location = manager.getTextureLocation(surfaceId);
        if (location == null) {
            return PLACEHOLDER_TEXTURE;
        }

        // Check if the texture has valid data
        if (!manager.hasValidTexture(surfaceId)) {
            return PLACEHOLDER_TEXTURE;
        }

        return location;
    }
}
