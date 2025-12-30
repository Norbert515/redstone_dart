/// Shared types and interfaces for Dart Minecraft modding.
///
/// This package contains pure Dart code with no platform dependencies.
/// It is used by both dart_mod_server and dart_mod_client.
library;

// Core types
export 'src/types.dart';

// Block API
export 'src/block/block.dart';
export 'src/block/block_settings.dart';
export 'src/block/block_model.dart';
export 'src/block/custom_block.dart';

// Item API
export 'src/item/item.dart';
export 'src/item/item_settings.dart';
export 'src/item/item_model.dart';
export 'src/item/custom_item.dart';
export 'src/item/item_stack.dart';

// Entity API
export 'src/entity/entity.dart';
export 'src/entity/entity_settings.dart';
export 'src/entity/entity_model.dart';
export 'src/entity/custom_entity.dart';
export 'src/entity/entity_goal.dart';

// World API
export 'src/world/world.dart';

// Registry interfaces
export 'src/registry/block_registry.dart';
export 'src/registry/item_registry.dart';
export 'src/registry/entity_registry.dart';

// Network protocol
export 'src/protocol/packet.dart';
export 'src/protocol/packet_types.dart';
export 'src/protocol/server_packets.dart';
export 'src/protocol/client_packets.dart';
