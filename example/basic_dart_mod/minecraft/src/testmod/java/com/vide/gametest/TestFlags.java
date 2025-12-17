package com.vide.gametest;

/**
 * Shared test state for callback verification in GameTests.
 *
 * These flags are set by event handlers and checked by tests
 * to verify that events are being properly dispatched through
 * the Dart bridge.
 */
public class TestFlags {
    public static volatile boolean blockBreakCalled = false;
    public static volatile boolean blockPlacedCalled = false;
    public static volatile boolean blockInteractCalled = false;
    public static volatile int tickCount = 0;
    public static volatile boolean playerJoinCalled = false;
    public static volatile boolean bridgeInitialized = false;

    /**
     * Reset all test flags to their default values.
     * Should be called at the start of each test.
     */
    public static void reset() {
        blockBreakCalled = false;
        blockPlacedCalled = false;
        blockInteractCalled = false;
        tickCount = 0;
        playerJoinCalled = false;
        bridgeInitialized = false;
    }
}
