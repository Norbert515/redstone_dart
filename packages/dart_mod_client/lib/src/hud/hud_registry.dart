/// Registry for HUD overlay widgets.
///
/// Provides registration, show/hide, and lifecycle management for HUD overlays.
library;

import 'dart:async';

import 'package:dart_mod_common/src/jni/jni_internal.dart';

import 'hud_events.dart';
import 'hud_overlay.dart';

/// State for an active HUD overlay.
class HudOverlayState {
  /// The overlay identifier.
  final String id;

  /// The overlay widget instance.
  final HudOverlay overlay;

  /// Surface ID if using multi-surface rendering.
  final int? surfaceId;

  HudOverlayState(this.id, this.overlay, [this.surfaceId]);

  @override
  String toString() => 'HudOverlayState(id: $id, surfaceId: $surfaceId)';
}

/// Registry for HUD overlay widgets.
///
/// Mod developers register overlay builders and can show/hide them dynamically.
///
/// Usage:
/// ```dart
/// // Register an overlay during mod initialization
/// HudRegistry.register('mymod:health', () => HealthOverlay());
///
/// // Show/hide overlays (from server commands, keybinds, etc.)
/// HudRegistry.show('mymod:health');
/// HudRegistry.hide('mymod:health');
/// HudRegistry.toggle('mymod:health');
///
/// // Check state
/// if (HudRegistry.isShown('mymod:health')) {
///   print('Health overlay is visible');
/// }
/// ```
class HudRegistry {
  static final Map<String, HudOverlay Function()> _builders = {};
  static final Map<String, HudOverlayState> _activeOverlays = {};

  static bool _initialized = false;
  static StreamSubscription<HudShowEvent>? _showSubscription;
  static StreamSubscription<HudHideEvent>? _hideSubscription;

  /// Initialize the HUD registry.
  ///
  /// Sets up event listeners for show/hide events from Java.
  /// Safe to call multiple times - will only initialize once.
  static void initialize() {
    if (_initialized) return;

    HudEvents.initialize();
    _showSubscription = HudEvents.onShow.listen(_onShow);
    _hideSubscription = HudEvents.onHide.listen(_onHide);

    _initialized = true;
  }

  static void _onShow(HudShowEvent event) {
    final id = event.overlayId;
    if (_activeOverlays.containsKey(id)) return;

    final builder = _builders[id];
    if (builder != null) {
      final overlay = builder();
      _activeOverlays[id] = HudOverlayState(id, overlay);
      print('[HudRegistry] Overlay shown: $id');
    } else {
      print('[HudRegistry] No builder registered for overlay: $id');
    }
  }

  static void _onHide(HudHideEvent event) {
    final id = event.overlayId;
    if (_activeOverlays.remove(id) != null) {
      print('[HudRegistry] Overlay hidden: $id');
    }
  }

  /// Register a HUD overlay builder.
  ///
  /// The builder function is called each time the overlay is shown.
  /// The [id] should be namespaced (e.g., 'mymod:health').
  static void register(String id, HudOverlay Function() builder) {
    _builders[id] = builder;
    print('[HudRegistry] Registered overlay: $id');
  }

  /// Unregister a HUD overlay.
  ///
  /// If the overlay is currently shown, it will be hidden first.
  static void unregister(String id) {
    if (_activeOverlays.containsKey(id)) {
      hide(id);
    }
    _builders.remove(id);
  }

  /// Show a registered HUD overlay.
  ///
  /// Calls Java to show the overlay, which triggers the show event.
  /// Returns the overlay state, or null if not registered.
  static HudOverlayState? show(String id) {
    if (!_builders.containsKey(id)) {
      print('[HudRegistry] Cannot show unregistered overlay: $id');
      return null;
    }

    // Call Java to show the overlay
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridgeClient',
      'showHudOverlay',
      '(Ljava/lang/String;)V',
      [id],
    );

    return _activeOverlays[id];
  }

  /// Hide a HUD overlay.
  ///
  /// Calls Java to hide the overlay, which triggers the hide event.
  static void hide(String id) {
    if (!_activeOverlays.containsKey(id)) return;

    // Call Java to hide the overlay
    GenericJniBridge.callStaticVoidMethod(
      'com/redstone/DartBridgeClient',
      'hideHudOverlay',
      '(Ljava/lang/String;)V',
      [id],
    );
  }

  /// Toggle a HUD overlay.
  ///
  /// Shows the overlay if hidden, hides if shown.
  /// Returns the overlay state if now shown, null if now hidden.
  static HudOverlayState? toggle(String id) {
    if (isShown(id)) {
      hide(id);
      return null;
    } else {
      return show(id);
    }
  }

  /// Check if an overlay is currently shown.
  static bool isShown(String id) => _activeOverlays.containsKey(id);

  /// Check if an overlay is registered (but may not be shown).
  static bool isRegistered(String id) => _builders.containsKey(id);

  /// Get all currently shown overlay IDs.
  static List<String> get shownOverlays => _activeOverlays.keys.toList();

  /// Get all registered overlay IDs.
  static List<String> get registeredOverlays => _builders.keys.toList();

  /// Get the state of a shown overlay.
  ///
  /// Returns null if the overlay is not currently shown.
  static HudOverlayState? getState(String id) => _activeOverlays[id];

  /// Get all active overlay states.
  static List<HudOverlayState> get activeStates => _activeOverlays.values.toList();

  /// Dispose of resources.
  static void dispose() {
    _showSubscription?.cancel();
    _hideSubscription?.cancel();
    _activeOverlays.clear();
    _builders.clear();
    _initialized = false;
  }
}
