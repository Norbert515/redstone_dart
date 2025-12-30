/// Server-side Dart Minecraft mod runtime.
///
/// This package provides the server-side implementation for Dart Minecraft mods.
/// It uses FFI to communicate with the native server bridge.
library;

// Re-export common types
export 'package:dart_mod_common/dart_mod_common.dart';

// Server-specific exports
export 'src/bridge.dart' show ServerBridge;
export 'src/registries.dart';
export 'src/events.dart';
export 'src/world_access.dart';
export 'src/network.dart';
