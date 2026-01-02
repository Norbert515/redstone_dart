/// Sealed class representing item model types.
/// Textures are specified as file paths: 'assets/textures/item/example.png'
library;

sealed class ItemModel {
  const ItemModel();

  /// Standard 2D item (like diamond, stick, ingots)
  /// Uses minecraft:item/generated parent
  factory ItemModel.generated({required String texture}) = GeneratedItemModel;

  /// Handheld item (like tools, weapons)
  /// Uses minecraft:item/handheld parent - renders differently in hand
  factory ItemModel.handheld({required String texture}) = HandheldItemModel;

  /// Convert to JSON for manifest
  Map<String, dynamic> toJson();

  /// Get the Minecraft parent model path
  String get parentModel;

  /// Get texture path
  String get texturePath;
}

final class GeneratedItemModel extends ItemModel {
  final String texture;

  const GeneratedItemModel({required this.texture});

  @override
  String get parentModel => 'minecraft:item/generated';

  @override
  String get texturePath => texture;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'generated',
        'texture': texture,
      };
}

final class HandheldItemModel extends ItemModel {
  final String texture;

  const HandheldItemModel({required this.texture});

  @override
  String get parentModel => 'minecraft:item/handheld';

  @override
  String get texturePath => texture;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'handheld',
        'texture': texture,
      };
}
