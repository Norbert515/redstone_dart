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

/// Entity stepped on block callback
typedef ProxyBlockSteppedOnCallbackNative = Void Function(
    Int64 handlerId, Int64 worldId, Int32 x, Int32 y, Int32 z, Int32 entityId);

/// Entity fallen upon block callback
typedef ProxyBlockFallenUponCallbackNative = Void Function(
    Int64 handlerId, Int64 worldId, Int32 x, Int32 y, Int32 z,
    Int32 entityId, Double fallDistance);

/// Random tick callback
typedef ProxyBlockRandomTickCallbackNative = Void Function(
    Int64 handlerId, Int64 worldId, Int32 x, Int32 y, Int32 z);

/// Block placed callback
typedef ProxyBlockPlacedCallbackNative = Void Function(
    Int64 handlerId, Int64 worldId, Int32 x, Int32 y, Int32 z, Int64 playerId);

/// Block removed callback
typedef ProxyBlockRemovedCallbackNative = Void Function(
    Int64 handlerId, Int64 worldId, Int32 x, Int32 y, Int32 z);

/// Neighbor changed callback
typedef ProxyBlockNeighborChangedCallbackNative = Void Function(
    Int64 handlerId, Int64 worldId, Int32 x, Int32 y, Int32 z,
    Int32 neighborX, Int32 neighborY, Int32 neighborZ);

/// Entity inside block callback
typedef ProxyBlockEntityInsideCallbackNative = Void Function(
    Int64 handlerId, Int64 worldId, Int32 x, Int32 y, Int32 z, Int32 entityId);

// =============================================================================
// Proxy Entity Callback Types (for custom Dart-defined entities)
// =============================================================================

/// Entity spawn callback - called when a custom entity spawns
typedef ProxyEntitySpawnCallbackNative = Void Function(
    Int64 handlerId, Int32 entityId, Int64 worldId);

/// Entity tick callback - called every game tick
typedef ProxyEntityTickCallbackNative = Void Function(
    Int64 handlerId, Int32 entityId);

/// Entity death callback - called when entity dies
typedef ProxyEntityDeathCallbackNative = Void Function(
    Int64 handlerId, Int32 entityId, Pointer<Utf8> damageSource);

/// Entity damage callback - returns true to allow damage, false to cancel
typedef ProxyEntityDamageCallbackNative = Bool Function(
    Int64 handlerId, Int32 entityId, Pointer<Utf8> damageSource, Double amount);

/// Entity attack callback - called when entity attacks another
typedef ProxyEntityAttackCallbackNative = Void Function(
    Int64 handlerId, Int32 entityId, Int32 targetId);

/// Entity target acquired callback - called when entity acquires a target
typedef ProxyEntityTargetCallbackNative = Void Function(
    Int64 handlerId, Int32 entityId, Int32 targetId);

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

// =============================================================================
// Screen/GUI Callback Types
// =============================================================================

/// Screen init callback - called when screen is initialized
typedef ScreenInitCallbackNative = Void Function(
    Int64 screenId, Int32 width, Int32 height);

/// Screen tick callback - called every game tick
typedef ScreenTickCallbackNative = Void Function(Int64 screenId);

/// Screen render callback - called every frame
typedef ScreenRenderCallbackNative = Void Function(
    Int64 screenId, Int32 mouseX, Int32 mouseY, Float partialTick);

/// Screen close callback - called when screen is closed
typedef ScreenCloseCallbackNative = Void Function(Int64 screenId);

/// Screen key pressed callback - returns true if event was handled
typedef ScreenKeyPressedCallbackNative = Bool Function(
    Int64 screenId, Int32 keyCode, Int32 scanCode, Int32 modifiers);

/// Screen key released callback - returns true if event was handled
typedef ScreenKeyReleasedCallbackNative = Bool Function(
    Int64 screenId, Int32 keyCode, Int32 scanCode, Int32 modifiers);

/// Screen char typed callback - returns true if event was handled
typedef ScreenCharTypedCallbackNative = Bool Function(
    Int64 screenId, Int32 codePoint, Int32 modifiers);

