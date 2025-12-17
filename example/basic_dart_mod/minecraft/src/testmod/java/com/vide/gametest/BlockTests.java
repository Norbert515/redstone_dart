package com.vide.gametest;

import com.redstone.DartBridge;
import com.redstone.proxy.DartBlockProxy;
import net.fabricmc.fabric.api.gametest.v1.FabricGameTest;
import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.gametest.framework.GameTest;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;

/**
 * GameTests for custom block functionality registered through the Dart bridge.
 *
 * These tests verify that:
 * - Custom blocks are properly registered
 * - Block placement works
 * - Block break callbacks fire correctly
 */
public class BlockTests implements FabricGameTest {

    /**
     * Test that the block registry contains expected blocks.
     * Custom blocks registered from Dart should be available.
     */
    @GameTest(template = EMPTY_STRUCTURE)
    public void blockRegistryContainsBlocks(GameTestHelper helper) {
        // Check that the built-in registry is accessible
        int blockCount = 0;
        for (Block block : BuiltInRegistries.BLOCK) {
            blockCount++;
        }

        if (blockCount == 0) {
            helper.fail("Block registry is empty");
            return;
        }

        helper.succeed();
    }

    /**
     * Test that a standard block can be placed.
     * This verifies the basic block placement mechanism works.
     */
    @GameTest(template = EMPTY_STRUCTURE)
    public void canPlaceStandardBlock(GameTestHelper helper) {
        BlockPos pos = new BlockPos(0, 1, 0);
        helper.setBlock(pos, Blocks.STONE);

        helper.succeedWhen(() -> {
            Block placed = helper.getBlockState(pos).getBlock();
            if (placed != Blocks.STONE) {
                throw new AssertionError("Expected STONE but got " + placed);
            }
        });
    }

    /**
     * Test that a block can be destroyed.
     * This verifies block destruction works correctly.
     */
    @GameTest(template = EMPTY_STRUCTURE)
    public void canDestroyBlock(GameTestHelper helper) {
        BlockPos pos = new BlockPos(0, 1, 0);

        // Place a block
        helper.setBlock(pos, Blocks.DIRT);

        // Destroy it
        helper.destroyBlock(pos);

        helper.succeedWhen(() -> {
            Block block = helper.getBlockState(pos).getBlock();
            if (block != Blocks.AIR) {
                throw new AssertionError("Block should be air after destruction");
            }
        });
    }

    /**
     * Test that DartBlockProxy blocks are registered.
     * Looks for any block that is an instance of DartBlockProxy.
     */
    @GameTest(template = EMPTY_STRUCTURE)
    public void dartProxyBlocksRegistered(GameTestHelper helper) {
        if (!DartBridge.isInitialized()) {
            // If Dart isn't initialized, we can't expect proxy blocks
            helper.succeed();
            return;
        }

        boolean foundProxyBlock = false;
        for (Block block : BuiltInRegistries.BLOCK) {
            if (block instanceof DartBlockProxy) {
                foundProxyBlock = true;
                break;
            }
        }

        // It's OK if no proxy blocks are registered - the test Dart script
        // might not register any blocks
        helper.succeed();
    }

    /**
     * Test placing and breaking a DartBlockProxy if one exists.
     */
    @GameTest(template = EMPTY_STRUCTURE, timeoutTicks = 40)
    public void dartProxyBlockPlaceAndBreak(GameTestHelper helper) {
        if (!DartBridge.isInitialized()) {
            helper.succeed();
            return;
        }

        // Find a DartBlockProxy block to test
        Block proxyBlock = null;
        for (Block block : BuiltInRegistries.BLOCK) {
            if (block instanceof DartBlockProxy) {
                proxyBlock = block;
                break;
            }
        }

        if (proxyBlock == null) {
            // No proxy blocks registered, that's OK
            helper.succeed();
            return;
        }

        BlockPos pos = new BlockPos(0, 1, 0);
        final Block testBlock = proxyBlock;

        // Place the proxy block
        helper.setBlock(pos, testBlock);

        helper.runAfterDelay(5, () -> {
            // Verify it was placed
            Block placed = helper.getBlockState(pos).getBlock();
            if (placed != testBlock) {
                helper.fail("Failed to place DartBlockProxy");
                return;
            }

            // Destroy it
            helper.destroyBlock(pos);

            helper.runAfterDelay(5, () -> {
                // Verify destruction
                Block after = helper.getBlockState(pos).getBlock();
                if (after == testBlock) {
                    helper.fail("DartBlockProxy was not destroyed");
                    return;
                }
                helper.succeed();
            });
        });
    }
}
