/// Entity model types for the Redstone texture system.
///
/// This library provides a sealed class hierarchy for defining entity models
/// with different texture configurations.
library;

/// Sealed class representing entity model types.
/// Textures are specified as file paths: 'assets/textures/entity/example.png'
sealed class EntityModel {
  const EntityModel();

  /// Humanoid model (two-legged like zombies, players)
  factory EntityModel.humanoid({required String texture}) = HumanoidModel;

  /// Quadruped model (four-legged like cows, pigs)
  factory EntityModel.quadruped({required String texture}) = QuadrupedModel;

  /// Single-layer simple model (like slimes, basic mobs)
  factory EntityModel.simple({required String texture, double scale}) =
      SimpleModel;

  /// Reference a custom model/texture (for advanced users)
  factory EntityModel.custom({required String texture}) = CustomEntityModel;

  /// Convert to JSON for manifest
  Map<String, dynamic> toJson();

  /// Get all texture paths used by this model
  List<String> get texturePaths;
}

/// Humanoid model (two-legged like zombies, players)
final class HumanoidModel extends EntityModel {
  /// The texture path for the humanoid model
  final String texture;

  const HumanoidModel({required this.texture});

  @override
  List<String> get texturePaths => [texture];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'humanoid',
        'texture': texture,
      };
}

/// Quadruped model (four-legged like cows, pigs)
final class QuadrupedModel extends EntityModel {
  /// The texture path for the quadruped model
  final String texture;

  const QuadrupedModel({required this.texture});

  @override
  List<String> get texturePaths => [texture];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'quadruped',
        'texture': texture,
      };
}

/// Single-layer simple model (like slimes, basic mobs)
final class SimpleModel extends EntityModel {
  /// The texture path for the simple model
  final String texture;

  /// The scale of the model
  final double scale;

  const SimpleModel({required this.texture, this.scale = 1.0});

  @override
  List<String> get texturePaths => [texture];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'simple',
        'texture': texture,
        'scale': scale,
      };
}

/// Reference a custom model/texture (for advanced users)
final class CustomEntityModel extends EntityModel {
  /// The texture path for the custom model
  final String texture;

  const CustomEntityModel({required this.texture});

  @override
  List<String> get texturePaths => [texture];

  @override
  Map<String, dynamic> toJson() => {
        'type': 'custom',
        'texture': texture,
      };
}
