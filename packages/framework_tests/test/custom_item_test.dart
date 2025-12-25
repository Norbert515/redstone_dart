/// Custom item callback tests.
///
/// Tests for CustomItem callbacks: onUse, onUseOnBlock, onUseOnEntity.
/// These are unit tests that directly call the callback methods.
import 'package:dart_mc/api/custom_item.dart';
import 'package:dart_mc/api/item_model.dart';
import 'package:test/test.dart';

/// Test item that tracks callback invocations.
class TestCallbackItem extends CustomItem {
  final List<String> calls = [];

  TestCallbackItem()
      : super(
          id: 'test:callback_item',
          settings: const ItemSettings(maxStackSize: 1),
          model: ItemModel.generated(texture: 'textures/item/test.png'),
        );

  @override
  ItemActionResult onUse(int worldId, int playerId, int hand) {
    calls.add('use:$worldId:$playerId:$hand');
    return ItemActionResult.success;
  }

  @override
  ItemActionResult onUseOnBlock(
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
    int hand,
  ) {
    calls.add('useOnBlock:$worldId:$x,$y,$z:$playerId:$hand');
    return ItemActionResult.consume;
  }

  @override
  ItemActionResult onUseOnEntity(
    int worldId,
    int entityId,
    int playerId,
    int hand,
  ) {
    calls.add('useOnEntity:$worldId:$entityId:$playerId:$hand');
    return ItemActionResult.success;
  }
}

/// Minimal item that doesn't override callbacks - tests default behavior.
class MinimalItem extends CustomItem {
  MinimalItem()
      : super(
          id: 'test:minimal_item',
          settings: const ItemSettings(),
          model: ItemModel.generated(texture: 'textures/item/minimal.png'),
        );
}

/// Item that returns different results for each callback.
class VariedResultItem extends CustomItem {
  VariedResultItem()
      : super(
          id: 'test:varied_item',
          settings: const ItemSettings(),
          model: ItemModel.generated(texture: 'textures/item/varied.png'),
        );

  @override
  ItemActionResult onUse(int worldId, int playerId, int hand) {
    return ItemActionResult.consumePartial;
  }

  @override
  ItemActionResult onUseOnBlock(
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
    int hand,
  ) {
    return ItemActionResult.fail;
  }

  @override
  ItemActionResult onUseOnEntity(
    int worldId,
    int entityId,
    int playerId,
    int hand,
  ) {
    return ItemActionResult.consume;
  }
}

