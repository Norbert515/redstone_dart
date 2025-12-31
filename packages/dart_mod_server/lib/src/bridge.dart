/// Server-side FFI bridge to native server code.
library;

// ignore_for_file: unused_field

import 'dart:ffi';
import 'dart:io';

import 'package:dart_mod_common/dart_mod_common.dart' show GenericJniBridge;
import 'package:ffi/ffi.dart';

/// Type alias for backward compatibility with code using Bridge.
typedef Bridge = ServerBridge;

/// FFI bindings to the server-side native bridge.
///
/// This class provides the FFI interface to dart_bridge_server native functions.
class ServerBridge {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  /// Whether the mod is running in datagen mode (asset generation only).
  /// When true, registries will exit after writing manifests instead of running the game.
  static bool isDatagenMode = false;

  /// Counter for datagen mode handler IDs.
  static int _datagenHandlerId = 1;

  /// Initialize the server bridge with the native library.
  static void init(String libraryPath) {
    if (_initialized) return;

    _lib = DynamicLibrary.open(libraryPath);
    _initialized = true;

    // Bind all functions
    _bindFunctions();
  }

  /// Initialize the bridge by loading the native library from process symbols.
  ///
  /// This is the preferred initialization method when running embedded in the
  /// Dart VM (via dart_dll), where symbols are already available in the current process.
  ///
  /// For datagen mode, set the REDSTONE_DATAGEN environment variable to 'true'.
  static void initialize() {
    if (_initialized) return;

    // Check for datagen mode via environment variable
    final datagenEnv = Platform.environment['REDSTONE_DATAGEN'];
    if (datagenEnv == 'true' || datagenEnv == '1') {
      isDatagenMode = true;
      _initialized = true;
      // Initialize GenericJniBridge (will also be in datagen mode)
      GenericJniBridge.init();
      print('ServerBridge: Running in DATAGEN mode (no native library)');
      return;
    }

    _lib = _loadLibrary();
    _initialized = true;
    print('ServerBridge: Native library loaded');

    // Initialize GenericJniBridge (uses process symbols for JNI calls)
    GenericJniBridge.init();

    // Bind all functions
    _bindFunctions();
  }

  static DynamicLibrary _loadLibrary() {
    // When running embedded, try to use the current process first
    // (symbols are exported by the host application)
    try {
      final lib = DynamicLibrary.process();
      // Verify we can find our symbols
      lib.lookup('server_register_block_break_handler');
      print('ServerBridge: Using process symbols (embedded mode)');
      return lib;
    } catch (_) {
      // Fall back to loading from file
      print('ServerBridge: Falling back to file loading');
    }

    final String libraryName;
    if (Platform.isWindows) {
      libraryName = 'dart_bridge_server.dll';
    } else if (Platform.isMacOS) {
      libraryName = 'libdart_bridge_server.dylib';
    } else {
      libraryName = 'libdart_bridge_server.so';
    }

    // Try multiple paths to find the library
    final paths = [
      libraryName, // Current directory
      'dart_bridge_server.dylib', // Without lib prefix (our build)
      '../native/build/$libraryName', // Build output
      '../native/build/dart_bridge_server.dylib', // Build output without prefix
      'native/build/lib/$libraryName',
      'native/build/dart_bridge_server.dylib',
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

  /// Check if the bridge is initialized.
  static bool get isInitialized => _initialized;

  /// Get the native library instance.
  static DynamicLibrary get library {
    if (_lib == null) {
      throw StateError('ServerBridge not initialized. Call ServerBridge.initialize() first.');
    }
    return _lib!;
  }

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

  // Registry ready handler
  static late final _ServerRegisterRegistryReadyHandler _serverRegisterRegistryReadyHandler;

  // Communication functions
  static late final _ServerSendChatMessage _serverSendChatMessage;
  // Note: server_stop_server is not implemented in native code yet
  // static late final _ServerStopServer _serverStopServer;

  // Note: Container item access functions are not implemented in native code yet
  // These use JNI calls instead
  // static late final _ServerGetContainerItem _serverGetContainerItem;
  // static late final _ServerSetContainerItem _serverSetContainerItem;
  // static late final _ServerGetContainerSlotCount _serverGetContainerSlotCount;
  // static late final _ServerClearContainerSlot _serverClearContainerSlot;
  // static late final _ServerOpenContainerForPlayer _serverOpenContainerForPlayer;
  // static late final _ServerFreeString _serverFreeString;

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

    // Registry ready handler
    _serverRegisterRegistryReadyHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_RegistryReadyCallbackNative>>),
        void Function(Pointer<NativeFunction<_RegistryReadyCallbackNative>>)>('server_register_registry_ready_handler');

    // Communication functions
    _serverSendChatMessage = lib.lookupFunction<
        Void Function(Int64, Pointer<Utf8>),
        void Function(int, Pointer<Utf8>)>('server_send_chat_message');

    // Note: server_stop_server is not implemented in native code yet
    // _serverStopServer = lib.lookupFunction<
    //     Void Function(),
    //     void Function()>('server_stop_server');

    // Note: Container item access functions are not implemented in native code yet
    // These should use JNI calls instead
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
    // In datagen mode, return fake handler IDs (no FFI available)
    if (isDatagenMode) {
      return _datagenHandlerId++;
    }

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
    // In datagen mode, return fake handler IDs (no FFI available)
    if (isDatagenMode) {
      return _datagenHandlerId++;
    }

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
    // In datagen mode, return fake handler IDs (no FFI available)
    if (isDatagenMode) {
      return _datagenHandlerId++;
    }

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
    if (isDatagenMode) return;
    _serverSignalRegistrationsQueued();
    print('ServerBridge: Signaled registrations are queued');
  }

