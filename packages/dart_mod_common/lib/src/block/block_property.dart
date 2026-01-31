/// Block state property definitions for custom blocks.
library;

import '../types.dart';

/// Base class for block state properties.
///
/// Properties define the possible states a block can be in (e.g., powered/unpowered,
/// facing direction, power level).
sealed class BlockProperty {
  /// The property name (e.g., "powered", "facing", "power").
  final String name;

  const BlockProperty(this.name);

  /// Number of possible values for this property.
  int get valueCount;

  /// Convert a value to its index for state encoding.
  int valueToIndex(dynamic value);

  /// Convert an index back to a value.
  dynamic indexToValue(int index);
}

/// A boolean property (true/false).
///
/// Example: `powered`, `lit`, `triggered`
class BooleanProperty extends BlockProperty {
  const BooleanProperty(super.name);

  @override
  int get valueCount => 2;

  @override
  int valueToIndex(dynamic value) => (value as bool) ? 1 : 0;

  @override
  bool indexToValue(int index) => index == 1;
}

/// An integer property with min/max bounds.
///
/// Example: `power` (0-15), `age` (0-7), `level` (0-8)
class IntProperty extends BlockProperty {
  final int min;
  final int max;

  const IntProperty(super.name, {required this.min, required this.max})
      : assert(min >= 0),
        assert(max > min),
        assert(max <= 15); // Minecraft limitation

  @override
  int get valueCount => max - min + 1;

  @override
  int valueToIndex(dynamic value) => (value as int) - min;

  @override
  int indexToValue(int index) => index + min;
}

/// A direction property for block orientation.
///
/// Example: `facing`
class DirectionProperty extends BlockProperty {
  final List<Direction> allowedDirections;

  DirectionProperty(super.name, {List<Direction>? allowed})
      : allowedDirections = allowed ?? Direction.values;

  /// All six directions.
  static final all = DirectionProperty('facing');

  /// Horizontal directions only (N, S, E, W).
  static DirectionProperty horizontal(String name) => DirectionProperty(
        name,
        allowed: [
          Direction.north,
          Direction.south,
          Direction.east,
          Direction.west,
        ],
      );

  @override
  int get valueCount => allowedDirections.length;

  @override
  int valueToIndex(dynamic value) {
    final dir = value as Direction;
    final index = allowedDirections.indexOf(dir);
    return index >= 0 ? index : 0;
  }

  @override
  Direction indexToValue(int index) => allowedDirections[index];
}

/// An enum property for custom enum values.
///
/// Example: Comparator mode (compare/subtract), Slab type (top/bottom/double)
class EnumProperty<T extends Enum> extends BlockProperty {
  final List<T> values;

  const EnumProperty(super.name, this.values);

  @override
  int get valueCount => values.length;

  @override
  int valueToIndex(dynamic value) => values.indexOf(value as T);

  @override
  T indexToValue(int index) => values[index];
}
