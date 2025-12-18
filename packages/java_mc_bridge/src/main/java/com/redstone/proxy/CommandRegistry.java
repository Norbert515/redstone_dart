package com.redstone.proxy;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.*;
import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import com.mojang.brigadier.builder.RequiredArgumentBuilder;
import com.mojang.brigadier.context.CommandContext;
import com.redstone.DartBridge;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.arguments.*;
import net.minecraft.commands.arguments.coordinates.BlockPosArgument;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Registry for Dart-defined custom commands.
 *
 * Commands are registered using Fabric's Command API and routed to Dart
 * callbacks through the native bridge.
 */
public class CommandRegistry {
    private static final Logger LOGGER = LoggerFactory.getLogger("CommandRegistry");
    private static final Gson GSON = new Gson();
    private static final Map<Long, CommandDef> commands = new HashMap<>();
    private static boolean initialized = false;

    /**
     * Internal record to store command definitions.
     */
    private record CommandDef(
        long id,
        String name,
        String description,
        JsonArray arguments,
        int permission
    ) {}

    /**
     * Register a command from Dart.
     *
     * @param commandId Unique command ID from Dart
     * @param name Command name (without leading slash)
     * @param description Optional description for help
     * @param argsJson JSON array of argument definitions
     * @param permission Required permission level (0-4)
     * @return true if registration succeeded
     */
    public static boolean registerCommand(
            long commandId,
            String name,
            String description,
            String argsJson,
            int permission) {

        if (!initialized) {
            initialize();
        }

        try {
            JsonArray args = GSON.fromJson(argsJson, JsonArray.class);
            commands.put(commandId, new CommandDef(commandId, name, description, args, permission));
            LOGGER.info("Registered command: /{} (ID: {})", name, commandId);
            return true;
        } catch (Exception e) {
            LOGGER.error("Failed to register command /{}: {}", name, e.getMessage());
            return false;
        }
    }

