package com.redstone.proxy;

import com.redstone.DartBridge;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.RandomSource;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.InsideBlockEffectApplier;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.Property;
import net.minecraft.world.level.redstone.Orientation;
import net.minecraft.world.phys.BlockHitResult;
import org.jetbrains.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * A Block proxy that delegates all behavior to Dart.
 *
 * Each instance of this class represents a single Dart-defined block type.
 * The dartHandlerId links to the Dart-side CustomBlock instance.
 *
 * Supports:
 * - Dynamic block state properties (boolean, int, direction)
 * - Redstone signal emission and reception
 * - All standard block callbacks (use, step, break, etc.)
 */
public class DartBlockProxy extends Block {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartBlockProxy");

    // ThreadLocal to pass properties to createBlockStateDefinition() during super() constructor
    // This is needed because createBlockStateDefinition() is called before our fields are initialized
    private static final ThreadLocal<List<DartBlockProperty>> PENDING_PROPERTIES = new ThreadLocal<>();

    private final long dartHandlerId;
    private final boolean ticksRandomly;

    // Block state property support
    private final List<Property<?>> blockProperties;
    private final Map<String, Property<?>> propertyByName;

    // Redstone support
    private final boolean isRedstoneSource;
    private final boolean hasAnalogOutput;

    /**
     * Set pending properties before constructing a DartBlockProxy.
     * This must be called before new DartBlockProxy() when using block state properties.
     *
     * @param props List of property definitions from Dart registration
     */
    public static void setPendingProperties(List<DartBlockProperty> props) {
        PENDING_PROPERTIES.set(props);
    }

    /**
     * Clear pending properties after construction.
     */
    public static void clearPendingProperties() {
        PENDING_PROPERTIES.remove();
    }

    public DartBlockProxy(Properties settings, long dartHandlerId, Object blockSettings) {
        super(settings);
        this.dartHandlerId = dartHandlerId;

        // Initialize property collections
        List<DartBlockProperty> pendingProps = PENDING_PROPERTIES.get();
        this.blockProperties = new ArrayList<>();
        this.propertyByName = new HashMap<>();

        // Convert pending Dart properties to Minecraft properties
        if (pendingProps != null) {
            for (DartBlockProperty dp : pendingProps) {
                Property<?> prop = dp.toMinecraftProperty();
                blockProperties.add(prop);
                propertyByName.put(dp.name, prop);
            }

            // Register default state with all properties at their first values
            if (!blockProperties.isEmpty()) {
                BlockState defaultState = this.stateDefinition.any();
                for (Property<?> prop : blockProperties) {
                    defaultState = setPropertyDefault(defaultState, prop);
                }
                this.registerDefaultState(defaultState);
            }
        }

        // Extract ticksRandomly from the record if available
        this.ticksRandomly = extractBoolean(blockSettings, "ticksRandomly", false);

        // Extract redstone settings
        this.isRedstoneSource = extractBoolean(blockSettings, "isRedstoneSource", false);
        this.hasAnalogOutput = extractBoolean(blockSettings, "hasAnalogOutput", false);
    }

