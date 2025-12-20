package com.redstone.proxy;

import net.fabricmc.fabric.api.object.builder.v1.entity.FabricDefaultAttributeRegistry;
import net.fabricmc.fabric.api.object.builder.v1.entity.FabricEntityTypeBuilder;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.entity.EntityDimensions;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.animal.Animal;
import net.minecraft.world.entity.projectile.ThrowableProjectile;
import net.minecraft.world.item.Item;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Registry for Dart-defined proxy entities.
 *
 * This registry manages the lifecycle of proxy entities and provides
 * methods for registering new entities from Dart code.
 *
 * The registration process is two-phase:
 * 1. createEntity() - Called from Dart to reserve a handler ID and store entity settings
 * 2. registerEntity() - Called from Dart to register the entity with Minecraft's registry
 *
 * This two-phase approach is needed because Minecraft requires a ResourceKey during
 * entity construction, but we don't know the entity's namespace:path until registration.
 */
public class EntityProxyRegistry {
    private static final Logger LOGGER = LoggerFactory.getLogger("EntityProxyRegistry");
    private static final Map<Long, EntityType<?>> entityTypes = new HashMap<>();
    private static final Map<Long, EntitySettings> pendingSettings = new HashMap<>();
    private static final Map<Long, Item> animalBreedingItems = new HashMap<>();
    private static long nextHandlerId = 1;

    // Base type constants matching Dart side
    public static final int BASE_TYPE_PATHFINDER_MOB = 0;
    public static final int BASE_TYPE_MONSTER = 1;
    public static final int BASE_TYPE_ANIMAL = 2;
    public static final int BASE_TYPE_PROJECTILE = 3;

    /**
     * Holds entity settings between createEntity() and registerEntity() calls.
     */
    private record EntitySettings(
        float width, float height, double maxHealth,
        double movementSpeed, double attackDamage, int spawnGroup, int baseType,
        String breedingItem
    ) {}

    /**
     * Create a new entity slot with the given settings.
     * Returns the handler ID that links to this entity.
     *
     * Called from Dart via JNI during the first phase of entity registration.
     *
     * @param width Entity collision box width.
     * @param height Entity collision box height.
     * @param maxHealth Maximum health points.
     * @param movementSpeed Movement speed multiplier.
     * @param attackDamage Base attack damage.
     * @param spawnGroup Spawn group ordinal (0=monster, 1=creature, 2=ambient, 3=water_creature, 4=misc).
     * @param baseType Entity base type (0=PathfinderMob, 1=Monster, 2=Animal, 3=Projectile).
     * @return The handler ID to use when registering the entity.
     */
    public static long createEntity(float width, float height, float maxHealth,
                                     float movementSpeed, float attackDamage, int spawnGroup, int baseType) {
        return createEntityWithBreedingItem(width, height, maxHealth, movementSpeed, attackDamage, spawnGroup, baseType, null);
    }

    /**
     * Create a new entity slot with the given settings, including breeding item for animals.
     * Returns the handler ID that links to this entity.
     *
     * Called from Dart via JNI during the first phase of entity registration.
     *
     * @param width Entity collision box width.
     * @param height Entity collision box height.
     * @param maxHealth Maximum health points.
     * @param movementSpeed Movement speed multiplier.
     * @param attackDamage Base attack damage.
     * @param spawnGroup Spawn group ordinal (0=monster, 1=creature, 2=ambient, 3=water_creature, 4=misc).
     * @param baseType Entity base type (0=PathfinderMob, 1=Monster, 2=Animal, 3=Projectile).
     * @param breedingItem The breeding item identifier (e.g., "minecraft:wheat"), or null if not applicable.
     * @return The handler ID to use when registering the entity.
     */
    public static long createEntityWithBreedingItem(float width, float height, float maxHealth,
                                     float movementSpeed, float attackDamage, int spawnGroup, int baseType,
                                     String breedingItem) {
        long handlerId = nextHandlerId++;

        // Store settings for use during registerEntity()
        pendingSettings.put(handlerId, new EntitySettings(
            width, height, maxHealth, movementSpeed, attackDamage, spawnGroup, baseType, breedingItem));

        LOGGER.info("Created entity slot with handler ID: {}, baseType: {}, breedingItem: {}", handlerId, baseType, breedingItem);
        return handlerId;
    }

