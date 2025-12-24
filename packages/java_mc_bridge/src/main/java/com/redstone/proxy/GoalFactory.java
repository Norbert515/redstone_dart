package com.redstone.proxy;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.PathfinderMob;
import net.minecraft.world.entity.ai.goal.*;
import net.minecraft.world.entity.ai.goal.target.HurtByTargetGoal;
import net.minecraft.world.entity.ai.goal.target.NearestAttackableTargetGoal;
import net.minecraft.world.entity.animal.Animal;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.crafting.Ingredient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.EnumSet;
import java.util.HashSet;
import java.util.Set;

/**
 * Factory for creating vanilla Minecraft Goal objects from JSON configuration.
 *
 * This class is used by proxy entities to register AI goals based on
 * configurations provided from Dart code.
 */
public class GoalFactory {
    private static final Logger LOGGER = LoggerFactory.getLogger("GoalFactory");

    /**
     * Register goals from JSON config to the mob's goalSelector.
     *
     * @param mob The mob to register goals for.
     * @param goalsJson JSON array of goal configurations.
     */
    public static void registerGoals(Mob mob, String goalsJson) {
        if (goalsJson == null || goalsJson.isEmpty()) return;

        try {
            JsonArray goals = JsonParser.parseString(goalsJson).getAsJsonArray();
            for (JsonElement element : goals) {
                JsonObject goalConfig = element.getAsJsonObject();
                Goal goal = createGoal(mob, goalConfig);
                if (goal != null) {
                    int priority = goalConfig.get("priority").getAsInt();
                    mob.goalSelector.addGoal(priority, goal);
                    LOGGER.debug("Registered goal type '{}' with priority {} for mob {}",
                        goalConfig.get("type").getAsString(), priority, mob.getType().getDescriptionId());
                }
            }
        } catch (Exception e) {
            LOGGER.error("Failed to parse goals JSON: {}", e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * Register target goals from JSON config to the mob's targetSelector.
     *
     * @param mob The mob to register target goals for.
     * @param targetGoalsJson JSON array of target goal configurations.
     */
    public static void registerTargetGoals(Mob mob, String targetGoalsJson) {
        if (targetGoalsJson == null || targetGoalsJson.isEmpty()) return;

        try {
            JsonArray goals = JsonParser.parseString(targetGoalsJson).getAsJsonArray();
            for (JsonElement element : goals) {
                JsonObject goalConfig = element.getAsJsonObject();
                Goal goal = createTargetGoal(mob, goalConfig);
                if (goal != null) {
                    int priority = goalConfig.get("priority").getAsInt();
                    mob.targetSelector.addGoal(priority, goal);
                    LOGGER.debug("Registered target goal type '{}' with priority {} for mob {}",
                        goalConfig.get("type").getAsString(), priority, mob.getType().getDescriptionId());
                }
            }
        } catch (Exception e) {
            LOGGER.error("Failed to parse target goals JSON: {}", e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * Create a Goal from JSON configuration.
     */
    private static Goal createGoal(Mob mob, JsonObject config) {
        String type = config.get("type").getAsString();

        try {
            return switch (type) {
                case "float" -> new FloatGoal(mob);

                case "melee_attack" -> {
                    if (!(mob instanceof PathfinderMob pathfinderMob)) {
                        LOGGER.warn("melee_attack goal requires PathfinderMob, got {}", mob.getClass().getSimpleName());
                        yield null;
                    }
                    double speed = getDouble(config, "speedModifier", 1.0);
                    boolean follow = getBoolean(config, "followEvenIfNotSeen", true);
                    yield new MeleeAttackGoal(pathfinderMob, speed, follow);
                }

                case "leap_at_target" -> {
                    float yd = (float) getDouble(config, "yd", 0.4);
                    yield new LeapAtTargetGoal(mob, yd);
                }

                case "random_stroll" -> {
                    if (!(mob instanceof PathfinderMob pathfinderMob)) {
                        LOGGER.warn("random_stroll goal requires PathfinderMob, got {}", mob.getClass().getSimpleName());
                        yield null;
                    }
                    double speed = getDouble(config, "speedModifier", 1.0);
                    yield new RandomStrollGoal(pathfinderMob, speed);
                }

                case "water_avoiding_random_stroll" -> {
                    if (!(mob instanceof PathfinderMob pathfinderMob)) {
                        LOGGER.warn("water_avoiding_random_stroll goal requires PathfinderMob, got {}", mob.getClass().getSimpleName());
                        yield null;
                    }
                    double speed = getDouble(config, "speedModifier", 1.0);
                    yield new WaterAvoidingRandomStrollGoal(pathfinderMob, speed);
                }

                case "look_at_player" -> {
                    float distance = (float) getDouble(config, "lookDistance", 8.0);
                    yield new LookAtPlayerGoal(mob, Player.class, distance);
                }

                case "random_look_around" -> new RandomLookAroundGoal(mob);

                case "panic" -> {
                    if (!(mob instanceof PathfinderMob pathfinderMob)) {
                        LOGGER.warn("panic goal requires PathfinderMob, got {}", mob.getClass().getSimpleName());
                        yield null;
                    }
                    double speed = getDouble(config, "speedModifier", 1.5);
                    yield new PanicGoal(pathfinderMob, speed);
                }

                case "breed" -> {
                    if (!(mob instanceof Animal animal)) {
                        LOGGER.warn("breed goal requires Animal, got {}", mob.getClass().getSimpleName());
                        yield null;
                    }
                    double speed = getDouble(config, "speedModifier", 1.0);
                    yield new BreedGoal(animal, speed);
                }

                case "tempt" -> {
                    if (!(mob instanceof PathfinderMob pathfinderMob)) {
                        LOGGER.warn("tempt goal requires PathfinderMob, got {}", mob.getClass().getSimpleName());
                        yield null;
                    }
                    double speed = getDouble(config, "speedModifier", 1.0);
                    String itemId = getString(config, "temptItem", "minecraft:wheat");
                    boolean canScare = getBoolean(config, "canScare", false);
                    yield createTemptGoal(pathfinderMob, speed, itemId, canScare);
                }

                case "follow_parent" -> {
                    if (!(mob instanceof Animal animal)) {
                        LOGGER.warn("follow_parent goal requires Animal, got {}", mob.getClass().getSimpleName());
                        yield null;
                    }
                    double speed = getDouble(config, "speedModifier", 1.1);
                    yield new FollowParentGoal(animal, speed);
                }

                case "custom" -> {
                    String goalId = config.get("goalId").getAsString();
                    boolean requiresUpdateEveryTick = getBoolean(config, "requiresUpdateEveryTick", true);

                    // Parse flags
                    EnumSet<Goal.Flag> flags = EnumSet.noneOf(Goal.Flag.class);
                    if (config.has("flags") && !config.get("flags").isJsonNull()) {
                        JsonArray flagsArray = config.getAsJsonArray("flags");
                        Set<String> flagStrings = new HashSet<>();
                        for (JsonElement flag : flagsArray) {
                            flagStrings.add(flag.getAsString());
                        }
                        flags = DartGoal.parseFlags(flagStrings);
                    }

                    yield new DartGoal(mob, goalId, flags, requiresUpdateEveryTick);
                }

                default -> {
                    LOGGER.warn("Unknown goal type: {}", type);
                    yield null;
                }
            };
        } catch (Exception e) {
            LOGGER.error("Failed to create goal '{}': {}", type, e.getMessage());
            e.printStackTrace();
            return null;
        }
    }

    /**
     * Create a target Goal from JSON configuration.
     */
    private static Goal createTargetGoal(Mob mob, JsonObject config) {
        String type = config.get("type").getAsString();

        try {
            return switch (type) {
                case "nearest_attackable_target" -> {
                    String targetType = getString(config, "targetType", "player");
                    boolean mustSee = getBoolean(config, "mustSee", true);
                    Class<?> targetClass = resolveTargetClass(targetType);
                    yield new NearestAttackableTargetGoal(mob, targetClass, mustSee);
                }

                case "hurt_by_target" -> {
                    if (!(mob instanceof PathfinderMob pathfinderMob)) {
                        LOGGER.warn("hurt_by_target goal requires PathfinderMob, got {}", mob.getClass().getSimpleName());
                        yield null;
                    }
                    boolean alertOthers = getBoolean(config, "alertOthers", true);
                    HurtByTargetGoal goal = new HurtByTargetGoal(pathfinderMob);
                    if (alertOthers) {
                        goal.setAlertOthers();
                    }
                    yield goal;
                }

                case "custom" -> {
                    String goalId = config.get("goalId").getAsString();
                    boolean requiresUpdateEveryTick = getBoolean(config, "requiresUpdateEveryTick", true);

                    // Parse flags
                    EnumSet<Goal.Flag> flags = EnumSet.noneOf(Goal.Flag.class);
                    if (config.has("flags") && !config.get("flags").isJsonNull()) {
                        JsonArray flagsArray = config.getAsJsonArray("flags");
                        Set<String> flagStrings = new HashSet<>();
                        for (JsonElement flag : flagsArray) {
                            flagStrings.add(flag.getAsString());
                        }
                        flags = DartGoal.parseFlags(flagStrings);
                    }

                    yield new DartGoal(mob, goalId, flags, requiresUpdateEveryTick);
                }

                default -> {
                    LOGGER.warn("Unknown target goal type: {}", type);
                    yield null;
                }
            };
        } catch (Exception e) {
            LOGGER.error("Failed to create target goal '{}': {}", type, e.getMessage());
            e.printStackTrace();
            return null;
        }
    }

    /**
     * Resolve entity class from target type string.
     */
    private static Class<?> resolveTargetClass(String targetType) {
        return switch (targetType) {
            case "player", "minecraft:player" -> Player.class;
            // Add more entity types as needed
            default -> {
                LOGGER.warn("Unknown target type '{}', defaulting to Player", targetType);
                yield Player.class;
            }
        };
    }

    /**
     * Create a TemptGoal with the specified item.
     */
    private static Goal createTemptGoal(PathfinderMob mob, double speed, String itemId, boolean canScare) {
        try {
            var identifier = Identifier.tryParse(itemId);
            if (identifier == null) {
                LOGGER.error("Invalid item identifier: {}", itemId);
                return null;
            }
            var itemOpt = BuiltInRegistries.ITEM.getOptional(identifier);
            if (itemOpt.isEmpty()) {
                LOGGER.error("Item not found in registry: {}", itemId);
                return null;
            }
            var ingredient = Ingredient.of(itemOpt.get());
            return new TemptGoal(mob, speed, ingredient, canScare);
        } catch (Exception e) {
            LOGGER.error("Failed to create TemptGoal with item '{}': {}", itemId, e.getMessage());
            return null;
        }
    }

    // Helper methods for JSON parsing

    private static double getDouble(JsonObject config, String key, double defaultValue) {
        return config.has(key) ? config.get(key).getAsDouble() : defaultValue;
    }

    private static boolean getBoolean(JsonObject config, String key, boolean defaultValue) {
        return config.has(key) ? config.get(key).getAsBoolean() : defaultValue;
    }

    private static String getString(JsonObject config, String key, String defaultValue) {
        return config.has(key) ? config.get(key).getAsString() : defaultValue;
    }
}
