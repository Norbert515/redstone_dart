/// Client-side FFI bridge to native client code.
library;

// ignore_for_file: unused_field

import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:ffi/ffi.dart';

/// FFI bindings to the client-side native bridge.
///
/// This class provides the FFI interface to dart_bridge_client native functions.
/// The client bridge uses the Flutter Embedder for GUI rendering.
class ClientBridge {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  /// Initialize the client bridge with the native library.
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

  static late final _DartClientInit _dartClientInit;
  static late final _DartClientShutdown _dartClientShutdown;
  static late final _DartClientProcessTasks _dartClientProcessTasks;
  static late final _DartClientSetJvm _dartClientSetJvm;
  static late final _DartClientSetFrameCallback _dartClientSetFrameCallback;
  static late final _DartClientGetServiceUrl _dartClientGetServiceUrl;

  // Window/Input functions
  static late final _DartClientSendWindowMetrics _dartClientSendWindowMetrics;
  static late final _DartClientSendPointerEvent _dartClientSendPointerEvent;
  static late final _DartClientSendKeyEvent _dartClientSendKeyEvent;

  // Callback registration functions
  static late final _ClientRegisterScreenInitHandler _clientRegisterScreenInitHandler;
  static late final _ClientRegisterScreenTickHandler _clientRegisterScreenTickHandler;
  static late final _ClientRegisterScreenRenderHandler _clientRegisterScreenRenderHandler;
  static late final _ClientRegisterScreenCloseHandler _clientRegisterScreenCloseHandler;
  static late final _ClientRegisterScreenKeyPressedHandler _clientRegisterScreenKeyPressedHandler;
  static late final _ClientRegisterScreenKeyReleasedHandler _clientRegisterScreenKeyReleasedHandler;
  static late final _ClientRegisterScreenCharTypedHandler _clientRegisterScreenCharTypedHandler;
  static late final _ClientRegisterScreenMouseClickedHandler _clientRegisterScreenMouseClickedHandler;
  static late final _ClientRegisterScreenMouseReleasedHandler _clientRegisterScreenMouseReleasedHandler;
  static late final _ClientRegisterScreenMouseDraggedHandler _clientRegisterScreenMouseDraggedHandler;
  static late final _ClientRegisterScreenMouseScrolledHandler _clientRegisterScreenMouseScrolledHandler;

  static late final _ClientRegisterWidgetPressedHandler _clientRegisterWidgetPressedHandler;
  static late final _ClientRegisterWidgetTextChangedHandler _clientRegisterWidgetTextChangedHandler;

  static late final _ClientRegisterContainerScreenInitHandler _clientRegisterContainerScreenInitHandler;
  static late final _ClientRegisterContainerScreenRenderBgHandler _clientRegisterContainerScreenRenderBgHandler;
  static late final _ClientRegisterContainerScreenCloseHandler _clientRegisterContainerScreenCloseHandler;

  static late final _ClientRegisterContainerSlotClickHandler _clientRegisterContainerSlotClickHandler;
  static late final _ClientRegisterContainerQuickMoveHandler _clientRegisterContainerQuickMoveHandler;
  static late final _ClientRegisterContainerMayPlaceHandler _clientRegisterContainerMayPlaceHandler;
  static late final _ClientRegisterContainerMayPickupHandler _clientRegisterContainerMayPickupHandler;

  // Slot position update function
  static late final _ClientUpdateSlotPositions _clientUpdateSlotPositions;

  // Container lifecycle event callback registration
  static late final _ClientRegisterContainerOpenHandler _clientRegisterContainerOpenHandler;
  static late final _ClientRegisterContainerCloseHandler _clientRegisterContainerCloseHandler;

  static void _bindFunctions() {
    final lib = _lib!;

    // Lifecycle functions
    _dartClientInit = lib.lookupFunction<
        Bool Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>),
        bool Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>('dart_client_init');

    _dartClientShutdown =
        lib.lookupFunction<Void Function(), void Function()>('dart_client_shutdown');

    _dartClientProcessTasks =
        lib.lookupFunction<Void Function(), void Function()>('dart_client_process_tasks');

    _dartClientSetJvm = lib.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('dart_client_set_jvm');

