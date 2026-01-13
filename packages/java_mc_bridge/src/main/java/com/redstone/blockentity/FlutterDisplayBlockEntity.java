package com.redstone.blockentity;

import com.redstone.DartBridge;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.protocol.Packet;
import net.minecraft.network.protocol.game.ClientGamePacketListener;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.storage.ValueInput;
import net.minecraft.world.level.storage.ValueOutput;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Block entity for displaying Flutter UI content on block faces.
 *
 * This block entity supports multi-block displays (e.g., 3x2 TV screen) by tracking
 * the grid position and total grid size. Each block in the grid references the same
 * Flutter surface but displays a different portion based on its grid coordinates.
 *
 * Key properties:
 * - surfaceId: Links to a Flutter surface (0 = main surface for now)
 * - gridX, gridY: Position within a multi-block grid (0,0 = top-left)
 * - gridWidth, gridHeight: Total grid dimensions
 * - facing: Which block face displays the content
 * - emissive: Whether to use fullbright lighting (true = ignore world light)
 */
public class FlutterDisplayBlockEntity extends BlockEntity {
    private static final Logger LOGGER = LoggerFactory.getLogger("FlutterDisplayBlockEntity");

    // Surface ID linking to Flutter - 0 means main surface
    private long surfaceId = 0;

    // Grid position for multi-block displays
    private int gridX = 0;
    private int gridY = 0;

    // Total grid dimensions (1x1 = single block display)
    private int gridWidth = 1;
    private int gridHeight = 1;

    // Which face of the block displays the content
    private Direction facing = Direction.NORTH;

    // Whether to use fullbright lighting (emissive)
    private boolean emissive = true;

    public FlutterDisplayBlockEntity(BlockEntityType<?> type, BlockPos pos, BlockState state) {
        super(type, pos, state);
    }

    // ==========================================================================
    // Getters and Setters
    // ==========================================================================

    public long getSurfaceId() {
        return surfaceId;
    }

    public void setSurfaceId(long surfaceId) {
        this.surfaceId = surfaceId;
        setChanged();
    }

    public int getGridX() {
        return gridX;
    }

    public void setGridX(int gridX) {
        this.gridX = gridX;
        setChanged();
    }

    public int getGridY() {
        return gridY;
    }

    public void setGridY(int gridY) {
        this.gridY = gridY;
        setChanged();
    }

    public int getGridWidth() {
        return gridWidth;
    }

    public void setGridWidth(int gridWidth) {
        this.gridWidth = Math.max(1, gridWidth);
        setChanged();
    }

    public int getGridHeight() {
        return gridHeight;
    }

    public void setGridHeight(int gridHeight) {
        this.gridHeight = Math.max(1, gridHeight);
        setChanged();
    }

    public Direction getFacing() {
        return facing;
    }

    public void setFacing(Direction facing) {
        this.facing = facing;
        setChanged();
    }

    public boolean isEmissive() {
        return emissive;
    }

    public void setEmissive(boolean emissive) {
        this.emissive = emissive;
        setChanged();
    }

    // ==========================================================================
    // Multi-block grid configuration
    // ==========================================================================

    /**
     * Configure this block entity for a multi-block display.
     *
     * @param surfaceId The Flutter surface ID to display
     * @param gridX X position in the grid (0 = left)
     * @param gridY Y position in the grid (0 = top)
     * @param gridWidth Total grid width
     * @param gridHeight Total grid height
     * @param facing Which block face to render on
     * @param emissive Whether to use fullbright lighting
     */
    public void configure(long surfaceId, int gridX, int gridY, int gridWidth, int gridHeight,
                         Direction facing, boolean emissive) {
        this.surfaceId = surfaceId;
        this.gridX = gridX;
        this.gridY = gridY;
        this.gridWidth = Math.max(1, gridWidth);
        this.gridHeight = Math.max(1, gridHeight);
        this.facing = facing;
        this.emissive = emissive;
        setChanged();

        // Sync to clients
        if (level != null && !level.isClientSide()) {
            level.sendBlockUpdated(getBlockPos(), getBlockState(), getBlockState(), 3);
        }
    }

    // ==========================================================================
    // NBT Persistence
    // ==========================================================================

    @Override
    protected void loadAdditional(ValueInput valueInput) {
        super.loadAdditional(valueInput);

        this.surfaceId = valueInput.getIntOr("SurfaceId", 0);
        this.gridX = valueInput.getIntOr("GridX", 0);
        this.gridY = valueInput.getIntOr("GridY", 0);
        this.gridWidth = valueInput.getIntOr("GridWidth", 1);
        this.gridHeight = valueInput.getIntOr("GridHeight", 1);

        int facingOrdinal = valueInput.getIntOr("Facing", Direction.NORTH.ordinal());
        this.facing = Direction.values()[facingOrdinal];

        this.emissive = valueInput.getBooleanOr("Emissive", true);
    }

    @Override
    protected void saveAdditional(ValueOutput valueOutput) {
        super.saveAdditional(valueOutput);

        valueOutput.putInt("SurfaceId", (int) surfaceId);
        valueOutput.putInt("GridX", gridX);
        valueOutput.putInt("GridY", gridY);
        valueOutput.putInt("GridWidth", gridWidth);
        valueOutput.putInt("GridHeight", gridHeight);
        valueOutput.putInt("Facing", facing.ordinal());
        valueOutput.putBoolean("Emissive", emissive);
    }

    // ==========================================================================
    // Client Sync
    // ==========================================================================

    @Override
    public CompoundTag getUpdateTag(HolderLookup.Provider registries) {
        CompoundTag tag = super.getUpdateTag(registries);
        tag.putLong("SurfaceId", surfaceId);
        tag.putInt("GridX", gridX);
        tag.putInt("GridY", gridY);
        tag.putInt("GridWidth", gridWidth);
        tag.putInt("GridHeight", gridHeight);
        tag.putInt("Facing", facing.ordinal());
        tag.putBoolean("Emissive", emissive);
        return tag;
    }

    @Override
    public Packet<ClientGamePacketListener> getUpdatePacket() {
        return ClientboundBlockEntityDataPacket.create(this);
    }
}
