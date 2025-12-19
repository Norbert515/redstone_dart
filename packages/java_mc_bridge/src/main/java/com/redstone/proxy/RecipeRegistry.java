package com.redstone.proxy;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import net.minecraft.core.NonNullList;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.crafting.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.lang.reflect.Field;
import java.util.*;

/**
 * Registry for Dart-defined custom recipes.
 *
 * Supports all major recipe types: shaped, shapeless, smelting, blasting,
 * smoking, campfire, stonecutting, and smithing.
 */
public class RecipeRegistry {
    private static final Logger LOGGER = LoggerFactory.getLogger("RecipeRegistry");
    private static final Gson GSON = new Gson();
    private static final Map<String, RecipeDef> recipes = new HashMap<>();
    private static final Set<String> removedRecipes = new HashSet<>();
    private static final Set<String> removedByOutput = new HashSet<>();
    private static boolean initialized = false;

    /**
     * Internal record to store recipe definitions.
     */
    private record RecipeDef(
        String id,
        String type,
        JsonObject data
    ) {}

    /**
     * Initialize the recipe system.
     */
    public static void initialize() {
        if (initialized) return;
        initialized = true;
        LOGGER.info("RecipeRegistry initialized");
    }

    /**
     * Register a recipe from Dart.
     *
     * @param id Recipe identifier (e.g., "mymod:diamond_hammer")
     * @param type Recipe type (shaped, shapeless, smelting, etc.)
     * @param dataJson JSON object containing recipe data
     * @return true if registration succeeded
     */
    public static boolean registerRecipe(String id, String type, String dataJson) {
        try {
            JsonObject data = GSON.fromJson(dataJson, JsonObject.class);
            recipes.put(id, new RecipeDef(id, type, data));
            LOGGER.info("Registered {} recipe: {}", type, id);
            return true;
        } catch (Exception e) {
            LOGGER.error("Failed to register recipe {}: {}", id, e.getMessage());
            return false;
        }
    }

    /**
     * Remove a recipe by ID.
     *
     * @param recipeId The recipe identifier
     * @return true if marked for removal
     */
    public static boolean removeRecipe(String recipeId) {
        removedRecipes.add(recipeId);
        LOGGER.info("Marked recipe for removal: {}", recipeId);
        return true;
    }

    /**
     * Remove all recipes producing a specific item.
     *
     * @param itemId The output item ID
     * @return Number of recipes marked for removal
     */
    public static int removeRecipesByOutput(String itemId) {
        removedByOutput.add(itemId);
        LOGGER.info("Marked recipes for removal by output: {}", itemId);
        return 1; // Actual count determined at runtime
    }

    /**
     * Build all registered recipes. Called during server resource loading.
     * Returns a map of recipe ID -> Recipe for injection.
     */
    public static Map<Identifier, Recipe<?>> buildRecipes() {
        Map<Identifier, Recipe<?>> builtRecipes = new HashMap<>();

        for (RecipeDef def : recipes.values()) {
            try {
                Recipe<?> recipe = buildRecipe(def);
                if (recipe != null) {
                    builtRecipes.put(Identifier.parse(def.id()), recipe);
                }
            } catch (Exception e) {
                LOGGER.error("Failed to build recipe {}: {}", def.id(), e.getMessage());
            }
        }

        return builtRecipes;
    }

    /**
     * Build a single recipe from its definition.
     */
    private static Recipe<?> buildRecipe(RecipeDef def) {
        return switch (def.type()) {
            case "shaped" -> buildShapedRecipe(def);
            case "shapeless" -> buildShapelessRecipe(def);
            case "smelting" -> buildSmeltingRecipe(def);
            case "blasting" -> buildBlastingRecipe(def);
            case "smoking" -> buildSmokingRecipe(def);
            case "campfire" -> buildCampfireRecipe(def);
            case "stonecutting" -> buildStonecuttingRecipe(def);
            case "smithing", "smithingTransform" -> buildSmithingRecipe(def);
            default -> {
                LOGGER.warn("Unknown recipe type: {}", def.type());
                yield null;
            }
        };
    }

