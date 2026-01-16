/// Block model types for the Redstone texture system.
///
/// This library provides a sealed class hierarchy for defining block models
/// with different texture configurations.
library;

import '../types.dart' show Direction;

/// A 3D vector for block model coordinates (0-16 scale, can extend -16 to 32)
class ModelVec3 {
  final double x, y, z;
  const ModelVec3(this.x, this.y, this.z);

  List<double> toJson() => [x, y, z];
}

/// UV coordinates for a face texture (0-16 scale)
class UV {
  final double u1, v1, u2, v2;
  const UV(this.u1, this.v1, this.u2, this.v2);

  List<double> toJson() => [u1, v1, u2, v2];
}

/// Element rotation configuration
class ElementRotation {
  final ModelVec3 origin;
  final String axis; // 'x', 'y', or 'z'
  final double angle;
  final bool rescale;

  const ElementRotation({
    required this.origin,
    required this.axis,
    required this.angle,
    this.rescale = false,
  });

  Map<String, dynamic> toJson() => {
        'origin': origin.toJson(),
        'axis': axis,
        'angle': angle,
        if (rescale) 'rescale': rescale,
      };
}

/// A single face of a block element
class ElementFace {
  final String texture; // Texture variable name (without #)
  final UV? uv; // Optional UV coords
  final Direction? cullface; // Optional cull direction
  final int rotation; // 0, 90, 180, or 270
  final int tintIndex; // -1 = no tint

  const ElementFace({
    required this.texture,
    this.uv,
    this.cullface,
    this.rotation = 0,
    this.tintIndex = -1,
  });

  Map<String, dynamic> toJson() => {
        'texture': '#$texture',
        if (uv != null) 'uv': uv!.toJson(),
        if (cullface != null) 'cullface': cullface!.name,
        if (rotation != 0) 'rotation': rotation,
        if (tintIndex != -1) 'tintindex': tintIndex,
      };
}

/// A cuboid element in the block model
class BlockElement {
  final ModelVec3 from;
  final ModelVec3 to;
  final Map<Direction, ElementFace> faces;
  final ElementRotation? rotation;
  final bool shade;
  final int lightEmission;

  const BlockElement({
    required this.from,
    required this.to,
    required this.faces,
    this.rotation,
    this.shade = true,
    this.lightEmission = 0,
  });

  Map<String, dynamic> toJson() => {
        'from': from.toJson(),
        'to': to.toJson(),
        'faces': {
          for (final entry in faces.entries) entry.key.name: entry.value.toJson(),
        },
        if (rotation != null) 'rotation': rotation!.toJson(),
        if (!shade) 'shade': shade,
        if (lightEmission > 0) 'light_emission': lightEmission,
      };
}

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

  /// Invisible block model (no faces rendered)
  /// Use this for blocks that are rendered entirely via BlockEntityRenderer
  factory BlockModel.invisible() = InvisibleModel;

  /// Custom model with programmatically defined elements
  factory BlockModel.elements({
    required Map<String, String> textures,
    required List<BlockElement> elements,
    String? parent,
    bool? ambientOcclusion,
  }) = ElementsModel;

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

/// Block model defined by custom elements
final class ElementsModel extends BlockModel {
  /// Map of texture variable names to file paths
  final Map<String, String> textures;

  /// List of cuboid elements that make up the model
  final List<BlockElement> elements;

  /// Optional parent model to inherit from
  final String? parent;

  /// Whether to use ambient occlusion
  final bool? ambientOcclusion;

  const ElementsModel({
    required this.textures,
    required this.elements,
    this.parent,
    this.ambientOcclusion,
  });

  @override
  String get parentModel => parent ?? '';

  @override
  List<String> get texturePaths => textures.values.toList();

  @override
  Map<String, dynamic> toJson() => {
        'type': 'elements',
        'textures': textures,
        'elements': elements.map((e) => e.toJson()).toList(),
        if (parent != null) 'parent': parent,
        if (ambientOcclusion != null) 'ambientOcclusion': ambientOcclusion,
      };
}

/// Block model with no visible faces (for animated/custom rendered blocks)
final class InvisibleModel extends BlockModel {
  const InvisibleModel();

  @override
  String get parentModel => '';

  @override
  List<String> get texturePaths => [];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'invisible',
      };
}
