package com.redstone.worldgen;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import net.fabricmc.fabric.api.biome.v1.BiomeModifications;
import net.fabricmc.fabric.api.biome.v1.BiomeSelectionContext;
import net.fabricmc.fabric.api.biome.v1.BiomeSelectors;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.resources.Identifier;
import net.minecraft.tags.TagKey;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.levelgen.GenerationStep;
import net.minecraft.world.level.levelgen.placement.PlacedFeature;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Predicate;

/**
 * Registry for Dart-defined ore features for world generation.
 *
 * This registry handles ore feature registration by generating JSON datapack files
 * at runtime. In Minecraft 1.19.3+, ConfiguredFeature and PlacedFeature are dynamic
 * registries that can only be populated via JSON datapacks, not programmatic registration.
 *
 * The workflow is:
 * 1. Dart calls registerOreFeature() during mod init
 * 2. We generate JSON files in a mod datapack directory
 * 3. We register BiomeModifications to add the features to biomes
 * 4. Minecraft loads the JSON files when the server starts
 *
 * Ores can be configured with:
 * - Vein size and frequency
 * - Y-level distribution (uniform, triangle, trapezoid)
 * - Biome selection (overworld, nether, end, or biome tags)
 * - Deepslate variants with configurable transition Y-level
 */
public class OreFeatureRegistry {
    private static final Logger LOGGER = LoggerFactory.getLogger("OreFeatureRegistry");
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    // Track registered features for debugging
    private static final Map<String, OreConfig> registeredOres = new HashMap<>();

    // Base path for generated datapack files (in the run directory)
    private static Path datapackBasePath = null;

    /**
     * Configuration record for ore generation.
     *
     * @param oreBlockId         Block ID of the ore (e.g., "mymod:ruby_ore")
     * @param veinSize           Max number of blocks per vein (e.g., 9 for iron)
     * @param veinsPerChunk      Average veins per chunk (e.g., 8)
     * @param minY               Minimum Y level (e.g., -64)
     * @param maxY               Maximum Y level (e.g., 64)
     * @param distributionType   Height distribution: "uniform", "triangle", or "trapezoid"
     * @param replaceableTag     Tag of blocks the ore can replace (e.g., "minecraft:stone_ore_replaceables")
     * @param biomeSelector      Biome filter: "overworld", "nether", "end", or tag like "#minecraft:is_overworld"
     * @param deepslateVariant   Optional deepslate variant block ID (e.g., "mymod:deepslate_ruby_ore")
     * @param deepslateTransitionY Y level where deepslate takes over (e.g., 0)
     */
    public record OreConfig(
        String oreBlockId,
        int veinSize,
        int veinsPerChunk,
        int minY,
        int maxY,
        String distributionType,
        String replaceableTag,
        String biomeSelector,
        String deepslateVariant,
        int deepslateTransitionY
    ) {}

    /**
     * Initialize the datapack path. Must be called before registering ore features.
     * This sets up the directory where JSON files will be generated.
     *
     * The files are generated in the mod's resources directory structure, which Fabric
     * automatically loads as part of the mod's built-in datapack. This approach works
     * because:
     * 1. Fabric treats mod resources as a virtual datapack
     * 2. The files are written during mod init, before datapacks are loaded
     * 3. BiomeModifications.addFeature references features by key, and the JSON provides the actual data
     *
     * Alternative approach: We write to a "global datapack" directory that applies to all worlds.
     * In 1.21, this is typically handled through the mod's resources, but for runtime generation
     * we write to a special location that acts as an always-enabled datapack.
     */
    private static void ensureDatapackPath() {
        if (datapackBasePath == null) {
            // Write to the mod's runtime data directory
            // This uses Fabric's resource loading which treats mod JARs as datapacks
            // For runtime generation, we write to a directory that Minecraft will scan
            String runDir = System.getProperty("user.dir");

            // Use the global datapacks folder - this works for both singleplayer and servers
            // Minecraft 1.21+ supports a "datapacks" folder in the game directory for global datapacks
            datapackBasePath = Path.of(runDir, "global_packs", "required_data", "dart_worldgen");

            try {
                // Create the datapack structure
                Files.createDirectories(datapackBasePath);

                // Create pack.mcmeta
                Path packMcmeta = datapackBasePath.resolve("pack.mcmeta");
                JsonObject pack = new JsonObject();
                JsonObject packInfo = new JsonObject();
                packInfo.addProperty("pack_format", 48); // 1.21 pack format
                packInfo.addProperty("description", "Dart-generated worldgen features");
                pack.add("pack", packInfo);
                Files.writeString(packMcmeta, GSON.toJson(pack));

                LOGGER.info("Created datapack at: {}", datapackBasePath);
                LOGGER.info("NOTE: This datapack will be auto-enabled for new worlds.");
                LOGGER.info("For existing worlds, you may need to copy it to the world's datapacks folder.");
            } catch (IOException e) {
                LOGGER.error("Failed to create datapack directory: {}", e.getMessage());
            }
        }
    }

