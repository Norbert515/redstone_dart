package com.redstone.proxy;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import net.fabricmc.fabric.api.loot.v3.LootTableEvents;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.storage.loot.LootPool;
import net.minecraft.world.level.storage.loot.LootTable;
import net.minecraft.world.level.storage.loot.entries.LootItem;
import net.minecraft.world.level.storage.loot.entries.LootPoolEntryContainer;
import net.minecraft.world.level.storage.loot.functions.LootItemFunction;
import net.minecraft.world.level.storage.loot.functions.SetItemCountFunction;
import net.minecraft.world.level.storage.loot.predicates.LootItemCondition;
import net.minecraft.world.level.storage.loot.predicates.LootItemKilledByPlayerCondition;
import net.minecraft.world.level.storage.loot.predicates.LootItemRandomChanceCondition;
import net.minecraft.world.level.storage.loot.predicates.LootItemRandomChanceWithEnchantedBonusCondition;
import net.minecraft.world.level.storage.loot.providers.number.ConstantValue;
import net.minecraft.world.level.storage.loot.providers.number.UniformGenerator;
import net.minecraft.core.Holder;
import net.minecraft.core.registries.BuiltInRegistries;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Registry for Dart-defined loot table modifications.
 *
 * Allows modifying existing Minecraft loot tables by adding new pools
 * and entries through the Fabric Loot API.
 */
public class LootTableRegistry {
    private static final Logger LOGGER = LoggerFactory.getLogger("LootTableRegistry");
    private static final Gson GSON = new Gson();
    private static final Map<String, List<JsonArray>> modifications = new HashMap<>();
    private static boolean initialized = false;

    /**
     * Initialize the loot table modification system.
     */
    public static void initialize() {
        if (initialized) return;

        LootTableEvents.MODIFY.register((key, tableBuilder, source, registries) -> {
            // Get the loot table identifier from the ResourceKey
            String tableId = key.identifier().toString();

            List<JsonArray> mods = modifications.get(tableId);
            if (mods == null || mods.isEmpty()) return;

            for (JsonArray pools : mods) {
                for (JsonElement poolElem : pools) {
                    JsonObject poolJson = poolElem.getAsJsonObject();
                    LootPool.Builder pool = buildPool(poolJson);
                    if (pool != null) {
                        tableBuilder.pool(pool.build());
                    }
                }
            }

            LOGGER.debug("Applied {} modification(s) to loot table: {}", mods.size(), tableId);
        });

        initialized = true;
        LOGGER.info("LootTableRegistry initialized");
    }

    /**
     * Add a modification to a loot table.
     *
     * @param tableId The loot table ID (e.g., "minecraft:entities/zombie")
     * @param poolsJson JSON array of pool definitions
     * @return true if the modification was registered
     */
    public static boolean addModification(String tableId, String poolsJson) {
        try {
            JsonArray pools = GSON.fromJson(poolsJson, JsonArray.class);
            modifications.computeIfAbsent(tableId, k -> new ArrayList<>()).add(pools);
            LOGGER.info("Added loot modification for table: {}", tableId);
            return true;
        } catch (Exception e) {
            LOGGER.error("Failed to add loot modification for {}: {}", tableId, e.getMessage());
            return false;
        }
    }

