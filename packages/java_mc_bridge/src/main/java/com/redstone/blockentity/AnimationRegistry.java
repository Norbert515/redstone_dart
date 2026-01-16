package com.redstone.blockentity;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Registry that maps block IDs to their animation configurations.
 *
 * When a block is registered from Dart with an animation, this registry
 * stores the animation configuration so that the AnimatedBlockEntity can
 * compute animation state based on tick count.
 *
 * Animation types supported:
 * - spin: Continuous rotation around an axis
 * - bob: Bobbing up and down (floating effect)
 * - pulse: Scale pulsing (breathing effect)
 * - combined: Multiple animations combined
 */
public class AnimationRegistry {
    private static final Logger LOGGER = LoggerFactory.getLogger("AnimationRegistry");

    /**
     * Configuration for a block animation.
     * Stores the JSON representation of the animation for flexible parsing.
     */
    public record AnimationConfig(
        int handlerId,
        String animationType,
        String animationJson
    ) {}

    /**
     * Map of block ID (e.g., "mymod:spinning_block") to animation configuration.
     */
    private static final Map<String, AnimationConfig> animationConfigs = new HashMap<>();

    /**
     * Register an animation configuration for a block.
     *
     * @param blockId The full block ID (namespace:path)
     * @param handlerId The Dart handler ID for this block
     * @param animationType The type of animation (spin, bob, pulse, combined, custom)
     * @param animationJson JSON string containing the animation parameters
     */
    public static void registerAnimation(
            String blockId,
            int handlerId,
            String animationType,
            String animationJson) {

        AnimationConfig config = new AnimationConfig(handlerId, animationType, animationJson);
        animationConfigs.put(blockId, config);
        LOGGER.info("Registered animation config for {}: type={}", blockId, animationType);
    }

    /**
     * Get the animation configuration for a block.
     *
     * @param blockId The full block ID (namespace:path)
     * @return The configuration, or null if no animation is registered for this block
     */
    public static AnimationConfig getConfig(String blockId) {
        return animationConfigs.get(blockId);
    }

    /**
     * Check if a block has a registered animation.
     *
     * @param blockId The full block ID (namespace:path)
     * @return true if this block has an animation
     */
    public static boolean hasAnimation(String blockId) {
        return animationConfigs.containsKey(blockId);
    }

    /**
     * Get all registered animation configurations.
     *
     * @return Map of block IDs to their configurations
     */
    public static Map<String, AnimationConfig> getAllConfigs() {
        return new HashMap<>(animationConfigs);
    }

    /**
     * Get the number of registered animation types.
     */
    public static int getCount() {
        return animationConfigs.size();
    }

    /**
     * Clear all registered animation configurations.
     * Used for testing or world unload.
     */
    public static void clear() {
        animationConfigs.clear();
    }
}
