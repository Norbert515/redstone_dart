/// Native bridge bindings for communicating with the C++ layer.
///
/// This file contains the FFI bindings to the native dart_mc_bridge library.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'jni/generic_bridge.dart';

/// Callback type definitions matching the native side
typedef BlockBreakCallbackNative = Int32 Function(
    Int32 x, Int32 y, Int32 z, Int64 playerId);
typedef BlockInteractCallbackNative = Int32 Function(
    Int32 x, Int32 y, Int32 z, Int64 playerId, Int32 hand);
typedef TickCallbackNative = Void Function(Int64 tick);

/// Proxy block callback types (for custom Dart-defined blocks)
/// Returns Bool: true to allow break, false to cancel
typedef ProxyBlockBreakCallbackNative = Bool Function(
    Int64 handlerId, Int64 worldId, Int32 x, Int32 y, Int32 z, Int64 playerId);
typedef ProxyBlockUseCallbackNative = Int32 Function(
    Int64 handlerId, Int64 worldId, Int32 x, Int32 y, Int32 z,
    Int64 playerId, Int32 hand);

// =============================================================================
// New Event Callback Types
// =============================================================================

/// Player join callback
typedef PlayerJoinCallbackNative = Void Function(Int32 playerId);

/// Player leave callback
typedef PlayerLeaveCallbackNative = Void Function(Int32 playerId);

/// Player respawn callback
typedef PlayerRespawnCallbackNative = Void Function(Int32 playerId, Bool endConquered);

/// Player death callback - returns custom death message (or nullptr for default)
typedef PlayerDeathCallbackNative = Pointer<Utf8> Function(Int32 playerId, Pointer<Utf8> damageSource);

/// Entity damage callback - returns true to allow, false to cancel
typedef EntityDamageCallbackNative = Bool Function(Int32 entityId, Pointer<Utf8> damageSource, Double amount);

/// Entity death callback
typedef EntityDeathCallbackNative = Void Function(Int32 entityId, Pointer<Utf8> damageSource);

/// Player attack entity callback - returns true to allow, false to cancel
typedef PlayerAttackEntityCallbackNative = Bool Function(Int32 playerId, Int32 targetId);

/// Player chat callback - returns modified message or nullptr to cancel
typedef PlayerChatCallbackNative = Pointer<Utf8> Function(Int32 playerId, Pointer<Utf8> message);

/// Player command callback - returns true to allow, false to cancel
typedef PlayerCommandCallbackNative = Bool Function(Int32 playerId, Pointer<Utf8> command);

/// Item use callback - returns true to allow, false to cancel
typedef ItemUseCallbackNative = Bool Function(Int32 playerId, Pointer<Utf8> itemId, Int32 count, Int32 hand);

/// Item use on block callback - returns EventResult value
typedef ItemUseOnBlockCallbackNative = Int32 Function(
    Int32 playerId, Pointer<Utf8> itemId, Int32 count, Int32 hand,
    Int32 x, Int32 y, Int32 z, Int32 face);

/// Item use on entity callback - returns EventResult value
typedef ItemUseOnEntityCallbackNative = Int32 Function(
    Int32 playerId, Pointer<Utf8> itemId, Int32 count, Int32 hand, Int32 targetId);

/// Block place callback - returns true to allow, false to cancel
typedef BlockPlaceCallbackNative = Bool Function(
    Int32 playerId, Int32 x, Int32 y, Int32 z, Pointer<Utf8> blockId);

/// Player pickup item callback - returns true to allow, false to cancel
typedef PlayerPickupItemCallbackNative = Bool Function(Int32 playerId, Int32 itemEntityId);

/// Player drop item callback - returns true to allow, false to cancel
typedef PlayerDropItemCallbackNative = Bool Function(Int32 playerId, Pointer<Utf8> itemId, Int32 count);

/// Server lifecycle callbacks (no parameters)
typedef ServerLifecycleCallbackNative = Void Function();

/// Native function signatures
typedef RegisterBlockBreakHandlerNative = Void Function(
    Pointer<NativeFunction<BlockBreakCallbackNative>> callback);
typedef RegisterBlockBreakHandler = void Function(
    Pointer<NativeFunction<BlockBreakCallbackNative>> callback);

typedef RegisterBlockInteractHandlerNative = Void Function(
    Pointer<NativeFunction<BlockInteractCallbackNative>> callback);
typedef RegisterBlockInteractHandler = void Function(
    Pointer<NativeFunction<BlockInteractCallbackNative>> callback);

typedef RegisterTickHandlerNative = Void Function(
    Pointer<NativeFunction<TickCallbackNative>> callback);
typedef RegisterTickHandler = void Function(
    Pointer<NativeFunction<TickCallbackNative>> callback);