  // ==========================================================================
  // Registry Ready Callback (for Flutter embedder timing)
  // ==========================================================================

  /// User-provided callback to be invoked when registries are ready.
  static void Function()? _onRegistryReadyCallback;

  /// Native callback function pointer that bridges to Dart.
  @pragma('vm:entry-point')
  static void _nativeRegistryReadyCallback() {
    print('ServerBridge: Registry ready callback received from Java');
    _onRegistryReadyCallback?.call();
  }

  /// Register a callback to be invoked when Java signals that registries are ready.
  ///
  /// With the Flutter embedder, Dart's `main()` runs immediately when the engine starts,
  /// but Minecraft's registries may not be ready yet. Use this method to defer registration
  /// of blocks, items, and entities until it's safe.
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   ServerBridge.initialize();
  ///   Events.registerProxyBlockHandlers(); // These don't use registries
  ///
  ///   ServerBridge.onRegistryReady(() {
  ///     // Now safe to register items, blocks, entities
  ///     registerItems();
  ///     registerBlocks();
  ///     registerEntities();
  ///   });
  /// }
  /// ```
  static void onRegistryReady(void Function() callback) {
    if (isDatagenMode) {
      // In datagen mode, call immediately since there's no Java to signal
      callback();
      // Exit after registrations complete - manifests have been written
      print('ServerBridge: Datagen mode complete, exiting...');
      exit(0);
    }

    _onRegistryReadyCallback = callback;

    // Register the native callback with the C++ layer
    final nativeCallback = Pointer.fromFunction<_RegistryReadyCallbackNative>(
      _nativeRegistryReadyCallback,
    );
    _serverRegisterRegistryReadyHandler(nativeCallback);
    print('ServerBridge: Registry ready callback registered');
  }

  // ==========================================================================
  // Communication APIs
  // ==========================================================================

  /// Send a chat message to a player.
  ///
  /// [playerId] is the entity ID of the player (or 0 to broadcast to all).
  /// [message] is the text to send.
  static void sendChatMessage(int playerId, String message) {
    if (isDatagenMode) return;
    final messagePtr = message.toNativeUtf8();
    try {
      _serverSendChatMessage(playerId, messagePtr);
    } finally {
      calloc.free(messagePtr);
    }
  }

  /// Stop the Minecraft server gracefully.
  ///
  /// This will cause the server to halt and exit. Use this when you need
  /// to programmatically stop the server (e.g., after tests complete).
  ///
  /// NOTE: Not implemented in native code yet. Use JNI-based approach instead.
  static void stopServer() {
    if (isDatagenMode) return;
    print('ServerBridge: stopServer() not implemented in native code');
    // TODO: Implement via JNI call to MinecraftServer.halt()
  }

