/// Event-driven container lifecycle notifications.
///
/// This replaces the polling-based approach for detecting container open/close.
/// Container events are dispatched from Java via JNI when FlutterContainerScreen
/// is initialized or removed.
library;

import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Event data for container open.
class ContainerOpenEvent {
  /// The container menu ID.
  final int menuId;

  /// The number of slots in the container.
  final int slotCount;

  /// The container type ID (e.g., 'mymod:custom_chest').
  ///
  /// May be empty if the container type is unknown or not a DartContainerMenu.
  final String containerId;

  /// The container title.
  ///
  /// May be empty if no title was provided.
  final String title;

  ContainerOpenEvent(this.menuId, this.slotCount, this.containerId, this.title);

  @override
  String toString() =>
      'ContainerOpenEvent(menuId: $menuId, slotCount: $slotCount, containerId: $containerId, title: $title)';
}

/// Event stream for container lifecycle events.
///
/// This provides event-driven notifications when containers are opened or closed,
/// replacing the need to poll [ClientContainerView.menuId].
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
/// ContainerEvents.initialize();
///
/// // Listen for container events
/// ContainerEvents.onOpen.listen((event) {
///   print('Container opened: menuId=${event.menuId}, slots=${event.slotCount}');
/// });
///
/// ContainerEvents.onClose.listen((menuId) {
///   print('Container closed: menuId=$menuId');
/// });
/// ```
class ContainerEvents {
  static final _openController =
      StreamController<ContainerOpenEvent>.broadcast();
  static final _closeController = StreamController<int>.broadcast();

  static bool _initialized = false;

  /// Stream emitting events when containers open.
  ///
  /// The event contains the menu ID and slot count of the opened container.
  static Stream<ContainerOpenEvent> get onOpen => _openController.stream;

  /// Stream emitting the menu ID when containers close.
  static Stream<int> get onClose => _closeController.stream;

  /// NativeCallable for container open events.
  /// Uses .listener() to safely handle calls from any thread.
  static NativeCallable<_ContainerOpenCallbackNative>? _openCallable;

  /// NativeCallable for container close events.
  /// Uses .listener() to safely handle calls from any thread.
  static NativeCallable<_ContainerCloseCallbackNative>? _closeCallable;

  /// Initialize container event callbacks.
  ///
  /// This registers FFI callbacks with the native bridge to receive
  /// container lifecycle events. Should be called during client initialization.
  ///
  /// Uses [NativeCallable.listener] which creates callbacks that can be invoked
  /// from **any thread**. The Dart callback is automatically posted to the
  /// isolate's event loop, making it safe to call from Java's render thread.
  ///
  /// Safe to call multiple times - will only initialize once.
  static void initialize() {
    if (_initialized) return;

    // Get the process library (same pattern as GenericJniBridge)
    final lib = DynamicLibrary.process();

    // Lookup the registration functions directly
    final registerOpenHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ContainerOpenCallbackNative>>),
        void Function(Pointer<NativeFunction<_ContainerOpenCallbackNative>>)>(
      'client_register_container_open_handler',
    );

    final registerCloseHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_ContainerCloseCallbackNative>>),
        void Function(Pointer<NativeFunction<_ContainerCloseCallbackNative>>)>(
      'client_register_container_close_handler',
    );

    // Create NativeCallable.listener - these are safe to call from ANY thread
    // The Dart VM will automatically post the callback to our isolate's event loop
    _openCallable = NativeCallable<_ContainerOpenCallbackNative>.listener(
      (int menuId, int slotCount, Pointer<Utf8> containerIdPtr,
          Pointer<Utf8> titlePtr) {
        // Read strings from malloc'd pointers (native code allocated them)
        String containerId = '';
        String title = '';

        if (containerIdPtr.address != 0) {
          containerId = containerIdPtr.toDartString();
          // Free the malloc'd string
          malloc.free(containerIdPtr);
        }

        if (titlePtr.address != 0) {
          title = titlePtr.toDartString();
          // Free the malloc'd string
          malloc.free(titlePtr);
        }

        print('[ContainerEvents] Container OPENED: menuId=$menuId, '
            'slotCount=$slotCount, containerId=$containerId, title=$title');
        _openController
            .add(ContainerOpenEvent(menuId, slotCount, containerId, title));
      },
    );

    _closeCallable = NativeCallable<_ContainerCloseCallbackNative>.listener(
      (int menuId) {
        print('[ContainerEvents] Container CLOSED: menuId=$menuId');
        _closeController.add(menuId);
      },
    );

    // Register with native bridge
    registerOpenHandler(_openCallable!.nativeFunction);
    registerCloseHandler(_closeCallable!.nativeFunction);

    _initialized = true;
    print('[ContainerEvents] Container event callbacks registered');
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
typedef _ContainerOpenCallbackNative = Void Function(
    Int32 menuId, Int32 slotCount, Pointer<Utf8> containerId, Pointer<Utf8> title);
typedef _ContainerCloseCallbackNative = Void Function(Int32 menuId);
