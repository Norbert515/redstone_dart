package com.redstone.proxy;

import net.minecraft.world.level.block.state.properties.*;
import net.minecraft.core.Direction;
import java.util.Arrays;
import java.util.Collection;

/**
 * Wrapper for dynamically creating block state properties from Dart.
 *
 * These classes allow Dart code to define block state properties (boolean, int, direction)
 * that will be added to DartBlockProxy instances at registration time.
 */
public abstract class DartBlockProperty {
    public final String name;

    protected DartBlockProperty(String name) {
        this.name = name;
    }

    /**
     * Convert this Dart property definition to a Minecraft Property instance.
     */
    public abstract Property<?> toMinecraftProperty();

    /**
     * Get the number of possible values for this property.
     * Used for state encoding calculations.
     */
    public abstract int getValueCount();

    /**
     * Boolean property - can be true or false.
     *
     * Example use cases: powered, lit, open, triggered, etc.
     */
    public static class BooleanProp extends DartBlockProperty {
        public BooleanProp(String name) {
            super(name);
        }

        @Override
        public BooleanProperty toMinecraftProperty() {
            return BooleanProperty.create(name);
        }

        @Override
        public int getValueCount() {
            return 2;
        }
    }

    /**
     * Integer property with a min and max range.
     *
     * Example use cases: power (0-15), age (0-7), rotation (0-15), etc.
     */
    public static class IntProp extends DartBlockProperty {
        public final int min;
        public final int max;

        public IntProp(String name, int min, int max) {
            super(name);
            this.min = min;
            this.max = max;
        }

        @Override
        public IntegerProperty toMinecraftProperty() {
            return IntegerProperty.create(name, min, max);
        }

        @Override
        public int getValueCount() {
            return max - min + 1;
        }
    }

    /**
     * Direction property for blocks that can face different directions.
     *
     * Uses EnumProperty<Direction> since Minecraft's Mojang mappings don't have
     * a separate DirectionProperty class.
     *
     * Example use cases: facing, orientation, etc.
     */
    public static class DirectionProp extends DartBlockProperty {
        public final Direction[] allowedDirections;

        /**
         * Create a direction property.
         *
         * @param name Property name (e.g., "facing")
         * @param allowed Allowed directions, or null for all 6 directions
         */
        public DirectionProp(String name, Direction[] allowed) {
            super(name);
            this.allowedDirections = allowed != null ? allowed : Direction.values();
        }

        @Override
        public EnumProperty<Direction> toMinecraftProperty() {
            return EnumProperty.create(name, Direction.class, Arrays.asList(allowedDirections));
        }

        @Override
        public int getValueCount() {
            return allowedDirections.length;
        }

        /**
         * Create a direction property for horizontal directions only (N, S, E, W).
         */
        public static DirectionProp horizontal(String name) {
            return new DirectionProp(name, new Direction[]{
                Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST
            });
        }

        /**
         * Create a direction property for all 6 directions.
         */
        public static DirectionProp all(String name) {
            return new DirectionProp(name, Direction.values());
        }
    }

    /**
     * Factory methods for creating properties from JSON data.
     * These are called from Java when processing Dart registration data.
     */
    public static DartBlockProperty fromJson(String type, String name, Object... args) {
        return switch (type.toLowerCase()) {
            case "boolean", "bool" -> new BooleanProp(name);
            case "int", "integer" -> {
                int min = args.length > 0 ? ((Number) args[0]).intValue() : 0;
                int max = args.length > 1 ? ((Number) args[1]).intValue() : 15;
                yield new IntProp(name, min, max);
            }
            case "direction" -> {
                if (args.length > 0 && args[0] instanceof String dirType) {
                    yield switch (dirType.toLowerCase()) {
                        case "horizontal" -> DirectionProp.horizontal(name);
                        case "all", "full" -> DirectionProp.all(name);
                        default -> DirectionProp.all(name);
                    };
                }
                yield DirectionProp.all(name);
            }
            default -> throw new IllegalArgumentException("Unknown property type: " + type);
        };
    }
}
