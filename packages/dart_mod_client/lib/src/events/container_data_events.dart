/// Event-driven container data change notifications.
///
/// This provides push-based data synchronization for container data (progress bars,
/// furnace burn time, etc.). When Java's ContainerData changes, it calls the native
/// bridge which dispatches to this handler. No more polling!
library;

import 'dart:async';
import 'dart:ffi';

/// Event emitted when container data changes.
///
/// Container data is used for things like furnace progress bars, brewing stand
/// fuel levels, and other numeric values that need to be synchronized from
/// server to client.
class ContainerDataChangedEvent {
  /// The menu ID of the container.
  final int menuId;

  /// The data slot index (e.g., 0 for burn time, 1 for cook progress).
  final int slotIndex;

  /// The new value.
  final int value;

  ContainerDataChangedEvent({
    required this.menuId,
    required this.slotIndex,
    required this.value,
  });

  @override
  String toString() =>
      'ContainerDataChangedEvent(menuId: $menuId, slotIndex: $slotIndex, value: $value)';
}

/// Event stream for container data change events.
///
/// This provides push-based notifications when container data changes,
/// eliminating the need to poll for data updates.
///
/// Uses [NativeCallable.listener] to safely receive callbacks from native code
/// on any thread. The callbacks are automatically posted to the Dart isolate's
/// event loop, avoiding the "Cannot invoke native callback outside an isolate" error.
///
/// Usage:
/// ```dart
/// // Initialize once during client setup
/// ContainerDataEvents.initialize();
///
/// // Listen for data changes
/// ContainerDataEvents.onDataChanged.listen((event) {
///   print('Data changed: slot=${event.slotIndex}, value=${event.value}');
///   // Update UI based on new values
/// });
/// ```
class ContainerDataEvents {
  static final _controller =
      StreamController<ContainerDataChangedEvent>.broadcast();

  static bool _initialized = false;

  /// Stream emitting events when container data changes.
  ///
  /// The event contains the menu ID, slot index, and new value.
  static Stream<ContainerDataChangedEvent> get onDataChanged =>
      _controller.stream;

  /// NativeCallable for data change events.
  /// Uses .listener() to safely handle calls from any thread.
  static NativeCallable<_ContainerDataChangedCallbackNative>? _callable;

  /// Initialize container data event callbacks.
  ///
  /// This registers FFI callbacks with the native bridge to receive
  /// container data change events. Should be called during client initialization.
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

    // Lookup the registration function
    final registerHandler = lib.lookupFunction<
        Void Function(
            Pointer<NativeFunction<_ContainerDataChangedCallbackNative>>),
        void Function(
            Pointer<NativeFunction<_ContainerDataChangedCallbackNative>>)>(
      'client_register_container_data_changed_handler',
    );

    // Create NativeCallable.listener - safe to call from ANY thread
    // The Dart VM will automatically post the callback to our isolate's event loop
    _callable = NativeCallable<_ContainerDataChangedCallbackNative>.listener(
      (int menuId, int slotIndex, int value) {
        _controller.add(ContainerDataChangedEvent(
          menuId: menuId,
          slotIndex: slotIndex,
          value: value,
        ));
      },
    );

    // Register with native bridge
    registerHandler(_callable!.nativeFunction);

    _initialized = true;
  }

  /// Dispose of resources.
  ///
  /// This closes the stream controller and NativeCallable handle.
  /// Call when shutting down.
  static void dispose() {
    _callable?.close();
    _controller.close();
  }
}

// Native callback signature: void (*)(int32_t menu_id, int32_t slot_index, int32_t value)
typedef _ContainerDataChangedCallbackNative = Void Function(
    Int32 menuId, Int32 slotIndex, Int32 value);