    _dartClientSetFrameCallback = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_FrameCallbackNative>>),
        void Function(Pointer<NativeFunction<_FrameCallbackNative>>)>('dart_client_set_frame_callback');

    _dartClientGetServiceUrl = lib.lookupFunction<
        Pointer<Utf8> Function(),
        Pointer<Utf8> Function()>('dart_client_get_service_url');

    // Window/Input functions
    _dartClientSendWindowMetrics = lib.lookupFunction<
        Void Function(Int32, Int32, Double),
        void Function(int, int, double)>('dart_client_send_window_metrics');

    _dartClientSendPointerEvent = lib.lookupFunction<
        Void Function(Int32, Double, Double, Int64),
        void Function(int, double, double, int)>('dart_client_send_pointer_event');

    _dartClientSendKeyEvent = lib.lookupFunction<
        Void Function(Int32, Int64, Int64, Pointer<Utf8>, Int32),
        void Function(int, int, int, Pointer<Utf8>, int)>('dart_client_send_key_event');

    // Screen callback registration
    _clientRegisterScreenInitHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenInitCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenInitCallbackNative>>)>('client_register_screen_init_handler');

    _clientRegisterScreenTickHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenTickCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenTickCallbackNative>>)>('client_register_screen_tick_handler');

    _clientRegisterScreenRenderHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenRenderCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenRenderCallbackNative>>)>('client_register_screen_render_handler');

    _clientRegisterScreenCloseHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenCloseCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenCloseCallbackNative>>)>('client_register_screen_close_handler');

    _clientRegisterScreenKeyPressedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenKeyPressedCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenKeyPressedCallbackNative>>)>('client_register_screen_key_pressed_handler');

    _clientRegisterScreenKeyReleasedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenKeyReleasedCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenKeyReleasedCallbackNative>>)>('client_register_screen_key_released_handler');

    _clientRegisterScreenCharTypedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenCharTypedCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenCharTypedCallbackNative>>)>('client_register_screen_char_typed_handler');

    _clientRegisterScreenMouseClickedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenMouseClickedCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenMouseClickedCallbackNative>>)>('client_register_screen_mouse_clicked_handler');

    _clientRegisterScreenMouseReleasedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenMouseReleasedCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenMouseReleasedCallbackNative>>)>('client_register_screen_mouse_released_handler');

    _clientRegisterScreenMouseDraggedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenMouseDraggedCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenMouseDraggedCallbackNative>>)>('client_register_screen_mouse_dragged_handler');

    _clientRegisterScreenMouseScrolledHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenMouseScrolledCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenMouseScrolledCallbackNative>>)>('client_register_screen_mouse_scrolled_handler');

    // Widget callback registration
    _clientRegisterWidgetPressedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_WidgetPressedCallbackNative>>),
        void Function(Pointer<NativeFunction<_WidgetPressedCallbackNative>>)>('client_register_widget_pressed_handler');

    _clientRegisterWidgetTextChangedHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_WidgetTextChangedCallbackNative>>),
        void Function(Pointer<NativeFunction<_WidgetTextChangedCallbackNative>>)>('client_register_widget_text_changed_handler');

    // Container screen callback registration
    _clientRegisterContainerScreenInitHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ContainerScreenInitCallbackNative>>),
        void Function(Pointer<NativeFunction<_ContainerScreenInitCallbackNative>>)>('client_register_container_screen_init_handler');

    _clientRegisterContainerScreenRenderBgHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ContainerScreenRenderBgCallbackNative>>),
        void Function(Pointer<NativeFunction<_ContainerScreenRenderBgCallbackNative>>)>('client_register_container_screen_render_bg_handler');

    _clientRegisterContainerScreenCloseHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ContainerScreenCloseCallbackNative>>),
        void Function(Pointer<NativeFunction<_ContainerScreenCloseCallbackNative>>)>('client_register_container_screen_close_handler');

    // Container menu callback registration
    _clientRegisterContainerSlotClickHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ContainerSlotClickCallbackNative>>),
        void Function(Pointer<NativeFunction<_ContainerSlotClickCallbackNative>>)>('client_register_container_slot_click_handler');

    _clientRegisterContainerQuickMoveHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ContainerQuickMoveCallbackNative>>),
        void Function(Pointer<NativeFunction<_ContainerQuickMoveCallbackNative>>)>('client_register_container_quick_move_handler');

    _clientRegisterContainerMayPlaceHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ContainerMayPlaceCallbackNative>>),
        void Function(Pointer<NativeFunction<_ContainerMayPlaceCallbackNative>>)>('client_register_container_may_place_handler');

    _clientRegisterContainerMayPickupHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ContainerMayPickupCallbackNative>>),
        void Function(Pointer<NativeFunction<_ContainerMayPickupCallbackNative>>)>('client_register_container_may_pickup_handler');

    // Slot position update function
    _clientUpdateSlotPositions = lib.lookupFunction<
        Void Function(Int32, Pointer<Int32>, Int32),
        void Function(int, Pointer<Int32>, int)>('client_update_slot_positions');

    // Container lifecycle event callback registration
    _clientRegisterContainerOpenHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ContainerOpenCallbackNative>>),
        void Function(Pointer<NativeFunction<_ContainerOpenCallbackNative>>)>('client_register_container_open_handler');

    _clientRegisterContainerCloseHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ContainerCloseCallbackNative>>),
        void Function(Pointer<NativeFunction<_ContainerCloseCallbackNative>>)>('client_register_container_close_handler');
  }

  // ==========================================================================
  // Public API
  // ==========================================================================

  /// Initialize the Flutter engine for client-side rendering.
  static bool clientInit(String assetsPath, String icuDataPath, String? aotLibraryPath) {
    final assetsPathPtr = assetsPath.toNativeUtf8();
    final icuDataPathPtr = icuDataPath.toNativeUtf8();
    final aotLibraryPathPtr = aotLibraryPath?.toNativeUtf8() ?? nullptr;

    try {
      return _dartClientInit(assetsPathPtr, icuDataPathPtr, aotLibraryPathPtr);
    } finally {
      calloc.free(assetsPathPtr);
      calloc.free(icuDataPathPtr);
      if (aotLibraryPath != null) calloc.free(aotLibraryPathPtr);
    }
  }

  /// Shutdown the Flutter engine.
  static void clientShutdown() {
    _dartClientShutdown();
  }

  /// Process pending Flutter tasks.
  static void processTasks() {
    _dartClientProcessTasks();
  }

  /// Set JVM reference for JNI callbacks.
  static void clientSetJvm(Pointer<Void> jvm) {
    _dartClientSetJvm(jvm);
  }

  /// Set the frame callback for receiving rendered frames.
  static void setFrameCallback(Pointer<NativeFunction<_FrameCallbackNative>> callback) {
    _dartClientSetFrameCallback(callback);
  }

  /// Get the Dart VM service URL for hot reload/debugging.
  static String? getServiceUrl() {
    final ptr = _dartClientGetServiceUrl();
    if (ptr == nullptr) return null;
    return ptr.toDartString();
  }

  /// Send window size change to Flutter.
  static void sendWindowMetrics(int width, int height, double pixelRatio) {
    _dartClientSendWindowMetrics(width, height, pixelRatio);
  }

  /// Send pointer/mouse event to Flutter.
  static void sendPointerEvent(int phase, double x, double y, int buttons) {
    _dartClientSendPointerEvent(phase, x, y, buttons);
  }

  /// Send keyboard event to Flutter.
  static void sendKeyEvent(int type, int physicalKey, int logicalKey, String? characters, int modifiers) {
    final charactersPtr = characters?.toNativeUtf8() ?? nullptr;
    try {
      _dartClientSendKeyEvent(type, physicalKey, logicalKey, charactersPtr, modifiers);
    } finally {
      if (characters != null) calloc.free(charactersPtr);
    }
  }

  /// Update slot positions for a container menu.
  ///
  /// Sends the positions of inventory slots to the native side so Java can
  /// render Minecraft items on top of Flutter UI.
  ///
  /// [menuId] is the container menu identifier.
  /// [positions] maps slot indices to their screen-space rectangles (in physical pixels).
  static void updateSlotPositions(int menuId, Map<int, Rect> positions) {
    if (positions.isEmpty) {
      // Send empty array to clear positions
      final emptyPtr = calloc<Int32>(0);
      try {
        _clientUpdateSlotPositions(menuId, emptyPtr, 0);
      } finally {
        calloc.free(emptyPtr);
      }
      return;
    }

    // Format: [slotIndex, x, y, width, height, ...]
    // Each slot takes 5 integers
    final dataLength = positions.length * 5;
    final data = Int32List(dataLength);

    var i = 0;
    for (final entry in positions.entries) {
      data[i] = entry.key; // slotIndex
      data[i + 1] = entry.value.left.round(); // x
      data[i + 2] = entry.value.top.round(); // y
      data[i + 3] = entry.value.width.round(); // width
      data[i + 4] = entry.value.height.round(); // height
      i += 5;
    }

    // Allocate native memory and copy data
    final dataPtr = calloc<Int32>(dataLength);
    try {
      for (var j = 0; j < dataLength; j++) {
        dataPtr[j] = data[j];
      }
      _clientUpdateSlotPositions(menuId, dataPtr, dataLength);
    } finally {
      calloc.free(dataPtr);
    }
  }

  /// Register container open callback.
  ///
  /// The callback is invoked when a container screen is opened.
  static void registerContainerOpenHandler(Pointer<NativeFunction<_ContainerOpenCallbackNative>> callback) {
    _clientRegisterContainerOpenHandler(callback);
  }

  /// Register container close callback.
  ///
  /// The callback is invoked when a container screen is closed.
  static void registerContainerCloseHandler(Pointer<NativeFunction<_ContainerCloseCallbackNative>> callback) {
    _clientRegisterContainerCloseHandler(callback);
  }
}

