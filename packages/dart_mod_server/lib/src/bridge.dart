/// Server-side FFI bridge to native server code.
library;

// ignore_for_file: unused_field

import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// FFI bindings to the server-side native bridge.
///
/// This class provides the FFI interface to dart_bridge_server native functions.
class ServerBridge {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  /// Initialize the server bridge with the native library.
  static void init(String libraryPath) {
    if (_initialized) return;

    _lib = DynamicLibrary.open(libraryPath);
    _initialized = true;

    // Bind all functions
    _bindFunctions();
  }

  /// Check if the bridge is initialized.
  static bool get isInitialized => _initialized;

  // ==========================================================================
  // Native Function Bindings
  // ==========================================================================

  static late final _DartServerInit _dartServerInit;
  static late final _DartServerShutdown _dartServerShutdown;
  static late final _DartServerTick _dartServerTick;
  static late final _DartServerSetJvm _dartServerSetJvm;
  static late final _DartServerGetServiceUrl _dartServerGetServiceUrl;

  // Registration queue functions
  static late final _ServerQueueBlockRegistration _serverQueueBlockRegistration;
  static late final _ServerQueueItemRegistration _serverQueueItemRegistration;
  static late final _ServerQueueEntityRegistration _serverQueueEntityRegistration;
  static late final _ServerSignalRegistrationsQueued _serverSignalRegistrationsQueued;

  // Callback registration functions
  static late final _ServerRegisterBlockBreakHandler _serverRegisterBlockBreakHandler;
  static late final _ServerRegisterTickHandler _serverRegisterTickHandler;
  static late final _ServerRegisterProxyBlockBreakHandler _serverRegisterProxyBlockBreakHandler;
  static late final _ServerRegisterProxyBlockUseHandler _serverRegisterProxyBlockUseHandler;
  static late final _ServerRegisterProxyBlockSteppedOnHandler _serverRegisterProxyBlockSteppedOnHandler;
  static late final _ServerRegisterProxyBlockFallenUponHandler _serverRegisterProxyBlockFallenUponHandler;
  static late final _ServerRegisterProxyBlockRandomTickHandler _serverRegisterProxyBlockRandomTickHandler;
  static late final _ServerRegisterProxyBlockPlacedHandler _serverRegisterProxyBlockPlacedHandler;
  static late final _ServerRegisterProxyBlockRemovedHandler _serverRegisterProxyBlockRemovedHandler;
  static late final _ServerRegisterProxyBlockNeighborChangedHandler _serverRegisterProxyBlockNeighborChangedHandler;
  static late final _ServerRegisterProxyBlockEntityInsideHandler _serverRegisterProxyBlockEntityInsideHandler;

  static late final _ServerRegisterPlayerJoinHandler _serverRegisterPlayerJoinHandler;
  static late final _ServerRegisterPlayerLeaveHandler _serverRegisterPlayerLeaveHandler;
  static late final _ServerRegisterPlayerRespawnHandler _serverRegisterPlayerRespawnHandler;
  static late final _ServerRegisterPlayerDeathHandler _serverRegisterPlayerDeathHandler;
  static late final _ServerRegisterEntityDamageHandler _serverRegisterEntityDamageHandler;
  static late final _ServerRegisterEntityDeathHandler _serverRegisterEntityDeathHandler;
  static late final _ServerRegisterPlayerAttackEntityHandler _serverRegisterPlayerAttackEntityHandler;
  static late final _ServerRegisterPlayerChatHandler _serverRegisterPlayerChatHandler;
  static late final _ServerRegisterPlayerCommandHandler _serverRegisterPlayerCommandHandler;
  static late final _ServerRegisterItemUseHandler _serverRegisterItemUseHandler;
  static late final _ServerRegisterItemUseOnBlockHandler _serverRegisterItemUseOnBlockHandler;
  static late final _ServerRegisterItemUseOnEntityHandler _serverRegisterItemUseOnEntityHandler;
  static late final _ServerRegisterBlockPlaceHandler _serverRegisterBlockPlaceHandler;
  static late final _ServerRegisterPlayerPickupItemHandler _serverRegisterPlayerPickupItemHandler;
  static late final _ServerRegisterPlayerDropItemHandler _serverRegisterPlayerDropItemHandler;
  static late final _ServerRegisterServerStartingHandler _serverRegisterServerStartingHandler;
  static late final _ServerRegisterServerStartedHandler _serverRegisterServerStartedHandler;
  static late final _ServerRegisterServerStoppingHandler _serverRegisterServerStoppingHandler;