/// Screen mouse clicked callback - returns true if event was handled
typedef ScreenMouseClickedCallbackNative = Bool Function(
    Int64 screenId, Double mouseX, Double mouseY, Int32 button);

/// Screen mouse released callback - returns true if event was handled
typedef ScreenMouseReleasedCallbackNative = Bool Function(
    Int64 screenId, Double mouseX, Double mouseY, Int32 button);

/// Screen mouse dragged callback - returns true if event was handled
typedef ScreenMouseDraggedCallbackNative = Bool Function(
    Int64 screenId, Double mouseX, Double mouseY, Int32 button,
    Double dragX, Double dragY);

/// Screen mouse scrolled callback - returns true if event was handled
typedef ScreenMouseScrolledCallbackNative = Bool Function(
    Int64 screenId, Double mouseX, Double mouseY, Double deltaX, Double deltaY);

// =============================================================================
// Widget Callback Types
// =============================================================================

/// Widget pressed callback - called when a button widget is pressed
typedef WidgetPressedCallbackNative = Void Function(
    Int64 screenId, Int64 widgetId);

/// Widget text changed callback - called when edit box text changes
typedef WidgetTextChangedCallbackNative = Void Function(
    Int64 screenId, Int64 widgetId, Pointer<Utf8> text);

// =============================================================================
// Container Screen Callback Types
// =============================================================================

/// Container screen init callback - called when container screen is initialized
typedef ContainerScreenInitCallbackNative = Void Function(
    Int64 screenId, Int32 width, Int32 height,
    Int32 leftPos, Int32 topPos, Int32 imageWidth, Int32 imageHeight);

/// Container screen render background callback - called every frame to render background
typedef ContainerScreenRenderBgCallbackNative = Void Function(
    Int64 screenId, Int32 mouseX, Int32 mouseY,
    Float partialTick, Int32 leftPos, Int32 topPos);

/// Container screen close callback - called when container screen is closed
typedef ContainerScreenCloseCallbackNative = Void Function(Int64 screenId);

// =============================================================================
// Container Menu Slot Callback Types
// =============================================================================

/// Container slot click callback - returns -1 to skip default handling, 0+ for custom result
typedef ContainerSlotClickCallbackNative = Int32 Function(
    Int64 menuId, Int32 slotIndex, Int32 button, Int32 clickType, Pointer<Utf8> carriedItem);

/// Container quick move callback - returns serialized ItemStack or nullptr for default
typedef ContainerQuickMoveCallbackNative = Pointer<Utf8> Function(
    Int64 menuId, Int32 slotIndex);

/// Container may place callback - returns true to allow, false to deny
typedef ContainerMayPlaceCallbackNative = Bool Function(
    Int64 menuId, Int32 slotIndex, Pointer<Utf8> itemData);

/// Container may pickup callback - returns true to allow, false to deny
typedef ContainerMayPickupCallbackNative = Bool Function(
    Int64 menuId, Int32 slotIndex);

// =============================================================================
// Container Item Access API Types (Dart -> Java)
// =============================================================================

/// Get container item - returns "itemId:count:damage:maxDamage"
typedef GetContainerItemNative = Pointer<Utf8> Function(Int64 menuId, Int32 slotIndex);
typedef GetContainerItem = Pointer<Utf8> Function(int menuId, int slotIndex);

/// Set container item
typedef SetContainerItemNative = Void Function(
    Int64 menuId, Int32 slotIndex, Pointer<Utf8> itemId, Int32 count);
typedef SetContainerItemDart = void Function(
    int menuId, int slotIndex, Pointer<Utf8> itemId, int count);

/// Get container slot count
typedef GetContainerSlotCountNative = Int32 Function(Int64 menuId);
typedef GetContainerSlotCount = int Function(int menuId);

/// Clear container slot
typedef ClearContainerSlotNative = Void Function(Int64 menuId, Int32 slotIndex);
typedef ClearContainerSlotDart = void Function(int menuId, int slotIndex);

/// Free a string allocated by native code
typedef FreeStringNative = Void Function(Pointer<Utf8> str);
typedef FreeStringDart = void Function(Pointer<Utf8> str);

// =============================================================================
// Container Opening API Types (Dart -> Java)
// =============================================================================

