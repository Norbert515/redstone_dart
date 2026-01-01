/// Event-driven container lifecycle notifications.
///
/// This replaces the polling-based approach for detecting container open/close.
/// Container events are dispatched from Java via JNI when FlutterContainerScreen
/// is initialized or removed.
library;

import 'dart:async';
import 'dart:ffi';

/// Event data for container open.
class ContainerOpenEvent {
  /// The container menu ID.
  final int menuId;

  /// The number of slots in the container.
  final int slotCount;

  ContainerOpenEvent(this.menuId, this.slotCount);

  @override
  String toString() =>
      'ContainerOpenEvent(menuId: $menuId, slotCount: $slotCount)';
}

/// Event stream for container lifecycle events.
///
/// This provides event-driven notifications when containers are opened or closed,
/// replacing the need to poll [ClientContainerView.menuId].
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

  /// Called from native callback when a container opens.
  ///
  /// This is invoked by the FFI callback registered during [initialize].
  static void _onContainerOpen(int menuId, int slotCount) {
    print(
        '[ContainerEvents] Container OPENED: menuId=$menuId, slotCount=$slotCount');
    _openController.add(ContainerOpenEvent(menuId, slotCount));
  }

  /// Called from native callback when a container closes.
  ///
  /// This is invoked by the FFI callback registered during [initialize].
  static void _onContainerClose(int menuId) {
    print('[ContainerEvents] Container CLOSED: menuId=$menuId');
    _closeController.add(menuId);
  }

  /// Pointer to the native open callback function.
  /// Stored as static to prevent garbage collection.
  static Pointer<NativeFunction<_ContainerOpenCallbackNative>>? _openCallbackPtr;

  /// Pointer to the native close callback function.
  /// Stored as static to prevent garbage collection.
  static Pointer<NativeFunction<_ContainerCloseCallbackNative>>?
      _closeCallbackPtr;

  /// Initialize container event callbacks.
  ///
  /// This registers FFI callbacks with the native bridge to receive
  /// container lifecycle events. Should be called during client initialization.
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

    // Create native function pointers from the static methods
    _openCallbackPtr =
        Pointer.fromFunction<_ContainerOpenCallbackNative>(_nativeOnContainerOpen);
    _closeCallbackPtr =
        Pointer.fromFunction<_ContainerCloseCallbackNative>(_nativeOnContainerClose);

    // Register with native bridge
    registerOpenHandler(_openCallbackPtr!);
    registerCloseHandler(_closeCallbackPtr!);

    _initialized = true;
    print('[ContainerEvents] Container event callbacks registered');
  }

  /// Dispose of resources.
  ///
  /// This closes the stream controllers. Call when shutting down.
  static void dispose() {
    _openController.close();
    _closeController.close();
  }
}

// Native callback that bridges to Dart
void _nativeOnContainerOpen(int menuId, int slotCount) {
  ContainerEvents._onContainerOpen(menuId, slotCount);
}

void _nativeOnContainerClose(int menuId) {
  ContainerEvents._onContainerClose(menuId);
}

// Native callback signatures
typedef _ContainerOpenCallbackNative = Void Function(
    Int32 menuId, Int32 slotCount);
typedef _ContainerCloseCallbackNative = Void Function(Int32 menuId);
