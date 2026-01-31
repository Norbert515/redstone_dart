/// Event-driven custom screen lifecycle notifications.
///
/// This provides event-driven notifications when custom screens are opened or closed.
/// Screen events are dispatched from Java via FFI when FlutterCustomScreen
/// is initialized or removed.
library;

import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Event data for screen open.
class ScreenOpenEvent {
  /// Unique screen ID for this instance.
  final int screenId;

  /// Screen type identifier (e.g., 'mymod:settings').
  final String screenType;

  /// Screen width in GUI coordinates.
  final int width;

  /// Screen height in GUI coordinates.
  final int height;

  ScreenOpenEvent(this.screenId, this.screenType, this.width, this.height);

  @override
  String toString() =>
      'ScreenOpenEvent(screenId: $screenId, type: $screenType, ${width}x$height)';
}

/// Event data for screen close.
class ScreenCloseEvent {
  /// The screen instance ID that was closed.
  final int screenId;

  ScreenCloseEvent(this.screenId);

  @override
  String toString() => 'ScreenCloseEvent(screenId: $screenId)';
}

/// Event stream for custom screen lifecycle events.
///
/// This provides event-driven notifications when custom screens are opened or closed.
///
/// Uses [NativeCallable.listener] to safely receive callbacks from native code
/// on any thread. The callbacks are automatically posted to the Dart isolate's
/// event loop, avoiding the "Cannot invoke native callback outside an isolate" error.
///
/// String pointers passed from native code are malloc'd and must be freed after reading.
///
/// Usage:
/// ```dart
/// // Initialize once during client setup
/// ScreenEvents.initialize();
///
/// // Listen for screen events
/// ScreenEvents.onOpen.listen((event) {
///   print('Screen opened: screenId=${event.screenId}, type=${event.screenType}');
/// });
///
/// ScreenEvents.onClose.listen((event) {
///   print('Screen closed: screenId=${event.screenId}');
/// });
/// ```
class ScreenEvents {
  static final _openController =
      StreamController<ScreenOpenEvent>.broadcast();
  static final _closeController =
      StreamController<ScreenCloseEvent>.broadcast();

  static bool _initialized = false;

  /// Stream emitting events when custom screens open.
  ///
  /// The event contains the screen ID, type, and dimensions.
  static Stream<ScreenOpenEvent> get onOpen => _openController.stream;

  /// Stream emitting events when custom screens close.
  static Stream<ScreenCloseEvent> get onClose => _closeController.stream;

  /// NativeCallable for screen open events.
  /// Uses .listener() to safely handle calls from any thread.
  static NativeCallable<_ScreenOpenCallbackNative>? _openCallable;

  /// NativeCallable for screen close events.
  /// Uses .listener() to safely handle calls from any thread.
  static NativeCallable<_ScreenCloseCallbackNative>? _closeCallable;

  /// Initialize screen event callbacks.
  ///
  /// This registers FFI callbacks with the native bridge to receive
  /// screen lifecycle events. Should be called during client initialization.
  ///
  /// Uses [NativeCallable.listener] which creates callbacks that can be invoked
  /// from **any thread**. The Dart callback is automatically posted to the
  /// isolate's event loop, making it safe to call from Java's render thread.
  ///
  /// Safe to call multiple times - will only initialize once.
  static void initialize() {
    if (_initialized) return;

    // Get the process library (same pattern as ContainerEvents)
    final lib = DynamicLibrary.process();

    // Lookup the registration functions directly
    final registerOpenHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenOpenCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenOpenCallbackNative>>)>(
      'client_register_custom_screen_open_handler',
    );

    final registerCloseHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ScreenCloseCallbackNative>>),
        void Function(Pointer<NativeFunction<_ScreenCloseCallbackNative>>)>(
      'client_register_custom_screen_close_handler',
    );

    // Create NativeCallable.listener - these are safe to call from ANY thread
    // The Dart VM will automatically post the callback to our isolate's event loop
    _openCallable = NativeCallable<_ScreenOpenCallbackNative>.listener(
      (int screenId, Pointer<Utf8> screenTypePtr, int width, int height) {
        // Read string from malloc'd pointer (native code allocated it)
        String screenType = '';

        if (screenTypePtr.address != 0) {
          screenType = screenTypePtr.toDartString();
          // Free the malloc'd string
          malloc.free(screenTypePtr);
        }

        _openController.add(ScreenOpenEvent(screenId, screenType, width, height));
      },
    );

    _closeCallable = NativeCallable<_ScreenCloseCallbackNative>.listener(
      (int screenId) {
        _closeController.add(ScreenCloseEvent(screenId));
      },
    );

    // Register with native bridge
    registerOpenHandler(_openCallable!.nativeFunction);
    registerCloseHandler(_closeCallable!.nativeFunction);

    _initialized = true;
  }

  /// Dispose of resources.
  ///
  /// This closes the stream controllers and NativeCallable handles.
  /// Call when shutting down.
  static void dispose() {
    _openCallable?.close();
    _closeCallable?.close();
    _openController.close();
    _closeController.close();
  }
}

// Native callback signatures
typedef _ScreenOpenCallbackNative = Void Function(
    Int32 screenId, Pointer<Utf8> screenType, Int32 width, Int32 height);
typedef _ScreenCloseCallbackNative = Void Function(Int32 screenId);