/// Proxy block handler registration signatures
typedef RegisterProxyBlockBreakHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyBlockBreakCallbackNative>> callback);
typedef RegisterProxyBlockBreakHandler = void Function(
    Pointer<NativeFunction<ProxyBlockBreakCallbackNative>> callback);

typedef RegisterProxyBlockUseHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyBlockUseCallbackNative>> callback);
typedef RegisterProxyBlockUseHandler = void Function(
    Pointer<NativeFunction<ProxyBlockUseCallbackNative>> callback);

/// Chat message function signature
typedef SendChatMessageNative = Void Function(Int64 playerId, Pointer<Utf8> message);
typedef SendChatMessage = void Function(int playerId, Pointer<Utf8> message);

// =============================================================================
// New Event Handler Registration Signatures
// =============================================================================

typedef RegisterPlayerJoinHandlerNative = Void Function(
    Pointer<NativeFunction<PlayerJoinCallbackNative>> callback);
typedef RegisterPlayerJoinHandler = void Function(
    Pointer<NativeFunction<PlayerJoinCallbackNative>> callback);

typedef RegisterPlayerLeaveHandlerNative = Void Function(
    Pointer<NativeFunction<PlayerLeaveCallbackNative>> callback);
typedef RegisterPlayerLeaveHandler = void Function(
    Pointer<NativeFunction<PlayerLeaveCallbackNative>> callback);

typedef RegisterPlayerRespawnHandlerNative = Void Function(
    Pointer<NativeFunction<PlayerRespawnCallbackNative>> callback);
typedef RegisterPlayerRespawnHandler = void Function(
    Pointer<NativeFunction<PlayerRespawnCallbackNative>> callback);

typedef RegisterPlayerDeathHandlerNative = Void Function(
    Pointer<NativeFunction<PlayerDeathCallbackNative>> callback);
typedef RegisterPlayerDeathHandler = void Function(
    Pointer<NativeFunction<PlayerDeathCallbackNative>> callback);

typedef RegisterEntityDamageHandlerNative = Void Function(
    Pointer<NativeFunction<EntityDamageCallbackNative>> callback);
typedef RegisterEntityDamageHandler = void Function(
    Pointer<NativeFunction<EntityDamageCallbackNative>> callback);

typedef RegisterEntityDeathHandlerNative = Void Function(
    Pointer<NativeFunction<EntityDeathCallbackNative>> callback);
typedef RegisterEntityDeathHandler = void Function(
    Pointer<NativeFunction<EntityDeathCallbackNative>> callback);

typedef RegisterPlayerAttackEntityHandlerNative = Void Function(
    Pointer<NativeFunction<PlayerAttackEntityCallbackNative>> callback);
typedef RegisterPlayerAttackEntityHandler = void Function(
    Pointer<NativeFunction<PlayerAttackEntityCallbackNative>> callback);

typedef RegisterPlayerChatHandlerNative = Void Function(
    Pointer<NativeFunction<PlayerChatCallbackNative>> callback);
typedef RegisterPlayerChatHandler = void Function(
    Pointer<NativeFunction<PlayerChatCallbackNative>> callback);

typedef RegisterPlayerCommandHandlerNative = Void Function(
    Pointer<NativeFunction<PlayerCommandCallbackNative>> callback);
typedef RegisterPlayerCommandHandler = void Function(
    Pointer<NativeFunction<PlayerCommandCallbackNative>> callback);

typedef RegisterItemUseHandlerNative = Void Function(
    Pointer<NativeFunction<ItemUseCallbackNative>> callback);
typedef RegisterItemUseHandler = void Function(
    Pointer<NativeFunction<ItemUseCallbackNative>> callback);

typedef RegisterItemUseOnBlockHandlerNative = Void Function(
    Pointer<NativeFunction<ItemUseOnBlockCallbackNative>> callback);
typedef RegisterItemUseOnBlockHandler = void Function(
    Pointer<NativeFunction<ItemUseOnBlockCallbackNative>> callback);

typedef RegisterItemUseOnEntityHandlerNative = Void Function(
    Pointer<NativeFunction<ItemUseOnEntityCallbackNative>> callback);
typedef RegisterItemUseOnEntityHandler = void Function(
    Pointer<NativeFunction<ItemUseOnEntityCallbackNative>> callback);

typedef RegisterBlockPlaceHandlerNative = Void Function(
    Pointer<NativeFunction<BlockPlaceCallbackNative>> callback);
typedef RegisterBlockPlaceHandler = void Function(
    Pointer<NativeFunction<BlockPlaceCallbackNative>> callback);

typedef RegisterPlayerPickupItemHandlerNative = Void Function(
    Pointer<NativeFunction<PlayerPickupItemCallbackNative>> callback);
typedef RegisterPlayerPickupItemHandler = void Function(
    Pointer<NativeFunction<PlayerPickupItemCallbackNative>> callback);

