/// Shared types between client and server.
///
/// This package contains types that need to be shared between the
/// client and server packages, such as:
/// - Custom packet definitions
/// - Shared data models
/// - Constants
library;

// Re-export common types that both client and server might need
export 'package:dart_mod_common/dart_mod_common.dart' show BlockPos, Vec3;

// Container definitions shared between client and server
export 'src/simple_furnace_container.dart';