  static late final _ServerRegisterProxyEntitySpawnHandler _serverRegisterProxyEntitySpawnHandler;
  static late final _ServerRegisterProxyEntityTickHandler _serverRegisterProxyEntityTickHandler;
  static late final _ServerRegisterProxyEntityDeathHandler _serverRegisterProxyEntityDeathHandler;
  static late final _ServerRegisterProxyEntityDamageHandler _serverRegisterProxyEntityDamageHandler;
  static late final _ServerRegisterProxyEntityAttackHandler _serverRegisterProxyEntityAttackHandler;
  static late final _ServerRegisterProxyEntityTargetHandler _serverRegisterProxyEntityTargetHandler;

  static late final _ServerRegisterProxyItemAttackEntityHandler _serverRegisterProxyItemAttackEntityHandler;
  static late final _ServerRegisterProxyItemUseHandler _serverRegisterProxyItemUseHandler;
  static late final _ServerRegisterProxyItemUseOnBlockHandler _serverRegisterProxyItemUseOnBlockHandler;
  static late final _ServerRegisterProxyItemUseOnEntityHandler _serverRegisterProxyItemUseOnEntityHandler;

  static late final _ServerRegisterCommandExecuteHandler _serverRegisterCommandExecuteHandler;

  static late final _ServerRegisterCustomGoalCanUseHandler _serverRegisterCustomGoalCanUseHandler;
  static late final _ServerRegisterCustomGoalCanContinueToUseHandler _serverRegisterCustomGoalCanContinueToUseHandler;
  static late final _ServerRegisterCustomGoalStartHandler _serverRegisterCustomGoalStartHandler;
  static late final _ServerRegisterCustomGoalTickHandler _serverRegisterCustomGoalTickHandler;
  static late final _ServerRegisterCustomGoalStopHandler _serverRegisterCustomGoalStopHandler;

  static late final _ServerSetSendChatMessageCallback _serverSetSendChatMessageCallback;

  static void _bindFunctions() {
    final lib = _lib!;

    // Lifecycle functions
    _dartServerInit = lib.lookupFunction<
        Bool Function(Pointer<Utf8>, Pointer<Utf8>, Int32),
        bool Function(Pointer<Utf8>, Pointer<Utf8>, int)>('dart_server_init');

    _dartServerShutdown =
        lib.lookupFunction<Void Function(), void Function()>('dart_server_shutdown');

    _dartServerTick =
        lib.lookupFunction<Void Function(), void Function()>('dart_server_tick');

    _dartServerSetJvm = lib.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('dart_server_set_jvm');

    _dartServerGetServiceUrl = lib.lookupFunction<
        Pointer<Utf8> Function(),
        Pointer<Utf8> Function()>('dart_server_get_service_url');

    // Registration queue functions
    _serverQueueBlockRegistration = lib.lookupFunction<
        Int64 Function(
            Pointer<Utf8>, Pointer<Utf8>,
            Float, Float, Bool, Int32,
            Double, Double, Double,
            Bool, Bool, Bool, Bool),
        int Function(
            Pointer<Utf8>, Pointer<Utf8>,
            double, double, bool, int,
            double, double, double,
            bool, bool, bool, bool)>('server_queue_block_registration');

    _serverQueueItemRegistration = lib.lookupFunction<
        Int64 Function(
            Pointer<Utf8>, Pointer<Utf8>,
            Int32, Int32, Bool,
            Double, Double, Double),
        int Function(
            Pointer<Utf8>, Pointer<Utf8>,
            int, int, bool,
            double, double, double)>('server_queue_item_registration');

    _serverQueueEntityRegistration = lib.lookupFunction<
        Int64 Function(
            Pointer<Utf8>, Pointer<Utf8>,
            Double, Double, Double, Double, Double,
            Int32, Int32, Pointer<Utf8>,
            Pointer<Utf8>, Pointer<Utf8>, Double,
            Pointer<Utf8>, Pointer<Utf8>),
        int Function(
            Pointer<Utf8>, Pointer<Utf8>,
            double, double, double, double, double,
            int, int, Pointer<Utf8>,
            Pointer<Utf8>, Pointer<Utf8>, double,
            Pointer<Utf8>, Pointer<Utf8>)>('server_queue_entity_registration');

    _serverSignalRegistrationsQueued =
        lib.lookupFunction<Void Function(), void Function()>('server_signal_registrations_queued');

    // Callback registration - bind all the handlers
    _bindCallbackRegistrations(lib);
  }

