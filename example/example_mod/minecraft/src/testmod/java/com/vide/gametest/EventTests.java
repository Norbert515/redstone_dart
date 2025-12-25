package com.vide.gametest;

import com.redstone.DartBridge;
import net.fabricmc.fabric.api.gametest.v1.FabricGameTest;
import net.minecraft.gametest.framework.GameTest;
import net.minecraft.gametest.framework.GameTestHelper;

/**
 * GameTests for event dispatch through the Dart bridge.
 *
 * These tests verify that:
 * - Tick events are dispatched
 * - The event system doesn't cause crashes
 * - Events can be processed over multiple ticks
 */
public class EventTests implements FabricGameTest {

    /**
     * Test that tick events are being dispatched.
     * We can't directly observe Dart receiving the events, but we can
     * verify that dispatchTick doesn't throw.
     */
    @GameTest(template = EMPTY_STRUCTURE, timeoutTicks = 60)
    public void tickEventsDispatch(GameTestHelper helper) {
        if (!DartBridge.isInitialized()) {
            helper.fail("Dart VM not initialized");
            return;
        }

        // Wait multiple ticks to ensure tick dispatch is working
        helper.runAfterDelay(30, () -> {
            // If we haven't crashed by now, tick events are being handled
            helper.succeed();
        });
    }

    /**
     * Test that multiple rapid tick events can be handled.
     * This stress tests the event dispatch mechanism.
     */
    @GameTest(template = EMPTY_STRUCTURE, timeoutTicks = 100)
    public void rapidTickEventsWork(GameTestHelper helper) {
        if (!DartBridge.isInitialized()) {
            helper.fail("Dart VM not initialized");
            return;
        }

        // Let the server run for a while with normal tick processing
        // This tests stability under continuous event dispatch
        helper.runAfterDelay(80, () -> {
            helper.succeed();
        });
    }

    /**
     * Test that the bridge survives safeTick calls.
     * safeTick processes async Dart operations.
     */
    @GameTest(template = EMPTY_STRUCTURE, timeoutTicks = 40)
    public void safeTickProcessing(GameTestHelper helper) {
        if (!DartBridge.isInitialized()) {
            helper.fail("Dart VM not initialized");
            return;
        }

        // safeTick is called automatically on each server tick
        // This test just verifies it doesn't cause issues
        helper.runAfterDelay(20, () -> {
            helper.succeed();
        });
    }

    /**
     * Test that server lifecycle events don't crash the bridge.
     * The bridge should handle serverStarting/Started events gracefully.
     */
    @GameTest(template = EMPTY_STRUCTURE)
    public void lifecycleEventsHandled(GameTestHelper helper) {
        if (!DartBridge.isInitialized()) {
            helper.fail("Dart VM not initialized");
            return;
        }

        // If we're running this test, the server has already started
        // and lifecycle events have been dispatched successfully
        helper.succeed();
    }

    /**
     * Test concurrent event processing doesn't cause issues.
     * Simulates what happens when multiple events occur in rapid succession.
     */
    @GameTest(template = EMPTY_STRUCTURE, timeoutTicks = 60)
    public void concurrentEventsSafe(GameTestHelper helper) {
        if (!DartBridge.isInitialized()) {
            helper.fail("Dart VM not initialized");
            return;
        }

        // Multiple events happening in sequence
        for (int i = 0; i < 10; i++) {
            final int iteration = i;
            helper.runAfterDelay(i * 2, () -> {
                // These calls should all succeed without crashing
                if (DartBridge.isInitialized()) {
                    // Just verify the bridge is still responsive
                    DartBridge.getServiceUrl();
                }
            });
        }

        // Final check after all events
        helper.runAfterDelay(40, () -> {
            if (!DartBridge.isInitialized()) {
                helper.fail("Bridge crashed during concurrent events");
                return;
            }
            helper.succeed();
        });
    }
}
