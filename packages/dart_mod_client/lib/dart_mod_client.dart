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
