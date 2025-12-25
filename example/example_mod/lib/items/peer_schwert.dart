import 'package:dart_mc/dart_mc.dart';

/// A custom sword item - the Peer Schwert.
/// Summons lightning on hit!
class PeerSchwert extends CustomItem {
  PeerSchwert()
      : super(
          id: 'example_mod:peer_schwert',
          settings: ItemSettings(
            maxStackSize: 1, // Swords don't stack
            maxDamage: 250, // Durability (iron sword level)
            combat: CombatAttributes.sword(damage: 6.0),
          ),
          model: ItemModel.handheld(
            texture: 'assets/textures/item/peer-schwert.png',
          ),
        );

  @override
  bool onAttackEntity(int worldId, int attackerId, int targetId) {
    final target = Entity(targetId);
    final world = World.overworld;
    world.spawnLightning(target.position);
    return true;
  }
}
