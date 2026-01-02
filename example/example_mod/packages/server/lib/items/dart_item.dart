import 'package:dart_mod_server/dart_mod_server.dart';

/// Example custom item that demonstrates the item system.
///
/// This item is dropped by HelloBlock and can be picked up by players.
class DartItem extends CustomItem {
  DartItem()
      : super(
          id: 'example_mod:dart_item',
          settings: ItemSettings(maxStackSize: 64),
          model: ItemModel.generated(texture: 'assets/textures/item/dart_item.png'),
        );
}
