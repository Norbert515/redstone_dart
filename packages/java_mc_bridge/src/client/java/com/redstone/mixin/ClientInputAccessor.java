package com.redstone.mixin;

import net.minecraft.client.player.ClientInput;
import net.minecraft.world.entity.player.Input;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.gen.Accessor;

/**
 * Mixin accessor for ClientInput to directly set the keyPresses field.
 *
 * Since Input is an immutable record, we need to replace the entire keyPresses
 * object with a new Input record containing the desired state.
 */
@Mixin(ClientInput.class)
public interface ClientInputAccessor {
    /**
     * Set the keyPresses field to a new Input record.
     * @param input The new Input record with desired key press states
     */
    @Accessor("keyPresses")
    void setKeyPresses(Input input);

    /**
     * Get the current keyPresses field value.
     * @return The current Input record
     */
    @Accessor("keyPresses")
    Input getKeyPresses();
}
