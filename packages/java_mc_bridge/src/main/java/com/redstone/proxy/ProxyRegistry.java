package com.redstone.proxy;

import net.fabricmc.fabric.api.itemgroup.v1.ItemGroupEvents;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.entity.EquipmentSlotGroup;
import net.minecraft.world.entity.ai.attributes.AttributeModifier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.core.component.DataComponents;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.CreativeModeTabs;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.component.ItemAttributeModifiers;
import net.minecraft.world.item.component.Weapon;
import net.minecraft.world.level.block.state.BlockBehaviour;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Registry for Dart-defined proxy blocks and items.
 *
 * This registry manages the lifecycle of proxy blocks/items and provides
 * methods for registering new blocks and items from Dart code.
 *
 * The registration process is two-phase:
 * 1. createBlock()/createItem() - Called from Dart to reserve a handler ID and store settings
 * 2. registerBlock()/registerItem() - Called from Dart to register with Minecraft's registry
 *
 * This two-phase approach is needed because Minecraft requires a ResourceKey during
 * block/item construction, but we don't know the namespace:path until registration.
 */
public class ProxyRegistry {
    private static final Logger LOGGER = LoggerFactory.getLogger("ProxyRegistry");
    private static final Map<Long, DartBlockProxy> blocks = new HashMap<>();
    private static final Map<Long, BlockSettings> pendingSettings = new HashMap<>();
    private static final Map<Long, Item> items = new HashMap<>();
    private static final Map<Long, ItemSettings> pendingItemSettings = new HashMap<>();
    private static long nextHandlerId = 1;

    /**
     * Holds block settings between createBlock() and registerBlock() calls.
     */
    private record BlockSettings(
        float hardness,
        float resistance,
        boolean requiresTool,
        int luminance,
        double slipperiness,
        double velocityMultiplier,
        double jumpVelocityMultiplier,
        boolean ticksRandomly,
        boolean collidable,
        boolean replaceable,
        boolean burnable
    ) {}

    /**
     * Holds item settings between createItem() and registerItem() calls.
     */
    private record ItemSettings(
        int maxStackSize,
        int maxDamage,
        boolean fireResistant,
        double attackDamage,
        double attackSpeed,
        double attackKnockback
    ) {}

    /**
     * Create a new DartBlockProxy with the given settings.
     * Returns the handler ID that links to this block.
     *
     * Called from Dart via JNI during the first phase of block registration.
     *
     * @param hardness Block hardness (time to break). Use -1 for unbreakable.
     * @param resistance Explosion resistance.
     * @param requiresTool Whether the block requires the correct tool to drop items.
     * @param luminance Light emission level (0-15).
     * @param slipperiness Slipperiness factor (default 0.6, ice is 0.98).
     * @param velocityMultiplier Movement speed multiplier (default 1.0, soul sand is 0.4).
     * @param jumpVelocityMultiplier Jump height multiplier (default 1.0, honey is 0.5).
     * @param ticksRandomly Whether block receives random ticks.
     * @param collidable Whether entities collide with this block.
     * @param replaceable Whether block can be replaced when placing.
     * @param burnable Whether block can catch fire.
     * @return The handler ID to use when registering the block.
     */
    public static long createBlock(
            float hardness,
            float resistance,
            boolean requiresTool,
            int luminance,
            double slipperiness,
            double velocityMultiplier,
            double jumpVelocityMultiplier,
            boolean ticksRandomly,
            boolean collidable,
            boolean replaceable,
            boolean burnable) {
        long handlerId = nextHandlerId++;

        // Store settings for use during registerBlock()
        pendingSettings.put(handlerId, new BlockSettings(
            hardness, resistance, requiresTool,
            luminance, slipperiness, velocityMultiplier, jumpVelocityMultiplier,
            ticksRandomly, collidable, replaceable, burnable));

        LOGGER.info("Prepared DartBlockProxy slot with handler ID: {}", handlerId);
        return handlerId;
    }

