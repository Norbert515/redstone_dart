import 'package:dart_mc/dart_mc.dart';

/// A stick made from obsidian - used to craft the Peer Schwert.
class ObsidianStick extends CustomItem {
  ObsidianStick()
      : super(
          id: 'basic_dart_mod:obsidian_stick',
          settings: ItemSettings(maxStackSize: 64),
          model: ItemModel.generated(texture: 'assets/textures/item/obsidian_stick.png'),
        );
}
