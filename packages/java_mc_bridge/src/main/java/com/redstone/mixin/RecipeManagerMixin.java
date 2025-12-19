package com.redstone.mixin;

import com.redstone.proxy.RecipeRegistry;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.packs.resources.ResourceManager;
import net.minecraft.util.profiling.ProfilerFiller;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.crafting.RecipeMap;
import net.minecraft.world.item.crafting.Recipe;
import net.minecraft.world.item.crafting.RecipeHolder;
import net.minecraft.world.item.crafting.RecipeManager;
import net.minecraft.world.item.crafting.RecipeType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

/**
 * Mixin to inject Dart-defined recipes into Minecraft's recipe manager.
 *
 * This mixin targets RecipeManager and injects custom recipes
 * from RecipeRegistry after vanilla recipes are loaded.
 */
@Mixin(RecipeManager.class)
public abstract class RecipeManagerMixin {

    @Unique
    private static final Logger LOGGER = LoggerFactory.getLogger("RecipeManagerMixin");

    @Unique
    private static Field recipesField = null;

    @Unique
    private static boolean fieldSearchAttempted = false;

    /**
     * Inject at the end of the apply method to add custom recipes.
     * The apply method is called during resource reload when recipes are loaded.
     * In 1.21.x, the signature is:
     * apply(RecipeMap, ResourceManager, ProfilerFiller)
     */
    @Inject(
        method = "apply(Lnet/minecraft/world/item/crafting/RecipeMap;Lnet/minecraft/server/packs/resources/ResourceManager;Lnet/minecraft/util/profiling/ProfilerFiller;)V",
        at = @At("TAIL")
    )
    private void redstone$injectRecipes(RecipeMap prepared, ResourceManager resourceManager, ProfilerFiller profiler, CallbackInfo ci) {
        Map<RecipeType<?>, Map<Identifier, RecipeHolder<?>>> recipesByType = findRecipesMap();

        if (recipesByType != null) {
            injectDartRecipes(recipesByType);
            removeMarkedRecipes(recipesByType);
        } else {
            LOGGER.warn("Could not access recipe map - recipes not injected");
        }
    }

    /**
     * Use reflection to find the recipes map field.
     * This handles different Minecraft versions/mappings gracefully.
     */
    @Unique
    @SuppressWarnings("unchecked")
    private Map<RecipeType<?>, Map<Identifier, RecipeHolder<?>>> findRecipesMap() {
        if (recipesField != null) {
            try {
                return (Map<RecipeType<?>, Map<Identifier, RecipeHolder<?>>>) recipesField.get(this);
            } catch (Exception e) {
                LOGGER.error("Failed to access recipes field: {}", e.getMessage());
                return null;
            }
        }

        if (fieldSearchAttempted) {
            return null;
        }
        fieldSearchAttempted = true;

        // Search for the Map<RecipeType, Map<?, ?>> field
        Class<?> clazz = this.getClass().getSuperclass(); // RecipeManager
        for (Field field : clazz.getDeclaredFields()) {
            if (Map.class.isAssignableFrom(field.getType())) {
                try {
                    field.setAccessible(true);
                    Object value = field.get(this);
                    if (value instanceof Map<?, ?> map && !map.isEmpty()) {
                        // Check if this looks like the recipes map (keyed by RecipeType)
                        Object firstKey = map.keySet().iterator().next();
                        if (firstKey instanceof RecipeType<?>) {
                            recipesField = field;
                            LOGGER.info("Found recipes field: {} in {}", field.getName(), clazz.getSimpleName());
                            return (Map<RecipeType<?>, Map<Identifier, RecipeHolder<?>>>) value;
                        }
                    }
                } catch (Exception e) {
                    LOGGER.debug("Skipping field {}: {}", field.getName(), e.getMessage());
                }
            }
        }

        LOGGER.error("Could not find recipes map field in RecipeManager");
        return null;
    }

    /**
     * Inject recipes from Dart's RecipeRegistry into the recipe manager.
     */
    @Unique
    private void injectDartRecipes(Map<RecipeType<?>, Map<Identifier, RecipeHolder<?>>> recipesByType) {
        Map<Identifier, Recipe<?>> dartRecipes = RecipeRegistry.buildRecipes();

        if (dartRecipes.isEmpty()) {
            return;
        }

        int added = 0;
        for (Map.Entry<Identifier, Recipe<?>> entry : dartRecipes.entrySet()) {
            Identifier id = entry.getKey();
            Recipe<?> recipe = entry.getValue();

            try {
                // Get the recipe type
                RecipeType<?> type = recipe.getType();

                // Get or create the map for this recipe type
                Map<Identifier, RecipeHolder<?>> typeMap = recipesByType.get(type);
                if (typeMap == null) {
                    // Create a new mutable map for this type
                    typeMap = new HashMap<>();
                    recipesByType.put(type, typeMap);
                }

                // Create a RecipeHolder for the recipe
                // In 1.21.x, RecipeHolder wraps the recipe with its resource key
                @SuppressWarnings("unchecked")
                RecipeHolder<?> holder = new RecipeHolder<>(
                    ResourceKey.create(net.minecraft.core.registries.Registries.RECIPE, id),
                    recipe
                );

                // Add to the map
                typeMap.put(id, holder);
                added++;

                LOGGER.debug("Injected recipe: {}", id);
            } catch (Exception e) {
                LOGGER.error("Failed to inject recipe {}: {}", id, e.getMessage(), e);
            }
        }

        if (added > 0) {
            LOGGER.info("Injected {} custom recipe(s) from Dart", added);
        }
    }

    /**
     * Remove recipes marked for removal by Dart.
     */
    @Unique
    private void removeMarkedRecipes(Map<RecipeType<?>, Map<Identifier, RecipeHolder<?>>> recipesByType) {
        int removed = 0;

        for (Map.Entry<RecipeType<?>, Map<Identifier, RecipeHolder<?>>> typeEntry : recipesByType.entrySet()) {
            Map<Identifier, RecipeHolder<?>> typeMap = typeEntry.getValue();

            Iterator<Map.Entry<Identifier, RecipeHolder<?>>> iterator = typeMap.entrySet().iterator();
            while (iterator.hasNext()) {
                Map.Entry<Identifier, RecipeHolder<?>> entry = iterator.next();
                Identifier recipeId = entry.getKey();
                RecipeHolder<?> holder = entry.getValue();

                // Get the result ItemStack for checking removal by output
                ItemStack result = getRecipeResult(holder.value());

                if (RecipeRegistry.shouldRemoveRecipe(recipeId, result)) {
                    iterator.remove();
                    removed++;
                    LOGGER.debug("Removed recipe: {}", recipeId);
                }
            }
        }

        if (removed > 0) {
            LOGGER.info("Removed {} recipe(s) as requested by Dart", removed);
        }
    }

    /**
     * Get the result ItemStack from a recipe.
     * This handles various recipe types that have different result getters.
     */
    @Unique
    private ItemStack getRecipeResult(Recipe<?> recipe) {
        try {
            // For now, return empty stack - removal by output may need more work
            // Different recipe types have different ways to get results in 1.21.x
            return ItemStack.EMPTY;
        } catch (Exception e) {
            return ItemStack.EMPTY;
        }
    }
}