    /**
     * Build a shaped crafting recipe.
     */
    private static ShapedRecipe buildShapedRecipe(RecipeDef def) {
        JsonObject data = def.data();

        // Get pattern
        List<String> pattern = new ArrayList<>();
        for (var elem : data.getAsJsonArray("pattern")) {
            pattern.add(elem.getAsString());
        }

        // Get key mappings
        Map<Character, Ingredient> keys = new HashMap<>();
        JsonObject keysJson = data.getAsJsonObject("keys");
        for (var entry : keysJson.entrySet()) {
            char key = entry.getKey().charAt(0);
            String itemId = entry.getValue().getAsString();
            Item item = BuiltInRegistries.ITEM.getValue(Identifier.parse(itemId));
            if (item != Items.AIR) {
                keys.put(key, Ingredient.of(item));
            }
        }

        // Get result
        String resultId = data.get("result").getAsString();
        int count = data.has("count") ? data.get("count").getAsInt() : 1;
        Item resultItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(resultId));
        ItemStack result = new ItemStack(resultItem, count);

        // Get optional group
        String group = data.has("group") ? data.get("group").getAsString() : "";

        // Build recipe
        int width = pattern.isEmpty() ? 0 : pattern.get(0).length();
        int height = pattern.size();

        // Build list of Optional<Ingredient> for ShapedRecipePattern (1.21.x API)
        List<Optional<Ingredient>> ingredients = new ArrayList<>(width * height);
        for (int i = 0; i < width * height; i++) {
            ingredients.add(Optional.empty());
        }
        for (int row = 0; row < height; row++) {
            String rowStr = pattern.get(row);
            for (int col = 0; col < rowStr.length(); col++) {
                char c = rowStr.charAt(col);
                if (c != ' ' && keys.containsKey(c)) {
                    ingredients.set(row * width + col, Optional.of(keys.get(c)));
                }
            }
        }

