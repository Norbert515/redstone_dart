package com.redstone.render;

import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.renderer.entity.state.ZombieRenderState;

/**
 * Custom render state for Dart entities.
 *
 * Extends ZombieRenderState to be compatible with ZombieModel (humanoid rendering).
 * This includes the fields needed for humanoid animations:
 * - isAggressive (attack animation)
 * - isConverting (zombie conversion animation)
 * - All HumanoidRenderState fields
 *
 * Also includes the 'baby' field for ageable entities like CowModel.
 */
@Environment(EnvType.CLIENT)
public class DartEntityRenderState extends ZombieRenderState {
    public boolean baby = false;
}