/// Open a container for a player - returns true if successful
typedef OpenContainerForPlayerNative = Bool Function(Int32 playerId, Pointer<Utf8> containerId);
typedef OpenContainerForPlayerDart = bool Function(int playerId, Pointer<Utf8> containerId);

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

typedef RegisterProxyBlockSteppedOnHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyBlockSteppedOnCallbackNative>> callback);
typedef RegisterProxyBlockSteppedOnHandler = void Function(
    Pointer<NativeFunction<ProxyBlockSteppedOnCallbackNative>> callback);

typedef RegisterProxyBlockFallenUponHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyBlockFallenUponCallbackNative>> callback);
typedef RegisterProxyBlockFallenUponHandler = void Function(
    Pointer<NativeFunction<ProxyBlockFallenUponCallbackNative>> callback);

typedef RegisterProxyBlockRandomTickHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyBlockRandomTickCallbackNative>> callback);
typedef RegisterProxyBlockRandomTickHandler = void Function(
    Pointer<NativeFunction<ProxyBlockRandomTickCallbackNative>> callback);

typedef RegisterProxyBlockPlacedHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyBlockPlacedCallbackNative>> callback);
typedef RegisterProxyBlockPlacedHandler = void Function(
    Pointer<NativeFunction<ProxyBlockPlacedCallbackNative>> callback);

typedef RegisterProxyBlockRemovedHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyBlockRemovedCallbackNative>> callback);
typedef RegisterProxyBlockRemovedHandler = void Function(
    Pointer<NativeFunction<ProxyBlockRemovedCallbackNative>> callback);

typedef RegisterProxyBlockNeighborChangedHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyBlockNeighborChangedCallbackNative>> callback);
typedef RegisterProxyBlockNeighborChangedHandler = void Function(
    Pointer<NativeFunction<ProxyBlockNeighborChangedCallbackNative>> callback);

typedef RegisterProxyBlockEntityInsideHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyBlockEntityInsideCallbackNative>> callback);
typedef RegisterProxyBlockEntityInsideHandler = void Function(
    Pointer<NativeFunction<ProxyBlockEntityInsideCallbackNative>> callback);

// =============================================================================
// Proxy Entity Handler Registration Signatures
// =============================================================================

typedef RegisterProxyEntitySpawnHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyEntitySpawnCallbackNative>> callback);
typedef RegisterProxyEntitySpawnHandler = void Function(
    Pointer<NativeFunction<ProxyEntitySpawnCallbackNative>> callback);

typedef RegisterProxyEntityTickHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyEntityTickCallbackNative>> callback);
typedef RegisterProxyEntityTickHandler = void Function(
    Pointer<NativeFunction<ProxyEntityTickCallbackNative>> callback);

typedef RegisterProxyEntityDeathHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyEntityDeathCallbackNative>> callback);
typedef RegisterProxyEntityDeathHandler = void Function(
    Pointer<NativeFunction<ProxyEntityDeathCallbackNative>> callback);

typedef RegisterProxyEntityDamageHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyEntityDamageCallbackNative>> callback);
typedef RegisterProxyEntityDamageHandler = void Function(
    Pointer<NativeFunction<ProxyEntityDamageCallbackNative>> callback);

typedef RegisterProxyEntityAttackHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyEntityAttackCallbackNative>> callback);
typedef RegisterProxyEntityAttackHandler = void Function(
    Pointer<NativeFunction<ProxyEntityAttackCallbackNative>> callback);

typedef RegisterProxyEntityTargetHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyEntityTargetCallbackNative>> callback);
typedef RegisterProxyEntityTargetHandler = void Function(
    Pointer<NativeFunction<ProxyEntityTargetCallbackNative>> callback);

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

// =============================================================================
// Screen Callback Registration Signatures
// =============================================================================

typedef RegisterScreenInitHandlerNative = Void Function(
    Pointer<NativeFunction<ScreenInitCallbackNative>> callback);
typedef RegisterScreenInitHandler = void Function(
    Pointer<NativeFunction<ScreenInitCallbackNative>> callback);

