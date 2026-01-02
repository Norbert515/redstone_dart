/// Block model types for the Redstone texture system.
///
/// This library provides a sealed class hierarchy for defining block models
/// with different texture configurations.
library;

/// Sealed class representing block model types.
/// Textures are specified as file paths: 'assets/textures/block/example.png'
sealed class BlockModel {
  const BlockModel();

  /// Same texture on all 6 sides (stone, dirt, etc.)
  factory BlockModel.cubeAll({required String texture}) = CubeAllModel;

  /// Different texture for top/bottom (end) vs sides (pillars)
  factory BlockModel.cubeColumn({
    required String end,
    required String side,
  }) = CubeColumnModel;

  /// Different textures for bottom, top, and sides (grass block)
  factory BlockModel.cubeBottomTop({
    required String bottom,
    required String top,
    required String side,
  }) = CubeBottomTopModel;

  /// Rotatable column that orients based on placement (logs)
  factory BlockModel.orientableCubeColumn({
    required String end,
    required String side,
  }) = OrientableCubeColumnModel;

  /// Reference a custom JSON model file
  factory BlockModel.custom({required String modelPath}) = CustomModel;

  /// Convert to JSON for manifest
  Map<String, dynamic> toJson();

  /// Get the Minecraft parent model path (e.g., 'minecraft:block/cube_all')
  String get parentModel;

  /// Get all texture paths used by this model
  List<String> get texturePaths;
}

/// Same texture on all 6 sides (stone, dirt, etc.)
final class CubeAllModel extends BlockModel {
  /// The texture path for all sides
  final String texture;

  const CubeAllModel({required this.texture});

  @override
  String get parentModel => 'minecraft:block/cube_all';

  @override
  List<String> get texturePaths => [texture];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'cube_all',
        'textures': {
          'all': texture,
        },
      };
}

/// Different texture for top/bottom (end) vs sides (pillars)
final class CubeColumnModel extends BlockModel {
  /// The texture path for top and bottom
  final String end;

  /// The texture path for sides
  final String side;

  const CubeColumnModel({
    required this.end,
    required this.side,
  });

  @override
  String get parentModel => 'minecraft:block/cube_column';

  @override
  List<String> get texturePaths => [end, side];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'cube_column',
        'textures': {
          'end': end,
          'side': side,
        },
      };
}

/// Different textures for bottom, top, and sides (grass block)
final class CubeBottomTopModel extends BlockModel {
  /// The texture path for the bottom
  final String bottom;

  /// The texture path for the top
  final String top;

  /// The texture path for the sides
  final String side;

  const CubeBottomTopModel({
    required this.bottom,
    required this.top,
    required this.side,
  });

  @override
  String get parentModel => 'minecraft:block/cube_bottom_top';

  @override
  List<String> get texturePaths => [bottom, top, side];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'cube_bottom_top',
        'textures': {
          'bottom': bottom,
          'top': top,
          'side': side,
        },
      };
}

/// Rotatable column that orients based on placement (logs)
final class OrientableCubeColumnModel extends BlockModel {
  /// The texture path for top and bottom
  final String end;

  /// The texture path for sides
  final String side;

  const OrientableCubeColumnModel({
    required this.end,
    required this.side,
  });

  @override
  String get parentModel => 'minecraft:block/cube_column';

  @override
  List<String> get texturePaths => [end, side];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'orientable_cube_column',
        'textures': {
          'end': end,
          'side': side,
        },
      };
}

/// Reference a custom JSON model file
final class CustomModel extends BlockModel {
  /// The path to the custom model JSON file
  final String modelPath;

  const CustomModel({required this.modelPath});

  @override
  String get parentModel => modelPath;

  @override
  List<String> get texturePaths => [];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'custom',
        'modelPath': modelPath,
      };
}
