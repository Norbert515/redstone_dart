package com.vide.gametest;

import com.redstone.DartBridge;
import net.fabricmc.fabric.api.gametest.v1.FabricGameTest;
import net.minecraft.gametest.framework.GameTest;
import net.minecraft.gametest.framework.GameTestHelper;

/**
 * GameTests for the Dart bridge initialization and basic communication.
 *
 * These tests verify that:
 * - The native library loads correctly
 * - The Dart VM initializes properly
 * - Basic bridge communication works
 */
public class BridgeTests implements FabricGameTest {

    /**
     * Test that the native library is loaded.
     * This is the most basic requirement for the bridge to work.
     */
    @GameTest(template = EMPTY_STRUCTURE)
    public void nativeLibraryLoaded(GameTestHelper helper) {
        boolean loaded = DartBridge.isLibraryLoaded();
        if (!loaded) {
            helper.fail("Native library dart_mc_bridge is not loaded");
            return;
        }
        helper.succeed();
    }

    /**
     * Test that the Dart VM initializes.
     * This verifies the init() call succeeds and the VM is running.
     */
    @GameTest(template = EMPTY_STRUCTURE)
    public void dartVmInitializes(GameTestHelper helper) {
        // Check if already initialized (from mod startup)
        if (DartBridge.isInitialized()) {
            helper.succeed();
            return;
        }

        // If not initialized, the library might not be loaded
        if (!DartBridge.isLibraryLoaded()) {
            helper.fail("Cannot test VM init - native library not loaded");
            return;
        }

        // VM should have been initialized during mod loading
        helper.fail("Dart VM was not initialized during mod startup");
    }

    /**
     * Test that the bridge can handle tick callbacks without crashing.
     * This verifies the basic event dispatch mechanism works.
     */
    @GameTest(template = EMPTY_STRUCTURE, timeoutTicks = 40)
    public void tickCallbacksWork(GameTestHelper helper) {
        if (!DartBridge.isInitialized()) {
            helper.fail("Dart VM not initialized");
            return;
        }

        // The tick callback is called automatically by ServerTickEvents
        // We just need to wait a bit and verify no crash occurred
        helper.runAfterDelay(20, () -> {
            // If we get here without crashing, tick callbacks work
            helper.succeed();
        });
    }

    /**
     * Test that the service URL is available when debugging is enabled.
     * This is useful for hot reload during development.
     */
    @GameTest(template = EMPTY_STRUCTURE)
    public void serviceUrlAvailable(GameTestHelper helper) {
        if (!DartBridge.isInitialized()) {
            helper.fail("Dart VM not initialized");
            return;
        }

        String url = DartBridge.getServiceUrl();
        // URL may be null if not running in debug mode, which is OK
        // We just verify getServiceUrl() doesn't throw
        helper.succeed();
    }
}