typedef RegisterScreenTickHandlerNative = Void Function(
    Pointer<NativeFunction<ScreenTickCallbackNative>> callback);
typedef RegisterScreenTickHandler = void Function(
    Pointer<NativeFunction<ScreenTickCallbackNative>> callback);

typedef RegisterScreenRenderHandlerNative = Void Function(
    Pointer<NativeFunction<ScreenRenderCallbackNative>> callback);
typedef RegisterScreenRenderHandler = void Function(
    Pointer<NativeFunction<ScreenRenderCallbackNative>> callback);

typedef RegisterScreenCloseHandlerNative = Void Function(
    Pointer<NativeFunction<ScreenCloseCallbackNative>> callback);
typedef RegisterScreenCloseHandler = void Function(
    Pointer<NativeFunction<ScreenCloseCallbackNative>> callback);

typedef RegisterScreenKeyPressedHandlerNative = Void Function(
    Pointer<NativeFunction<ScreenKeyPressedCallbackNative>> callback);
typedef RegisterScreenKeyPressedHandler = void Function(
    Pointer<NativeFunction<ScreenKeyPressedCallbackNative>> callback);

typedef RegisterScreenKeyReleasedHandlerNative = Void Function(
    Pointer<NativeFunction<ScreenKeyReleasedCallbackNative>> callback);
typedef RegisterScreenKeyReleasedHandler = void Function(
    Pointer<NativeFunction<ScreenKeyReleasedCallbackNative>> callback);

typedef RegisterScreenCharTypedHandlerNative = Void Function(
    Pointer<NativeFunction<ScreenCharTypedCallbackNative>> callback);
typedef RegisterScreenCharTypedHandler = void Function(
    Pointer<NativeFunction<ScreenCharTypedCallbackNative>> callback);

typedef RegisterScreenMouseClickedHandlerNative = Void Function(
    Pointer<NativeFunction<ScreenMouseClickedCallbackNative>> callback);
typedef RegisterScreenMouseClickedHandler = void Function(
    Pointer<NativeFunction<ScreenMouseClickedCallbackNative>> callback);

typedef RegisterScreenMouseReleasedHandlerNative = Void Function(
    Pointer<NativeFunction<ScreenMouseReleasedCallbackNative>> callback);
typedef RegisterScreenMouseReleasedHandler = void Function(
    Pointer<NativeFunction<ScreenMouseReleasedCallbackNative>> callback);

typedef RegisterScreenMouseDraggedHandlerNative = Void Function(
    Pointer<NativeFunction<ScreenMouseDraggedCallbackNative>> callback);
typedef RegisterScreenMouseDraggedHandler = void Function(
    Pointer<NativeFunction<ScreenMouseDraggedCallbackNative>> callback);

typedef RegisterScreenMouseScrolledHandlerNative = Void Function(
    Pointer<NativeFunction<ScreenMouseScrolledCallbackNative>> callback);
typedef RegisterScreenMouseScrolledHandler = void Function(
    Pointer<NativeFunction<ScreenMouseScrolledCallbackNative>> callback);

// =============================================================================
// Widget Callback Registration Signatures
// =============================================================================

typedef RegisterWidgetPressedHandlerNative = Void Function(
    Pointer<NativeFunction<WidgetPressedCallbackNative>> callback);
typedef RegisterWidgetPressedHandler = void Function(
    Pointer<NativeFunction<WidgetPressedCallbackNative>> callback);

typedef RegisterWidgetTextChangedHandlerNative = Void Function(
    Pointer<NativeFunction<WidgetTextChangedCallbackNative>> callback);
typedef RegisterWidgetTextChangedHandler = void Function(
    Pointer<NativeFunction<WidgetTextChangedCallbackNative>> callback);

// =============================================================================
// Container Screen Callback Registration Signatures
// =============================================================================

typedef RegisterContainerScreenInitHandlerNative = Void Function(
    Pointer<NativeFunction<ContainerScreenInitCallbackNative>> callback);
typedef RegisterContainerScreenInitHandler = void Function(
    Pointer<NativeFunction<ContainerScreenInitCallbackNative>> callback);

typedef RegisterContainerScreenRenderBgHandlerNative = Void Function(
    Pointer<NativeFunction<ContainerScreenRenderBgCallbackNative>> callback);
