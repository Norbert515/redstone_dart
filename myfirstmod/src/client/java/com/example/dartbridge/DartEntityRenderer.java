package com.example.dartbridge;

import com.example.dartbridge.proxy.DartEntityProxy;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;

/**
 * Simple renderer for Dart proxy entities.
 * Currently renders only a shadow - proper model support will be added in Phase 3.
 *
 * The entity is functional on the server side (AI, damage, etc.) but visually
 * only shows as a shadow until we add proper model rendering.
 */
public class DartEntityRenderer extends EntityRenderer<DartEntityProxy, DartEntityRenderState> {

    public DartEntityRenderer(EntityRendererProvider.Context context) {
        super(context);
        // Show a shadow so players know something is there
        this.shadowRadius = 0.5f;
    }

    @Override
    public DartEntityRenderState createRenderState() {
        return new DartEntityRenderState();
    }

    // TODO: Add proper model rendering in Phase 3
    // For now, entities show only as shadows on the ground
}
