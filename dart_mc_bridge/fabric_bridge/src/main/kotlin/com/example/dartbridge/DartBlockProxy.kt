package com.example.dartbridge

import net.minecraft.block.Block
import net.minecraft.block.BlockState
import net.minecraft.block.Blocks
import net.minecraft.entity.player.PlayerEntity
import net.minecraft.util.ActionResult
import net.minecraft.util.Hand
import net.minecraft.util.hit.BlockHitResult
import net.minecraft.util.math.BlockPos
import net.minecraft.world.World

/**
 * A proxy block that delegates its behavior to Dart code.
 *
 * This block can be used to create custom blocks where the logic
 * is implemented in Dart rather than Kotlin/Java.
 *
 * Usage:
 * 1. Register this block with a unique identifier
 * 2. In Dart, register handlers for this block's events
 * 3. When players interact with the block, Dart handlers are called
 */
class DartBlockProxy(settings: Settings) : Block(settings) {

    companion object {
        /**
         * Create a DartBlockProxy with default settings.
         */
        fun create(): DartBlockProxy {
            return DartBlockProxy(
                Settings.copy(Blocks.STONE)
                    .strength(2.0f, 6.0f)
            )
        }

        /**
         * Create a DartBlockProxy copying settings from another block.
         */
        fun copyOf(block: Block): DartBlockProxy {
            return DartBlockProxy(Settings.copy(block))
        }
    }

    // TODO: Add block ID for Dart to identify which block is being interacted with
    // This could be used to have multiple different Dart-controlled blocks

    @Deprecated("Deprecated in Java")
    override fun onUse(
        state: BlockState,
        world: World,
        pos: BlockPos,
        player: PlayerEntity,
        hand: Hand,
        hit: BlockHitResult
    ): ActionResult {
        if (world.isClient) {
            return ActionResult.SUCCESS
        }

        if (!DartBridge.isInitialized()) {
            return ActionResult.PASS
        }

        val handValue = if (hand == Hand.MAIN_HAND) 0 else 1
        val result = DartBridge.onBlockInteract(
            pos.x,
            pos.y,
            pos.z,
            player.id.toLong(),
            handValue
        )

        return if (result != 0) {
            ActionResult.SUCCESS
        } else {
            ActionResult.FAIL
        }
    }

    override fun onBreak(world: World, pos: BlockPos, state: BlockState, player: PlayerEntity): BlockState {
        if (!world.isClient && DartBridge.isInitialized()) {
            val result = DartBridge.onBlockBreak(
                pos.x,
                pos.y,
                pos.z,
                player.id.toLong()
            )

            if (result == 0) {
                // Dart cancelled the break - we can't actually prevent it here
                // since onBreak is called after the break is confirmed,
                // but we could add visual/audio feedback
                println("[DartBlockProxy] Block break was marked as cancelled by Dart")
            }
        }

        return super.onBreak(world, pos, state, player)
    }
}