typedef RegisterContainerScreenRenderBgHandler = void Function(
    Pointer<NativeFunction<ContainerScreenRenderBgCallbackNative>> callback);

typedef RegisterContainerScreenCloseHandlerNative = Void Function(
    Pointer<NativeFunction<ContainerScreenCloseCallbackNative>> callback);
typedef RegisterContainerScreenCloseHandler = void Function(
    Pointer<NativeFunction<ContainerScreenCloseCallbackNative>> callback);

// =============================================================================
// Container Menu Slot Callback Registration Signatures
// =============================================================================

typedef RegisterContainerSlotClickHandlerNative = Void Function(
    Pointer<NativeFunction<ContainerSlotClickCallbackNative>> callback);
typedef RegisterContainerSlotClickHandler = void Function(
    Pointer<NativeFunction<ContainerSlotClickCallbackNative>> callback);

typedef RegisterContainerQuickMoveHandlerNative = Void Function(
    Pointer<NativeFunction<ContainerQuickMoveCallbackNative>> callback);
typedef RegisterContainerQuickMoveHandler = void Function(
    Pointer<NativeFunction<ContainerQuickMoveCallbackNative>> callback);

typedef RegisterContainerMayPlaceHandlerNative = Void Function(
    Pointer<NativeFunction<ContainerMayPlaceCallbackNative>> callback);
typedef RegisterContainerMayPlaceHandler = void Function(
    Pointer<NativeFunction<ContainerMayPlaceCallbackNative>> callback);

typedef RegisterContainerMayPickupHandlerNative = Void Function(
    Pointer<NativeFunction<ContainerMayPickupCallbackNative>> callback);
typedef RegisterContainerMayPickupHandler = void Function(
    Pointer<NativeFunction<ContainerMayPickupCallbackNative>> callback);

/// Bridge to the native library.
class Bridge {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  /// Whether we're running in datagen mode (no JNI/Minecraft).
  /// In this mode, stub values are returned for all JNI calls.
  static bool isDatagenMode = false;