  static void _bindCallbackRegistrations(DynamicLibrary lib) {
    // Block break handler
    _serverRegisterBlockBreakHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_BlockBreakCallbackNative>>),
        void Function(Pointer<NativeFunction<_BlockBreakCallbackNative>>)>('server_register_block_break_handler');

    // Tick handler
    _serverRegisterTickHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_TickCallbackNative>>),
        void Function(Pointer<NativeFunction<_TickCallbackNative>>)>('server_register_tick_handler');

    // Proxy block handlers
    _serverRegisterProxyBlockBreakHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyBlockBreakCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyBlockBreakCallbackNative>>)>('server_register_proxy_block_break_handler');

    _serverRegisterProxyBlockUseHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyBlockUseCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyBlockUseCallbackNative>>)>('server_register_proxy_block_use_handler');

    _serverRegisterProxyBlockSteppedOnHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyBlockSteppedOnCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyBlockSteppedOnCallbackNative>>)>('server_register_proxy_block_stepped_on_handler');

    _serverRegisterProxyBlockFallenUponHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyBlockFallenUponCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyBlockFallenUponCallbackNative>>)>('server_register_proxy_block_fallen_upon_handler');

    _serverRegisterProxyBlockRandomTickHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyBlockRandomTickCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyBlockRandomTickCallbackNative>>)>('server_register_proxy_block_random_tick_handler');

    _serverRegisterProxyBlockPlacedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyBlockPlacedCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyBlockPlacedCallbackNative>>)>('server_register_proxy_block_placed_handler');

    _serverRegisterProxyBlockRemovedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyBlockRemovedCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyBlockRemovedCallbackNative>>)>('server_register_proxy_block_removed_handler');

    _serverRegisterProxyBlockNeighborChangedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyBlockNeighborChangedCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyBlockNeighborChangedCallbackNative>>)>('server_register_proxy_block_neighbor_changed_handler');

    _serverRegisterProxyBlockEntityInsideHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyBlockEntityInsideCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyBlockEntityInsideCallbackNative>>)>('server_register_proxy_block_entity_inside_handler');

    // Player handlers
    _serverRegisterPlayerJoinHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_PlayerJoinCallbackNative>>),
        void Function(Pointer<NativeFunction<_PlayerJoinCallbackNative>>)>('server_register_player_join_handler');

    _serverRegisterPlayerLeaveHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_PlayerLeaveCallbackNative>>),
        void Function(Pointer<NativeFunction<_PlayerLeaveCallbackNative>>)>('server_register_player_leave_handler');

    _serverRegisterPlayerRespawnHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_PlayerRespawnCallbackNative>>),
        void Function(Pointer<NativeFunction<_PlayerRespawnCallbackNative>>)>('server_register_player_respawn_handler');

    _serverRegisterPlayerDeathHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_PlayerDeathCallbackNative>>),
        void Function(Pointer<NativeFunction<_PlayerDeathCallbackNative>>)>('server_register_player_death_handler');

    _serverRegisterEntityDamageHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_EntityDamageCallbackNative>>),
        void Function(Pointer<NativeFunction<_EntityDamageCallbackNative>>)>('server_register_entity_damage_handler');

    _serverRegisterEntityDeathHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_EntityDeathCallbackNative>>),
        void Function(Pointer<NativeFunction<_EntityDeathCallbackNative>>)>('server_register_entity_death_handler');

    _serverRegisterPlayerAttackEntityHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_PlayerAttackEntityCallbackNative>>),
        void Function(Pointer<NativeFunction<_PlayerAttackEntityCallbackNative>>)>('server_register_player_attack_entity_handler');

    _serverRegisterPlayerChatHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_PlayerChatCallbackNative>>),
        void Function(Pointer<NativeFunction<_PlayerChatCallbackNative>>)>('server_register_player_chat_handler');

    _serverRegisterPlayerCommandHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_PlayerCommandCallbackNative>>),
        void Function(Pointer<NativeFunction<_PlayerCommandCallbackNative>>)>('server_register_player_command_handler');

    _serverRegisterItemUseHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ItemUseCallbackNative>>),
        void Function(Pointer<NativeFunction<_ItemUseCallbackNative>>)>('server_register_item_use_handler');

    _serverRegisterItemUseOnBlockHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ItemUseOnBlockCallbackNative>>),
        void Function(Pointer<NativeFunction<_ItemUseOnBlockCallbackNative>>)>('server_register_item_use_on_block_handler');

    _serverRegisterItemUseOnEntityHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ItemUseOnEntityCallbackNative>>),
        void Function(Pointer<NativeFunction<_ItemUseOnEntityCallbackNative>>)>('server_register_item_use_on_entity_handler');

    _serverRegisterBlockPlaceHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_BlockPlaceCallbackNative>>),
        void Function(Pointer<NativeFunction<_BlockPlaceCallbackNative>>)>('server_register_block_place_handler');

    _serverRegisterPlayerPickupItemHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_PlayerPickupItemCallbackNative>>),
        void Function(Pointer<NativeFunction<_PlayerPickupItemCallbackNative>>)>('server_register_player_pickup_item_handler');

    _serverRegisterPlayerDropItemHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_PlayerDropItemCallbackNative>>),
        void Function(Pointer<NativeFunction<_PlayerDropItemCallbackNative>>)>('server_register_player_drop_item_handler');

    _serverRegisterServerStartingHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ServerLifecycleCallbackNative>>),
        void Function(Pointer<NativeFunction<_ServerLifecycleCallbackNative>>)>('server_register_server_starting_handler');

    _serverRegisterServerStartedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ServerLifecycleCallbackNative>>),
        void Function(Pointer<NativeFunction<_ServerLifecycleCallbackNative>>)>('server_register_server_started_handler');

    _serverRegisterServerStoppingHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ServerLifecycleCallbackNative>>),
        void Function(Pointer<NativeFunction<_ServerLifecycleCallbackNative>>)>('server_register_server_stopping_handler');

    // Proxy entity handlers
    _serverRegisterProxyEntitySpawnHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyEntitySpawnCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyEntitySpawnCallbackNative>>)>('server_register_proxy_entity_spawn_handler');

    _serverRegisterProxyEntityTickHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyEntityTickCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyEntityTickCallbackNative>>)>('server_register_proxy_entity_tick_handler');

    _serverRegisterProxyEntityDeathHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyEntityDeathCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyEntityDeathCallbackNative>>)>('server_register_proxy_entity_death_handler');

    _serverRegisterProxyEntityDamageHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyEntityDamageCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyEntityDamageCallbackNative>>)>('server_register_proxy_entity_damage_handler');

    _serverRegisterProxyEntityAttackHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyEntityAttackCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyEntityAttackCallbackNative>>)>('server_register_proxy_entity_attack_handler');

    _serverRegisterProxyEntityTargetHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyEntityTargetCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyEntityTargetCallbackNative>>)>('server_register_proxy_entity_target_handler');

    // Proxy item handlers
    _serverRegisterProxyItemAttackEntityHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyItemAttackEntityCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyItemAttackEntityCallbackNative>>)>('server_register_proxy_item_attack_entity_handler');

    _serverRegisterProxyItemUseHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyItemUseCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyItemUseCallbackNative>>)>('server_register_proxy_item_use_handler');

    _serverRegisterProxyItemUseOnBlockHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyItemUseOnBlockCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyItemUseOnBlockCallbackNative>>)>('server_register_proxy_item_use_on_block_handler');

    _serverRegisterProxyItemUseOnEntityHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ProxyItemUseOnEntityCallbackNative>>),
        void Function(Pointer<NativeFunction<_ProxyItemUseOnEntityCallbackNative>>)>('server_register_proxy_item_use_on_entity_handler');

    // Command handler
    _serverRegisterCommandExecuteHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_CommandExecuteCallbackNative>>),
        void Function(Pointer<NativeFunction<_CommandExecuteCallbackNative>>)>('server_register_command_execute_handler');

    // Custom goal handlers
    _serverRegisterCustomGoalCanUseHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_CustomGoalCanUseCallbackNative>>),
        void Function(Pointer<NativeFunction<_CustomGoalCanUseCallbackNative>>)>('server_register_custom_goal_can_use_handler');

    _serverRegisterCustomGoalCanContinueToUseHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_CustomGoalCanContinueToUseCallbackNative>>),
        void Function(Pointer<NativeFunction<_CustomGoalCanContinueToUseCallbackNative>>)>('server_register_custom_goal_can_continue_to_use_handler');

    _serverRegisterCustomGoalStartHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_CustomGoalStartCallbackNative>>),
        void Function(Pointer<NativeFunction<_CustomGoalStartCallbackNative>>)>('server_register_custom_goal_start_handler');

    _serverRegisterCustomGoalTickHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_CustomGoalTickCallbackNative>>),
        void Function(Pointer<NativeFunction<_CustomGoalTickCallbackNative>>)>('server_register_custom_goal_tick_handler');

    _serverRegisterCustomGoalStopHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_CustomGoalStopCallbackNative>>),
        void Function(Pointer<NativeFunction<_CustomGoalStopCallbackNative>>)>('server_register_custom_goal_stop_handler');

    // Send chat message callback
    _serverSetSendChatMessageCallback = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_SendChatMessageCallbackNative>>),
        void Function(Pointer<NativeFunction<_SendChatMessageCallbackNative>>)>('server_set_send_chat_message_callback');
  }

  // ==========================================================================
  // Public API
  // ==========================================================================

  /// Initialize the Dart VM and load the server-side script.
  static bool serverInit(String scriptPath, String? packageConfig, int servicePort) {
    final scriptPathPtr = scriptPath.toNativeUtf8();
    final packageConfigPtr = packageConfig?.toNativeUtf8() ?? nullptr;

    try {
      return _dartServerInit(scriptPathPtr, packageConfigPtr, servicePort);
    } finally {
      calloc.free(scriptPathPtr);
      if (packageConfig != null) calloc.free(packageConfigPtr);
    }
  }

  /// Shutdown the Dart VM.
  static void serverShutdown() {
    _dartServerShutdown();
  }

  /// Tick the Dart VM (drain microtask queue).
  static void serverTick() {
    _dartServerTick();
  }

  /// Set JVM reference for JNI callbacks.
  static void serverSetJvm(Pointer<Void> jvm) {
    _dartServerSetJvm(jvm);
  }

  /// Get the Dart VM service URL for hot reload/debugging.
  static String? getServiceUrl() {
    final ptr = _dartServerGetServiceUrl();
    if (ptr == nullptr) return null;
    return ptr.toDartString();
  }

  /// Queue a block for registration.
  static int queueBlockRegistration({
    required String namespace,
    required String path,
    required double hardness,
    required double resistance,
    required bool requiresTool,
    required int luminance,
    required double slipperiness,
    required double velocityMultiplier,
    required double jumpVelocityMultiplier,
    required bool ticksRandomly,
    required bool collidable,
    required bool replaceable,
    required bool burnable,
  }) {
    final namespacePtr = namespace.toNativeUtf8();
    final pathPtr = path.toNativeUtf8();

    try {
      return _serverQueueBlockRegistration(
        namespacePtr, pathPtr,
        hardness, resistance, requiresTool, luminance,
        slipperiness, velocityMultiplier, jumpVelocityMultiplier,
        ticksRandomly, collidable, replaceable, burnable,
      );
    } finally {
      calloc.free(namespacePtr);
      calloc.free(pathPtr);
    }
  }

  /// Queue an item for registration.
  static int queueItemRegistration({
    required String namespace,
    required String path,
    required int maxStackSize,
    required int maxDamage,
    required bool fireResistant,
    required double attackDamage,
    required double attackSpeed,
    required double attackKnockback,
  }) {
    final namespacePtr = namespace.toNativeUtf8();
    final pathPtr = path.toNativeUtf8();

    try {
      return _serverQueueItemRegistration(
        namespacePtr, pathPtr,
        maxStackSize, maxDamage, fireResistant,
        attackDamage, attackSpeed, attackKnockback,
      );
    } finally {
      calloc.free(namespacePtr);
      calloc.free(pathPtr);
    }
  }

  /// Queue an entity for registration.
  static int queueEntityRegistration({
    required String namespace,
    required String path,
    required double width,
    required double height,
    required double maxHealth,
    required double movementSpeed,
    required double attackDamage,
    required int spawnGroup,
    required int baseType,
    String? breedingItem,
    String? modelType,
    String? texturePath,
    double modelScale = 1.0,
    String? goalsJson,
    String? targetGoalsJson,
  }) {
    final namespacePtr = namespace.toNativeUtf8();
    final pathPtr = path.toNativeUtf8();
    final breedingItemPtr = breedingItem?.toNativeUtf8() ?? nullptr;
    final modelTypePtr = modelType?.toNativeUtf8() ?? nullptr;
    final texturePathPtr = texturePath?.toNativeUtf8() ?? nullptr;
    final goalsJsonPtr = goalsJson?.toNativeUtf8() ?? nullptr;
    final targetGoalsJsonPtr = targetGoalsJson?.toNativeUtf8() ?? nullptr;

    try {
      return _serverQueueEntityRegistration(
        namespacePtr, pathPtr,
        width, height, maxHealth, movementSpeed, attackDamage,
        spawnGroup, baseType, breedingItemPtr,
        modelTypePtr, texturePathPtr, modelScale,
        goalsJsonPtr, targetGoalsJsonPtr,
      );
    } finally {
      calloc.free(namespacePtr);
      calloc.free(pathPtr);
      if (breedingItem != null) calloc.free(breedingItemPtr);
      if (modelType != null) calloc.free(modelTypePtr);
      if (texturePath != null) calloc.free(texturePathPtr);
      if (goalsJson != null) calloc.free(goalsJsonPtr);
      if (targetGoalsJson != null) calloc.free(targetGoalsJsonPtr);
    }
  }

  /// Signal that all registrations are queued.
  static void signalRegistrationsQueued() {
    _serverSignalRegistrationsQueued();
  }

  // ==========================================================================
  // Callback Registration
  // ==========================================================================

  /// Register a tick handler callback.
  static void registerTickHandler(Pointer<NativeFunction<_TickCallbackNative>> callback) {
    _serverRegisterTickHandler(callback);
  }

  // ... Additional callback registration methods follow the same pattern
}