    /**
     * Register the block with Minecraft's registry.
     * Must be called during mod initialization before registry freeze.
     *
     * Called from Dart via JNI during the second phase of block registration.
     *
     * @param handlerId The handler ID returned by createBlock().
     * @param namespace The block namespace (e.g., "dartmod").
     * @param path The block path (e.g., "example_block").
     * @return true if registration succeeded, false otherwise.
     */
    public static boolean registerBlock(long handlerId, String namespace, String path) {
        BlockSettings settings = pendingSettings.get(handlerId);
        if (settings == null) {
            LOGGER.error("Cannot register block: handler ID {} not found (createBlock not called?)", handlerId);
            return false;
        }

        try {
            // Create resource keys
            ResourceKey<net.minecraft.world.level.block.Block> blockKey = ResourceKey.create(
                Registries.BLOCK,
                Identifier.fromNamespaceAndPath(namespace, path)
            );
            ResourceKey<Item> itemKey = ResourceKey.create(
                Registries.ITEM,
                Identifier.fromNamespaceAndPath(namespace, path)
            );

            // Create block properties with the settings from createBlock()
            BlockBehaviour.Properties properties = BlockBehaviour.Properties.of()
                .strength(settings.hardness(), settings.resistance())
                .setId(blockKey);

            if (settings.requiresTool()) {
                properties = properties.requiresCorrectToolForDrops();
            }

            // Apply luminance (light level)
            if (settings.luminance() > 0) {
                final int lightLevel = settings.luminance();
                properties = properties.lightLevel(state -> lightLevel);
            }

            // Apply friction (slipperiness)
            if (settings.slipperiness() != 0.6) {
                properties = properties.friction((float) settings.slipperiness());
            }

            // Apply velocity multiplier (speed factor)
            if (settings.velocityMultiplier() != 1.0) {
                properties = properties.speedFactor((float) settings.velocityMultiplier());
            }

            // Apply jump velocity multiplier (jump factor)
            if (settings.jumpVelocityMultiplier() != 1.0) {
                properties = properties.jumpFactor((float) settings.jumpVelocityMultiplier());
            }

            // Apply random ticks
            if (settings.ticksRandomly()) {
                properties = properties.randomTicks();
            }

            // Apply collidable (noCollision if not collidable)
            if (!settings.collidable()) {
                properties = properties.noCollision();
            }

            // Apply replaceable
            if (settings.replaceable()) {
                properties = properties.replaceable();
            }

            // Apply burnable (ignitedByLava)
            if (settings.burnable()) {
                properties = properties.ignitedByLava();
            }

            DartBlockProxy block = new DartBlockProxy(properties, handlerId, settings);
            blocks.put(handlerId, block);
            pendingSettings.remove(handlerId); // Clean up pending settings

            // Register the block
            Registry.register(BuiltInRegistries.BLOCK, blockKey, block);

            // Also register a BlockItem so it appears in creative inventory
            BlockItem blockItem = new BlockItem(block,
                new Item.Properties().setId(itemKey).useBlockDescriptionPrefix());
            Registry.register(BuiltInRegistries.ITEM, itemKey, blockItem);

            // Add to Building Blocks creative tab
            ItemGroupEvents.modifyEntriesEvent(CreativeModeTabs.BUILDING_BLOCKS).register(entries -> {
                entries.accept(blockItem);
            });

            LOGGER.info("Registered block: {}:{} with handler ID {}", namespace, path, handlerId);
            return true;
        } catch (Exception e) {
            LOGGER.error("Failed to register block {}:{}: {}", namespace, path, e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Get a block by its handler ID.
     */
    public static DartBlockProxy getBlock(long handlerId) {
        return blocks.get(handlerId);
    }

    /**
     * Get all registered handler IDs.
     */
    public static long[] getAllHandlerIds() {
        return blocks.keySet().stream().mapToLong(Long::longValue).toArray();
    }

    /**
     * Get the number of registered blocks.
     */
    public static int getBlockCount() {
        return blocks.size();
    }

    // ==================== ITEM REGISTRATION ====================

    /**
     * Create a new item with the given settings.
     * Called from Dart via JNI.
     *
     * @param maxStackSize Maximum stack size (1-64)
     * @param maxDamage Maximum durability (0 for non-damageable)
     * @param fireResistant Whether item survives fire/lava
     * @param attackDamage Attack damage bonus (NaN if not set)
     * @param attackSpeed Attack speed modifier (NaN if not set)
     * @param attackKnockback Attack knockback bonus (NaN if not set)
     * @return Handler ID for this item
     */
    public static long createItem(
            int maxStackSize,
            int maxDamage,
            boolean fireResistant,
            double attackDamage,
            double attackSpeed,
            double attackKnockback) {
        long handlerId = nextHandlerId++;
        pendingItemSettings.put(handlerId, new ItemSettings(
            maxStackSize, maxDamage, fireResistant,
            attackDamage, attackSpeed, attackKnockback
        ));
        LOGGER.info("Created item settings with handler ID: {}", handlerId);
        return handlerId;
    }

    /**
     * Register an item with Minecraft's registry.
     * Called from Dart via JNI.
     *
     * @param handlerId The handler ID from createItem
     * @param namespace The mod namespace (e.g., "mymod")
     * @param path The item path (e.g., "dart_item")
     * @return true if registration succeeded
     */
    public static boolean registerItem(long handlerId, String namespace, String path) {
        ItemSettings settings = pendingItemSettings.remove(handlerId);
        if (settings == null) {
            LOGGER.error("No pending item settings for handler ID: {}", handlerId);
            return false;
        }

        try {
            Identifier itemId = Identifier.fromNamespaceAndPath(namespace, path);
            ResourceKey<Item> itemKey = ResourceKey.create(Registries.ITEM, itemId);

            Item.Properties props = new Item.Properties()
                .setId(itemKey)
                .stacksTo(settings.maxStackSize());

            if (settings.maxDamage() > 0) {
                props = props.durability(settings.maxDamage());
            }
            if (settings.fireResistant()) {
                props = props.fireResistant();
            }

            // Apply combat attributes if set (NaN means not set)
            if (!Double.isNaN(settings.attackDamage()) ||
                !Double.isNaN(settings.attackSpeed()) ||
                !Double.isNaN(settings.attackKnockback())) {

                ItemAttributeModifiers.Builder attrBuilder = ItemAttributeModifiers.builder();

                if (!Double.isNaN(settings.attackDamage())) {
                    attrBuilder.add(
                        Attributes.ATTACK_DAMAGE,
                        new AttributeModifier(
                            Item.BASE_ATTACK_DAMAGE_ID,
                            settings.attackDamage(),
                            AttributeModifier.Operation.ADD_VALUE
                        ),
                        EquipmentSlotGroup.MAINHAND
                    );
                }

                if (!Double.isNaN(settings.attackSpeed())) {
                    attrBuilder.add(
                        Attributes.ATTACK_SPEED,
                        new AttributeModifier(
                            Item.BASE_ATTACK_SPEED_ID,
                            settings.attackSpeed(),
                            AttributeModifier.Operation.ADD_VALUE
                        ),
                        EquipmentSlotGroup.MAINHAND
                    );
                }

                if (!Double.isNaN(settings.attackKnockback())) {
                    attrBuilder.add(
                        Attributes.ATTACK_KNOCKBACK,
                        new AttributeModifier(
                            Identifier.fromNamespaceAndPath(namespace, path + "_knockback"),
                            settings.attackKnockback(),
                            AttributeModifier.Operation.ADD_VALUE
                        ),
                        EquipmentSlotGroup.MAINHAND
                    );
                }

                props = props.attributes(attrBuilder.build());

                // Add WEAPON component - required for postHurtEnemy to be called
                // The Weapon component takes itemDamagePerAttack (durability cost per hit)
                props = props.component(DataComponents.WEAPON, new Weapon(1));
                LOGGER.info("Added WEAPON component to item {}:{}", namespace, path);
            }

            // Create proxy item that routes callbacks to Dart
            DartItemProxy item = new DartItemProxy(props, handlerId);
            Registry.register(BuiltInRegistries.ITEM, itemKey, item);
            items.put(handlerId, item);

            // Add to creative tab (Ingredients)
            ItemGroupEvents.modifyEntriesEvent(CreativeModeTabs.INGREDIENTS)
                .register(entries -> entries.accept(item));

            LOGGER.info("Registered item: {}:{} with handler ID: {}", namespace, path, handlerId);
            return true;
        } catch (Exception e) {
            LOGGER.error("Failed to register item: {}:{}", namespace, path, e);
            return false;
        }
    }

    /**
     * Get an item by handler ID.
     */
    public static Item getItem(long handlerId) {
        return items.get(handlerId);
    }

    /**
     * Get all registered item handler IDs.
     */
    public static long[] getAllItemHandlerIds() {
        return items.keySet().stream().mapToLong(Long::longValue).toArray();
    }

    /**
     * Get the number of registered items.
     */
    public static int getItemCount() {
        return items.size();
    }
}
