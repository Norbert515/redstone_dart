/// Event-driven HUD overlay lifecycle notifications.
///
/// This provides event-driven notifications when HUD overlays are shown or hidden.
/// HUD events are dispatched from Java via FFI when overlays are activated/deactivated.
library;

import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Event data for HUD overlay show.
class HudShowEvent {
  /// The overlay identifier (e.g., 'mymod:health').
  final String overlayId;

  HudShowEvent(this.overlayId);

  @override
  String toString() => 'HudShowEvent(overlayId: $overlayId)';
}

/// Event data for HUD overlay hide.
class HudHideEvent {
  /// The overlay identifier that was hidden.
  final String overlayId;

  HudHideEvent(this.overlayId);

  @override
  String toString() => 'HudHideEvent(overlayId: $overlayId)';
}

/// Event stream for HUD overlay lifecycle events.
///
/// This provides event-driven notifications when HUD overlays are shown or hidden.
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
/// HudEvents.initialize();
///
/// // Listen for HUD events
/// HudEvents.onShow.listen((event) {
///   print('HUD overlay shown: ${event.overlayId}');
/// });
///
/// HudEvents.onHide.listen((event) {
///   print('HUD overlay hidden: ${event.overlayId}');
/// });
/// ```
class HudEvents {
  static final _showController = StreamController<HudShowEvent>.broadcast();
  static final _hideController = StreamController<HudHideEvent>.broadcast();

  static bool _initialized = false;

  /// Stream emitting events when HUD overlays are shown.
  static Stream<HudShowEvent> get onShow => _showController.stream;

  /// Stream emitting events when HUD overlays are hidden.
  static Stream<HudHideEvent> get onHide => _hideController.stream;

  /// NativeCallable for HUD show events.
  /// Uses .listener() to safely handle calls from any thread.
  static NativeCallable<_HudShowCallbackNative>? _showCallable;

  /// NativeCallable for HUD hide events.
  /// Uses .listener() to safely handle calls from any thread.
  static NativeCallable<_HudHideCallbackNative>? _hideCallable;

  /// Initialize HUD event callbacks.
  ///
  /// This registers FFI callbacks with the native bridge to receive
  /// HUD lifecycle events. Should be called during client initialization.
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
    final registerShowHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_HudShowCallbackNative>>),
        void Function(Pointer<NativeFunction<_HudShowCallbackNative>>)>(
      'client_register_hud_show_handler',
    );

    final registerHideHandler = lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_HudHideCallbackNative>>),
        void Function(Pointer<NativeFunction<_HudHideCallbackNative>>)>(
      'client_register_hud_hide_handler',
    );

    // Create NativeCallable.listener - these are safe to call from ANY thread
    // The Dart VM will automatically post the callback to our isolate's event loop
    _showCallable = NativeCallable<_HudShowCallbackNative>.listener(
      (Pointer<Utf8> overlayIdPtr) {
        // Read string from malloc'd pointer (native code allocated it)
        String overlayId = '';

        if (overlayIdPtr.address != 0) {
          overlayId = overlayIdPtr.toDartString();
          // Free the malloc'd string
          malloc.free(overlayIdPtr);
        }

        _showController.add(HudShowEvent(overlayId));
      },
    );

    _hideCallable = NativeCallable<_HudHideCallbackNative>.listener(
      (Pointer<Utf8> overlayIdPtr) {
        // Read string from malloc'd pointer (native code allocated it)
        String overlayId = '';

        if (overlayIdPtr.address != 0) {
          overlayId = overlayIdPtr.toDartString();
          // Free the malloc'd string
          malloc.free(overlayIdPtr);
        }

        _hideController.add(HudHideEvent(overlayId));
      },
    );

    // Register with native bridge
    registerShowHandler(_showCallable!.nativeFunction);
    registerHideHandler(_hideCallable!.nativeFunction);

    _initialized = true;
  }

  /// Dispose of resources.
  ///
  /// This closes the stream controllers and NativeCallable handles.
  /// Call when shutting down.
  static void dispose() {
    _showCallable?.close();
    _hideCallable?.close();
    _showController.close();
    _hideController.close();
  }
}

// Native callback signatures
typedef _HudShowCallbackNative = Void Function(Pointer<Utf8> overlayId);
typedef _HudHideCallbackNative = Void Function(Pointer<Utf8> overlayId);