    /**
     * Register an ore feature for world generation.
     *
     * In modern Minecraft (1.19.3+), ores are generated using a two-step system:
     * 1. ConfiguredFeature - defines WHAT to generate (the ore block, vein size, replaceable blocks)
     * 2. PlacedFeature - defines WHERE to generate (height range, frequency, biomes)
     *
     * This method generates JSON datapack files for both and registers BiomeModifications
     * to add the features to the appropriate biomes.
     *
     * Note: This must be called during mod initialization, before the server starts.
     *
     * @param namespace Mod namespace (e.g., "mymod")
     * @param path      Feature path (e.g., "ruby_ore")
     * @param config    Ore configuration parameters
     */
    public static void registerOreFeature(String namespace, String path, OreConfig config) {
        try {
            String fullId = namespace + ":" + path;
            LOGGER.info("Registering ore feature: {} with config: {}", fullId, config);

            // Validate the ore block exists
            Identifier oreBlockId = Identifier.parse(config.oreBlockId());
            Block oreBlock = BuiltInRegistries.BLOCK.getValue(oreBlockId);

            if (oreBlock == null || oreBlock == BuiltInRegistries.BLOCK.getValue(BuiltInRegistries.BLOCK.getDefaultKey())) {
                LOGGER.error("Ore block not found in registry: {} - make sure the block is registered before the ore feature", config.oreBlockId());
                return;
            }

            // Ensure datapack directory exists
            ensureDatapackPath();

            // Generate the ConfiguredFeature JSON
            boolean configuredSuccess = generateConfiguredFeatureJson(namespace, path, config);
            if (!configuredSuccess) {
                LOGGER.error("Failed to generate ConfiguredFeature JSON for: {}", fullId);
                return;
            }

            // Generate the PlacedFeature JSON
            boolean placedSuccess = generatePlacedFeatureJson(namespace, path, config);
            if (!placedSuccess) {
                LOGGER.error("Failed to generate PlacedFeature JSON for: {}", fullId);
                return;
            }

            // Create the resource key for the placed feature
            ResourceKey<PlacedFeature> placedKey = ResourceKey.create(
                Registries.PLACED_FEATURE,
                Identifier.fromNamespaceAndPath(namespace, path)
            );

            // Get the biome selector
            Predicate<BiomeSelectionContext> biomeSelector = getBiomeSelector(config.biomeSelector());

            // Register with BiomeModifications API
            BiomeModifications.addFeature(
                biomeSelector,
                GenerationStep.Decoration.UNDERGROUND_ORES,
                placedKey
            );

            // Store for debugging/introspection
            registeredOres.put(fullId, config);

            LOGGER.info("Successfully registered ore feature: {} (vein size: {}, veins/chunk: {}, Y: {}..{}, distribution: {})",
                fullId, config.veinSize(), config.veinsPerChunk(), config.minY(), config.maxY(), config.distributionType());
            LOGGER.info("Generated JSON files in datapack: {}", datapackBasePath);

        } catch (Exception e) {
            LOGGER.error("Failed to register ore feature {}:{}: {}", namespace, path, e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * Generate the ConfiguredFeature JSON file.
     *
     * Example output:
     * {
     *   "type": "minecraft:ore",
     *   "config": {
     *     "discard_chance_on_air_exposure": 0.0,
     *     "size": 9,
     *     "targets": [
     *       {
     *         "state": { "Name": "mymod:ruby_ore" },
     *         "target": { "predicate_type": "minecraft:tag_match", "tag": "minecraft:stone_ore_replaceables" }
     *       }
     *     ]
     *   }
     * }
     */
    private static boolean generateConfiguredFeatureJson(String namespace, String path, OreConfig config) {
        try {
            // Create directory structure
            Path featureDir = datapackBasePath.resolve("data").resolve(namespace).resolve("worldgen").resolve("configured_feature");
            Files.createDirectories(featureDir);

            // Build the JSON structure
            JsonObject root = new JsonObject();
            root.addProperty("type", "minecraft:ore");

            JsonObject oreConfig = new JsonObject();
            oreConfig.addProperty("discard_chance_on_air_exposure", 0.0);
            oreConfig.addProperty("size", config.veinSize());

            // Build targets array
            JsonArray targets = new JsonArray();

            // Main ore target
            JsonObject mainTarget = new JsonObject();
            JsonObject mainState = new JsonObject();
            mainState.addProperty("Name", config.oreBlockId());
            mainTarget.add("state", mainState);

            JsonObject mainTargetTest = new JsonObject();
            mainTargetTest.addProperty("predicate_type", "minecraft:tag_match");
            mainTargetTest.addProperty("tag", config.replaceableTag());
            mainTarget.add("target", mainTargetTest);

            targets.add(mainTarget);

            // Deepslate variant if specified
            if (config.deepslateVariant() != null && !config.deepslateVariant().isEmpty()) {
                // Validate deepslate block exists
                Identifier deepslateId = Identifier.parse(config.deepslateVariant());
                Block deepslateBlock = BuiltInRegistries.BLOCK.getValue(deepslateId);

                if (deepslateBlock != null && deepslateBlock != BuiltInRegistries.BLOCK.getValue(BuiltInRegistries.BLOCK.getDefaultKey())) {
                    JsonObject deepslateTarget = new JsonObject();
                    JsonObject deepslateState = new JsonObject();
                    deepslateState.addProperty("Name", config.deepslateVariant());
                    deepslateTarget.add("state", deepslateState);

                    JsonObject deepslateTest = new JsonObject();
                    deepslateTest.addProperty("predicate_type", "minecraft:tag_match");
                    deepslateTest.addProperty("tag", "minecraft:deepslate_ore_replaceables");
                    deepslateTarget.add("target", deepslateTest);

                    targets.add(deepslateTarget);
                    LOGGER.info("Added deepslate variant to configured feature: {}", config.deepslateVariant());
                }
            }

            oreConfig.add("targets", targets);
            root.add("config", oreConfig);

            // Write the file
            Path featureFile = featureDir.resolve(path + ".json");
            Files.writeString(featureFile, GSON.toJson(root));
            LOGGER.debug("Generated configured feature JSON: {}", featureFile);

            return true;
        } catch (IOException e) {
            LOGGER.error("Failed to generate ConfiguredFeature JSON: {}", e.getMessage());
            return false;
        }
    }

    /**
     * Generate the PlacedFeature JSON file.
     *
     * Example output:
     * {
     *   "feature": "mymod:ruby_ore",
     *   "placement": [
     *     { "type": "minecraft:count", "count": 8 },
     *     { "type": "minecraft:in_square" },
     *     { "type": "minecraft:height_range", "height": { "type": "minecraft:uniform", "min_inclusive": {"absolute": -64}, "max_inclusive": {"absolute": 64} } },
     *     { "type": "minecraft:biome" }
     *   ]
     * }
     */
    private static boolean generatePlacedFeatureJson(String namespace, String path, OreConfig config) {
        try {
            // Create directory structure
            Path featureDir = datapackBasePath.resolve("data").resolve(namespace).resolve("worldgen").resolve("placed_feature");
            Files.createDirectories(featureDir);

            // Build the JSON structure
            JsonObject root = new JsonObject();
            root.addProperty("feature", namespace + ":" + path);

            JsonArray placement = new JsonArray();

            // Count placement (veins per chunk)
            JsonObject countPlacement = new JsonObject();
            countPlacement.addProperty("type", "minecraft:count");
            countPlacement.addProperty("count", config.veinsPerChunk());
            placement.add(countPlacement);

            // In square placement (spread horizontally)
            JsonObject inSquarePlacement = new JsonObject();
            inSquarePlacement.addProperty("type", "minecraft:in_square");
            placement.add(inSquarePlacement);

            // Height range placement
            JsonObject heightRangePlacement = new JsonObject();
            heightRangePlacement.addProperty("type", "minecraft:height_range");

            JsonObject height = new JsonObject();
            String heightType = switch (config.distributionType().toLowerCase()) {
                case "triangle" -> "minecraft:trapezoid"; // Triangle in game is called trapezoid
                case "trapezoid" -> "minecraft:trapezoid";
                default -> "minecraft:uniform";
            };
            height.addProperty("type", heightType);

            JsonObject minInclusive = new JsonObject();
            minInclusive.addProperty("absolute", config.minY());
            height.add("min_inclusive", minInclusive);

            JsonObject maxInclusive = new JsonObject();
            maxInclusive.addProperty("absolute", config.maxY());
            height.add("max_inclusive", maxInclusive);

            heightRangePlacement.add("height", height);
            placement.add(heightRangePlacement);

            // Biome filter
            JsonObject biomePlacement = new JsonObject();
            biomePlacement.addProperty("type", "minecraft:biome");
            placement.add(biomePlacement);

            root.add("placement", placement);

            // Write the file
            Path featureFile = featureDir.resolve(path + ".json");
            Files.writeString(featureFile, GSON.toJson(root));
            LOGGER.debug("Generated placed feature JSON: {}", featureFile);

            return true;
        } catch (IOException e) {
            LOGGER.error("Failed to generate PlacedFeature JSON: {}", e.getMessage());
            return false;
        }
    }

    /**
     * Get the biome selector predicate based on the selector string.
     */
    private static Predicate<BiomeSelectionContext> getBiomeSelector(String selectorString) {
        if (selectorString == null || selectorString.isEmpty()) {
            return BiomeSelectors.foundInOverworld();
        }

        return switch (selectorString.toLowerCase()) {
            case "overworld" -> BiomeSelectors.foundInOverworld();
            case "nether", "the_nether" -> BiomeSelectors.foundInTheNether();
            case "end", "the_end" -> BiomeSelectors.foundInTheEnd();
            default -> {
                if (selectorString.startsWith("#")) {
                    // It's a biome tag like "#minecraft:is_overworld"
                    String tagString = selectorString.substring(1);
                    Identifier tagId = Identifier.parse(tagString);
                    TagKey<net.minecraft.world.level.biome.Biome> biomeTag = TagKey.create(
                        Registries.BIOME,
                        tagId
                    );
                    yield BiomeSelectors.tag(biomeTag);
                } else {
                    // Default to overworld
                    LOGGER.warn("Unknown biome selector: {} - defaulting to overworld", selectorString);
                    yield BiomeSelectors.foundInOverworld();
                }
            }
        };
    }

    /**
     * Parse the namespace from a block/tag ID string.
     * E.g., "minecraft:stone" -> "minecraft", "my_ore" -> "minecraft"
     */
    private static String parseNamespace(String id) {
        int colonIndex = id.indexOf(':');
        if (colonIndex > 0) {
            return id.substring(0, colonIndex);
        }
        return "minecraft";
    }

    /**
     * Parse the path from a block/tag ID string.
     * E.g., "minecraft:stone" -> "stone", "my_ore" -> "my_ore"
     */
    private static String parsePath(String id) {
        int colonIndex = id.indexOf(':');
        if (colonIndex > 0) {
            return id.substring(colonIndex + 1);
        }
        return id;
    }

    /**
     * Get all registered ore configurations for debugging.
     */
    public static Map<String, OreConfig> getRegisteredOres() {
        return new HashMap<>(registeredOres);
    }

    /**
     * Get the count of registered ore features.
     */
    public static int getOreCount() {
        return registeredOres.size();
    }

    /**
     * Get the path where datapack files are generated.
     */
    public static Path getDatapackPath() {
        return datapackBasePath;
    }
}