    /**
     * Register the entity with Minecraft's registry.
     * Must be called during mod initialization before registry freeze.
     *
     * Called from Dart via JNI during the second phase of entity registration.
     *
     * @param handlerId The handler ID returned by createEntity().
     * @param namespace The entity namespace (e.g., "dartmod").
     * @param path The entity path (e.g., "custom_zombie").
     * @return true if registration succeeded, false otherwise.
     */
    public static boolean registerEntity(long handlerId, String namespace, String path) {
        EntitySettings settings = pendingSettings.get(handlerId);
        if (settings == null) {
            LOGGER.error("No pending entity settings for handler ID: {}", handlerId);
            return false;
        }

        try {
            // Map spawn group ordinal to MobCategory
            MobCategory category = switch (settings.spawnGroup()) {
                case 0 -> MobCategory.MONSTER;
                case 1 -> MobCategory.CREATURE;
                case 2 -> MobCategory.AMBIENT;
                case 3 -> MobCategory.WATER_CREATURE;
                default -> MobCategory.MISC;
            };

            // Create identifier for this entity
            Identifier entityId = Identifier.fromNamespaceAndPath(namespace, path);

            // Create resource key for this entity
            ResourceKey<EntityType<?>> key = ResourceKey.create(
                Registries.ENTITY_TYPE,
                entityId
            );

            final long capturedHandlerId = handlerId;
            EntityType<?> entityType;

            // Switch based on base type
            if (settings.baseType() == BASE_TYPE_PROJECTILE) {
                // Projectiles don't use createMob - use create() instead
                entityType = FabricEntityTypeBuilder.<DartProjectileProxy>create(category,
                        (type, level) -> new DartProjectileProxy(type, level, capturedHandlerId))
                    .dimensions(EntityDimensions.fixed(settings.width(), settings.height()))
                    .trackRangeChunks(4)
                    .trackedUpdateRate(10)
                    .build(key);

                // Register with Minecraft's entity type registry
                Registry.register(BuiltInRegistries.ENTITY_TYPE, entityId, entityType);

                // Projectiles don't have attributes - no FabricDefaultAttributeRegistry call
                LOGGER.info("Registered projectile {}:{} with handler ID {}", namespace, path, handlerId);
            } else if (settings.baseType() == BASE_TYPE_MONSTER) {
                // Monster entity - hostile mob with Monster base class
                EntityType<DartMonsterProxy> monsterEntityType = FabricEntityTypeBuilder.<DartMonsterProxy>createMob()
                    .spawnGroup(category)
                    .entityFactory((type, level) -> new DartMonsterProxy(type, level, capturedHandlerId))
                    .dimensions(EntityDimensions.fixed(settings.width(), settings.height()))
                    .build(key);

                // Register with Minecraft's entity type registry
                Registry.register(BuiltInRegistries.ENTITY_TYPE, entityId, monsterEntityType);

                // Register attributes using Fabric API with Monster attributes
                AttributeSupplier.Builder attributes = DartMonsterProxy.createAttributes(
                    settings.maxHealth(), settings.movementSpeed(), settings.attackDamage());
                FabricDefaultAttributeRegistry.register(monsterEntityType, attributes);

                entityType = monsterEntityType;
                LOGGER.info("Registered monster {}:{} with handler ID {}", namespace, path, handlerId);
            } else if (settings.baseType() == BASE_TYPE_ANIMAL) {
                // Animal entity - breedable passive mob
                // Resolve breeding item from identifier
                Item breedingItem = null;
                if (settings.breedingItem() != null && !settings.breedingItem().isEmpty()) {
                    Identifier itemId = Identifier.tryParse(settings.breedingItem());
                    if (itemId != null) {
                        var itemOpt = BuiltInRegistries.ITEM.getOptional(itemId);
                        if (itemOpt.isPresent()) {
                            breedingItem = itemOpt.get();
                            LOGGER.info("Resolved breeding item {} for animal {}", settings.breedingItem(), entityId);
                        } else {
                            LOGGER.warn("Breeding item not found in registry: {}", settings.breedingItem());
                        }
                    } else {
                        LOGGER.warn("Invalid breeding item identifier: {}", settings.breedingItem());
                    }
                }

                // Store breeding item for entity factory to use
                final Item capturedBreedingItem = breedingItem;
                animalBreedingItems.put(capturedHandlerId, breedingItem);

                EntityType<DartAnimalProxy> animalEntityType = FabricEntityTypeBuilder.<DartAnimalProxy>createMob()
                    .spawnGroup(category)
                    .entityFactory((type, level) -> new DartAnimalProxy(type, level, capturedHandlerId, capturedBreedingItem))
                    .dimensions(EntityDimensions.fixed(settings.width(), settings.height()))
                    .build(key);

                // Register with Minecraft's entity type registry
                Registry.register(BuiltInRegistries.ENTITY_TYPE, entityId, animalEntityType);

                // Register attributes using Fabric API with Animal attributes
                AttributeSupplier.Builder animalAttributes = DartAnimalProxy.createAttributes(
                    settings.maxHealth(), settings.movementSpeed(), settings.attackDamage());
                FabricDefaultAttributeRegistry.register(animalEntityType, animalAttributes);

                entityType = animalEntityType;
                LOGGER.info("Registered animal {}:{} with handler ID {}, breedingItem: {}",
                    namespace, path, handlerId, settings.breedingItem());
            } else {
                // Default: PathfinderMob entity
                // Build entity type using FabricEntityTypeBuilder for proper type inference
                // We capture the handlerId in the factory lambda
                EntityType<DartEntityProxy> mobEntityType = FabricEntityTypeBuilder.<DartEntityProxy>createMob()
                    .spawnGroup(category)
                    .entityFactory((type, level) -> new DartEntityProxy(type, level, capturedHandlerId))
                    .dimensions(EntityDimensions.fixed(settings.width(), settings.height()))
                    .build(key);

                // Register with Minecraft's entity type registry
                Registry.register(BuiltInRegistries.ENTITY_TYPE, entityId, mobEntityType);

                // Register attributes using Fabric API
                AttributeSupplier.Builder attributes = DartEntityProxy.createAttributes(
                    settings.maxHealth(), settings.movementSpeed(), settings.attackDamage());
                FabricDefaultAttributeRegistry.register(mobEntityType, attributes);

                entityType = mobEntityType;
                LOGGER.info("Registered entity {}:{} with handler ID {}", namespace, path, handlerId);
            }

            entityTypes.put(handlerId, entityType);
            pendingSettings.remove(handlerId);

            return true;
        } catch (Exception e) {
            LOGGER.error("Failed to register entity {}:{}: {}", namespace, path, e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Get the EntityType for a handler ID.
     */
    public static EntityType<?> getEntityType(long handlerId) {
        return entityTypes.get(handlerId);
    }

    /**
     * Get the breeding item for an animal entity.
     *
     * @param handlerId The handler ID of the animal entity.
     * @return The breeding item, or null if not set or not an animal.
     */
    public static Item getBreedingItem(long handlerId) {
        return animalBreedingItems.get(handlerId);
    }

    /**
     * Get the handler ID for an EntityType (reverse lookup).
     *
     * @param type The EntityType to look up.
     * @return The handler ID, or -1 if not found.
     */
    public static long getHandlerIdByType(EntityType<?> type) {
        for (var entry : entityTypes.entrySet()) {
            if (entry.getValue() == type) {
                return entry.getKey();
            }
        }
        return -1;
    }

    /**
     * Get all registered handler IDs.
     */
    public static long[] getAllHandlerIds() {
        return entityTypes.keySet().stream().mapToLong(Long::longValue).toArray();
    }

    /**
     * Get the number of registered entities.
     */
    public static int getEntityCount() {
        return entityTypes.size();
    }
}