  // ==========================================================================
  // Container Item Access APIs (Server-side)
  // NOTE: These functions are not implemented in native code yet.
  // Container access should use JNI calls directly.
  // ==========================================================================

  /// Get item from container slot.
  /// Returns "itemId:count:damage:maxDamage" or empty string.
  ///
  /// NOTE: Not implemented in native code yet.
  static String getContainerItem(int menuId, int slotIndex) {
    if (isDatagenMode) return '';
    print('ServerBridge: getContainerItem() not implemented in native code');
    return '';
  }

  /// Set item in container slot.
  ///
  /// NOTE: Not implemented in native code yet.
  static void setContainerItem(int menuId, int slotIndex, String itemId, int count) {
    if (isDatagenMode) return;
    print('ServerBridge: setContainerItem() not implemented in native code');
  }

  /// Get total slot count for a container menu.
  ///
  /// NOTE: Not implemented in native code yet.
  static int getContainerSlotCount(int menuId) {
    if (isDatagenMode) return 0;
    print('ServerBridge: getContainerSlotCount() not implemented in native code');
    return 0;
  }

  /// Clear a container slot.
  ///
  /// NOTE: Not implemented in native code yet.
  static void clearContainerSlot(int menuId, int slotIndex) {
    if (isDatagenMode) return;
    print('ServerBridge: clearContainerSlot() not implemented in native code');
  }

  /// Open a container for a player.
  ///
  /// [playerId] is the entity ID of the player.
  /// [containerId] is the registered container type ID (e.g., "mymod:diamond_chest").
  ///
  /// Returns true if the container was opened successfully.
  ///
  /// NOTE: Not implemented in native code yet.
  static bool openContainerForPlayer(int playerId, String containerId) {
    if (isDatagenMode) return false;
    print('ServerBridge: openContainerForPlayer() not implemented in native code');
    return false;
  }

  // ==========================================================================
  // Callback Registration
  // ==========================================================================

  /// Register a block break handler callback.
  static void registerBlockBreakHandler(Pointer<NativeFunction<_BlockBreakCallbackNative>> callback) {
    _serverRegisterBlockBreakHandler(callback);
  }

  /// Register a block interact handler callback.
  static void registerBlockInteractHandler(Pointer<NativeFunction<_BlockInteractCallbackNative>> callback) {
    // Note: Block interact uses a different native signature - needs to be added if not present
    // For now, we'll skip this as it may not be needed
  }

  /// Register a tick handler callback.
  static void registerTickHandler(Pointer<NativeFunction<_TickCallbackNative>> callback) {
    _serverRegisterTickHandler(callback);
  }

  // Proxy Block Handlers
  static void registerProxyBlockBreakHandler(Pointer<NativeFunction<_ProxyBlockBreakCallbackNative>> callback) {
    _serverRegisterProxyBlockBreakHandler(callback);
  }

  static void registerProxyBlockUseHandler(Pointer<NativeFunction<_ProxyBlockUseCallbackNative>> callback) {
    _serverRegisterProxyBlockUseHandler(callback);
  }

  static void registerProxyBlockSteppedOnHandler(Pointer<NativeFunction<_ProxyBlockSteppedOnCallbackNative>> callback) {
    _serverRegisterProxyBlockSteppedOnHandler(callback);
  }

  static void registerProxyBlockFallenUponHandler(Pointer<NativeFunction<_ProxyBlockFallenUponCallbackNative>> callback) {
    _serverRegisterProxyBlockFallenUponHandler(callback);
  }

  static void registerProxyBlockRandomTickHandler(Pointer<NativeFunction<_ProxyBlockRandomTickCallbackNative>> callback) {
    _serverRegisterProxyBlockRandomTickHandler(callback);
  }

  static void registerProxyBlockPlacedHandler(Pointer<NativeFunction<_ProxyBlockPlacedCallbackNative>> callback) {
    _serverRegisterProxyBlockPlacedHandler(callback);
  }

  static void registerProxyBlockRemovedHandler(Pointer<NativeFunction<_ProxyBlockRemovedCallbackNative>> callback) {
    _serverRegisterProxyBlockRemovedHandler(callback);
  }

  static void registerProxyBlockNeighborChangedHandler(Pointer<NativeFunction<_ProxyBlockNeighborChangedCallbackNative>> callback) {
    _serverRegisterProxyBlockNeighborChangedHandler(callback);
  }

