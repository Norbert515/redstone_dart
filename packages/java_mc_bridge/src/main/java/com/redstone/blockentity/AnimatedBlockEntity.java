package com.redstone.blockentity;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.redstone.DartBridge;
import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Block entity that stores animation state with previous values for interpolation.
 *
 * Animation state includes rotation, translation, scale, and pivot point.
 * Previous tick values are stored for smooth interpolation during rendering.
 *
 * For built-in animations (spin, bob, pulse), the animation is computed directly
 * in Java based on the animation config stored in AnimationRegistry. This avoids
 * JNI overhead for simple time-based animations.
 *
 * For custom animations, Dart is called via JNI to compute the animation state.
 */
public class AnimatedBlockEntity extends BlockEntity {
    private static final Logger LOGGER = LoggerFactory.getLogger("AnimatedBlockEntity");
    private static final Gson GSON = new Gson();

    // Handler ID linking to the Dart-side block entity type handler
    protected final int handlerId;

    // Hash of the block position for unique identification
    protected final long blockPosHash;

    // Current animation state
    private float rotationX = 0, rotationY = 0, rotationZ = 0;
    private float translateX = 0, translateY = 0, translateZ = 0;
    private float scaleX = 1, scaleY = 1, scaleZ = 1;
    private float pivotX = 0.5f, pivotY = 0.5f, pivotZ = 0.5f;

    // Previous tick state (for interpolation)
    private float oRotationX = 0, oRotationY = 0, oRotationZ = 0;
    private float oTranslateX = 0, oTranslateY = 0, oTranslateZ = 0;
    private float oScaleX = 1, oScaleY = 1, oScaleZ = 1;

    // Animation time tracking
    private int tickCount = 0;

    // Cached animation config (parsed once on first tick)
    private JsonObject animationConfig = null;
    private boolean configLoaded = false;
    private String blockId = null;

    public AnimatedBlockEntity(BlockEntityType<?> type, BlockPos pos, BlockState state, int handlerId) {
        super(type, pos, state);
        this.handlerId = handlerId;
        this.blockPosHash = DartBlockEntity.posToHash(pos);
    }

    /**
     * Tick method. Called every game tick (20 times per second).
     * Runs on both client and server to keep animation state synchronized.
     * Saves previous state for interpolation and computes animation based on config.
     */
    public static void tick(Level level, BlockPos pos, BlockState state, AnimatedBlockEntity entity) {
        // Save previous state for interpolation
        entity.oRotationX = entity.rotationX;
        entity.oRotationY = entity.rotationY;
        entity.oRotationZ = entity.rotationZ;
        entity.oTranslateX = entity.translateX;
        entity.oTranslateY = entity.translateY;
        entity.oTranslateZ = entity.translateZ;
        entity.oScaleX = entity.scaleX;
        entity.oScaleY = entity.scaleY;
        entity.oScaleZ = entity.scaleZ;

        entity.tickCount++;

        // Compute animation state based on config
        entity.computeAnimationState();
    }

    /**
     * Load animation config from registry if not already loaded.
     */
    private void loadAnimationConfig() {
        if (configLoaded) return;
        configLoaded = true;

        // Get block ID from block state
        if (blockId == null) {
            blockId = BuiltInRegistries.BLOCK.getKey(getBlockState().getBlock()).toString();
        }

        // Load animation config from registry
        AnimationRegistry.AnimationConfig config = AnimationRegistry.getConfig(blockId);
        if (config != null && config.animationJson() != null && !config.animationJson().isEmpty()) {
            try {
                animationConfig = GSON.fromJson(config.animationJson(), JsonObject.class);
            } catch (Exception e) {
                LOGGER.error("Failed to parse animation config for {}: {}", blockId, e.getMessage());
            }
        }
    }

    /**
     * Compute animation state based on the animation config.
     * Supports spin, bob, pulse, and combined animations computed directly in Java.
     * For custom animations, falls back to Dart JNI calls.
     */
    private void computeAnimationState() {
        loadAnimationConfig();

        if (animationConfig == null) {
            return;
        }

        // Reset state before applying animation
        rotationX = 0;
        rotationY = 0;
        rotationZ = 0;
        translateX = 0;
        translateY = 0;
        translateZ = 0;
        scaleX = 1;
        scaleY = 1;
        scaleZ = 1;
        pivotX = 0.5f;
        pivotY = 0.5f;
        pivotZ = 0.5f;

        // Compute time in seconds (20 ticks per second)
        double time = tickCount / 20.0;

        // Apply animation based on type
        applyAnimation(animationConfig, time);
    }

