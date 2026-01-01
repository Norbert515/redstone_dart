/// Client-side Dart Minecraft mod runtime with Flutter integration.
///
/// This package provides the client-side implementation for Dart Minecraft mods.
/// It uses the Flutter Embedder for GUI rendering and FFI to communicate with
/// the native client bridge.
library;

// Re-export common types
export 'package:dart_mod_common/dart_mod_common.dart';

// Client-specific exports
export 'src/bridge.dart' show ClientBridge;
export 'src/screens.dart';
export 'src/widgets.dart';
export 'src/network.dart';
export 'src/gui/gui.dart';
export 'src/inventory/client_container_view.dart';
export 'src/events/container_events.dart';