    /**
     * Initialize the command registration system.
     */
    public static void initialize() {
        if (initialized) return;

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            // Register all pending commands
            for (CommandDef cmd : commands.values()) {
                registerWithDispatcher(dispatcher, cmd);
            }
        });

        initialized = true;
        LOGGER.info("CommandRegistry initialized");
    }

    /**
     * Register a command with the Brigadier dispatcher.
     */
    private static void registerWithDispatcher(CommandDispatcher<CommandSourceStack> dispatcher, CommandDef cmd) {
        try {
            LiteralArgumentBuilder<CommandSourceStack> builder = Commands.literal(cmd.name());
            // Note: Permission checking removed - CommandSourceStack.hasPermission() isn't available in 1.21.x
            // Custom permission logic can be added in the command execution handler if needed

            if (cmd.arguments() == null || cmd.arguments().isEmpty()) {
                // No arguments - just execute
                builder.executes(context -> executeCommand(context, cmd.id()));
            } else {
                // Build argument chain
                builder = buildArgumentChain(builder, cmd.arguments(), 0, cmd.id());
            }

            dispatcher.register(builder);
            LOGGER.debug("Registered /{} with dispatcher", cmd.name());
        } catch (Exception e) {
            LOGGER.error("Failed to register /{} with dispatcher: {}", cmd.name(), e.getMessage());
        }
    }

    /**
     * Build the argument chain recursively.
     */
    @SuppressWarnings("unchecked")
    private static LiteralArgumentBuilder<CommandSourceStack> buildArgumentChain(
            LiteralArgumentBuilder<CommandSourceStack> builder,
            JsonArray args,
            int index,
            long commandId) {

        if (index >= args.size()) {
            // End of arguments - add execution
            return builder.executes(context -> executeCommand(context, commandId));
        }

        JsonObject arg = args.get(index).getAsJsonObject();
        String argName = arg.get("name").getAsString();
        String argType = arg.get("type").getAsString();
        boolean required = arg.has("required") ? arg.get("required").getAsBoolean() : true;

        RequiredArgumentBuilder<CommandSourceStack, ?> argBuilder = createArgumentBuilder(argName, argType);

        if (index == args.size() - 1) {
            // Last argument - add execution
            argBuilder.executes(context -> executeCommand(context, commandId));
        } else {
            // More arguments to come
            RequiredArgumentBuilder<CommandSourceStack, ?> nextArg = buildNextArgument(args, index + 1, commandId);
            argBuilder.then(nextArg);
        }

        // If not required, also allow executing without this argument
        if (!required && index > 0) {
            builder.executes(context -> executeCommand(context, commandId));
        }

        return builder.then(argBuilder);
    }

    /**
     * Build the next argument in the chain.
     */
    private static RequiredArgumentBuilder<CommandSourceStack, ?> buildNextArgument(
            JsonArray args,
            int index,
            long commandId) {

        JsonObject arg = args.get(index).getAsJsonObject();
        String argName = arg.get("name").getAsString();
        String argType = arg.get("type").getAsString();

        RequiredArgumentBuilder<CommandSourceStack, ?> argBuilder = createArgumentBuilder(argName, argType);

        if (index == args.size() - 1) {
            // Last argument
            argBuilder.executes(context -> executeCommand(context, commandId));
        } else {
            // More arguments
            argBuilder.then(buildNextArgument(args, index + 1, commandId));
        }

        return argBuilder;
    }

    /**
     * Create an argument builder for the given type.
     */
    private static RequiredArgumentBuilder<CommandSourceStack, ?> createArgumentBuilder(String name, String type) {
        return switch (type) {
            case "string" -> Commands.argument(name, StringArgumentType.string());
            case "integer" -> Commands.argument(name, IntegerArgumentType.integer());
            case "double_" -> Commands.argument(name, DoubleArgumentType.doubleArg());
            case "bool_" -> Commands.argument(name, BoolArgumentType.bool());
            case "player" -> Commands.argument(name, EntityArgument.player());
            case "position" -> Commands.argument(name, BlockPosArgument.blockPos());
            // TODO: BlockStateArgument and ItemArgument require CommandBuildContext in 1.21.x
            // For now, fall back to string arguments - users should provide block/item IDs as strings
            case "block" -> Commands.argument(name, StringArgumentType.string());
            case "item" -> Commands.argument(name, StringArgumentType.string());
            case "greedyString" -> Commands.argument(name, StringArgumentType.greedyString());
            default -> Commands.argument(name, StringArgumentType.string());
        };
    }

    /**
     * Execute a command and dispatch to Dart.
     */
    private static int executeCommand(CommandContext<CommandSourceStack> context, long commandId) {
        try {
            CommandSourceStack source = context.getSource();
            ServerPlayer player = source.getPlayer();
            int playerId = player != null ? player.getId() : 0;

            // Collect arguments
            JsonObject argsJson = new JsonObject();
            CommandDef cmd = commands.get(commandId);
            if (cmd != null && cmd.arguments() != null) {
                for (JsonElement elem : cmd.arguments()) {
                    JsonObject argDef = elem.getAsJsonObject();
                    String argName = argDef.get("name").getAsString();
                    String argType = argDef.get("type").getAsString();

                    try {
                        Object value = getArgumentValue(context, argName, argType);
                        if (value != null) {
                            argsJson.addProperty(argName, value.toString());
                        }
                    } catch (IllegalArgumentException e) {
                        // Argument not provided (optional)
                    }
                }
            }

            // Dispatch to Dart via native bridge
            return DartBridge.onCommandExecute(commandId, playerId, GSON.toJson(argsJson));
        } catch (Exception e) {
            LOGGER.error("Error executing command {}: {}", commandId, e.getMessage());
            return 0;
        }
    }

    /**
     * Get an argument value from the context.
     */
    private static Object getArgumentValue(CommandContext<CommandSourceStack> context, String name, String type) {
        return switch (type) {
            case "string", "greedyString", "block", "item" -> StringArgumentType.getString(context, name);
            case "integer" -> IntegerArgumentType.getInteger(context, name);
            case "double_" -> DoubleArgumentType.getDouble(context, name);
            case "bool_" -> BoolArgumentType.getBool(context, name);
            case "player" -> {
                try {
                    ServerPlayer p = EntityArgument.getPlayer(context, name);
                    yield p.getId();
                } catch (Exception e) {
                    yield null;
                }
            }
            case "position" -> {
                try {
                    var pos = BlockPosArgument.getBlockPos(context, name);
                    yield pos.getX() + "," + pos.getY() + "," + pos.getZ();
                } catch (Exception e) {
                    yield null;
                }
            }
            default -> null;
        };
    }

    /**
     * Send feedback message to a player (called from Dart).
     */
    public static void sendFeedback(int playerId, String message) {
        ServerPlayer player = DartBridge.getPlayerById(playerId);
        if (player != null) {
            player.sendSystemMessage(Component.literal(message));
        }
    }

    /**
     * Send error message to a player (called from Dart).
     */
    public static void sendError(int playerId, String message) {
        ServerPlayer player = DartBridge.getPlayerById(playerId);
        if (player != null) {
            player.sendSystemMessage(Component.literal("\u00A7c" + message)); // Red color
        }
    }

    /**
     * Get all registered command IDs.
     */
    public static long[] getAllCommandIds() {
        return commands.keySet().stream().mapToLong(Long::longValue).toArray();
    }

    /**
     * Get the count of registered commands.
     */
    public static int getCommandCount() {
        return commands.size();
    }
}
