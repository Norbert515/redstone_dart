/// Main entry point for the Dart Minecraft mod.
///
/// This file is loaded by the native bridge when the Dart VM is initialized.
/// All event handlers should be registered here.
library dart_mod;

import 'src/bridge.dart';
import 'src/events.dart';
import 'src/types.dart';

export 'src/bridge.dart';
export 'src/events.dart';
export 'src/types.dart';
export 'api/block.dart';
export 'api/player.dart';
export 'api/world.dart';

/// Main entry point called when the Dart VM is initialized.
void main() {
  print('Dart Mod initialized!');

  // Initialize the native bridge
  Bridge.initialize();

  // Register event handlers
  Events.onBlockBreak((x, y, z, playerId) {
    print('Block broken at ($x, $y, $z) by player $playerId');
    return EventResult.allow;
  });

  Events.onBlockInteract((x, y, z, playerId, hand) {
    print('Block interacted at ($x, $y, $z) by player $playerId with hand $hand');
    return EventResult.allow;
  });

  Events.onTick((tick) {
    // Called every game tick (20 times per second)
    // Add your tick logic here
  });

  print('Event handlers registered!');
}
