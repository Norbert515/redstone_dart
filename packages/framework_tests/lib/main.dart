// framework_tests - A Minecraft mod built with Redstone
//
// Tests for the onAttackEntity callback system.

import 'package:dart_mc/dart_mc.dart';

// ===========================================================================
// Test Items - onAttackEntity callback testing
// ===========================================================================

/// Test sword that logs when onAttackEntity is called and spawns lightning.
class TestLightningSword extends CustomItem {
  static int attackCount = 0;

  TestLightningSword()
      : super(
          id: 'framework_tests:test_lightning_sword',
          settings: ItemSettings(
            maxStackSize: 1,
            maxDamage: 100,
            combat: CombatAttributes.sword(damage: 10.0),
          ),
          model: ItemModel.handheld(
            texture: 'assets/textures/item/test_sword.png',
          ),
        );

  @override
  bool onAttackEntity(int worldId, int attackerId, int targetId) {
    attackCount++;
    print('=== TEST: onAttackEntity CALLBACK FIRED ===');
    print('  attackCount: $attackCount');
    print('  worldId: $worldId');
    print('  attackerId: $attackerId');
    print('  targetId: $targetId');

    try {
      final target = Entity(targetId);
      final pos = target.position;
      print('  target position: $pos');

      final world = World.overworld;
      world.spawnLightning(pos);
      print('  Lightning spawned successfully!');
    } catch (e, st) {
      print('  ERROR: $e');
      print('  Stack: $st');
    }

    return true;
  }
}

/// Simple test sword that just logs (no lightning) to isolate issues.
class TestSimpleSword extends CustomItem {
  static int hitCount = 0;

  TestSimpleSword()
      : super(
          id: 'framework_tests:test_simple_sword',
          settings: ItemSettings(
            maxStackSize: 1,
            maxDamage: 100,
            combat: CombatAttributes.sword(damage: 5.0),
          ),
          model: ItemModel.handheld(
            texture: 'assets/textures/item/test_sword.png',
          ),
        );

  @override
  bool onAttackEntity(int worldId, int attackerId, int targetId) {
    hitCount++;
    print('=== TEST: TestSimpleSword.onAttackEntity ===');
    print('  hitCount: $hitCount');
    print('  worldId=$worldId, attackerId=$attackerId, targetId=$targetId');
    return true;
  }
}

// ===========================================================================
// Test Block
// ===========================================================================

class HelloBlock extends CustomBlock {
  HelloBlock()
      : super(
          id: 'framework_tests:hello_block',
          settings: BlockSettings(
            hardness: 1.0,
            resistance: 1.0,
            requiresTool: false,
          ),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player != null) {
      player.sendMessage('Hello from Framework Tests!');
      player.sendMessage('TestSimpleSword hits: ${TestSimpleSword.hitCount}');
      player.sendMessage('TestLightningSword hits: ${TestLightningSword.attackCount}');
    }
    return ActionResult.success;
  }
}

// ===========================================================================
// Main entry point
// ===========================================================================

void main() {
  print('=== Framework Tests - onAttackEntity Testing ===');

  // Initialize the native bridge
  Bridge.initialize();

  // Register proxy handlers
  Events.registerProxyBlockHandlers();
  Events.registerProxyItemHandlers();
  print('Proxy handlers registered (blocks + items)');

  // Register test items BEFORE blocks
  print('Registering test items...');
  ItemRegistry.register(TestSimpleSword());
  ItemRegistry.register(TestLightningSword());
  ItemRegistry.freeze();
  print('Items registered: ${ItemRegistry.itemCount}');

  // Register test blocks
  BlockRegistry.register(HelloBlock());
  BlockRegistry.freeze();
  print('Blocks registered: ${BlockRegistry.blockCount}');

  // Log when we're ready
  print('=== Framework Tests Ready ===');
  print('Test items:');
  print('  /give @p framework_tests:test_simple_sword');
  print('  /give @p framework_tests:test_lightning_sword');
  print('Hit any mob with these swords to test onAttackEntity callback.');
}
