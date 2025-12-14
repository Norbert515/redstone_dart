package com.example.dartbridge

import net.minecraft.block.Block
import net.minecraft.block.BlockState
import net.minecraft.block.Blocks
import net.minecraft.entity.player.PlayerEntity
import net.minecraft.util.ActionResult
import net.minecraft.util.hit.BlockHitResult
import net.minecraft.util.math.BlockPos
import net.minecraft.world.World

/**
 * A proxy block that delegates its behavior to Dart code.
 *
 * Each instance of this class represents a single Dart-defined block type.
 * The dartHandlerId links to the Dart-side CustomBlock instance, allowing
 * multiple different block types with different behaviors.
 *
 * Usage:
 * 1. Create block via ProxyRegistry.createBlock() which assigns a handler ID
 * 2. Register the block via ProxyRegistry.registerBlock()
 * 3. In Dart, register handlers for this block's events using the handler ID
 * 4. When players interact with the block, Dart handlers are called
 */
class DartBlockProxy(
    settings: Settings,
    val dartHandlerId: Long
) : Block(settings) {

    companion object {
        /**
         * Create a DartBlockProxy with default settings and a handler ID.
         */
        fun create(dartHandlerId: Long): DartBlockProxy {
            return DartBlockProxy(
                Settings.copy(Blocks.STONE)
                    .strength(2.0f, 6.0f),
                dartHandlerId
            )
        }

        /**
         * Create a DartBlockProxy copying settings from another block.
         */
        fun copyOf(block: Block, dartHandlerId: Long): DartBlockProxy {
            return DartBlockProxy(Settings.copy(block), dartHandlerId)
        }
    }

    /**
     * Called when the block is used (right-clicked) by a player.
     * Delegates to Dart via the native bridge.
     *
     * Note: In Minecraft 1.21+, the onUse signature changed to not include Hand.
     */
    override fun onUse(
        state: BlockState,
        world: World,
        pos: BlockPos,
        player: PlayerEntity,
        hit: BlockHitResult
    ): ActionResult {
        if (world.isClient) {
            return ActionResult.SUCCESS
        }

        if (!DartBridge.isInitialized()) {
            return ActionResult.PASS
        }

        val result = DartBridge.onProxyBlockUse(
            dartHandlerId,
            world.hashCode().toLong(),
            pos.x,
            pos.y,
            pos.z,
            player.id.toLong(),
            0 // Hand is not available in new API, default to main hand
        )

        // ActionResult values: SUCCESS=0, CONSUME=1, CONSUME_PARTIAL=2, PASS=3, FAIL=4
        return ActionResult.entries.getOrElse(result) { ActionResult.PASS }
    }

    /**
     * Called when the block is broken by a player.
     * Delegates to Dart via the native bridge.
     */
    override fun onBreak(world: World, pos: BlockPos, state: BlockState, player: PlayerEntity): BlockState {
        if (!world.isClient && DartBridge.isInitialized()) {
            DartBridge.onProxyBlockBreak(
                dartHandlerId,
                world.hashCode().toLong(),
                pos.x,
                pos.y,
                pos.z,
                player.id.toLong()
            )
        }

        return super.onBreak(world, pos, state, player)
    }

    // Additional lifecycle methods that can be overridden to delegate to Dart:

    /**
     * Called when an entity steps on this block.
     */
    // override fun onSteppedOn(world: World, pos: BlockPos, state: BlockState, entity: Entity) {
    //     if (!world.isClient && DartBridge.isInitialized()) {
    //         DartBridge.onProxyBlockSteppedOn(dartHandlerId, ...)
    //     }
    //     super.onSteppedOn(world, pos, state, entity)
    // }

    /**
     * Called when an entity lands on this block.
     */
    // override fun onLandedUpon(world: World, state: BlockState, pos: BlockPos, entity: Entity, fallDistance: Float) {
    //     if (!world.isClient && DartBridge.isInitialized()) {
    //         DartBridge.onProxyBlockLandedUpon(dartHandlerId, ...)
    //     }
    //     super.onLandedUpon(world, state, pos, entity, fallDistance)
    // }

    /**
     * Called when a neighbor block changes.
     */
    // override fun neighborUpdate(state: BlockState, world: World, pos: BlockPos, sourceBlock: Block, sourcePos: BlockPos, notify: Boolean) {
    //     if (!world.isClient && DartBridge.isInitialized()) {
    //         DartBridge.onProxyBlockNeighborUpdate(dartHandlerId, ...)
    //     }
    //     super.neighborUpdate(state, world, pos, sourceBlock, sourcePos, notify)
    // }
}
