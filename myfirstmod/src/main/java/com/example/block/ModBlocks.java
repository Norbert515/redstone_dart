package com.example.block;

import com.example.ExampleMod;
import com.example.dartbridge.DartContainerBlock;
import net.fabricmc.fabric.api.itemgroup.v1.ItemGroupEvents;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.CreativeModeTabs;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockBehaviour;

import java.util.function.Function;

public class ModBlocks {

    // Lucky Block - gives random loot when broken!
    public static final Block LUCKY_BLOCK = register(
            "lucky_block",
            LuckyBlock::new,
            BlockBehaviour.Properties.of()
                    .strength(0.5f)
                    .sound(SoundType.AMETHYST)
                    .lightLevel(state -> 7),
            true
    );

    // Teleporter Pad - teleports players between linked pads
    public static final Block TELEPORTER_PAD = register(
            "teleporter_pad",
            TeleporterPadBlock::new,
            BlockBehaviour.Properties.of()
                    .strength(2.0f)
                    .sound(SoundType.METAL)
                    .lightLevel(state -> 10)
                    .noOcclusion(),
            true
    );

    // Tech Fabricator - crafting station for high-tech items
    public static final Block TECH_FABRICATOR = register(
            "tech_fabricator",
            TechFabricatorBlock::new,
            BlockBehaviour.Properties.of()
                    .strength(3.5f)
                    .sound(SoundType.METAL)
                    .lightLevel(state -> 12)
                    .requiresCorrectToolForDrops(),
            true
    );

    // Dart Container - opens a Dart-controlled container screen
    public static final Block DART_CONTAINER = register(
            "dart_container",
            DartContainerBlock::new,
            BlockBehaviour.Properties.of()
                    .strength(2.0f)
                    .sound(SoundType.WOOD)
                    .lightLevel(state -> 8),
            true
    );

    private static ResourceKey<Block> keyOfBlock(String name) {
        return ResourceKey.create(
                Registries.BLOCK,
                Identifier.fromNamespaceAndPath(ExampleMod.MOD_ID, name)
        );
    }

    private static ResourceKey<Item> keyOfItem(String name) {
        return ResourceKey.create(
                Registries.ITEM,
                Identifier.fromNamespaceAndPath(ExampleMod.MOD_ID, name)
        );
    }

    private static Block register(String name, Function<BlockBehaviour.Properties, Block> factory,
                                  BlockBehaviour.Properties properties, boolean registerItem) {
        ResourceKey<Block> blockKey = keyOfBlock(name);
        Block block = factory.apply(properties.setId(blockKey));

        if (registerItem) {
            ResourceKey<Item> itemKey = keyOfItem(name);
            BlockItem blockItem = new BlockItem(block,
                    new Item.Properties().setId(itemKey).useBlockDescriptionPrefix());
            Registry.register(BuiltInRegistries.ITEM, itemKey, blockItem);
        }

        return Registry.register(BuiltInRegistries.BLOCK, blockKey, block);
    }

    public static void initialize() {
        ExampleMod.LOGGER.info("Registering mod blocks...");

        ItemGroupEvents.modifyEntriesEvent(CreativeModeTabs.FUNCTIONAL_BLOCKS).register(entries -> {
            entries.accept(LUCKY_BLOCK);
            entries.accept(TELEPORTER_PAD);
            entries.accept(TECH_FABRICATOR);
            entries.accept(DART_CONTAINER);
        });
    }
}
