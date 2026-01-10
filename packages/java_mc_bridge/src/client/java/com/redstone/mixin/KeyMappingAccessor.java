package com.redstone.mixin;

import com.mojang.blaze3d.platform.InputConstants;
import net.minecraft.client.KeyMapping;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.gen.Accessor;

import java.util.Map;

/**
 * Mixin accessor for KeyMapping to directly access fields.
 *
 * This bypasses ToggleKeyMapping.setDown() which has toggle logic that
 * interferes with hold/release behavior for keys like Shift and Control.
 */
@Mixin(KeyMapping.class)
public interface KeyMappingAccessor {
    /**
     * Directly set the isDown field, bypassing any toggle logic.
     * @param isDown The new value for the isDown field
     */
    @Accessor("isDown")
    void setIsDown(boolean isDown);

    /**
     * Get the current isDown field value.
     * @return The current isDown state
     */
    @Accessor("isDown")
    boolean getIsDown();

    /**
     * Get the current bound key for this KeyMapping.
     * @return The InputConstants.Key that this mapping is bound to
     */
    @Accessor("key")
    InputConstants.Key getKey();

    /**
     * Access the static ALL map that contains all registered KeyMappings.
     * @return The map of all KeyMappings keyed by their names
     */
    @Accessor("ALL")
    static Map<String, KeyMapping> getAll() {
        throw new AssertionError();
    }
}