typedef RegisterPlayerDropItemHandlerNative = Void Function(
    Pointer<NativeFunction<PlayerDropItemCallbackNative>> callback);
typedef RegisterPlayerDropItemHandler = void Function(
    Pointer<NativeFunction<PlayerDropItemCallbackNative>> callback);

typedef RegisterServerLifecycleHandlerNative = Void Function(
    Pointer<NativeFunction<ServerLifecycleCallbackNative>> callback);
typedef RegisterServerLifecycleHandler = void Function(
    Pointer<NativeFunction<ServerLifecycleCallbackNative>> callback);

/// Bridge to the native library.
class Bridge {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  /// Initialize the bridge by loading the native library.
  /// When running embedded in the Dart VM (via dart_dll), the symbols
  /// are already available in the current process.
  static void initialize() {
    if (_initialized) return;

    _lib = _loadLibrary();
    _initialized = true;
    print('Bridge: Native library loaded');

    // Initialize the generic JNI bridge
    GenericJniBridge.init();
    print('Bridge: Generic JNI bridge initialized');
  }

  static DynamicLibrary _loadLibrary() {
    // When running embedded, try to use the current process first
    // (symbols are exported by the host application)
    try {
      final lib = DynamicLibrary.process();
      // Verify we can find our symbols
      lib.lookup('register_block_break_handler');
      print('Bridge: Using process symbols (embedded mode)');
      return lib;
    } catch (_) {
      // Fall back to loading from file
      print('Bridge: Falling back to file loading');
    }

    final String libraryName;
    if (Platform.isWindows) {
      libraryName = 'dart_mc_bridge.dll';
    } else if (Platform.isMacOS) {
      libraryName = 'libdart_mc_bridge.dylib';
    } else {
      libraryName = 'libdart_mc_bridge.so';
    }

    // Try multiple paths to find the library
    final paths = [
      libraryName, // Current directory
      'dart_mc_bridge.dylib', // Without lib prefix (our build)
      '../native/build/$libraryName', // Build output
      '../native/build/dart_mc_bridge.dylib', // Build output without prefix
      'native/build/lib/$libraryName',
      'native/build/dart_mc_bridge.dylib',
    ];

    for (final path in paths) {
      try {
        return DynamicLibrary.open(path);
      } catch (_) {
        // Try next path
      }
    }

    throw StateError(
        'Failed to load native library. Tried paths: ${paths.join(", ")}');
  }

  /// Get the native library instance.
  static DynamicLibrary get library {
    if (_lib == null) {
      throw StateError('Bridge not initialized. Call Bridge.initialize() first.');
    }
    return _lib!;
  }

  /// Register a block break handler.
  static void registerBlockBreakHandler(
      Pointer<NativeFunction<BlockBreakCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterBlockBreakHandlerNative,
        RegisterBlockBreakHandler>('register_block_break_handler');
    register(callback);
  }

  /// Register a block interact handler.
  static void registerBlockInteractHandler(
      Pointer<NativeFunction<BlockInteractCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterBlockInteractHandlerNative,
        RegisterBlockInteractHandler>('register_block_interact_handler');
    register(callback);
  }

  /// Register a tick handler.
  static void registerTickHandler(
      Pointer<NativeFunction<TickCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterTickHandlerNative,
        RegisterTickHandler>('register_tick_handler');
    register(callback);
  }

  /// Register a proxy block break handler.
  /// This is called when a Dart-defined custom block is broken.
  static void registerProxyBlockBreakHandler(
      Pointer<NativeFunction<ProxyBlockBreakCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyBlockBreakHandlerNative,
        RegisterProxyBlockBreakHandler>('register_proxy_block_break_handler');
    register(callback);
  }

  /// Register a proxy block use handler.
  /// This is called when a Dart-defined custom block is right-clicked.
  static void registerProxyBlockUseHandler(
      Pointer<NativeFunction<ProxyBlockUseCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyBlockUseHandlerNative,
        RegisterProxyBlockUseHandler>('register_proxy_block_use_handler');
    register(callback);
  }

  /// Send a chat message to a player.
  ///
  /// [playerId] is the entity ID of the player (or 0 to broadcast to all).
  /// [message] is the text to send.
  static void sendChatMessage(int playerId, String message) {
    final send = library.lookupFunction<SendChatMessageNative, SendChatMessage>(
        'send_chat_message');
    final messagePtr = message.toNativeUtf8();
    try {
      send(playerId, messagePtr);
    } finally {
      calloc.free(messagePtr);
    }
  }

  // ===========================================================================
  // New Event Handler Registration Methods
  // ===========================================================================

