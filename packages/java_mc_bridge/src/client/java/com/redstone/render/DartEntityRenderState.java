package com.redstone.render;

import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.renderer.entity.state.LivingEntityRenderState;

/**
 * Custom render state for Dart entities that includes the baby field
 * required for ageable models like CowModel.
 */
@Environment(EnvType.CLIENT)
public class DartEntityRenderState extends LivingEntityRenderState {
    public boolean baby = false;
}
