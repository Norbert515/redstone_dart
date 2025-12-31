/// Server-side Dart Minecraft mod runtime.
///
/// This package provides the server-side implementation for Dart Minecraft mods.
/// It uses FFI to communicate with the native server bridge.
library;

// Re-export common types, hiding server-specific overrides
// We hide World so we can export ServerWorld as World
export 'package:dart_mod_common/dart_mod_common.dart'
    hide CustomGoalRegistry, World;

// Server-specific exports
export 'src/bridge.dart' show ServerBridge, Bridge;
export 'src/registries.dart';
export 'src/events.dart';
export 'src/player.dart';
export 'src/entity.dart';
export 'src/entity_actions.dart';
export 'src/world_access.dart' show ServerWorld;
// Export ServerWorld as World for API compatibility
export 'src/world.dart';
export 'src/network.dart';
export 'src/container/container.dart';
export 'src/inventory.dart';
export 'src/commands.dart';
export 'src/recipes.dart';
export 'src/loot_tables.dart';
export 'src/custom_goal.dart';
export 'src/client_bridge.dart';
