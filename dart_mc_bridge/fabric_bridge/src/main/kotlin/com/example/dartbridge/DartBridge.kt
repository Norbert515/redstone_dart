package com.example.dartbridge

/**
 * JNI interface to the native Dart bridge.
 *
 * This object provides the Kotlin interface to the native C++ library
 * that manages the Dart VM and event dispatch.
 */
object DartBridge {
    private var initialized = false

    init {
        try {
            System.loadLibrary("dart_mc_bridge")
            println("[DartBridge] Native library loaded successfully")
        } catch (e: UnsatisfiedLinkError) {
            System.err.println("[DartBridge] Failed to load native library: ${e.message}")
            System.err.println("[DartBridge] Make sure libdart_mc_bridge is in java.library.path")
        }
    }

    /**
     * Initialize the Dart VM with the given kernel file.
     *
     * @param kernelPath Path to the compiled Dart kernel (.dill file)
     * @return true if initialization succeeded
     */
    external fun init(kernelPath: String): Boolean

    /**
     * Shutdown the Dart VM and clean up resources.
     */
    external fun shutdown()

    /**
     * Process Dart async tasks (microtask queue).
     * Should be called each game tick.
     */
    external fun tick()

    /**
     * Dispatch a block break event to Dart handlers.
     *
     * @param x Block X coordinate
     * @param y Block Y coordinate
     * @param z Block Z coordinate
     * @param playerId The entity ID of the player breaking the block
     * @return 1 to allow the break, 0 to cancel
     */
    external fun onBlockBreak(x: Int, y: Int, z: Int, playerId: Long): Int

    /**
     * Dispatch a block interact event to Dart handlers.
     *
     * @param x Block X coordinate
     * @param y Block Y coordinate
     * @param z Block Z coordinate
     * @param playerId The entity ID of the player
     * @param hand 0 for main hand, 1 for off hand
     * @return 1 to allow the interaction, 0 to cancel
     */
    external fun onBlockInteract(x: Int, y: Int, z: Int, playerId: Long, hand: Int): Int

    /**
     * Dispatch a tick event to Dart handlers.
     *
     * @param tick The current game tick
     */
    external fun onTick(tick: Long)

    // ============================================================
    // Proxy Block Callbacks
    // These are called by DartBlockProxy to delegate behavior to Dart
    // ============================================================

    /**
     * Called when a proxy block is broken.
     * Notifies Dart of the break event for the specific block handler.
     *
     * @param handlerId The Dart handler ID for this block type
     * @param worldId Identifier for the world (hash code)
     * @param x Block X coordinate
     * @param y Block Y coordinate
     * @param z Block Z coordinate
     * @param playerId The entity ID of the player breaking the block
     */
    external fun onProxyBlockBreak(
        handlerId: Long,
        worldId: Long,
        x: Int,
        y: Int,
        z: Int,
        playerId: Long
    )

    /**
     * Called when a proxy block is used (right-clicked).
     * Notifies Dart of the use event for the specific block handler.
     *
     * @param handlerId The Dart handler ID for this block type
     * @param worldId Identifier for the world (hash code)
     * @param x Block X coordinate
     * @param y Block Y coordinate
     * @param z Block Z coordinate
     * @param playerId The entity ID of the player
     * @param hand 0 for main hand, 1 for off hand
     * @return ActionResult ordinal (0=SUCCESS, 1=CONSUME, 2=CONSUME_PARTIAL, 3=PASS, 4=FAIL)
     */
    external fun onProxyBlockUse(
        handlerId: Long,
        worldId: Long,
        x: Int,
        y: Int,
        z: Int,
        playerId: Long,
        hand: Int
    ): Int

    /**
     * Check if the bridge is initialized.
     */
    fun isInitialized(): Boolean = initialized

    /**
     * Safe initialization wrapper.
     */
    fun safeInit(kernelPath: String): Boolean {
        if (initialized) {
            println("[DartBridge] Already initialized")
            return true
        }

        return try {
            initialized = init(kernelPath)
            if (initialized) {
                println("[DartBridge] Dart VM initialized successfully")
            } else {
                System.err.println("[DartBridge] Failed to initialize Dart VM")
            }
            initialized
        } catch (e: Exception) {
            System.err.println("[DartBridge] Exception during initialization: ${e.message}")
            false
        }
    }

    /**
     * Safe shutdown wrapper.
     */
    fun safeShutdown() {
        if (!initialized) return

        try {
            shutdown()
            initialized = false
            println("[DartBridge] Dart VM shut down")
        } catch (e: Exception) {
            System.err.println("[DartBridge] Exception during shutdown: ${e.message}")
        }
    }
}