// ==========================================================================
// Native callback type definitions
// ==========================================================================

typedef _DartServerInit = bool Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef _DartServerShutdown = void Function();
typedef _DartServerTick = void Function();
typedef _DartServerSetJvm = void Function(Pointer<Void>);
typedef _DartServerGetServiceUrl = Pointer<Utf8> Function();

typedef _ServerQueueBlockRegistration = int Function(
    Pointer<Utf8>, Pointer<Utf8>,
    double, double, bool, int,
    double, double, double,
    bool, bool, bool, bool);

typedef _ServerQueueItemRegistration = int Function(
    Pointer<Utf8>, Pointer<Utf8>,
    int, int, bool,
    double, double, double);

typedef _ServerQueueEntityRegistration = int Function(
    Pointer<Utf8>, Pointer<Utf8>,
    double, double, double, double, double,
    int, int, Pointer<Utf8>,
    Pointer<Utf8>, Pointer<Utf8>, double,
    Pointer<Utf8>, Pointer<Utf8>);

typedef _ServerSignalRegistrationsQueued = void Function();

// Callback registration typedefs
typedef _ServerRegisterBlockBreakHandler = void Function(Pointer<NativeFunction<_BlockBreakCallbackNative>>);
typedef _ServerRegisterTickHandler = void Function(Pointer<NativeFunction<_TickCallbackNative>>);
typedef _ServerRegisterProxyBlockBreakHandler = void Function(Pointer<NativeFunction<_ProxyBlockBreakCallbackNative>>);
typedef _ServerRegisterProxyBlockUseHandler = void Function(Pointer<NativeFunction<_ProxyBlockUseCallbackNative>>);
typedef _ServerRegisterProxyBlockSteppedOnHandler = void Function(Pointer<NativeFunction<_ProxyBlockSteppedOnCallbackNative>>);
typedef _ServerRegisterProxyBlockFallenUponHandler = void Function(Pointer<NativeFunction<_ProxyBlockFallenUponCallbackNative>>);
typedef _ServerRegisterProxyBlockRandomTickHandler = void Function(Pointer<NativeFunction<_ProxyBlockRandomTickCallbackNative>>);
typedef _ServerRegisterProxyBlockPlacedHandler = void Function(Pointer<NativeFunction<_ProxyBlockPlacedCallbackNative>>);
typedef _ServerRegisterProxyBlockRemovedHandler = void Function(Pointer<NativeFunction<_ProxyBlockRemovedCallbackNative>>);
typedef _ServerRegisterProxyBlockNeighborChangedHandler = void Function(Pointer<NativeFunction<_ProxyBlockNeighborChangedCallbackNative>>);
typedef _ServerRegisterProxyBlockEntityInsideHandler = void Function(Pointer<NativeFunction<_ProxyBlockEntityInsideCallbackNative>>);
typedef _ServerRegisterPlayerJoinHandler = void Function(Pointer<NativeFunction<_PlayerJoinCallbackNative>>);
typedef _ServerRegisterPlayerLeaveHandler = void Function(Pointer<NativeFunction<_PlayerLeaveCallbackNative>>);
typedef _ServerRegisterPlayerRespawnHandler = void Function(Pointer<NativeFunction<_PlayerRespawnCallbackNative>>);
typedef _ServerRegisterPlayerDeathHandler = void Function(Pointer<NativeFunction<_PlayerDeathCallbackNative>>);
typedef _ServerRegisterEntityDamageHandler = void Function(Pointer<NativeFunction<_EntityDamageCallbackNative>>);
typedef _ServerRegisterEntityDeathHandler = void Function(Pointer<NativeFunction<_EntityDeathCallbackNative>>);
typedef _ServerRegisterPlayerAttackEntityHandler = void Function(Pointer<NativeFunction<_PlayerAttackEntityCallbackNative>>);
typedef _ServerRegisterPlayerChatHandler = void Function(Pointer<NativeFunction<_PlayerChatCallbackNative>>);
typedef _ServerRegisterPlayerCommandHandler = void Function(Pointer<NativeFunction<_PlayerCommandCallbackNative>>);
typedef _ServerRegisterItemUseHandler = void Function(Pointer<NativeFunction<_ItemUseCallbackNative>>);
typedef _ServerRegisterItemUseOnBlockHandler = void Function(Pointer<NativeFunction<_ItemUseOnBlockCallbackNative>>);
typedef _ServerRegisterItemUseOnEntityHandler = void Function(Pointer<NativeFunction<_ItemUseOnEntityCallbackNative>>);
typedef _ServerRegisterBlockPlaceHandler = void Function(Pointer<NativeFunction<_BlockPlaceCallbackNative>>);
typedef _ServerRegisterPlayerPickupItemHandler = void Function(Pointer<NativeFunction<_PlayerPickupItemCallbackNative>>);
typedef _ServerRegisterPlayerDropItemHandler = void Function(Pointer<NativeFunction<_PlayerDropItemCallbackNative>>);
typedef _ServerRegisterServerStartingHandler = void Function(Pointer<NativeFunction<_ServerLifecycleCallbackNative>>);
typedef _ServerRegisterServerStartedHandler = void Function(Pointer<NativeFunction<_ServerLifecycleCallbackNative>>);
typedef _ServerRegisterServerStoppingHandler = void Function(Pointer<NativeFunction<_ServerLifecycleCallbackNative>>);
typedef _ServerRegisterProxyEntitySpawnHandler = void Function(Pointer<NativeFunction<_ProxyEntitySpawnCallbackNative>>);
typedef _ServerRegisterProxyEntityTickHandler = void Function(Pointer<NativeFunction<_ProxyEntityTickCallbackNative>>);
typedef _ServerRegisterProxyEntityDeathHandler = void Function(Pointer<NativeFunction<_ProxyEntityDeathCallbackNative>>);
typedef _ServerRegisterProxyEntityDamageHandler = void Function(Pointer<NativeFunction<_ProxyEntityDamageCallbackNative>>);
typedef _ServerRegisterProxyEntityAttackHandler = void Function(Pointer<NativeFunction<_ProxyEntityAttackCallbackNative>>);
typedef _ServerRegisterProxyEntityTargetHandler = void Function(Pointer<NativeFunction<_ProxyEntityTargetCallbackNative>>);
typedef _ServerRegisterProxyItemAttackEntityHandler = void Function(Pointer<NativeFunction<_ProxyItemAttackEntityCallbackNative>>);
typedef _ServerRegisterProxyItemUseHandler = void Function(Pointer<NativeFunction<_ProxyItemUseCallbackNative>>);
typedef _ServerRegisterProxyItemUseOnBlockHandler = void Function(Pointer<NativeFunction<_ProxyItemUseOnBlockCallbackNative>>);
typedef _ServerRegisterProxyItemUseOnEntityHandler = void Function(Pointer<NativeFunction<_ProxyItemUseOnEntityCallbackNative>>);
typedef _ServerRegisterCommandExecuteHandler = void Function(Pointer<NativeFunction<_CommandExecuteCallbackNative>>);
typedef _ServerRegisterCustomGoalCanUseHandler = void Function(Pointer<NativeFunction<_CustomGoalCanUseCallbackNative>>);
typedef _ServerRegisterCustomGoalCanContinueToUseHandler = void Function(Pointer<NativeFunction<_CustomGoalCanContinueToUseCallbackNative>>);
typedef _ServerRegisterCustomGoalStartHandler = void Function(Pointer<NativeFunction<_CustomGoalStartCallbackNative>>);
typedef _ServerRegisterCustomGoalTickHandler = void Function(Pointer<NativeFunction<_CustomGoalTickCallbackNative>>);
typedef _ServerRegisterCustomGoalStopHandler = void Function(Pointer<NativeFunction<_CustomGoalStopCallbackNative>>);
typedef _ServerSetSendChatMessageCallback = void Function(Pointer<NativeFunction<_SendChatMessageCallbackNative>>);