  /// Register a player join handler.
  static void registerPlayerJoinHandler(
      Pointer<NativeFunction<PlayerJoinCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterPlayerJoinHandlerNative,
        RegisterPlayerJoinHandler>('register_player_join_handler');
    register(callback);
  }

  /// Register a player leave handler.
  static void registerPlayerLeaveHandler(
      Pointer<NativeFunction<PlayerLeaveCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterPlayerLeaveHandlerNative,
        RegisterPlayerLeaveHandler>('register_player_leave_handler');
    register(callback);
  }

  /// Register a player respawn handler.
  static void registerPlayerRespawnHandler(
      Pointer<NativeFunction<PlayerRespawnCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterPlayerRespawnHandlerNative,
        RegisterPlayerRespawnHandler>('register_player_respawn_handler');
    register(callback);
  }

  /// Register a player death handler.
  static void registerPlayerDeathHandler(
      Pointer<NativeFunction<PlayerDeathCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterPlayerDeathHandlerNative,
        RegisterPlayerDeathHandler>('register_player_death_handler');
    register(callback);
  }

  /// Register an entity damage handler.
  static void registerEntityDamageHandler(
      Pointer<NativeFunction<EntityDamageCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterEntityDamageHandlerNative,
        RegisterEntityDamageHandler>('register_entity_damage_handler');
    register(callback);
  }

  /// Register an entity death handler.
  static void registerEntityDeathHandler(
      Pointer<NativeFunction<EntityDeathCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterEntityDeathHandlerNative,
        RegisterEntityDeathHandler>('register_entity_death_handler');
    register(callback);
  }

  /// Register a player attack entity handler.
  static void registerPlayerAttackEntityHandler(
      Pointer<NativeFunction<PlayerAttackEntityCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterPlayerAttackEntityHandlerNative,
        RegisterPlayerAttackEntityHandler>('register_player_attack_entity_handler');
    register(callback);
  }

  /// Register a player chat handler.
  static void registerPlayerChatHandler(
      Pointer<NativeFunction<PlayerChatCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterPlayerChatHandlerNative,
        RegisterPlayerChatHandler>('register_player_chat_handler');
    register(callback);
  }

  /// Register a player command handler.
  static void registerPlayerCommandHandler(
      Pointer<NativeFunction<PlayerCommandCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterPlayerCommandHandlerNative,
        RegisterPlayerCommandHandler>('register_player_command_handler');
    register(callback);
  }

  /// Register an item use handler.
  static void registerItemUseHandler(
      Pointer<NativeFunction<ItemUseCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterItemUseHandlerNative,
        RegisterItemUseHandler>('register_item_use_handler');
    register(callback);
  }

  /// Register an item use on block handler.
  static void registerItemUseOnBlockHandler(
      Pointer<NativeFunction<ItemUseOnBlockCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterItemUseOnBlockHandlerNative,
        RegisterItemUseOnBlockHandler>('register_item_use_on_block_handler');
    register(callback);
  }

  /// Register an item use on entity handler.
  static void registerItemUseOnEntityHandler(
      Pointer<NativeFunction<ItemUseOnEntityCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterItemUseOnEntityHandlerNative,
        RegisterItemUseOnEntityHandler>('register_item_use_on_entity_handler');
    register(callback);
  }

  /// Register a block place handler.
  static void registerBlockPlaceHandler(
      Pointer<NativeFunction<BlockPlaceCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterBlockPlaceHandlerNative,
        RegisterBlockPlaceHandler>('register_block_place_handler');
    register(callback);
  }

  /// Register a player pickup item handler.
  static void registerPlayerPickupItemHandler(
      Pointer<NativeFunction<PlayerPickupItemCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterPlayerPickupItemHandlerNative,
        RegisterPlayerPickupItemHandler>('register_player_pickup_item_handler');
    register(callback);
  }

  /// Register a player drop item handler.
  static void registerPlayerDropItemHandler(
      Pointer<NativeFunction<PlayerDropItemCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterPlayerDropItemHandlerNative,
        RegisterPlayerDropItemHandler>('register_player_drop_item_handler');
    register(callback);
  }

  /// Register a server starting handler.
  static void registerServerStartingHandler(
      Pointer<NativeFunction<ServerLifecycleCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterServerLifecycleHandlerNative,
        RegisterServerLifecycleHandler>('register_server_starting_handler');
    register(callback);
  }

  /// Register a server started handler.
  static void registerServerStartedHandler(
      Pointer<NativeFunction<ServerLifecycleCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterServerLifecycleHandlerNative,
        RegisterServerLifecycleHandler>('register_server_started_handler');
    register(callback);
  }

  /// Register a server stopping handler.
  static void registerServerStoppingHandler(
      Pointer<NativeFunction<ServerLifecycleCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterServerLifecycleHandlerNative,
        RegisterServerLifecycleHandler>('register_server_stopping_handler');
    register(callback);
  }
}
