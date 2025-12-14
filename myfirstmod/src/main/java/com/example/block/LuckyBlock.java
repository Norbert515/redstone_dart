package com.example.block;

import com.example.ExampleMod;
import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.entity.item.ItemEntity;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;

import java.util.List;
import java.util.Random;

/**
 * Lucky Block - When broken, drops random loot!
 * Can give you diamonds... or just dirt. It's all about luck!
 */
public class LuckyBlock extends Block {

    private record LootEntry(ItemStack stack, int weight) {}

    private static final List<LootEntry> LOOT_TABLE = List.of(
            // Common items (high weight)
            new LootEntry(new ItemStack(Items.DIRT, 4), 20),
            new LootEntry(new ItemStack(Items.COBBLESTONE, 8), 20),
            new LootEntry(new ItemStack(Items.STICK, 16), 15),
            new LootEntry(new ItemStack(Items.COAL, 4), 15),
            new LootEntry(new ItemStack(Items.RAW_IRON, 2), 12),

            // Uncommon items (medium weight)
            new LootEntry(new ItemStack(Items.GOLD_INGOT, 2), 8),
            new LootEntry(new ItemStack(Items.LAPIS_LAZULI, 8), 8),
            new LootEntry(new ItemStack(Items.REDSTONE, 8), 8),
            new LootEntry(new ItemStack(Items.IRON_INGOT, 3), 8),
            new LootEntry(new ItemStack(Items.EXPERIENCE_BOTTLE, 5), 7),

            // Rare items (low weight)
            new LootEntry(new ItemStack(Items.DIAMOND, 1), 4),
            new LootEntry(new ItemStack(Items.EMERALD, 2), 4),
            new LootEntry(new ItemStack(Items.GOLDEN_APPLE, 1), 3),
            new LootEntry(new ItemStack(Items.ENDER_PEARL, 2), 3),
            new LootEntry(new ItemStack(Items.NAME_TAG, 1), 3),

            // Epic items (very low weight)
            new LootEntry(new ItemStack(Items.DIAMOND_SWORD, 1), 2),
            new LootEntry(new ItemStack(Items.DIAMOND_PICKAXE, 1), 2),
            new LootEntry(new ItemStack(Items.ENCHANTED_GOLDEN_APPLE, 1), 1),
            new LootEntry(new ItemStack(Items.ELYTRA, 1), 1),
            new LootEntry(new ItemStack(Items.TOTEM_OF_UNDYING, 1), 1),

            // Troll items (medium weight - for fun!)
            new LootEntry(new ItemStack(Items.POISONOUS_POTATO, 10), 5),
            new LootEntry(new ItemStack(Items.ROTTEN_FLESH, 8), 5),
            new LootEntry(ItemStack.EMPTY, 5) // Nothing at all!
    );

    private static final Random random = new Random();

    public LuckyBlock(Properties properties) {
        super(properties);
    }

    // Called when block is broken - use spawnAfterBreak which is called on ServerLevel
    @Override
    protected void spawnAfterBreak(BlockState state, ServerLevel world, BlockPos pos, ItemStack tool, boolean dropExperience) {
        super.spawnAfterBreak(state, world, pos, tool, dropExperience);
        dropRandomLoot(world, pos);
    }

    private void dropRandomLoot(ServerLevel world, BlockPos pos) {
        int totalWeight = LOOT_TABLE.stream().mapToInt(LootEntry::weight).sum();
        int roll = random.nextInt(totalWeight);
        int currentWeight = 0;

        for (LootEntry entry : LOOT_TABLE) {
            currentWeight += entry.weight;
            if (roll < currentWeight) {
                ItemStack loot = entry.stack.copy();

                if (!loot.isEmpty()) {
                    double x = pos.getX() + 0.5;
                    double y = pos.getY() + 0.5;
                    double z = pos.getZ() + 0.5;

                    ItemEntity itemEntity = new ItemEntity(world, x, y, z, loot);
                    itemEntity.setDefaultPickUpDelay();
                    itemEntity.setDeltaMovement(
                            (random.nextDouble() - 0.5) * 0.3,
                            random.nextDouble() * 0.3 + 0.2,
                            (random.nextDouble() - 0.5) * 0.3
                    );

                    world.addFreshEntity(itemEntity);
                    world.playSound(null, pos, SoundEvents.AMETHYST_BLOCK_CHIME, SoundSource.BLOCKS, 1.0f, 1.0f);

                    ExampleMod.LOGGER.info("Lucky Block dropped: {}", loot.getItem());
                } else {
                    world.playSound(null, pos, SoundEvents.VILLAGER_NO, SoundSource.BLOCKS, 1.0f, 1.0f);
                    ExampleMod.LOGGER.info("Lucky Block dropped nothing!");
                }
                return;
            }
        }
    }
}
