/// Commands API for registering custom Minecraft commands.
///
/// This library provides a simple API for creating and registering custom
/// commands with Minecraft's Brigadier command system.
///
/// ## Example
///
/// ```dart
/// import 'package:dart_mod_server/dart_mod_server.dart';
///
/// void onModInit() {
///   Commands.register(
///     'heal',
///     execute: (context) {
///       context.source.health = 20.0;
///       context.sendFeedback('You have been healed!');
///       return 1; // Success
///     },
///     description: 'Heals the player to full health',
///     arguments: [
///       CommandArgument('amount', ArgumentType.integer),
///     ],
///   );
/// }
/// ```
library;

import 'dart:convert';
import 'dart:ffi';

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:ffi/ffi.dart';

import 'bridge.dart';
import 'player.dart';

/// The type of a command argument.
enum ArgumentType {
  /// A string argument.
  string,

  /// An integer argument.
  integer,

  /// A floating-point number argument.
  double_,

  /// A boolean argument.
  bool_,

  /// A player selector argument (returns Player).
  player,

  /// A block position argument (x, y, z).
  position,

  /// A block type argument.
  block,

  /// An item type argument.
  item,

  /// A greedy string (consumes all remaining input).
  greedyString,
}

/// Represents a command argument definition.
class CommandArgument {
  /// The name of the argument.
  final String name;

  /// The type of the argument.
  final ArgumentType type;

  /// Whether this argument is required (default: true).
  final bool required;

  /// Default value if not provided (only for optional arguments).
  final Object? defaultValue;

  /// Creates a command argument.
  const CommandArgument(
    this.name,
    this.type, {
    this.required = true,
    this.defaultValue,
  });

  /// Converts to JSON for serialization.
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'required': required,
        if (defaultValue != null) 'default': defaultValue,
      };
}

/// Context provided to command execution callbacks.
class CommandContext {
  /// The player who executed the command.
  final Player source;

  /// The parsed arguments as a map.
  final Map<String, dynamic> arguments;

  /// Internal handler for sending feedback.
  final void Function(String message) _sendFeedback;

  /// Internal handler for sending errors.
  final void Function(String message) _sendError;

  CommandContext._({
    required this.source,
    required this.arguments,
    required void Function(String) sendFeedback,
    required void Function(String) sendError,
  })  : _sendFeedback = sendFeedback,
        _sendError = sendError;

  /// Send feedback to the command source (player).
  void sendFeedback(String message) => _sendFeedback(message);

  /// Send an error message to the command source.
  void sendError(String message) => _sendError(message);

  /// Get an argument by name with type casting.
  T? getArgument<T>(String name) => arguments[name] as T?;

  /// Get a required argument, throwing if not present.
  T requireArgument<T>(String name) {
    final value = arguments[name];
    if (value == null) {
      throw ArgumentError('Required argument "$name" not provided');
    }
    return value as T;
  }
}

/// Callback type for command execution.
typedef CommandExecuteCallback = int Function(CommandContext context);

/// Registry for custom Minecraft commands.
///
/// Commands must be registered during mod initialization.
class Commands {
  static final Map<int, _RegisteredCommand> _commands = {};
  static int _nextCommandId = 1;
  static bool _handlersRegistered = false;

  Commands._();

  /// Register a custom command.
  ///
  /// [name] is the command name (without leading slash).
  /// [execute] is the callback invoked when the command runs.
  /// [description] is an optional description for help text.
  /// [arguments] defines the command's argument structure.
  /// [permission] is the permission level required (0-4, default 0).
  ///
  /// Returns the command ID.
  static int register(
    String name, {
    required CommandExecuteCallback execute,
    String? description,
    List<CommandArgument>? arguments,
    int permission = 0,
  }) {
    // Ensure handlers are registered
    _ensureHandlersRegistered();

    final commandId = _nextCommandId++;

    // Store the command locally
    _commands[commandId] = _RegisteredCommand(
      id: commandId,
      name: name,
      execute: execute,
      description: description,
      arguments: arguments ?? [],
      permission: permission,
    );

    // Serialize arguments to JSON
    final argsJson = jsonEncode(
      (arguments ?? []).map((a) => a.toJson()).toList(),
    );

    // Call Java to register the command
    final success = GenericJniBridge.callStaticBoolMethod(
      'com/redstone/proxy/CommandRegistry',
      'registerCommand',
      '(JLjava/lang/String;Ljava/lang/String;Ljava/lang/String;I)Z',
      [commandId, name, description ?? '', argsJson, permission],
    );

    if (!success) {
      _commands.remove(commandId);
      throw StateError('Failed to register command: $name');
    }

    print('Commands: Registered /$name with ID $commandId');
    return commandId;
  }

  /// Ensure native handlers are registered for command dispatch.
  static void _ensureHandlersRegistered() {
    if (_handlersRegistered) return;
    if (ServerBridge.isDatagenMode) {
      _handlersRegistered = true;
      return;
    }

    ServerBridge.registerCommandExecuteHandler(
      Pointer.fromFunction<_CommandExecuteCallbackNative>(
        _onCommandExecute,
        0,
      ),
    );

    _handlersRegistered = true;
  }

  /// Internal dispatch when a command is executed.
  @pragma('vm:entry-point')
  static int _onCommandExecute(
    int commandId,
    int playerId,
    Pointer<Utf8> argsJson,
  ) {
    final command = _commands[commandId];
    if (command == null) {
      print('Commands: Unknown command ID $commandId');
      return 0;
    }

    try {
      // Parse the arguments JSON
      final argsString = argsJson.toDartString();
      final Map<String, dynamic> args =
          argsString.isEmpty ? {} : jsonDecode(argsString);

      // Create the context
      final context = CommandContext._(
        source: Player(playerId),
        arguments: args,
        sendFeedback: (msg) => _sendFeedback(playerId, msg),
        sendError: (msg) => _sendError(playerId, msg),
      );

      // Execute the command
      return command.execute(context);
    } catch (e) {
      print('Commands: Error executing ${command.name}: $e');
      _sendError(playerId, 'Command error: $e');
      return 0;
    }
  }

  /// Send feedback to a player.
  static void _sendFeedback(int playerId, String message) {
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/proxy/CommandRegistry',
      'sendFeedback',
      '(ILjava/lang/String;)V',
      [playerId, message],
    );
  }

  /// Send an error message to a player.
  static void _sendError(int playerId, String message) {
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/proxy/CommandRegistry',
      'sendError',
      '(ILjava/lang/String;)V',
      [playerId, message],
    );
  }

  /// Get a registered command by ID.
  static _RegisteredCommand? getCommand(int commandId) => _commands[commandId];

  /// Get all registered commands.
  static Iterable<_RegisteredCommand> get allCommands => _commands.values;

  /// Get the number of registered commands.
  static int get commandCount => _commands.length;
}

/// Internal class to store registered command data.
class _RegisteredCommand {
  final int id;
  final String name;
  final CommandExecuteCallback execute;
  final String? description;
  final List<CommandArgument> arguments;
  final int permission;

  _RegisteredCommand({
    required this.id,
    required this.name,
    required this.execute,
    this.description,
    required this.arguments,
    required this.permission,
  });
}

// =============================================================================
// FFI Callback Type Definitions
// =============================================================================

/// Native callback type for command execution.
typedef _CommandExecuteCallbackNative = Int32 Function(
  Int64 commandId,
  Int32 playerId,
  Pointer<Utf8> argsJson,
);
