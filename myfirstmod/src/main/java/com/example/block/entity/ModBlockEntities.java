package com.example.block.entity;

import com.example.ExampleMod;
import com.example.block.ModBlocks;
import net.fabricmc.fabric.api.object.builder.v1.block.entity.FabricBlockEntityTypeBuilder;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityType;

public class ModBlockEntities {

    public static final BlockEntityType<TeleporterPadBlockEntity> TELEPORTER_PAD_ENTITY =
            register("teleporter_pad",
                    FabricBlockEntityTypeBuilder.create(TeleporterPadBlockEntity::new, ModBlocks.TELEPORTER_PAD)
                            .build());

    public static final BlockEntityType<TechFabricatorBlockEntity> TECH_FABRICATOR_ENTITY =
            register("tech_fabricator",
                    FabricBlockEntityTypeBuilder.create(TechFabricatorBlockEntity::new, ModBlocks.TECH_FABRICATOR)
                            .build());

    private static <T extends BlockEntity> BlockEntityType<T> register(String name, BlockEntityType<T> type) {
        Identifier id = Identifier.fromNamespaceAndPath(ExampleMod.MOD_ID, name);
        return Registry.register(BuiltInRegistries.BLOCK_ENTITY_TYPE, id, type);
    }

    public static void initialize() {
        ExampleMod.LOGGER.info("Registering block entities...");
    }
}