  /// Initialize the bridge by loading the native library.
  /// When running embedded in the Dart VM (via dart_dll), the symbols
  /// are already available in the current process.
  static void initialize() {
    if (_initialized) return;

    // Check for datagen mode via environment variable
    final datagenEnv = Platform.environment['REDSTONE_DATAGEN'];
    if (datagenEnv == 'true' || datagenEnv == '1') {
      isDatagenMode = true;
      _initialized = true;
      print('Bridge: Running in DATAGEN mode (no native library)');
      // Initialize GenericJniBridge in datagen mode (will use stubs)
      GenericJniBridge.init();
      return;
    }

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

  /// Register a proxy block stepped on handler.
  /// This is called when an entity walks on a Dart-defined custom block.
  static void registerProxyBlockSteppedOnHandler(
      Pointer<NativeFunction<ProxyBlockSteppedOnCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyBlockSteppedOnHandlerNative,
        RegisterProxyBlockSteppedOnHandler>('register_proxy_block_stepped_on_handler');
    register(callback);
  }

  /// Register a proxy block fallen upon handler.
  /// This is called when an entity falls onto a Dart-defined custom block.
  static void registerProxyBlockFallenUponHandler(
      Pointer<NativeFunction<ProxyBlockFallenUponCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyBlockFallenUponHandlerNative,
        RegisterProxyBlockFallenUponHandler>('register_proxy_block_fallen_upon_handler');
    register(callback);
  }

  /// Register a proxy block random tick handler.
  /// This is called on random ticks for blocks with ticksRandomly enabled.
  static void registerProxyBlockRandomTickHandler(
      Pointer<NativeFunction<ProxyBlockRandomTickCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyBlockRandomTickHandlerNative,
        RegisterProxyBlockRandomTickHandler>('register_proxy_block_random_tick_handler');
    register(callback);
  }

  /// Register a proxy block placed handler.
  /// This is called when a Dart-defined custom block is placed.
  static void registerProxyBlockPlacedHandler(
      Pointer<NativeFunction<ProxyBlockPlacedCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyBlockPlacedHandlerNative,
        RegisterProxyBlockPlacedHandler>('register_proxy_block_placed_handler');
    register(callback);
  }

  /// Register a proxy block removed handler.
  /// This is called when a Dart-defined custom block is removed.
  static void registerProxyBlockRemovedHandler(
      Pointer<NativeFunction<ProxyBlockRemovedCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyBlockRemovedHandlerNative,
        RegisterProxyBlockRemovedHandler>('register_proxy_block_removed_handler');
    register(callback);
  }

  /// Register a proxy block neighbor changed handler.
  /// This is called when a neighbor of a Dart-defined custom block changes.
  static void registerProxyBlockNeighborChangedHandler(
      Pointer<NativeFunction<ProxyBlockNeighborChangedCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyBlockNeighborChangedHandlerNative,
        RegisterProxyBlockNeighborChangedHandler>('register_proxy_block_neighbor_changed_handler');
    register(callback);
  }

  /// Register a proxy block entity inside handler.
  /// This is called when an entity is inside a Dart-defined custom block.
  static void registerProxyBlockEntityInsideHandler(
      Pointer<NativeFunction<ProxyBlockEntityInsideCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyBlockEntityInsideHandlerNative,
        RegisterProxyBlockEntityInsideHandler>('register_proxy_block_entity_inside_handler');
    register(callback);
  }

  // ===========================================================================
  // Proxy Entity Handler Registration Methods
  // ===========================================================================

  /// Register a proxy entity spawn handler.
  /// This is called when a Dart-defined custom entity spawns.
  static void registerProxyEntitySpawnHandler(
      Pointer<NativeFunction<ProxyEntitySpawnCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyEntitySpawnHandlerNative,
        RegisterProxyEntitySpawnHandler>('register_proxy_entity_spawn_handler');
    register(callback);
  }

  /// Register a proxy entity tick handler.
  /// This is called every game tick for Dart-defined custom entities.
  static void registerProxyEntityTickHandler(
      Pointer<NativeFunction<ProxyEntityTickCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyEntityTickHandlerNative,
        RegisterProxyEntityTickHandler>('register_proxy_entity_tick_handler');
    register(callback);
  }

  /// Register a proxy entity death handler.
  /// This is called when a Dart-defined custom entity dies.
  static void registerProxyEntityDeathHandler(
      Pointer<NativeFunction<ProxyEntityDeathCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyEntityDeathHandlerNative,
        RegisterProxyEntityDeathHandler>('register_proxy_entity_death_handler');
    register(callback);
  }

  /// Register a proxy entity damage handler.
  /// This is called when a Dart-defined custom entity takes damage.
  /// The callback should return true to allow the damage, false to cancel.
  static void registerProxyEntityDamageHandler(
      Pointer<NativeFunction<ProxyEntityDamageCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyEntityDamageHandlerNative,
        RegisterProxyEntityDamageHandler>('register_proxy_entity_damage_handler');
    register(callback);
  }

  /// Register a proxy entity attack handler.
  /// This is called when a Dart-defined custom entity attacks another entity.
  static void registerProxyEntityAttackHandler(
      Pointer<NativeFunction<ProxyEntityAttackCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyEntityAttackHandlerNative,
        RegisterProxyEntityAttackHandler>('register_proxy_entity_attack_handler');
    register(callback);
  }

  /// Register a proxy entity target handler.
  /// This is called when a Dart-defined custom entity acquires a target.
  static void registerProxyEntityTargetHandler(
      Pointer<NativeFunction<ProxyEntityTargetCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyEntityTargetHandlerNative,
        RegisterProxyEntityTargetHandler>('register_proxy_entity_target_handler');
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

  // ===========================================================================
  // Screen Callback Registration Methods
  // ===========================================================================

  /// Register a screen init handler.
  static void registerScreenInitHandler(
      Pointer<NativeFunction<ScreenInitCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterScreenInitHandlerNative,
        RegisterScreenInitHandler>('register_screen_init_callback');
    register(callback);
  }

  /// Register a screen tick handler.
  static void registerScreenTickHandler(
      Pointer<NativeFunction<ScreenTickCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterScreenTickHandlerNative,
        RegisterScreenTickHandler>('register_screen_tick_callback');
    register(callback);
  }

  /// Register a screen render handler.
  static void registerScreenRenderHandler(
      Pointer<NativeFunction<ScreenRenderCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterScreenRenderHandlerNative,
        RegisterScreenRenderHandler>('register_screen_render_callback');
    register(callback);
  }

  /// Register a screen close handler.
  static void registerScreenCloseHandler(
      Pointer<NativeFunction<ScreenCloseCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterScreenCloseHandlerNative,
        RegisterScreenCloseHandler>('register_screen_close_callback');
    register(callback);
  }

  /// Register a screen key pressed handler.
  static void registerScreenKeyPressedHandler(
      Pointer<NativeFunction<ScreenKeyPressedCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterScreenKeyPressedHandlerNative,
        RegisterScreenKeyPressedHandler>('register_screen_key_pressed_callback');
    register(callback);
  }

  /// Register a screen key released handler.
  static void registerScreenKeyReleasedHandler(
      Pointer<NativeFunction<ScreenKeyReleasedCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterScreenKeyReleasedHandlerNative,
        RegisterScreenKeyReleasedHandler>('register_screen_key_released_callback');
    register(callback);
  }

  /// Register a screen char typed handler.
  static void registerScreenCharTypedHandler(
      Pointer<NativeFunction<ScreenCharTypedCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterScreenCharTypedHandlerNative,
        RegisterScreenCharTypedHandler>('register_screen_char_typed_callback');
    register(callback);
  }

  /// Register a screen mouse clicked handler.
  static void registerScreenMouseClickedHandler(
      Pointer<NativeFunction<ScreenMouseClickedCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterScreenMouseClickedHandlerNative,
        RegisterScreenMouseClickedHandler>('register_screen_mouse_clicked_callback');
    register(callback);
  }

  /// Register a screen mouse released handler.
  static void registerScreenMouseReleasedHandler(
      Pointer<NativeFunction<ScreenMouseReleasedCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterScreenMouseReleasedHandlerNative,
        RegisterScreenMouseReleasedHandler>('register_screen_mouse_released_callback');
    register(callback);
  }

  /// Register a screen mouse dragged handler.
  static void registerScreenMouseDraggedHandler(
      Pointer<NativeFunction<ScreenMouseDraggedCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterScreenMouseDraggedHandlerNative,
        RegisterScreenMouseDraggedHandler>('register_screen_mouse_dragged_callback');
    register(callback);
  }

  /// Register a screen mouse scrolled handler.
  static void registerScreenMouseScrolledHandler(
      Pointer<NativeFunction<ScreenMouseScrolledCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterScreenMouseScrolledHandlerNative,
        RegisterScreenMouseScrolledHandler>('register_screen_mouse_scrolled_callback');
    register(callback);
  }

  // ===========================================================================
  // Widget Callback Registration Methods
  // ===========================================================================

  /// Register a widget pressed handler.
  static void registerWidgetPressedHandler(
      Pointer<NativeFunction<WidgetPressedCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterWidgetPressedHandlerNative,
        RegisterWidgetPressedHandler>('register_widget_pressed_callback');
    register(callback);
  }

  /// Register a widget text changed handler.
  static void registerWidgetTextChangedHandler(
      Pointer<NativeFunction<WidgetTextChangedCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterWidgetTextChangedHandlerNative,
        RegisterWidgetTextChangedHandler>('register_widget_text_changed_callback');
    register(callback);
  }

  // ===========================================================================
  // Container Screen Callback Registration Methods
  // ===========================================================================

  /// Register a container screen init handler.
  static void registerContainerScreenInitHandler(
      Pointer<NativeFunction<ContainerScreenInitCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterContainerScreenInitHandlerNative,
        RegisterContainerScreenInitHandler>('register_container_screen_init_callback');
    register(callback);
  }

  /// Register a container screen render background handler.
  static void registerContainerScreenRenderBgHandler(
      Pointer<NativeFunction<ContainerScreenRenderBgCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterContainerScreenRenderBgHandlerNative,
        RegisterContainerScreenRenderBgHandler>('register_container_screen_render_bg_callback');
    register(callback);
  }

  /// Register a container screen close handler.
  static void registerContainerScreenCloseHandler(
      Pointer<NativeFunction<ContainerScreenCloseCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterContainerScreenCloseHandlerNative,
        RegisterContainerScreenCloseHandler>('register_container_screen_close_callback');
    register(callback);
  }

  // ===========================================================================
  // Container Menu Slot Callback Registration Methods
  // ===========================================================================

  /// Register a container slot click handler.
  static void registerContainerSlotClickHandler(
      Pointer<NativeFunction<ContainerSlotClickCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterContainerSlotClickHandlerNative,
        RegisterContainerSlotClickHandler>('register_container_slot_click_callback');
    register(callback);
  }

  /// Register a container quick move handler.
  static void registerContainerQuickMoveHandler(
      Pointer<NativeFunction<ContainerQuickMoveCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterContainerQuickMoveHandlerNative,
        RegisterContainerQuickMoveHandler>('register_container_quick_move_callback');
    register(callback);
  }

  /// Register a container may place handler.
  static void registerContainerMayPlaceHandler(
      Pointer<NativeFunction<ContainerMayPlaceCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterContainerMayPlaceHandlerNative,
        RegisterContainerMayPlaceHandler>('register_container_may_place_callback');
    register(callback);
  }

  /// Register a container may pickup handler.
  static void registerContainerMayPickupHandler(
      Pointer<NativeFunction<ContainerMayPickupCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterContainerMayPickupHandlerNative,
        RegisterContainerMayPickupHandler>('register_container_may_pickup_callback');
    register(callback);
  }

  // ===========================================================================
  // Container Item Access APIs (Dart -> Java via C++)
  // ===========================================================================

  /// Get item from container slot.
  /// Returns "itemId:count:damage:maxDamage" or empty string.
  static String getContainerItem(int menuId, int slotIndex) {
    final fn = library.lookupFunction<GetContainerItemNative, GetContainerItem>(
        'dart_get_container_item');
    final result = fn(menuId, slotIndex);
    if (result == nullptr) return '';
    final str = result.toDartString();
    // Free the native string
    _freeNativeString(result);
    return str;
  }

  /// Set item in container slot.
  static void setContainerItem(int menuId, int slotIndex, String itemId, int count) {
    final fn = library.lookupFunction<SetContainerItemNative, SetContainerItemDart>(
        'dart_set_container_item');
    final itemIdPtr = itemId.toNativeUtf8();
    try {
      fn(menuId, slotIndex, itemIdPtr, count);
    } finally {
      calloc.free(itemIdPtr);
    }
  }

  /// Get total slot count for a container menu.
  static int getContainerSlotCount(int menuId) {
    final fn = library.lookupFunction<GetContainerSlotCountNative, GetContainerSlotCount>(
        'dart_get_container_slot_count');
    return fn(menuId);
  }

  /// Clear a container slot.
  static void clearContainerSlot(int menuId, int slotIndex) {
    final fn = library.lookupFunction<ClearContainerSlotNative, ClearContainerSlotDart>(
        'dart_clear_container_slot');
    fn(menuId, slotIndex);
  }

  /// Free a string allocated by native code.
  static void _freeNativeString(Pointer<Utf8> str) {
    final fn = library.lookupFunction<FreeStringNative, FreeStringDart>(
        'dart_free_string');
    fn(str);
  }

  // ===========================================================================
  // Container Opening API (Dart -> Java via C++)
  // ===========================================================================

  /// Open a container for a player.
  ///
  /// [playerId] is the entity ID of the player.
  /// [containerId] is the registered container type ID (e.g., "mymod:diamond_chest").
  ///
  /// Returns true if the container was opened successfully.
  static bool openContainerForPlayer(int playerId, String containerId) {
    final fn = library.lookupFunction<OpenContainerForPlayerNative, OpenContainerForPlayerDart>(
        'dart_open_container_for_player');
    final containerIdPtr = containerId.toNativeUtf8();
    try {
      return fn(playerId, containerIdPtr);
    } finally {
      calloc.free(containerIdPtr);
    }
  }
}