        return new ShapedRecipe(group, CraftingBookCategory.MISC,
            new ShapedRecipePattern(width, height, ingredients, Optional.empty()), result);
    }

    /**
     * Build a shapeless crafting recipe.
     */
    private static ShapelessRecipe buildShapelessRecipe(RecipeDef def) {
        JsonObject data = def.data();

        // Get ingredients
        NonNullList<Ingredient> ingredients = NonNullList.create();
        for (var elem : data.getAsJsonArray("ingredients")) {
            String itemId = elem.getAsString();
            Item item = BuiltInRegistries.ITEM.getValue(Identifier.parse(itemId));
            if (item != Items.AIR) {
                ingredients.add(Ingredient.of(item));
            }
        }

        // Get result
        String resultId = data.get("result").getAsString();
        int count = data.has("count") ? data.get("count").getAsInt() : 1;
        Item resultItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(resultId));
        ItemStack result = new ItemStack(resultItem, count);

        // Get optional group
        String group = data.has("group") ? data.get("group").getAsString() : "";

        return new ShapelessRecipe(group, CraftingBookCategory.MISC, result, ingredients);
    }

    /**
     * Build a smelting recipe.
     */
    private static SmeltingRecipe buildSmeltingRecipe(RecipeDef def) {
        JsonObject data = def.data();

        String inputId = data.get("input").getAsString();
        Item inputItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(inputId));
        Ingredient ingredient = Ingredient.of(inputItem);

        String resultId = data.get("result").getAsString();
        Item resultItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(resultId));
        ItemStack result = new ItemStack(resultItem);

        float experience = data.has("experience") ? data.get("experience").getAsFloat() : 0f;
        int cookingTime = data.has("cookingTime") ? data.get("cookingTime").getAsInt() : 200;
        String group = data.has("group") ? data.get("group").getAsString() : "";

        return new SmeltingRecipe(group, CookingBookCategory.MISC, ingredient, result, experience, cookingTime);
    }

    /**
     * Build a blasting recipe.
     */
    private static BlastingRecipe buildBlastingRecipe(RecipeDef def) {
        JsonObject data = def.data();

        String inputId = data.get("input").getAsString();
        Item inputItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(inputId));
        Ingredient ingredient = Ingredient.of(inputItem);

        String resultId = data.get("result").getAsString();
        Item resultItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(resultId));
        ItemStack result = new ItemStack(resultItem);

        float experience = data.has("experience") ? data.get("experience").getAsFloat() : 0f;
        int cookingTime = data.has("cookingTime") ? data.get("cookingTime").getAsInt() : 100;
        String group = data.has("group") ? data.get("group").getAsString() : "";

        return new BlastingRecipe(group, CookingBookCategory.MISC, ingredient, result, experience, cookingTime);
    }

    /**
     * Build a smoking recipe.
     */
    private static SmokingRecipe buildSmokingRecipe(RecipeDef def) {
        JsonObject data = def.data();

        String inputId = data.get("input").getAsString();
        Item inputItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(inputId));
        Ingredient ingredient = Ingredient.of(inputItem);

        String resultId = data.get("result").getAsString();
        Item resultItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(resultId));
        ItemStack result = new ItemStack(resultItem);

        float experience = data.has("experience") ? data.get("experience").getAsFloat() : 0f;
        int cookingTime = data.has("cookingTime") ? data.get("cookingTime").getAsInt() : 100;
        String group = data.has("group") ? data.get("group").getAsString() : "";

        return new SmokingRecipe(group, CookingBookCategory.FOOD, ingredient, result, experience, cookingTime);
    }

    /**
     * Build a campfire cooking recipe.
     */
    private static CampfireCookingRecipe buildCampfireRecipe(RecipeDef def) {
        JsonObject data = def.data();

        String inputId = data.get("input").getAsString();
        Item inputItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(inputId));
        Ingredient ingredient = Ingredient.of(inputItem);

        String resultId = data.get("result").getAsString();
        Item resultItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(resultId));
        ItemStack result = new ItemStack(resultItem);

        float experience = data.has("experience") ? data.get("experience").getAsFloat() : 0f;
        int cookingTime = data.has("cookingTime") ? data.get("cookingTime").getAsInt() : 600;
        String group = data.has("group") ? data.get("group").getAsString() : "";

        return new CampfireCookingRecipe(group, CookingBookCategory.FOOD, ingredient, result, experience, cookingTime);
    }

    /**
     * Build a stonecutting recipe.
     */
    private static StonecutterRecipe buildStonecuttingRecipe(RecipeDef def) {
        JsonObject data = def.data();

        String inputId = data.get("input").getAsString();
        Item inputItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(inputId));
        Ingredient ingredient = Ingredient.of(inputItem);

        String resultId = data.get("result").getAsString();
        int count = data.has("count") ? data.get("count").getAsInt() : 1;
        Item resultItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(resultId));
        ItemStack result = new ItemStack(resultItem, count);

        String group = data.has("group") ? data.get("group").getAsString() : "";

        return new StonecutterRecipe(group, ingredient, result);
    }

    /**
     * Build a smithing recipe (transformation style for 1.20+).
     * In 1.21.x, SmithingTransformRecipe constructor signature:
     * (Optional<Ingredient> template, Ingredient base, Optional<Ingredient> addition, TransmuteResult result)
     */
    private static SmithingTransformRecipe buildSmithingRecipe(RecipeDef def) {
        JsonObject data = def.data();

        // Template (optional)
        Optional<Ingredient> template = Optional.empty();
        if (data.has("template")) {
            String templateId = data.get("template").getAsString();
            Item templateItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(templateId));
            if (templateItem != Items.AIR) {
                template = Optional.of(Ingredient.of(templateItem));
            }
        }

        // Base item (required, NOT optional in 1.21.x)
        String baseId = data.get("base").getAsString();
        Item baseItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(baseId));
        Ingredient base = Ingredient.of(baseItem);

        // Addition item (optional)
        Optional<Ingredient> addition = Optional.empty();
        if (data.has("addition")) {
            String additionId = data.get("addition").getAsString();
            Item additionItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(additionId));
            if (additionItem != Items.AIR) {
                addition = Optional.of(Ingredient.of(additionItem));
            }
        }

        // Result - uses TransmuteResult in 1.21.x
        String resultId = data.get("result").getAsString();
        Item resultItem = BuiltInRegistries.ITEM.getValue(Identifier.parse(resultId));
        TransmuteResult result = new TransmuteResult(resultItem);

        return new SmithingTransformRecipe(template, base, addition, result);
    }

    /**
     * Check if a recipe should be removed.
     */
    public static boolean shouldRemoveRecipe(Identifier recipeId, ItemStack result) {
        // Check by ID
        if (removedRecipes.contains(recipeId.toString())) {
            return true;
        }

        // Check by output
        String outputId = BuiltInRegistries.ITEM.getKey(result.getItem()).toString();
        return removedByOutput.contains(outputId);
    }

    /**
     * Get all registered recipe IDs.
     */
    public static String[] getAllRecipeIds() {
        return recipes.keySet().toArray(new String[0]);
    }

    /**
     * Get the count of registered recipes.
     */
    public static int getRecipeCount() {
        return recipes.size();
    }

    /**
     * Clear all recipes (useful for hot reload).
     */
    public static void clearRecipes() {
        recipes.clear();
        removedRecipes.clear();
        removedByOutput.clear();
        LOGGER.info("Cleared all registered recipes");
    }

    // ========== Runtime Recipe Injection via Fabric Events ==========

    private static Field recipeMapField = null;
    private static boolean recipeMapFieldSearched = false;

    /**
     * Reset the field search state. Call this when RecipeManager might have changed
     * (e.g., after a data pack reload).
     */
    public static void resetFieldSearch() {
        recipeMapField = null;
        recipeMapFieldSearched = false;
        LOGGER.debug("Recipe map field search reset");
    }

    /**
     * Inject all registered Dart recipes into the running server's RecipeManager.
     * This is called from Fabric lifecycle events (SERVER_STARTED and END_DATA_PACK_RELOAD).
     *
     * In Minecraft 1.21.x, RecipeMap is immutable, so we need to:
     * 1. Get all existing recipes
     * 2. Add our Dart recipes
     * 3. Create a new RecipeMap
     * 4. Replace the recipes field in RecipeManager
     *
     * @param server The Minecraft server instance
     */
    public static void injectRecipes(MinecraftServer server) {
        LOGGER.info("=== RecipeRegistry.injectRecipes called ===");

        if (server == null) {
            LOGGER.error("Server is null, cannot inject recipes");
            return;
        }

        RecipeManager recipeManager = server.getRecipeManager();
        if (recipeManager == null) {
            LOGGER.error("RecipeManager is null, cannot inject recipes");
            return;
        }

        LOGGER.info("RecipeManager obtained: {}", recipeManager.getClass().getName());

        Map<Identifier, Recipe<?>> dartRecipes = buildRecipes();
        LOGGER.info("Built {} Dart recipes for injection", dartRecipes.size());

        if (dartRecipes.isEmpty() && removedRecipes.isEmpty() && removedByOutput.isEmpty()) {
            LOGGER.info("No Dart recipes to inject and none to remove");
            return;
        }

        try {
            // Get the RecipeMap field from RecipeManager
            Field recipesField = findRecipeMapField(recipeManager);
            if (recipesField == null) {
                LOGGER.error("Could not find recipes field in RecipeManager");
                return;
            }

            recipesField.setAccessible(true);
            Object currentRecipeMap = recipesField.get(recipeManager);

            // Get all existing recipes from the current RecipeMap
            List<RecipeHolder<?>> allRecipes = new ArrayList<>();

            // Use RecipeMap.values() to get existing recipes
            if (currentRecipeMap != null) {
                try {
                    java.lang.reflect.Method valuesMethod = currentRecipeMap.getClass().getMethod("values");
                    @SuppressWarnings("unchecked")
                    Collection<RecipeHolder<?>> existingRecipes = (Collection<RecipeHolder<?>>) valuesMethod.invoke(currentRecipeMap);

                    // Filter out recipes marked for removal
                    for (RecipeHolder<?> holder : existingRecipes) {
                        Identifier recipeId = holder.id().identifier();  // ResourceKey.identifier() returns Identifier
                        ItemStack result = getRecipeResult(holder.value());

                        if (!shouldRemoveRecipe(recipeId, result)) {
                            allRecipes.add(holder);
                        } else {
                            LOGGER.debug("Filtering out removed recipe: {}", recipeId);
                        }
                    }
                    LOGGER.info("Kept {} existing recipes (after filtering removals)", allRecipes.size());
                } catch (Exception e) {
                    LOGGER.error("Failed to get existing recipes: {}", e.getMessage(), e);
                    return;
                }
            }

            // Add Dart recipes
            int added = 0;
            for (Map.Entry<Identifier, Recipe<?>> entry : dartRecipes.entrySet()) {
                Identifier id = entry.getKey();
                Recipe<?> recipe = entry.getValue();

                try {
                    @SuppressWarnings("unchecked")
                    RecipeHolder<?> holder = new RecipeHolder<>(
                        ResourceKey.create(net.minecraft.core.registries.Registries.RECIPE, id),
                        recipe
                    );
                    allRecipes.add(holder);
                    added++;
                    LOGGER.debug("Added Dart recipe: {}", id);
                } catch (Exception e) {
                    LOGGER.error("Failed to create RecipeHolder for {}: {}", id, e.getMessage(), e);
                }
            }

            // Create a new RecipeMap using RecipeMap.create()
            java.lang.reflect.Method createMethod = RecipeMap.class.getMethod("create", Iterable.class);
            Object newRecipeMap = createMethod.invoke(null, allRecipes);

            // Set the new RecipeMap on the RecipeManager
            recipesField.set(recipeManager, newRecipeMap);

            LOGGER.info("=== Recipe injection complete: {} added, {} total recipes ===", added, allRecipes.size());

        } catch (Exception e) {
            LOGGER.error("Failed to inject recipes: {}", e.getMessage(), e);
        }
    }

    /**
     * Find the RecipeMap field in RecipeManager.
     */
    private static Field findRecipeMapField(RecipeManager recipeManager) {
        if (recipeMapField != null) {
            return recipeMapField;
        }

        Class<?> clazz = recipeManager.getClass();
        while (clazz != null && clazz != Object.class) {
            for (Field field : clazz.getDeclaredFields()) {
                if (field.getType().getSimpleName().equals("RecipeMap")) {
                    recipeMapField = field;
                    LOGGER.info("Found RecipeMap field: {} in {}", field.getName(), clazz.getSimpleName());
                    return field;
                }
            }
            clazz = clazz.getSuperclass();
        }

        LOGGER.error("Could not find RecipeMap field in RecipeManager");
        return null;
    }

    /**
     * Get the result ItemStack from a recipe.
     */
    private static ItemStack getRecipeResult(Recipe<?> recipe) {
        try {
            // Different recipe types have different ways to get results
            // For now, return empty - removal by output can be enhanced later
            return ItemStack.EMPTY;
        } catch (Exception e) {
            return ItemStack.EMPTY;
        }
    }
}
