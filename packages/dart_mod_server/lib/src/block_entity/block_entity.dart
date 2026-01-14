/// Block entity server-side support.
///
/// This module provides the server-side implementation for Dart-defined block entities.
library;

export 'block_entity_registry.dart';
// Note: initBlockEntityCallbacks is now called automatically by Bridge.initialize()
// so it's no longer exported in the public API
export 'block_entity_jni.dart';
