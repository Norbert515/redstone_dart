package com.redstone.flutter;

import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.network.chat.Component;

/**
 * Test screen for Flutter integration.
 * A concrete implementation that uses provided asset paths.
 */
@Environment(EnvType.CLIENT)
public class TestFlutterScreen extends FlutterScreen {

    private final String assetsPath;
    private final String icuPath;

    /**
     * Create a test Flutter screen with explicit asset paths.
     *
     * @param assetsPath Path to the Flutter assets directory
     * @param icuPath Path to the ICU data file
     */
    public TestFlutterScreen(String assetsPath, String icuPath) {
        super(Component.literal("Flutter Test"));
        this.assetsPath = assetsPath;
        this.icuPath = icuPath;
    }

    @Override
    protected String getFlutterAssetsPath() {
        return assetsPath;
    }

    @Override
    protected String getFlutterIcuPath() {
        return icuPath;
    }
}