// ==========================================================================
// Native callback type definitions
// ==========================================================================

typedef _DartClientInit = bool Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _DartClientShutdown = void Function();
typedef _DartClientProcessTasks = void Function();
typedef _DartClientSetJvm = void Function(Pointer<Void>);
typedef _DartClientSetFrameCallback = void Function(Pointer<NativeFunction<_FrameCallbackNative>>);
typedef _DartClientGetServiceUrl = Pointer<Utf8> Function();
typedef _DartClientSendWindowMetrics = void Function(int, int, double);
typedef _DartClientSendPointerEvent = void Function(int, double, double, int);
typedef _DartClientSendKeyEvent = void Function(int, int, int, Pointer<Utf8>, int);

// Callback registration typedefs
typedef _ClientRegisterScreenInitHandler = void Function(Pointer<NativeFunction<_ScreenInitCallbackNative>>);
typedef _ClientRegisterScreenTickHandler = void Function(Pointer<NativeFunction<_ScreenTickCallbackNative>>);
typedef _ClientRegisterScreenRenderHandler = void Function(Pointer<NativeFunction<_ScreenRenderCallbackNative>>);
typedef _ClientRegisterScreenCloseHandler = void Function(Pointer<NativeFunction<_ScreenCloseCallbackNative>>);
typedef _ClientRegisterScreenKeyPressedHandler = void Function(Pointer<NativeFunction<_ScreenKeyPressedCallbackNative>>);
typedef _ClientRegisterScreenKeyReleasedHandler = void Function(Pointer<NativeFunction<_ScreenKeyReleasedCallbackNative>>);
typedef _ClientRegisterScreenCharTypedHandler = void Function(Pointer<NativeFunction<_ScreenCharTypedCallbackNative>>);
typedef _ClientRegisterScreenMouseClickedHandler = void Function(Pointer<NativeFunction<_ScreenMouseClickedCallbackNative>>);
typedef _ClientRegisterScreenMouseReleasedHandler = void Function(Pointer<NativeFunction<_ScreenMouseReleasedCallbackNative>>);
typedef _ClientRegisterScreenMouseDraggedHandler = void Function(Pointer<NativeFunction<_ScreenMouseDraggedCallbackNative>>);
typedef _ClientRegisterScreenMouseScrolledHandler = void Function(Pointer<NativeFunction<_ScreenMouseScrolledCallbackNative>>);
typedef _ClientRegisterWidgetPressedHandler = void Function(Pointer<NativeFunction<_WidgetPressedCallbackNative>>);
typedef _ClientRegisterWidgetTextChangedHandler = void Function(Pointer<NativeFunction<_WidgetTextChangedCallbackNative>>);
typedef _ClientRegisterContainerScreenInitHandler = void Function(Pointer<NativeFunction<_ContainerScreenInitCallbackNative>>);
typedef _ClientRegisterContainerScreenRenderBgHandler = void Function(Pointer<NativeFunction<_ContainerScreenRenderBgCallbackNative>>);
typedef _ClientRegisterContainerScreenCloseHandler = void Function(Pointer<NativeFunction<_ContainerScreenCloseCallbackNative>>);
typedef _ClientRegisterContainerSlotClickHandler = void Function(Pointer<NativeFunction<_ContainerSlotClickCallbackNative>>);
typedef _ClientRegisterContainerQuickMoveHandler = void Function(Pointer<NativeFunction<_ContainerQuickMoveCallbackNative>>);
typedef _ClientRegisterContainerMayPlaceHandler = void Function(Pointer<NativeFunction<_ContainerMayPlaceCallbackNative>>);
typedef _ClientRegisterContainerMayPickupHandler = void Function(Pointer<NativeFunction<_ContainerMayPickupCallbackNative>>);
typedef _ClientUpdateSlotPositions = void Function(int, Pointer<Int32>, int);