  static void registerProxyBlockEntityInsideHandler(Pointer<NativeFunction<_ProxyBlockEntityInsideCallbackNative>> callback) {
    _serverRegisterProxyBlockEntityInsideHandler(callback);
  }

  // Player Event Handlers
  static void registerPlayerJoinHandler(Pointer<NativeFunction<_PlayerJoinCallbackNative>> callback) {
    _serverRegisterPlayerJoinHandler(callback);
  }

  static void registerPlayerLeaveHandler(Pointer<NativeFunction<_PlayerLeaveCallbackNative>> callback) {
    _serverRegisterPlayerLeaveHandler(callback);
  }

  static void registerPlayerRespawnHandler(Pointer<NativeFunction<_PlayerRespawnCallbackNative>> callback) {
    _serverRegisterPlayerRespawnHandler(callback);
  }

  static void registerPlayerDeathHandler(Pointer<NativeFunction<_PlayerDeathCallbackNative>> callback) {
    _serverRegisterPlayerDeathHandler(callback);
  }

  static void registerEntityDamageHandler(Pointer<NativeFunction<_EntityDamageCallbackNative>> callback) {
    _serverRegisterEntityDamageHandler(callback);
  }

  static void registerEntityDeathHandler(Pointer<NativeFunction<_EntityDeathCallbackNative>> callback) {
    _serverRegisterEntityDeathHandler(callback);
  }

  static void registerPlayerAttackEntityHandler(Pointer<NativeFunction<_PlayerAttackEntityCallbackNative>> callback) {
    _serverRegisterPlayerAttackEntityHandler(callback);
  }

  static void registerPlayerChatHandler(Pointer<NativeFunction<_PlayerChatCallbackNative>> callback) {
    _serverRegisterPlayerChatHandler(callback);
  }

  static void registerPlayerCommandHandler(Pointer<NativeFunction<_PlayerCommandCallbackNative>> callback) {
    _serverRegisterPlayerCommandHandler(callback);
  }

  // Item Event Handlers
  static void registerItemUseHandler(Pointer<NativeFunction<_ItemUseCallbackNative>> callback) {
    _serverRegisterItemUseHandler(callback);
  }

  static void registerItemUseOnBlockHandler(Pointer<NativeFunction<_ItemUseOnBlockCallbackNative>> callback) {
    _serverRegisterItemUseOnBlockHandler(callback);
  }

  static void registerItemUseOnEntityHandler(Pointer<NativeFunction<_ItemUseOnEntityCallbackNative>> callback) {
    _serverRegisterItemUseOnEntityHandler(callback);
  }

  static void registerBlockPlaceHandler(Pointer<NativeFunction<_BlockPlaceCallbackNative>> callback) {
    _serverRegisterBlockPlaceHandler(callback);
  }

  static void registerPlayerPickupItemHandler(Pointer<NativeFunction<_PlayerPickupItemCallbackNative>> callback) {
    _serverRegisterPlayerPickupItemHandler(callback);
  }

  static void registerPlayerDropItemHandler(Pointer<NativeFunction<_PlayerDropItemCallbackNative>> callback) {
    _serverRegisterPlayerDropItemHandler(callback);
  }

  // Server Lifecycle Handlers
  static void registerServerStartingHandler(Pointer<NativeFunction<_ServerLifecycleCallbackNative>> callback) {
    _serverRegisterServerStartingHandler(callback);
  }

  static void registerServerStartedHandler(Pointer<NativeFunction<_ServerLifecycleCallbackNative>> callback) {
    _serverRegisterServerStartedHandler(callback);
  }

  static void registerServerStoppingHandler(Pointer<NativeFunction<_ServerLifecycleCallbackNative>> callback) {
    _serverRegisterServerStoppingHandler(callback);
  }

  // Proxy Entity Handlers
  static void registerProxyEntitySpawnHandler(Pointer<NativeFunction<_ProxyEntitySpawnCallbackNative>> callback) {
    _serverRegisterProxyEntitySpawnHandler(callback);
  }

  static void registerProxyEntityTickHandler(Pointer<NativeFunction<_ProxyEntityTickCallbackNative>> callback) {
    _serverRegisterProxyEntityTickHandler(callback);
  }

