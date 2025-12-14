/// Block API for interacting with Minecraft blocks.
library;

import '../src/types.dart';

/// Represents a block type in Minecraft.
class Block {
  /// The block identifier (e.g., "minecraft:stone").
  final String id;

  const Block(this.id);

  /// Common block types
  static const air = Block('minecraft:air');
  static const stone = Block('minecraft:stone');
  static const dirt = Block('minecraft:dirt');
  static const grass = Block('minecraft:grass_block');
  static const cobblestone = Block('minecraft:cobblestone');
  static const oakPlanks = Block('minecraft:oak_planks');
  static const bedrock = Block('minecraft:bedrock');
  static const water = Block('minecraft:water');
  static const lava = Block('minecraft:lava');
  static const sand = Block('minecraft:sand');
  static const gravel = Block('minecraft:gravel');
  static const goldOre = Block('minecraft:gold_ore');
  static const ironOre = Block('minecraft:iron_ore');
  static const coalOre = Block('minecraft:coal_ore');
  static const diamondOre = Block('minecraft:diamond_ore');

  @override
  String toString() => 'Block($id)';

  @override
  bool operator ==(Object other) => other is Block && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Block state with position and additional properties.
class BlockState {
  final Block block;
  final BlockPos pos;
  final Map<String, String> properties;

  const BlockState({
    required this.block,
    required this.pos,
    this.properties = const {},
  });

  @override
  String toString() => 'BlockState(${block.id} at $pos, props: $properties)';
}

// TODO: Add methods to interact with blocks via native bridge
// These will require additional JNI functions to get/set blocks in the world
//
// Example future API:
// class Blocks {
//   static BlockState? getBlock(BlockPos pos) { ... }
//   static void setBlock(BlockPos pos, Block block) { ... }
//   static bool isAir(BlockPos pos) { ... }
// }
