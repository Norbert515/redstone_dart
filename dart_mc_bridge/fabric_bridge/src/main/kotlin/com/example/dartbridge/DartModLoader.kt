package com.example.dartbridge

import net.fabricmc.api.ModInitializer
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents
import net.fabricmc.fabric.api.event.player.PlayerBlockBreakEvents
import net.fabricmc.fabric.api.event.player.UseBlockCallback
import net.minecraft.util.ActionResult
import java.nio.file.Path

/**
 * Fabric mod initializer that loads and manages the Dart VM.
 *
 * This class is responsible for:
 * - Initializing the Dart VM when the server starts
 * - Forwarding Minecraft events to Dart handlers
 * - Shutting down the Dart VM when the server stops
 */
class DartModLoader : ModInitializer {
    companion object {
        const val MOD_ID = "dart_bridge"
        private var tickCounter: Long = 0

        /**
         * Path to the Dart kernel file.
         * This should be configurable via a config file in production.
         */
        fun getKernelPath(): String {
            // TODO: Make this configurable
            return Path.of("mods", "dart_mod.dill").toAbsolutePath().toString()
        }
    }

    override fun onInitialize() {
        println("[$MOD_ID] Initializing Dart Bridge mod...")

        // Initialize Dart VM when server starts
        ServerLifecycleEvents.SERVER_STARTING.register { server ->
            println("[$MOD_ID] Server starting, initializing Dart VM...")
            val kernelPath = getKernelPath()
            println("[$MOD_ID] Kernel path: $kernelPath")

            if (!DartBridge.safeInit(kernelPath)) {
                System.err.println("[$MOD_ID] Failed to initialize Dart VM!")
                System.err.println("[$MOD_ID] Make sure $kernelPath exists")
            }
        }

        // Shutdown Dart VM when server stops
        ServerLifecycleEvents.SERVER_STOPPED.register { server ->
            println("[$MOD_ID] Server stopped, shutting down Dart VM...")
            DartBridge.safeShutdown()
        }

        // Register tick event
        ServerTickEvents.END_SERVER_TICK.register { server ->
            if (DartBridge.isInitialized()) {
                DartBridge.onTick(tickCounter++)
            }
        }

        // Register block break event
        PlayerBlockBreakEvents.BEFORE.register { world, player, pos, state, blockEntity ->
            if (!DartBridge.isInitialized()) return@register true

            val result = DartBridge.onBlockBreak(
                pos.x,
                pos.y,
                pos.z,
                player.id.toLong()
            )

            // Return true to allow break, false to cancel
            result != 0
        }

        // Register block interact event
        UseBlockCallback.EVENT.register { player, world, hand, hitResult ->
            if (!DartBridge.isInitialized()) return@register ActionResult.PASS

            val pos = hitResult.blockPos
            val handValue = if (hand == net.minecraft.util.Hand.MAIN_HAND) 0 else 1

            val result = DartBridge.onBlockInteract(
                pos.x,
                pos.y,
                pos.z,
                player.id.toLong(),
                handValue
            )

            if (result == 0) {
                ActionResult.FAIL
            } else {
                ActionResult.PASS
            }
        }

        println("[$MOD_ID] Dart Bridge mod initialized!")
    }
}
