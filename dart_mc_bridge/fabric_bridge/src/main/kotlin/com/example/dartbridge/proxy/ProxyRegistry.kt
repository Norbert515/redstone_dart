package com.example.dartbridge.proxy

import com.example.dartbridge.DartBlockProxy
import net.minecraft.block.AbstractBlock
import net.minecraft.item.BlockItem
import net.minecraft.item.Item
import net.minecraft.registry.Registries
import net.minecraft.registry.Registry
import net.minecraft.util.Identifier

/**
 * Registry for Dart-defined proxy blocks.
 *
 * This registry manages the lifecycle of proxy blocks and provides
 * methods for registering new blocks from Dart code via JNI.
 *
 * Each block is assigned a unique handler ID that links it to its
 * corresponding Dart-side CustomBlock instance.
 */
object ProxyRegistry {
    private val blocks = mutableMapOf<Long, DartBlockProxy>()
    private var nextHandlerId = 1L

    /**
     * Create a new DartBlockProxy with the given settings.
     * Returns the handler ID that links to this block.
     *
     * Called from Dart via JNI.
     *
     * @param hardness How long it takes to break the block (e.g., stone = 1.5)
     * @param resistance How resistant the block is to explosions (e.g., stone = 6.0)
     * @param requiresTool Whether the block requires a tool to drop items
     * @return The handler ID for this block
     */
    @JvmStatic
    fun createBlock(
        hardness: Float,
        resistance: Float,
        requiresTool: Boolean
    ): Long {
        val handlerId = nextHandlerId++

        var settings = AbstractBlock.Settings.create()
            .strength(hardness, resistance)

        if (requiresTool) {
            settings = settings.requiresTool()
        }

        val block = DartBlockProxy(settings, handlerId)
        blocks[handlerId] = block

        println("[ProxyRegistry] Created block with handler ID: $handlerId (hardness=$hardness, resistance=$resistance)")
        return handlerId
    }

    /**
     * Register the block with Minecraft's registry.
     * Must be called during mod initialization before registry freeze.
     *
     * Called from Dart via JNI.
     *
     * @param handlerId The handler ID of the block to register
     * @param namespace The namespace for the block ID (e.g., "mymod")
     * @param path The path for the block ID (e.g., "custom_block")
     * @return true if registration succeeded, false if block not found
     */
    @JvmStatic
    fun registerBlock(handlerId: Long, namespace: String, path: String): Boolean {
        val block = blocks[handlerId]
        if (block == null) {
            System.err.println("[ProxyRegistry] Cannot register block: handler ID $handlerId not found")
            return false
        }

        return try {
            val identifier = Identifier.of(namespace, path)

            // Register the block
            Registry.register(Registries.BLOCK, identifier, block)

            // Also register a BlockItem so it appears in creative inventory
            val blockItem = BlockItem(block, Item.Settings())
            Registry.register(Registries.ITEM, identifier, blockItem)

            println("[ProxyRegistry] Registered block: $identifier (handler ID: $handlerId)")
            true
        } catch (e: Exception) {
            System.err.println("[ProxyRegistry] Failed to register block $namespace:$path: ${e.message}")
            false
        }
    }

    /**
     * Get a block by its handler ID.
     *
     * @param handlerId The handler ID of the block
     * @return The block, or null if not found
     */
    @JvmStatic
    fun getBlock(handlerId: Long): DartBlockProxy? = blocks[handlerId]

    /**
     * Get all registered handler IDs.
     *
     * @return Array of all handler IDs
     */
    @JvmStatic
    fun getAllHandlerIds(): LongArray = blocks.keys.toLongArray()

    /**
     * Get the total number of registered blocks.
     *
     * @return The number of blocks in the registry
     */
    @JvmStatic
    fun getBlockCount(): Int = blocks.size

    /**
     * Check if a block with the given handler ID exists.
     *
     * @param handlerId The handler ID to check
     * @return true if the block exists
     */
    @JvmStatic
    fun hasBlock(handlerId: Long): Boolean = blocks.containsKey(handlerId)

    /**
     * Remove a block from the internal registry.
     * Note: This does NOT unregister it from Minecraft's registry (which is immutable after game start).
     *
     * @param handlerId The handler ID of the block to remove
     * @return true if the block was removed
     */
    @JvmStatic
    fun removeBlock(handlerId: Long): Boolean {
        val removed = blocks.remove(handlerId) != null
        if (removed) {
            println("[ProxyRegistry] Removed block with handler ID: $handlerId from internal registry")
        }
        return removed
    }
}
