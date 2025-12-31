// Barrel export file for all blocks
export 'entity_radar_block.dart';
export 'hello_block.dart';
export 'lightning_rod_block.dart';
export 'message_block.dart';
export 'midas_block.dart';
export 'mob_spawner_block.dart';
export 'particle_block.dart';
export 'party_block.dart';
export 'rainbow_block.dart';
export 'terraformer_block.dart';
export 'weather_control_block.dart';

import 'package:dart_mod_server/dart_mod_server.dart';

import 'entity_radar_block.dart';
import 'hello_block.dart';
import 'lightning_rod_block.dart';
import 'message_block.dart';
import 'midas_block.dart';
import 'mob_spawner_block.dart';
import 'particle_block.dart';
import 'party_block.dart';
import 'rainbow_block.dart';
import 'terraformer_block.dart';
import 'weather_control_block.dart';

/// Registers all custom blocks and freezes the block registry.
/// Must be called AFTER registerItems() since blocks may reference items as drops.
void registerBlocks() {
  BlockRegistry.register(HelloBlock());
  BlockRegistry.register(MessageBlock());
  BlockRegistry.register(MidasBlock());
  BlockRegistry.register(LightningRodBlock());
  BlockRegistry.register(MobSpawnerBlock());
  BlockRegistry.register(ParticleBlock());
  BlockRegistry.register(PartyBlock());
  BlockRegistry.register(RainbowBlock());
  BlockRegistry.register(TerraformerBlock());
  BlockRegistry.register(WeatherControlBlock());
  BlockRegistry.register(EntityRadarBlock());
  BlockRegistry.freeze();
}