    /**
     * Apply a single animation to the current state.
     */
    private void applyAnimation(JsonObject anim, double time) {
        String type = anim.has("type") ? anim.get("type").getAsString() : "";

        switch (type) {
            case "spin" -> applySpinAnimation(anim, time);
            case "bob" -> applyBobAnimation(anim, time);
            case "pulse" -> applyPulseAnimation(anim, time);
            case "combined" -> applyCombinedAnimation(anim, time);
            case "custom" -> applyCustomAnimation(time);
            default -> LOGGER.warn("Unknown animation type: {}", type);
        }
    }

    /**
     * Apply spin animation: continuous rotation around an axis.
     */
    private void applySpinAnimation(JsonObject anim, double time) {
        String axis = anim.has("axis") ? anim.get("axis").getAsString() : "y";
        double speed = anim.has("speed") ? anim.get("speed").getAsDouble() : 1.0;

        // Load pivot point
        if (anim.has("pivot")) {
            JsonArray pivot = anim.getAsJsonArray("pivot");
            if (pivot.size() >= 3) {
                pivotX = pivot.get(0).getAsFloat();
                pivotY = pivot.get(1).getAsFloat();
                pivotZ = pivot.get(2).getAsFloat();
            }
        }

        // Compute rotation angle: speed rotations per second, 360 degrees per rotation
        float angle = (float) ((time * speed * 360.0) % 360.0);

        switch (axis) {
            case "x" -> rotationX += angle;
            case "y" -> rotationY += angle;
            case "z" -> rotationZ += angle;
        }
    }

    /**
     * Apply bob animation: bobbing up and down (floating effect).
     */
    private void applyBobAnimation(JsonObject anim, double time) {
        double amplitude = anim.has("amplitude") ? anim.get("amplitude").getAsDouble() : 0.1;
        double frequency = anim.has("frequency") ? anim.get("frequency").getAsDouble() : 1.0;

        // Sine wave oscillation
        translateY += (float) (Math.sin(time * frequency * 2 * Math.PI) * amplitude);
    }

    /**
     * Apply pulse animation: scale pulsing (breathing effect).
     */
    private void applyPulseAnimation(JsonObject anim, double time) {
        double minScale = anim.has("minScale") ? anim.get("minScale").getAsDouble() : 0.9;
        double maxScale = anim.has("maxScale") ? anim.get("maxScale").getAsDouble() : 1.1;
        double frequency = anim.has("frequency") ? anim.get("frequency").getAsDouble() : 1.0;

        // Load pivot point
        if (anim.has("pivot")) {
            JsonArray pivot = anim.getAsJsonArray("pivot");
            if (pivot.size() >= 3) {
                pivotX = pivot.get(0).getAsFloat();
                pivotY = pivot.get(1).getAsFloat();
                pivotZ = pivot.get(2).getAsFloat();
            }
        }

        // Oscillate between 0 and 1
        double t = (Math.sin(time * frequency * 2 * Math.PI) + 1) / 2;
        float scale = (float) (minScale + (maxScale - minScale) * t);

        scaleX *= scale;
        scaleY *= scale;
        scaleZ *= scale;
    }

    /**
     * Apply combined animation: multiple animations combined.
     */
    private void applyCombinedAnimation(JsonObject anim, double time) {
        if (!anim.has("animations")) return;

        JsonArray animations = anim.getAsJsonArray("animations");
        for (int i = 0; i < animations.size(); i++) {
            JsonObject subAnim = animations.get(i).getAsJsonObject();
            applyAnimation(subAnim, time);
        }
    }

    /**
     * Apply custom animation: call Dart via JNI to get animation state.
     * This is used for complex animations that can't be expressed declaratively.
     */
    private void applyCustomAnimation(double time) {
        // For custom animations, we would call Dart via JNI
        // This is a placeholder for future implementation
        // For now, custom animations are not supported on the Java side
        LOGGER.warn("Custom animations require Dart JNI callbacks (not yet implemented)");
    }

