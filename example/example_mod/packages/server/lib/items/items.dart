// Barrel export file for all items
export 'dart_item.dart';
export 'effect_wand.dart';
export 'enchant_wand.dart';
export 'healing_orb.dart';
export 'lightning_wand.dart';
export 'magic_apple.dart';
export 'obsidian_stick.dart';
export 'peer_schwert.dart';
export 'ruby_helmet.dart';
export 'ruby_sword.dart';
export 'teleport_staff.dart';

import 'package:dart_mod_server/dart_mod_server.dart';

import 'dart_item.dart';
import 'effect_wand.dart';
import 'enchant_wand.dart';
import 'healing_orb.dart';
import 'lightning_wand.dart';
import 'magic_apple.dart';
import 'obsidian_stick.dart';
import 'peer_schwert.dart';
import 'ruby_helmet.dart';
import 'ruby_sword.dart';
import 'teleport_staff.dart';

/// Registers all custom items and freezes the item registry.
/// Must be called BEFORE registerBlocks() since blocks may reference items as drops.
void registerItems() {
  ItemRegistry.register(DartItem());
  ItemRegistry.register(EffectWand());
  ItemRegistry.register(EnchantWand());
  ItemRegistry.register(HealingOrb());
  ItemRegistry.register(LightningWand());
  ItemRegistry.register(MagicApple());
  ItemRegistry.register(ObsidianStick());
  ItemRegistry.register(PeerSchwert());
  ItemRegistry.register(RubyHelmet());
  ItemRegistry.register(RubySword());
  ItemRegistry.register(TeleportStaff());
  ItemRegistry.freeze();
}
