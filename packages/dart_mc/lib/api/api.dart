/// Dart Minecraft API
///
/// This library provides the public API for interacting with Minecraft from Dart.
///
/// ## Overview
///
/// The main components of the API are:
///
/// - [World] - Access to the Minecraft world (get/set blocks, spawn entities)
/// - [Block] - Block types and positions
/// - [Player] - Player information and actions
/// - [Entity] - Entity manipulation
/// - [Item] - Item types and stacks
/// - [CustomBlock] - Create custom blocks with behaviors
/// - [BlockRegistry] - Register custom blocks
/// - [Events] - Subscribe to game events
///
/// ## Quick Start
///
/// ```dart
/// import 'package:dart_mc/api/api.dart';
///
/// void onTick(int tick) {
///   // Get the player's position
///   final player = Player.getLocalPlayer();
///   if (player == null) return;
///
///   final pos = player.position;
///   print('Player is at ${pos.x}, ${pos.y}, ${pos.z}');
///
///   // Set a block in the world
///   World.setBlock(pos.x.toInt(), pos.y.toInt() - 1, pos.z.toInt(), Block.stone);
/// }
/// ```
library;

export 'block.dart';
export 'block_model.dart';
export 'block_registry.dart';
export 'custom_block.dart';
export 'custom_entity.dart';
export 'custom_item.dart';
export 'entity.dart';
export 'entity_registry.dart';
export 'inventory.dart';
export 'item.dart';
export 'item_model.dart';
export 'item_registry.dart';
export 'player.dart';
export 'world.dart';