Future<void> main() async {
  group('ItemActionResult enum', () {
    test('has correct ordinal values for Java interop', () {
      // These values MUST match what Java expects
      expect(ItemActionResult.success.index, equals(0));
      expect(ItemActionResult.consumePartial.index, equals(1));
      expect(ItemActionResult.consume.index, equals(2));
      expect(ItemActionResult.fail.index, equals(3));
      expect(ItemActionResult.pass.index, equals(4));
    });

    test('has all expected values', () {
      expect(ItemActionResult.values, hasLength(5));
      expect(
        ItemActionResult.values,
        containsAll([
          ItemActionResult.success,
          ItemActionResult.consumePartial,
          ItemActionResult.consume,
          ItemActionResult.fail,
          ItemActionResult.pass,
        ]),
      );
    });
  });

  group('CustomItem default callbacks', () {
    test('onUse returns pass by default', () {
      final item = MinimalItem();

      final result = item.onUse(0, 1, 0);

      expect(result, equals(ItemActionResult.pass));
    });

    test('onUseOnBlock returns pass by default', () {
      final item = MinimalItem();

      final result = item.onUseOnBlock(0, 100, 64, 200, 1, 0);

      expect(result, equals(ItemActionResult.pass));
    });

    test('onUseOnEntity returns pass by default', () {
      final item = MinimalItem();

      final result = item.onUseOnEntity(0, 42, 1, 0);

      expect(result, equals(ItemActionResult.pass));
    });
  });

  group('onUse callback', () {
    test('is invoked with correct parameters', () {
      final item = TestCallbackItem();

      item.onUse(0, 123, 0);

      expect(item.calls, hasLength(1));
      expect(item.calls[0], equals('use:0:123:0'));
    });

    test('returns success from overridden implementation', () {
      final item = TestCallbackItem();

      final result = item.onUse(0, 1, 0);

      expect(result, equals(ItemActionResult.success));
    });

    test('works with main hand (0)', () {
      final item = TestCallbackItem();

      item.onUse(0, 1, 0);

      expect(item.calls.last, contains(':0')); // hand=0 at end
    });

    test('works with off hand (1)', () {
      final item = TestCallbackItem();

      item.onUse(0, 1, 1);

      expect(item.calls.last, equals('use:0:1:1'));
    });

    test('can be called multiple times', () {
      final item = TestCallbackItem();

      item.onUse(0, 1, 0);
      item.onUse(1, 2, 1);
      item.onUse(2, 3, 0);

      expect(item.calls, hasLength(3));
      expect(item.calls[0], equals('use:0:1:0'));
      expect(item.calls[1], equals('use:1:2:1'));
      expect(item.calls[2], equals('use:2:3:0'));
    });
  });

  group('onUseOnBlock callback', () {
    test('is invoked with correct parameters', () {
      final item = TestCallbackItem();

      item.onUseOnBlock(0, 100, 64, 200, 123, 0);

      expect(item.calls, hasLength(1));
      expect(item.calls[0], equals('useOnBlock:0:100,64,200:123:0'));
    });

    test('returns consume from overridden implementation', () {
      final item = TestCallbackItem();

      final result = item.onUseOnBlock(0, 0, 0, 0, 1, 0);

      expect(result, equals(ItemActionResult.consume));
    });

    test('passes block position correctly', () {
      final item = TestCallbackItem();

      item.onUseOnBlock(0, -50, 128, 999, 1, 0);

      expect(item.calls.last, equals('useOnBlock:0:-50,128,999:1:0'));
    });

    test('works with main hand (0)', () {
      final item = TestCallbackItem();

      item.onUseOnBlock(0, 0, 0, 0, 1, 0);

      expect(item.calls.last, endsWith(':0'));
    });

    test('works with off hand (1)', () {
      final item = TestCallbackItem();

      item.onUseOnBlock(0, 0, 0, 0, 1, 1);

      expect(item.calls.last, endsWith(':1'));
    });
  });

  group('onUseOnEntity callback', () {
    test('is invoked with correct parameters', () {
      final item = TestCallbackItem();

      item.onUseOnEntity(0, 42, 123, 0);

      expect(item.calls, hasLength(1));
      expect(item.calls[0], equals('useOnEntity:0:42:123:0'));
    });

    test('returns success from overridden implementation', () {
      final item = TestCallbackItem();

      final result = item.onUseOnEntity(0, 1, 1, 0);

      expect(result, equals(ItemActionResult.success));
    });

    test('passes entity ID correctly', () {
      final item = TestCallbackItem();

      item.onUseOnEntity(0, 999, 1, 0);

      expect(item.calls.last, equals('useOnEntity:0:999:1:0'));
    });

    test('works with main hand (0)', () {
      final item = TestCallbackItem();

      item.onUseOnEntity(0, 1, 1, 0);

      expect(item.calls.last, endsWith(':0'));
    });

    test('works with off hand (1)', () {
      final item = TestCallbackItem();

      item.onUseOnEntity(0, 1, 1, 1);

      expect(item.calls.last, endsWith(':1'));
    });
  });

  group('varied return values', () {
    test('onUse can return consumePartial', () {
      final item = VariedResultItem();

      final result = item.onUse(0, 1, 0);

      expect(result, equals(ItemActionResult.consumePartial));
    });

    test('onUseOnBlock can return fail', () {
      final item = VariedResultItem();

      final result = item.onUseOnBlock(0, 0, 0, 0, 1, 0);

      expect(result, equals(ItemActionResult.fail));
    });

    test('onUseOnEntity can return consume', () {
      final item = VariedResultItem();

      final result = item.onUseOnEntity(0, 1, 1, 0);

      expect(result, equals(ItemActionResult.consume));
    });
  });

  group('CustomItem properties', () {
    test('id is correctly set', () {
      final item = TestCallbackItem();

      expect(item.id, equals('test:callback_item'));
    });

    test('settings are correctly set', () {
      final item = TestCallbackItem();

      expect(item.settings.maxStackSize, equals(1));
    });

    test('isRegistered is false before registration', () {
      final item = TestCallbackItem();

      expect(item.isRegistered, isFalse);
    });

    test('handlerId throws before registration', () {
      final item = TestCallbackItem();

      expect(() => item.handlerId, throwsStateError);
    });

    test('setHandlerId sets the handler ID', () {
      final item = TestCallbackItem();
      item.setHandlerId(42);

      expect(item.isRegistered, isTrue);
      expect(item.handlerId, equals(42));
    });
  });

  group('ItemSettings', () {
    test('has correct default values', () {
      const settings = ItemSettings();

      expect(settings.maxStackSize, equals(64));
      expect(settings.maxDamage, equals(0));
      expect(settings.fireResistant, isFalse);
      expect(settings.combat, isNull);
    });

    test('can customize maxStackSize', () {
      const settings = ItemSettings(maxStackSize: 16);

      expect(settings.maxStackSize, equals(16));
    });

    test('can set fireResistant', () {
      const settings = ItemSettings(fireResistant: true);

      expect(settings.fireResistant, isTrue);
    });

    test('can set maxDamage for tools', () {
      const settings = ItemSettings(maxStackSize: 1, maxDamage: 250);

      expect(settings.maxStackSize, equals(1));
      expect(settings.maxDamage, equals(250));
    });
  });

  group('CombatAttributes', () {
    test('can create sword attributes', () {
      final combat = CombatAttributes.sword(damage: 6.0);

      expect(combat.attackDamage, equals(6.0));
      expect(combat.attackSpeed, equals(-2.4));
      expect(combat.attackKnockback, equals(0.0));
    });

    test('can create axe attributes', () {
      final combat = CombatAttributes.axe(damage: 9.0);

      expect(combat.attackDamage, equals(9.0));
      expect(combat.attackSpeed, equals(-3.0));
      expect(combat.attackKnockback, equals(0.0));
    });

    test('can customize all values', () {
      const combat = CombatAttributes(
        attackDamage: 7.0,
        attackSpeed: -2.0,
        attackKnockback: 1.5,
      );

      expect(combat.attackDamage, equals(7.0));
      expect(combat.attackSpeed, equals(-2.0));
      expect(combat.attackKnockback, equals(1.5));
    });
  });
}
