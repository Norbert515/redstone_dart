package com.redstone.entity;

import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.world.entity.Display;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;

/**
 * A display entity that renders Flutter UI content as a floating rectangle in the world.
 *
 * Supports billboard modes (inherited from Display):
 * - FIXED: No rotation adjustment
 * - VERTICAL: Rotate around Y axis to face camera
 * - HORIZONTAL: Rotate around X axis to face camera
 * - CENTER: Full billboard, always face camera
 *
 * The surfaceId links to a Flutter surface that provides the rendered texture.
 * Initially uses surfaceId=0 (main Flutter surface) for testing.
 */
public class FlutterDisplayEntity extends Display {

    // Synced entity data for Flutter-specific properties
    private static final EntityDataAccessor<Long> DATA_SURFACE_ID = SynchedEntityData.defineId(
        FlutterDisplayEntity.class, EntityDataSerializers.LONG
    );
    private static final EntityDataAccessor<Float> DATA_DISPLAY_WIDTH = SynchedEntityData.defineId(
        FlutterDisplayEntity.class, EntityDataSerializers.FLOAT
    );
    private static final EntityDataAccessor<Float> DATA_DISPLAY_HEIGHT = SynchedEntityData.defineId(
        FlutterDisplayEntity.class, EntityDataSerializers.FLOAT
    );

    // NBT tags
    public static final String TAG_SURFACE_ID = "surface_id";
    public static final String TAG_DISPLAY_WIDTH = "display_width";
    public static final String TAG_DISPLAY_HEIGHT = "display_height";

    // Client-side render state
    private FlutterRenderState flutterRenderState;

    public FlutterDisplayEntity(EntityType<?> entityType, Level level) {
        super(entityType, level);
        // Trigger initial render state creation
        this.updateRenderState = true;
    }

    @Override
    protected void defineSynchedData(SynchedEntityData.Builder builder) {
        super.defineSynchedData(builder);
        builder.define(DATA_SURFACE_ID, 0L);  // Default to main Flutter surface
        builder.define(DATA_DISPLAY_WIDTH, 1.0f);  // 1 meter wide
        builder.define(DATA_DISPLAY_HEIGHT, 1.0f);  // 1 meter tall
    }

    @Override
    public void onSyncedDataUpdated(EntityDataAccessor<?> accessor) {
        super.onSyncedDataUpdated(accessor);
        if (DATA_SURFACE_ID.equals(accessor) ||
            DATA_DISPLAY_WIDTH.equals(accessor) ||
            DATA_DISPLAY_HEIGHT.equals(accessor)) {
            this.updateRenderState = true;
        }
    }

    // ==========================================================================
    // Surface ID
    // ==========================================================================

    /**
     * Get the Flutter surface ID this entity displays.
     */
    public long getSurfaceId() {
        return this.entityData.get(DATA_SURFACE_ID);
    }

    /**
     * Set the Flutter surface ID this entity displays.
     */
    public void setSurfaceId(long surfaceId) {
        this.entityData.set(DATA_SURFACE_ID, surfaceId);
    }

    // ==========================================================================
    // Display Dimensions
    // ==========================================================================

    /**
     * Get the display width in world units (meters).
     */
    public float getDisplayWidth() {
        return this.entityData.get(DATA_DISPLAY_WIDTH);
    }

    /**
     * Set the display width in world units (meters).
     */
    public void setDisplayWidth(float width) {
        this.entityData.set(DATA_DISPLAY_WIDTH, width);
    }

    /**
     * Get the display height in world units (meters).
     */
    public float getDisplayHeight() {
        return this.entityData.get(DATA_DISPLAY_HEIGHT);
    }

    /**
     * Set the display height in world units (meters).
     */
    public void setDisplayHeight(float height) {
        this.entityData.set(DATA_DISPLAY_HEIGHT, height);
    }

    // ==========================================================================
    // Persistence
    // ==========================================================================

    @Override
    protected void readAdditionalSaveData(ValueInput input) {
        super.readAdditionalSaveData(input);
        this.setSurfaceId(input.getLongOr(TAG_SURFACE_ID, 0L));
        this.setDisplayWidth(input.getFloatOr(TAG_DISPLAY_WIDTH, 1.0f));
        this.setDisplayHeight(input.getFloatOr(TAG_DISPLAY_HEIGHT, 1.0f));
    }

    @Override
    protected void addAdditionalSaveData(ValueOutput output) {
        super.addAdditionalSaveData(output);
        output.putLong(TAG_SURFACE_ID, this.getSurfaceId());
        output.putFloat(TAG_DISPLAY_WIDTH, this.getDisplayWidth());
        output.putFloat(TAG_DISPLAY_HEIGHT, this.getDisplayHeight());
    }

    // ==========================================================================
    // Render State (Client-side)
    // ==========================================================================

    @Override
    protected void updateRenderSubState(boolean interpolate, float partialTick) {
        this.flutterRenderState = new FlutterRenderState(
            this.getSurfaceId(),
            this.getDisplayWidth(),
            this.getDisplayHeight()
        );
    }

    /**
     * Get the Flutter-specific render state.
     */
    public FlutterRenderState flutterRenderState() {
        return this.flutterRenderState;
    }

    /**
     * Flutter-specific render state containing surface and dimension info.
     */
    public record FlutterRenderState(long surfaceId, float displayWidth, float displayHeight) {}
}
