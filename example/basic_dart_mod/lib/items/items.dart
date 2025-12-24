// Barrel export file for all items
export 'dart_item.dart';
export 'effect_wand.dart';
export 'obsidian_stick.dart';
export 'peer_schwert.dart';

import 'package:dart_mc/dart_mc.dart';

import 'dart_item.dart';
import 'effect_wand.dart';
import 'obsidian_stick.dart';
import 'peer_schwert.dart';

/// Registers all custom items and freezes the item registry.
/// Must be called BEFORE registerBlocks() since blocks may reference items as drops.
void registerItems() {
  ItemRegistry.register(DartItem());
  ItemRegistry.register(EffectWand());
  ItemRegistry.register(ObsidianStick());
  ItemRegistry.register(PeerSchwert());
  ItemRegistry.freeze();
}
