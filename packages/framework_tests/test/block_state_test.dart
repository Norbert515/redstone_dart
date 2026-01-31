/// Block state property tests.
///
/// Tests for block state properties (BooleanProperty, IntProperty, DirectionProperty)
/// and state encoding/decoding. These are primarily unit tests since custom blocks
/// with properties need to be registered in the mod to test E2E behavior.
import 'package:redstone_test/redstone_test.dart';
import 'package:dart_mod_common/dart_mod_common.dart';

Future<void> main() async {
  // ============================================================================
  // Unit Tests - Block Property Classes
  // ============================================================================

  await group('BooleanProperty', () async {
    await testMinecraft('valueCount is 2', (game) async {
      const prop = BooleanProperty('powered');

      expect(prop.valueCount, equals(2));
    });

    await testMinecraft('valueToIndex maps false to 0', (game) async {
      const prop = BooleanProperty('powered');

      expect(prop.valueToIndex(false), equals(0));
    });

    await testMinecraft('valueToIndex maps true to 1', (game) async {
      const prop = BooleanProperty('powered');

      expect(prop.valueToIndex(true), equals(1));
    });

    await testMinecraft('indexToValue maps 0 to false', (game) async {
      const prop = BooleanProperty('powered');

      expect(prop.indexToValue(0), equals(false));
    });

    await testMinecraft('indexToValue maps 1 to true', (game) async {
      const prop = BooleanProperty('powered');

      expect(prop.indexToValue(1), equals(true));
    });

    await testMinecraft('round-trip conversion preserves value', (game) async {
      const prop = BooleanProperty('lit');

      for (final value in [true, false]) {
        final index = prop.valueToIndex(value);
        final result = prop.indexToValue(index);
        expect(result, equals(value));
      }
    });

    await testMinecraft('name is preserved', (game) async {
      const prop = BooleanProperty('triggered');

      expect(prop.name, equals('triggered'));
    });
  });

  await group('IntProperty', () async {
    await testMinecraft('valueCount is max - min + 1', (game) async {
      const prop = IntProperty('power', min: 0, max: 15);

      expect(prop.valueCount, equals(16));
    });

    await testMinecraft('valueCount for small range', (game) async {
      const prop = IntProperty('age', min: 0, max: 7);

      expect(prop.valueCount, equals(8));
    });

    await testMinecraft('valueToIndex subtracts min', (game) async {
      const prop = IntProperty('level', min: 1, max: 8);

      expect(prop.valueToIndex(1), equals(0));
      expect(prop.valueToIndex(4), equals(3));
      expect(prop.valueToIndex(8), equals(7));
    });

    await testMinecraft('indexToValue adds min', (game) async {
      const prop = IntProperty('level', min: 1, max: 8);

      expect(prop.indexToValue(0), equals(1));
      expect(prop.indexToValue(3), equals(4));
      expect(prop.indexToValue(7), equals(8));
    });

    await testMinecraft('round-trip conversion preserves value', (game) async {
      const prop = IntProperty('power', min: 0, max: 15);

      for (int value = 0; value <= 15; value++) {
        final index = prop.valueToIndex(value);
        final result = prop.indexToValue(index);
        expect(result, equals(value));
      }
    });

    await testMinecraft('min and max are stored', (game) async {
      const prop = IntProperty('moisture', min: 0, max: 7);

      expect(prop.min, equals(0));
      expect(prop.max, equals(7));
    });
  });

  await group('DirectionProperty', () async {
    await testMinecraft('all directions has 6 values', (game) async {
      final prop = DirectionProperty('facing');

      expect(prop.valueCount, equals(6));
    });

    await testMinecraft('horizontal has 4 values', (game) async {
      final prop = DirectionProperty.horizontal('facing');

      expect(prop.valueCount, equals(4));
    });

    await testMinecraft('horizontal excludes up and down', (game) async {
      final prop = DirectionProperty.horizontal('facing');

      expect(prop.allowedDirections.contains(Direction.up), isFalse);
      expect(prop.allowedDirections.contains(Direction.down), isFalse);
      expect(prop.allowedDirections.contains(Direction.north), isTrue);
      expect(prop.allowedDirections.contains(Direction.south), isTrue);
      expect(prop.allowedDirections.contains(Direction.east), isTrue);
      expect(prop.allowedDirections.contains(Direction.west), isTrue);
    });

    await testMinecraft('round-trip conversion preserves direction', (game) async {
      final prop = DirectionProperty('facing');

      for (final dir in Direction.values) {
        final index = prop.valueToIndex(dir);
        final result = prop.indexToValue(index);
        expect(result, equals(dir));
      }
    });

    await testMinecraft('custom allowed directions', (game) async {
      final prop = DirectionProperty(
        'vertical',
        allowed: [Direction.up, Direction.down],
      );

      expect(prop.valueCount, equals(2));
      expect(prop.allowedDirections, equals([Direction.up, Direction.down]));
    });
  });

  await group('EnumProperty', () async {
    await testMinecraft('valueCount matches enum values', (game) async {
      // Using Direction as a stand-in enum since we have access to it
      final prop = EnumProperty<Direction>(
        'mode',
        [Direction.north, Direction.south],
      );

      expect(prop.valueCount, equals(2));
    });

    await testMinecraft('round-trip conversion preserves value', (game) async {
      final prop = EnumProperty<Direction>(
        'mode',
        [Direction.north, Direction.south, Direction.east],
      );

      for (final value in prop.values) {
        final index = prop.valueToIndex(value);
        final result = prop.indexToValue(index);
        expect(result, equals(value));
      }
    });
  });

  // ============================================================================
  // Unit Tests - CustomBlockState
  // ============================================================================

  await group('CustomBlockState', () async {
    await testMinecraft('defaultState creates state with first values', (game) async {
      final properties = [
        const BooleanProperty('powered'),
        const IntProperty('power', min: 0, max: 15),
      ];

      final state = CustomBlockState.defaultState('test:block', properties);

      expect(state.getValueByName<bool>('powered'), equals(false));
      expect(state.getValueByName<int>('power'), equals(0));
    });

    await testMinecraft('setValue creates new state', (game) async {
      const powered = BooleanProperty('powered');
      final properties = [powered];

      final state = CustomBlockState.defaultState('test:block', properties);
      final newState = state.setValue(powered, true);

      // Original unchanged
      expect(state.getValue<bool>(powered), equals(false));
      // New state has updated value
      expect(newState.getValue<bool>(powered), equals(true));
    });

    await testMinecraft('encode/decode round-trip for boolean', (game) async {
      const powered = BooleanProperty('powered');
      final properties = [powered];

      final state = CustomBlockState.defaultState('test:block', properties)
          .setValue(powered, true);

      final encoded = state.encode();
      final decoded = CustomBlockState.fromEncoded('test:block', properties, encoded);

      expect(decoded.getValue<bool>(powered), equals(true));
    });

    await testMinecraft('encode/decode round-trip for int', (game) async {
      const power = IntProperty('power', min: 0, max: 15);
      final properties = [power];

      final state = CustomBlockState.defaultState('test:block', properties)
          .setValue(power, 10);

      final encoded = state.encode();
      final decoded = CustomBlockState.fromEncoded('test:block', properties, encoded);

      expect(decoded.getValue<int>(power), equals(10));
    });

    await testMinecraft('encode/decode round-trip for direction', (game) async {
      final facing = DirectionProperty.horizontal('facing');
      final properties = [facing];

      final state = CustomBlockState.defaultState('test:block', properties)
          .setValue(facing, Direction.east);

      final encoded = state.encode();
      final decoded = CustomBlockState.fromEncoded('test:block', properties, encoded);

      expect(decoded.getValue<Direction>(facing), equals(Direction.east));
    });

    await testMinecraft('encode/decode with multiple properties', (game) async {
      const powered = BooleanProperty('powered');
      const power = IntProperty('power', min: 0, max: 15);
      final facing = DirectionProperty.horizontal('facing');
      final properties = [powered, power, facing];

      final state = CustomBlockState.defaultState('test:block', properties)
          .setValue(powered, true)
          .setValue(power, 7)
          .setValue(facing, Direction.south);

      final encoded = state.encode();
      final decoded = CustomBlockState.fromEncoded('test:block', properties, encoded);

      expect(decoded.getValue<bool>(powered), equals(true));
      expect(decoded.getValue<int>(power), equals(7));
      expect(decoded.getValue<Direction>(facing), equals(Direction.south));
    });

    await testMinecraft('blockId is preserved', (game) async {
      final properties = <BlockProperty>[];
      final state = CustomBlockState.defaultState('mymod:custom_block', properties);

      expect(state.blockId, equals('mymod:custom_block'));
    });

    await testMinecraft('all possible boolean values encode uniquely', (game) async {
      const powered = BooleanProperty('powered');
      final properties = [powered];

      final encodedFalse = CustomBlockState.defaultState('test:block', properties)
          .setValue(powered, false)
          .encode();
      final encodedTrue = CustomBlockState.defaultState('test:block', properties)
          .setValue(powered, true)
          .encode();

      expect(encodedFalse, isNot(equals(encodedTrue)));
    });

    await testMinecraft('all power levels encode uniquely', (game) async {
      const power = IntProperty('power', min: 0, max: 15);
      final properties = [power];

      final encodedValues = <int>{};
      for (int i = 0; i <= 15; i++) {
        final encoded = CustomBlockState.defaultState('test:block', properties)
            .setValue(power, i)
            .encode();
        encodedValues.add(encoded);
      }

      expect(encodedValues.length, equals(16));
    });
  });

  // ============================================================================
  // Unit Tests - Bit Packing
  // ============================================================================

  await group('State bit packing', () async {
    await testMinecraft('boolean uses 1 bit', (game) async {
      const powered = BooleanProperty('powered');
      final properties = [powered];

      // With just a boolean, encoded should be 0 or 1
      final encodedFalse = CustomBlockState.defaultState('test:block', properties)
          .setValue(powered, false)
          .encode();
      final encodedTrue = CustomBlockState.defaultState('test:block', properties)
          .setValue(powered, true)
          .encode();

      expect(encodedFalse, equals(0));
      expect(encodedTrue, equals(1));
    });

    await testMinecraft('int uses correct number of bits', (game) async {
      // 16 values (0-15) needs 4 bits
      const power = IntProperty('power', min: 0, max: 15);
      final properties = [power];

      final encoded15 = CustomBlockState.defaultState('test:block', properties)
          .setValue(power, 15)
          .encode();

      // 15 in binary is 1111, so max encoded value should be 15
      expect(encoded15, equals(15));
    });

    await testMinecraft('properties are packed sequentially', (game) async {
      const powered = BooleanProperty('powered'); // 1 bit
      const power = IntProperty('power', min: 0, max: 15); // 4 bits
      final properties = [powered, power];

      // powered=true (bit 0 = 1) + power=5 (bits 1-4 = 0101)
      // Binary: 01011 = 11 in decimal
      final state = CustomBlockState.defaultState('test:block', properties)
          .setValue(powered, true)
          .setValue(power, 5);

      final encoded = state.encode();

      // First bit is powered (1), next 4 bits are power (5 = 0101)
      // So: 1 + (5 << 1) = 1 + 10 = 11
      expect(encoded, equals(11));
    });
  });

  // ============================================================================
  // BlockSettings Property Configuration
  // ============================================================================

  await group('BlockSettings with properties', () async {
    await testMinecraft('can create settings with properties', (game) async {
      final settings = BlockSettings(
        hardness: 1.0,
        resistance: 1.0,
        properties: [
          const BooleanProperty('powered'),
          const IntProperty('power', min: 0, max: 15),
        ],
      );

      expect(settings.properties.length, equals(2));
      expect(settings.properties[0].name, equals('powered'));
      expect(settings.properties[1].name, equals('power'));
    });

    await testMinecraft('can create redstone source settings', (game) async {
      final settings = BlockSettings(
        hardness: 1.0,
        resistance: 1.0,
        isRedstoneSource: true,
        properties: [
          const IntProperty('power', min: 0, max: 15),
        ],
      );

      expect(settings.isRedstoneSource, isTrue);
      expect(settings.hasAnalogOutput, isFalse);
    });

    await testMinecraft('can create analog output settings', (game) async {
      final settings = BlockSettings(
        hardness: 1.0,
        resistance: 1.0,
        hasAnalogOutput: true,
      );

      expect(settings.hasAnalogOutput, isTrue);
      expect(settings.isRedstoneSource, isFalse);
    });

    await testMinecraft('can create combined redstone settings', (game) async {
      final settings = BlockSettings(
        hardness: 1.0,
        resistance: 1.0,
        isRedstoneSource: true,
        hasAnalogOutput: true,
        properties: [
          const BooleanProperty('powered'),
        ],
      );

      expect(settings.isRedstoneSource, isTrue);
      expect(settings.hasAnalogOutput, isTrue);
      expect(settings.properties.length, equals(1));
    });
  });
}