// Native callback signatures
typedef _BlockBreakCallbackNative = Int32 Function(Int32, Int32, Int32, Int64);
typedef _TickCallbackNative = Void Function(Int64);
typedef _ProxyBlockBreakCallbackNative = Bool Function(Int64, Int64, Int32, Int32, Int32, Int64);
typedef _ProxyBlockUseCallbackNative = Int32 Function(Int64, Int64, Int32, Int32, Int32, Int64, Int32);
typedef _ProxyBlockSteppedOnCallbackNative = Void Function(Int64, Int64, Int32, Int32, Int32, Int32);
typedef _ProxyBlockFallenUponCallbackNative = Void Function(Int64, Int64, Int32, Int32, Int32, Int32, Float);
typedef _ProxyBlockRandomTickCallbackNative = Void Function(Int64, Int64, Int32, Int32, Int32);
typedef _ProxyBlockPlacedCallbackNative = Void Function(Int64, Int64, Int32, Int32, Int32, Int64);
typedef _ProxyBlockRemovedCallbackNative = Void Function(Int64, Int64, Int32, Int32, Int32);
typedef _ProxyBlockNeighborChangedCallbackNative = Void Function(Int64, Int64, Int32, Int32, Int32, Int32, Int32, Int32);
typedef _ProxyBlockEntityInsideCallbackNative = Void Function(Int64, Int64, Int32, Int32, Int32, Int32);
typedef _PlayerJoinCallbackNative = Void Function(Int32);
typedef _PlayerLeaveCallbackNative = Void Function(Int32);
typedef _PlayerRespawnCallbackNative = Void Function(Int32, Bool);
typedef _PlayerDeathCallbackNative = Pointer<Utf8> Function(Int32, Pointer<Utf8>);
typedef _EntityDamageCallbackNative = Bool Function(Int32, Pointer<Utf8>, Double);
typedef _EntityDeathCallbackNative = Void Function(Int32, Pointer<Utf8>);
typedef _PlayerAttackEntityCallbackNative = Bool Function(Int32, Int32);
typedef _PlayerChatCallbackNative = Pointer<Utf8> Function(Int32, Pointer<Utf8>);
typedef _PlayerCommandCallbackNative = Bool Function(Int32, Pointer<Utf8>);
typedef _ItemUseCallbackNative = Bool Function(Int32, Pointer<Utf8>, Int32, Int32);
typedef _ItemUseOnBlockCallbackNative = Int32 Function(Int32, Pointer<Utf8>, Int32, Int32, Int32, Int32, Int32, Int32);
typedef _ItemUseOnEntityCallbackNative = Int32 Function(Int32, Pointer<Utf8>, Int32, Int32, Int32);
typedef _BlockPlaceCallbackNative = Bool Function(Int32, Int32, Int32, Int32, Pointer<Utf8>);
typedef _PlayerPickupItemCallbackNative = Bool Function(Int32, Int32);
typedef _PlayerDropItemCallbackNative = Bool Function(Int32, Pointer<Utf8>, Int32);
typedef _ServerLifecycleCallbackNative = Void Function();
typedef _ProxyEntitySpawnCallbackNative = Void Function(Int64, Int32, Int64);
typedef _ProxyEntityTickCallbackNative = Void Function(Int64, Int32);
typedef _ProxyEntityDeathCallbackNative = Void Function(Int64, Int32, Pointer<Utf8>);
typedef _ProxyEntityDamageCallbackNative = Bool Function(Int64, Int32, Pointer<Utf8>, Double);
typedef _ProxyEntityAttackCallbackNative = Void Function(Int64, Int32, Int32);
typedef _ProxyEntityTargetCallbackNative = Void Function(Int64, Int32, Int32);
typedef _ProxyItemAttackEntityCallbackNative = Bool Function(Int64, Int32, Int32, Int32);
typedef _ProxyItemUseCallbackNative = Int32 Function(Int64, Int64, Int32, Int32);
typedef _ProxyItemUseOnBlockCallbackNative = Int32 Function(Int64, Int64, Int32, Int32, Int32, Int32, Int32);
typedef _ProxyItemUseOnEntityCallbackNative = Int32 Function(Int64, Int64, Int32, Int32, Int32);
typedef _CommandExecuteCallbackNative = Int32 Function(Int64, Int32, Pointer<Utf8>);
typedef _CustomGoalCanUseCallbackNative = Bool Function(Pointer<Utf8>, Int32);
typedef _CustomGoalCanContinueToUseCallbackNative = Bool Function(Pointer<Utf8>, Int32);
typedef _CustomGoalStartCallbackNative = Void Function(Pointer<Utf8>, Int32);
typedef _CustomGoalTickCallbackNative = Void Function(Pointer<Utf8>, Int32);
typedef _CustomGoalStopCallbackNative = Void Function(Pointer<Utf8>, Int32);
typedef _SendChatMessageCallbackNative = Void Function(Int64, Pointer<Utf8>);