    @Override
    protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
        // This is called during the super() constructor, before our fields are set
        // We use the ThreadLocal to get the properties that were set before construction
        List<DartBlockProperty> props = PENDING_PROPERTIES.get();
        if (props != null) {
            for (DartBlockProperty dp : props) {
                builder.add(dp.toMinecraftProperty());
            }
        }
    }

    /**
     * Extract a boolean value from a record-like object using reflection.
     */
    private static boolean extractBoolean(Object obj, String methodName, boolean defaultValue) {
        if (obj == null) return defaultValue;
        try {
            var method = obj.getClass().getMethod(methodName);
            return (Boolean) method.invoke(obj);
        } catch (Exception e) {
            return defaultValue;
        }
    }

    /**
     * Set a property to its default (first) value.
     */
    @SuppressWarnings("unchecked")
    private <T extends Comparable<T>> BlockState setPropertyDefault(BlockState state, Property<T> prop) {
        T defaultValue = prop.getPossibleValues().iterator().next();
        return state.setValue(prop, defaultValue);
    }

    // === Accessors ===

    public long getDartHandlerId() {
        return dartHandlerId;
    }

    /**
     * Get a property by name.
     */
    public Property<?> getProperty(String name) {
        return propertyByName.get(name);
    }

    /**
     * Get all block properties.
     */
    public List<Property<?>> getBlockProperties() {
        return blockProperties;
    }

    /**
     * Check if this block is configured as a redstone signal source.
     */
    public boolean isRedstoneSourceBlock() {
        return isRedstoneSource;
    }

    // === Redstone Methods ===

    @Override
    protected boolean isSignalSource(BlockState state) {
        return isRedstoneSource;
    }

    @Override
    protected int getSignal(BlockState state, BlockGetter level, BlockPos pos, Direction direction) {
        if (!isRedstoneSource || !DartBridge.isInitialized()) return 0;

        int stateData = encodeState(state);
        return DartBridge.onProxyBlockGetSignal(
            dartHandlerId,
            stateData,
            direction.ordinal()
        );
    }

    @Override
    protected int getDirectSignal(BlockState state, BlockGetter level, BlockPos pos, Direction direction) {
        if (!isRedstoneSource || !DartBridge.isInitialized()) return 0;

        int stateData = encodeState(state);
        return DartBridge.onProxyBlockGetDirectSignal(
            dartHandlerId,
            stateData,
            direction.ordinal()
        );
    }

    @Override
    protected boolean hasAnalogOutputSignal(BlockState state) {
        return hasAnalogOutput;
    }

    @Override
    protected int getAnalogOutputSignal(BlockState state, Level level, BlockPos pos, Direction direction) {
        if (!hasAnalogOutput || !DartBridge.isInitialized()) return 0;

        int stateData = encodeState(state);
        return DartBridge.onProxyBlockGetAnalogOutput(
            dartHandlerId,
            level.hashCode(),
            pos.getX(), pos.getY(), pos.getZ(),
            stateData
        );
    }

    // === State Encoding/Decoding ===

    /**
     * Encode the block state properties into a single int.
     * Each property gets a portion of bits based on its range.
     *
     * @param state The block state to encode
     * @return Packed integer containing all property values
     */
    public int encodeState(BlockState state) {
        if (blockProperties.isEmpty()) return 0;

        int encoded = 0;
        int shift = 0;

        for (Property<?> prop : blockProperties) {
            int value = getPropertyIndex(state, prop);
            int bits = bitsNeeded(prop);
            encoded |= (value << shift);
            shift += bits;
        }

        return encoded;
    }

    /**
     * Decode a packed int back into a BlockState.
     *
     * @param encoded The packed integer
     * @return A BlockState with the decoded property values
     */
    public BlockState decodeState(int encoded) {
        BlockState state = this.defaultBlockState();
        if (blockProperties.isEmpty()) return state;

        int shift = 0;
        for (Property<?> prop : blockProperties) {
            int bits = bitsNeeded(prop);
            int mask = (1 << bits) - 1;
            int value = (encoded >> shift) & mask;
            state = setPropertyByIndex(state, prop, value);
            shift += bits;
        }

        return state;
    }

    /**
     * Get the index of the current property value within its possible values.
     */
    private <T extends Comparable<T>> int getPropertyIndex(BlockState state, Property<T> prop) {
        T value = state.getValue(prop);
        int index = 0;
        for (T allowed : prop.getPossibleValues()) {
            if (allowed.equals(value)) return index;
            index++;
        }
        return 0;
    }

    /**
     * Set a property by its value index.
     */
    @SuppressWarnings("unchecked")
    private <T extends Comparable<T>> BlockState setPropertyByIndex(BlockState state, Property<T> prop, int index) {
        int i = 0;
        for (T allowed : prop.getPossibleValues()) {
            if (i == index) {
                return state.setValue(prop, allowed);
            }
            i++;
        }
        return state;
    }

    /**
     * Calculate the number of bits needed to represent all values of a property.
     */
    private int bitsNeeded(Property<?> prop) {
        int values = prop.getPossibleValues().size();
        if (values <= 1) return 0;
        return (int) Math.ceil(Math.log(values) / Math.log(2));
    }

    // === Standard Block Callbacks ===

    @Override
    public BlockState playerWillDestroy(Level level, BlockPos pos, BlockState state, Player player) {
        // Delegate to Dart
        if (DartBridge.isInitialized()) {
            DartBridge.onProxyBlockBreak(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                player.getId()
            );
        }
        return super.playerWillDestroy(level, pos, state, player);
    }

    @Override
    protected InteractionResult useWithoutItem(BlockState state, Level level, BlockPos pos,
                                                Player player, BlockHitResult hit) {
        LOGGER.info("useWithoutItem called! pos={}, clientSide={}, dartInit={}",
            pos, level.isClientSide(), DartBridge.isInitialized());

        // Only run on server side
        if (level.isClientSide()) {
            return InteractionResult.SUCCESS;
        }

        if (!DartBridge.isInitialized()) {
            LOGGER.warn("DartBridge not initialized! libraryLoaded={}", DartBridge.isLibraryLoaded());
            return InteractionResult.PASS;
        }

        LOGGER.info("Calling Dart onProxyBlockUse with handlerId={}", dartHandlerId);
        int result = DartBridge.onProxyBlockUse(
            dartHandlerId,
            level.hashCode(),
            pos.getX(),
            pos.getY(),
            pos.getZ(),
            player.getId(),
            0  // hand ordinal - simplified for now
        );
        LOGGER.info("Dart returned result={}", result);

        // Map result ordinal to InteractionResult
        // In 1.21+, InteractionResult is simplified
        return switch (result) {
            case 0 -> InteractionResult.SUCCESS;        // success, arm swings
            case 1, 2 -> InteractionResult.CONSUME;     // consume variants
            case 3 -> InteractionResult.PASS;           // no interaction
            case 4 -> InteractionResult.FAIL;           // interaction failed
            default -> InteractionResult.PASS;
        };
    }

    @Override
    public void stepOn(Level level, BlockPos pos, BlockState state, Entity entity) {
        // Only run on server side
        if (!level.isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyBlockSteppedOn(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                entity.getId()
            );
        }
        super.stepOn(level, pos, state, entity);
    }

    @Override
    public void fallOn(Level level, BlockState state, BlockPos pos, Entity entity, double fallDistance) {
        // Only run on server side
        if (!level.isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyBlockFallenUpon(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                entity.getId(),
                (float) fallDistance
            );
        }
        super.fallOn(level, state, pos, entity, fallDistance);
    }

    @Override
    protected void randomTick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random) {
        if (DartBridge.isInitialized()) {
            DartBridge.onProxyBlockRandomTick(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ()
            );
        }
        super.randomTick(state, level, pos, random);
    }

    @Override
    protected void onPlace(BlockState state, Level level, BlockPos pos, BlockState oldState, boolean movedByPiston) {
        // Only run on server side and only if block type changed
        if (!level.isClientSide() && !state.is(oldState.getBlock()) && DartBridge.isInitialized()) {
            // Get the player who placed it (may be null if placed by automation)
            // For now, we pass 0 as playerId when unknown
            DartBridge.onProxyBlockPlaced(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                0  // playerId - would need state context to get
            );
        }
        super.onPlace(state, level, pos, oldState, movedByPiston);
    }

    @Override
    protected void affectNeighborsAfterRemoval(BlockState state, ServerLevel level, BlockPos pos, boolean movedByPiston) {
        // Notify Dart that this block was removed
        if (DartBridge.isInitialized()) {
            DartBridge.onProxyBlockRemoved(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ()
            );
        }
        super.affectNeighborsAfterRemoval(state, level, pos, movedByPiston);
    }

    @Override
    protected void neighborChanged(BlockState state, Level level, BlockPos pos, Block neighborBlock, @Nullable Orientation orientation, boolean movedByPiston) {
        // Only run on server side
        if (!level.isClientSide() && DartBridge.isInitialized()) {
            // Since we no longer have neighborPos, pass the block's own position
            // The orientation can be used to determine the direction of the change
            DartBridge.onProxyBlockNeighborChanged(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                pos.getX(),  // neighborPos no longer available in new API
                pos.getY(),
                pos.getZ()
            );
        }
        super.neighborChanged(state, level, pos, neighborBlock, orientation, movedByPiston);
    }

    @Override
    protected void entityInside(BlockState state, Level level, BlockPos pos, Entity entity, InsideBlockEffectApplier applier, boolean intersects) {
        // Only run on server side
        if (!level.isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyBlockEntityInside(
                dartHandlerId,
                level.hashCode(),
                pos.getX(),
                pos.getY(),
                pos.getZ(),
                entity.getId()
            );
        }
        super.entityInside(state, level, pos, entity, applier, intersects);
    }
}