// Native callback signatures
typedef _FrameCallbackNative = Void Function(Pointer<Void>, Size, Size, Size);
typedef _ScreenInitCallbackNative = Void Function(Int64, Int32, Int32);
typedef _ScreenTickCallbackNative = Void Function(Int64);
typedef _ScreenRenderCallbackNative = Void Function(Int64, Int32, Int32, Float);
typedef _ScreenCloseCallbackNative = Void Function(Int64);
typedef _ScreenKeyPressedCallbackNative = Bool Function(Int64, Int32, Int32, Int32);
typedef _ScreenKeyReleasedCallbackNative = Bool Function(Int64, Int32, Int32, Int32);
typedef _ScreenCharTypedCallbackNative = Bool Function(Int64, Int32, Int32);
typedef _ScreenMouseClickedCallbackNative = Bool Function(Int64, Double, Double, Int32);
typedef _ScreenMouseReleasedCallbackNative = Bool Function(Int64, Double, Double, Int32);
typedef _ScreenMouseDraggedCallbackNative = Bool Function(Int64, Double, Double, Int32, Double, Double);
typedef _ScreenMouseScrolledCallbackNative = Bool Function(Int64, Double, Double, Double, Double);
typedef _WidgetPressedCallbackNative = Void Function(Int64, Int64);
typedef _WidgetTextChangedCallbackNative = Void Function(Int64, Int64, Pointer<Utf8>);
typedef _ContainerScreenInitCallbackNative = Void Function(Int64, Int32, Int32, Int32, Int32, Int32, Int32);
typedef _ContainerScreenRenderBgCallbackNative = Void Function(Int64, Int32, Int32, Float, Int32, Int32);
typedef _ContainerScreenCloseCallbackNative = Void Function(Int64);
typedef _ContainerSlotClickCallbackNative = Int32 Function(Int64, Int32, Int32, Int32, Pointer<Utf8>);
typedef _ContainerQuickMoveCallbackNative = Pointer<Utf8> Function(Int64, Int32);
typedef _ContainerMayPlaceCallbackNative = Bool Function(Int64, Int32, Pointer<Utf8>);
typedef _ContainerMayPickupCallbackNative = Bool Function(Int64, Int32);

// Container lifecycle event callback signatures
typedef _ContainerOpenCallbackNative = Void Function(Int32, Int32);
typedef _ContainerCloseCallbackNative = Void Function(Int32);

// Callback registration typedefs
typedef _ClientRegisterContainerOpenHandler = void Function(Pointer<NativeFunction<_ContainerOpenCallbackNative>>);
typedef _ClientRegisterContainerCloseHandler = void Function(Pointer<NativeFunction<_ContainerCloseCallbackNative>>);