  static void registerProxyEntityDeathHandler(Pointer<NativeFunction<_ProxyEntityDeathCallbackNative>> callback) {
    _serverRegisterProxyEntityDeathHandler(callback);
  }

  static void registerProxyEntityDamageHandler(Pointer<NativeFunction<_ProxyEntityDamageCallbackNative>> callback) {
    _serverRegisterProxyEntityDamageHandler(callback);
  }

  static void registerProxyEntityAttackHandler(Pointer<NativeFunction<_ProxyEntityAttackCallbackNative>> callback) {
    _serverRegisterProxyEntityAttackHandler(callback);
  }

  static void registerProxyEntityTargetHandler(Pointer<NativeFunction<_ProxyEntityTargetCallbackNative>> callback) {
    _serverRegisterProxyEntityTargetHandler(callback);
  }

  // Proxy Item Handlers
  static void registerProxyItemAttackEntityHandler(Pointer<NativeFunction<_ProxyItemAttackEntityCallbackNative>> callback) {
    _serverRegisterProxyItemAttackEntityHandler(callback);
  }

  static void registerProxyItemUseHandler(Pointer<NativeFunction<_ProxyItemUseCallbackNative>> callback) {
    _serverRegisterProxyItemUseHandler(callback);
  }

  static void registerProxyItemUseOnBlockHandler(Pointer<NativeFunction<_ProxyItemUseOnBlockCallbackNative>> callback) {
    _serverRegisterProxyItemUseOnBlockHandler(callback);
  }

  static void registerProxyItemUseOnEntityHandler(Pointer<NativeFunction<_ProxyItemUseOnEntityCallbackNative>> callback) {
    _serverRegisterProxyItemUseOnEntityHandler(callback);
  }

  // Command Handler
  static void registerCommandExecuteHandler(Pointer<NativeFunction<_CommandExecuteCallbackNative>> callback) {
    _serverRegisterCommandExecuteHandler(callback);
  }

  // Custom Goal Handlers
  static void registerCustomGoalCanUseHandler(Pointer<NativeFunction<_CustomGoalCanUseCallbackNative>> callback) {
    _serverRegisterCustomGoalCanUseHandler(callback);
  }

  static void registerCustomGoalCanContinueToUseHandler(Pointer<NativeFunction<_CustomGoalCanContinueToUseCallbackNative>> callback) {
    _serverRegisterCustomGoalCanContinueToUseHandler(callback);
  }

  static void registerCustomGoalStartHandler(Pointer<NativeFunction<_CustomGoalStartCallbackNative>> callback) {
    _serverRegisterCustomGoalStartHandler(callback);
  }

  static void registerCustomGoalTickHandler(Pointer<NativeFunction<_CustomGoalTickCallbackNative>> callback) {
    _serverRegisterCustomGoalTickHandler(callback);
  }

  static void registerCustomGoalStopHandler(Pointer<NativeFunction<_CustomGoalStopCallbackNative>> callback) {
    _serverRegisterCustomGoalStopHandler(callback);
  }
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
typedef _ServerRegisterRegistryReadyHandler = void Function(Pointer<NativeFunction<_RegistryReadyCallbackNative>>);

// Communication function typedefs
typedef _ServerSendChatMessage = void Function(int, Pointer<Utf8>);
// Note: Not implemented in native code yet
// typedef _ServerStopServer = void Function();

// Note: Container item access functions not implemented in native code yet
// typedef _ServerGetContainerItem = Pointer<Utf8> Function(int, int);
// typedef _ServerSetContainerItem = void Function(int, int, Pointer<Utf8>, int);
// typedef _ServerGetContainerSlotCount = int Function(int);
// typedef _ServerClearContainerSlot = void Function(int, int);
// typedef _ServerOpenContainerForPlayer = bool Function(int, Pointer<Utf8>);
// typedef _ServerFreeString = void Function(Pointer<Utf8>);

// Native callback signatures
typedef _BlockBreakCallbackNative = Int32 Function(Int32, Int32, Int32, Int64);
typedef _BlockInteractCallbackNative = Int32 Function(Int32, Int32, Int32, Int64, Int32);
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
typedef _RegistryReadyCallbackNative = Void Function();
