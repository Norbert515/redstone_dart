// Barrel export file for all items
export 'dart_item.dart';
export 'effect_wand.dart';
export 'healing_orb.dart';
export 'lightning_wand.dart';
export 'obsidian_stick.dart';
export 'peer_schwert.dart';
export 'teleport_staff.dart';

import 'package:dart_mc/dart_mc.dart';

import 'dart_item.dart';
import 'effect_wand.dart';
import 'healing_orb.dart';
import 'lightning_wand.dart';
import 'obsidian_stick.dart';
import 'peer_schwert.dart';
import 'teleport_staff.dart';

/// Registers all custom items and freezes the item registry.
/// Must be called BEFORE registerBlocks() since blocks may reference items as drops.
void registerItems() {
  ItemRegistry.register(DartItem());
  ItemRegistry.register(EffectWand());
  ItemRegistry.register(HealingOrb());
  ItemRegistry.register(LightningWand());
  ItemRegistry.register(ObsidianStick());
  ItemRegistry.register(PeerSchwert());
  ItemRegistry.register(TeleportStaff());
  ItemRegistry.freeze();
}
