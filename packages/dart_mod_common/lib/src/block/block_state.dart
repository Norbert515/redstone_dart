/// Custom block state representation with property values.
library;

import 'block_property.dart';

/// Represents a specific state of a custom block with property values.
///
/// CustomBlockState is immutable - changing a property returns a new CustomBlockState.
/// This is different from [BlockState] in block.dart which represents any block with position.
class CustomBlockState {
  final String blockId;
  final Map<String, dynamic> _values;
  final List<BlockProperty> _properties;

  const CustomBlockState._({
    required this.blockId,
    required Map<String, dynamic> values,
    required List<BlockProperty> properties,
  })  : _values = values,
        _properties = properties;

  /// Create a default state with all properties at their first values.
  factory CustomBlockState.defaultState(
      String blockId, List<BlockProperty> properties) {
    final values = <String, dynamic>{};
    for (final prop in properties) {
      values[prop.name] = prop.indexToValue(0);
    }
    return CustomBlockState._(
        blockId: blockId, values: values, properties: properties);
  }

  /// Decode a state from packed integer data.
  factory CustomBlockState.fromEncoded(
      String blockId, List<BlockProperty> properties, int encoded) {
    final values = <String, dynamic>{};
    int shift = 0;

    for (final prop in properties) {
      final bits = _bitsNeeded(prop.valueCount);
      final mask = (1 << bits) - 1;
      final index = (encoded >> shift) & mask;
      values[prop.name] = prop.indexToValue(index);
      shift += bits;
    }

    return CustomBlockState._(
        blockId: blockId, values: values, properties: properties);
  }

  /// Get a property value.
  T getValue<T>(BlockProperty property) {
    return _values[property.name] as T;
  }

  /// Get a property value by name.
  T getValueByName<T>(String name) {
    return _values[name] as T;
  }

  /// Create a new state with a different property value.
  CustomBlockState setValue<T>(BlockProperty property, T value) {
    final newValues = Map<String, dynamic>.from(_values);
    newValues[property.name] = value;
    return CustomBlockState._(
        blockId: blockId, values: newValues, properties: _properties);
  }

  /// Encode this state to a packed integer.
  int encode() {
    int encoded = 0;
    int shift = 0;

    for (final prop in _properties) {
      final value = _values[prop.name];
      final index = prop.valueToIndex(value);
      final bits = _bitsNeeded(prop.valueCount);
      encoded |= (index << shift);
      shift += bits;
    }

    return encoded;
  }

  static int _bitsNeeded(int values) {
    if (values <= 1) return 0;
    return (values - 1).bitLength;
  }

  @override
  String toString() => 'CustomBlockState($blockId, $_values)';
}