    /**
     * Update animation state. Called from Dart via JNI.
     *
     * @param rotX Rotation around X axis in degrees
     * @param rotY Rotation around Y axis in degrees
     * @param rotZ Rotation around Z axis in degrees
     * @param transX Translation along X axis
     * @param transY Translation along Y axis
     * @param transZ Translation along Z axis
     * @param scaleX Scale factor along X axis
     * @param scaleY Scale factor along Y axis
     * @param scaleZ Scale factor along Z axis
     * @param pivotX Pivot point X (0-1, relative to block)
     * @param pivotY Pivot point Y (0-1, relative to block)
     * @param pivotZ Pivot point Z (0-1, relative to block)
     */
    public void setAnimationState(
        float rotX, float rotY, float rotZ,
        float transX, float transY, float transZ,
        float scaleX, float scaleY, float scaleZ,
        float pivotX, float pivotY, float pivotZ
    ) {
        this.rotationX = rotX;
        this.rotationY = rotY;
        this.rotationZ = rotZ;
        this.translateX = transX;
        this.translateY = transY;
        this.translateZ = transZ;
        this.scaleX = scaleX;
        this.scaleY = scaleY;
        this.scaleZ = scaleZ;
        this.pivotX = pivotX;
        this.pivotY = pivotY;
        this.pivotZ = pivotZ;
    }

    // Getters for handler and position
    public int getHandlerId() { return handlerId; }
    public long getBlockPosHash() { return blockPosHash; }

    // Getters for current state
    public float getRotationX() { return rotationX; }
    public float getRotationY() { return rotationY; }
    public float getRotationZ() { return rotationZ; }
    public float getTranslateX() { return translateX; }
    public float getTranslateY() { return translateY; }
    public float getTranslateZ() { return translateZ; }
    public float getScaleX() { return scaleX; }
    public float getScaleY() { return scaleY; }
    public float getScaleZ() { return scaleZ; }
    public float getPivotX() { return pivotX; }
    public float getPivotY() { return pivotY; }
    public float getPivotZ() { return pivotZ; }

    // Getters for previous state (for interpolation)
    public float getORotationX() { return oRotationX; }
    public float getORotationY() { return oRotationY; }
    public float getORotationZ() { return oRotationZ; }
    public float getOTranslateX() { return oTranslateX; }
    public float getOTranslateY() { return oTranslateY; }
    public float getOTranslateZ() { return oTranslateZ; }
    public float getOScaleX() { return oScaleX; }
    public float getOScaleY() { return oScaleY; }
    public float getOScaleZ() { return oScaleZ; }

    public int getTickCount() { return tickCount; }

    @Override
    public void setLevel(Level level) {
        super.setLevel(level);

        // Notify Dart that this block entity was added to a level
        if (DartBridge.isInitialized()) {
            try {
                DartBridge.onBlockEntitySetLevel(handlerId, blockPosHash);
            } catch (Exception e) {
                LOGGER.error("Error notifying Dart of animated block entity setLevel: {}", e.getMessage());
            }
        }
    }

    @Override
    protected void loadAdditional(ValueInput valueInput) {
        super.loadAdditional(valueInput);
        tickCount = valueInput.getIntOr("TickCount", 0);

        // Notify Dart that this block entity was loaded
        if (DartBridge.isInitialized()) {
            try {
                DartBridge.onBlockEntityLoad(handlerId, blockPosHash, "{}");
            } catch (Exception e) {
                LOGGER.error("Error notifying Dart of animated block entity load: {}", e.getMessage());
            }
        }
    }

    @Override
    protected void saveAdditional(ValueOutput valueOutput) {
        super.saveAdditional(valueOutput);
        valueOutput.putInt("TickCount", tickCount);
    }

    @Override
    public void setRemoved() {
        super.setRemoved();

        // Notify Dart that this block entity was removed
        if (DartBridge.isInitialized()) {
            try {
                DartBridge.onBlockEntityRemoved(handlerId, blockPosHash);
            } catch (Exception e) {
                LOGGER.error("Error notifying Dart of animated block entity removal: {}", e.getMessage());
            }
        }
    }
}