    /**
     * Build a LootPool from JSON definition.
     */
    private static LootPool.Builder buildPool(JsonObject poolJson) {
        try {
            int rolls = poolJson.has("rolls") ? poolJson.get("rolls").getAsInt() : 1;
            int bonusRolls = poolJson.has("bonus_rolls") ? poolJson.get("bonus_rolls").getAsInt() : 0;

            LootPool.Builder pool = LootPool.lootPool()
                .setRolls(ConstantValue.exactly(rolls));

            if (bonusRolls > 0) {
                pool.setBonusRolls(ConstantValue.exactly(bonusRolls));
            }

            // Add pool-level conditions
            if (poolJson.has("conditions")) {
                for (JsonElement condElem : poolJson.getAsJsonArray("conditions")) {
                    LootItemCondition.Builder cond = buildCondition(condElem.getAsJsonObject());
                    if (cond != null) {
                        pool.when(cond);
                    }
                }
            }

            // Add entries
            if (poolJson.has("entries")) {
                for (JsonElement entryElem : poolJson.getAsJsonArray("entries")) {
                    LootPoolEntryContainer.Builder<?> entry = buildEntry(entryElem.getAsJsonObject());
                    if (entry != null) {
                        pool.add(entry);
                    }
                }
            }

            return pool;
        } catch (Exception e) {
            LOGGER.error("Failed to build loot pool: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Build a loot entry from JSON.
     */
    private static LootPoolEntryContainer.Builder<?> buildEntry(JsonObject entryJson) {
        try {
            String type = entryJson.has("type") ? entryJson.get("type").getAsString() : "item";
            if (!type.equals("item")) {
                LOGGER.warn("Unsupported entry type: {}", type);
                return null;
            }

            String itemId = entryJson.get("name").getAsString();
            Item item = BuiltInRegistries.ITEM.getValue(Identifier.parse(itemId));
            if (item == Items.AIR) {
                LOGGER.warn("Unknown item: {}", itemId);
                return null;
            }

            int weight = entryJson.has("weight") ? entryJson.get("weight").getAsInt() : 1;
            int quality = entryJson.has("quality") ? entryJson.get("quality").getAsInt() : 0;

            LootItem.Builder<?> entry = LootItem.lootTableItem(item)
                .setWeight(weight)
                .setQuality(quality);

            // Add entry-level conditions
            if (entryJson.has("conditions")) {
                for (JsonElement condElem : entryJson.getAsJsonArray("conditions")) {
                    LootItemCondition.Builder cond = buildCondition(condElem.getAsJsonObject());
                    if (cond != null) {
                        entry.when(cond);
                    }
                }
            }

            // Add functions
            if (entryJson.has("functions")) {
                for (JsonElement funcElem : entryJson.getAsJsonArray("functions")) {
                    LootItemFunction.Builder func = buildFunction(funcElem.getAsJsonObject());
                    if (func != null) {
                        entry.apply(func);
                    }
                }
            }

            return entry;
        } catch (Exception e) {
            LOGGER.error("Failed to build loot entry: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Build a loot condition from JSON.
     */
    private static LootItemCondition.Builder buildCondition(JsonObject condJson) {
        try {
            String type = condJson.get("type").getAsString();

            return switch (type) {
                case "random_chance" -> {
                    float chance = condJson.get("chance").getAsFloat();
                    yield LootItemRandomChanceCondition.randomChance(chance);
                }
                case "killed_by_player" -> LootItemKilledByPlayerCondition.killedByPlayer();
                // Add more condition types as needed
                default -> {
                    LOGGER.debug("Unsupported condition type: {}", type);
                    yield null;
                }
            };
        } catch (Exception e) {
            LOGGER.error("Failed to build condition: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Build a loot function from JSON.
     */
    private static LootItemFunction.Builder buildFunction(JsonObject funcJson) {
        try {
            String type = funcJson.get("function").getAsString();

            return switch (type) {
                case "set_count" -> {
                    JsonElement countElem = funcJson.get("count");
                    if (countElem.isJsonPrimitive()) {
                        int count = countElem.getAsInt();
                        yield SetItemCountFunction.setCount(ConstantValue.exactly(count));
                    } else {
                        JsonObject countObj = countElem.getAsJsonObject();
                        int min = countObj.get("min").getAsInt();
                        int max = countObj.get("max").getAsInt();
                        yield SetItemCountFunction.setCount(UniformGenerator.between(min, max));
                    }
                }
                // Add more function types as needed
                default -> {
                    LOGGER.debug("Unsupported function type: {}", type);
                    yield null;
                }
            };
        } catch (Exception e) {
            LOGGER.error("Failed to build function: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Get all modified table IDs.
     */
    public static String[] getModifiedTables() {
        return modifications.keySet().toArray(new String[0]);
    }

    /**
     * Get the count of modified tables.
     */
    public static int getModifiedTableCount() {
        return modifications.size();
    }

    /**
     * Clear all modifications (useful for hot reload).
     */
    public static void clearModifications() {
        modifications.clear();
        LOGGER.info("Cleared all loot table modifications");
    }
}
