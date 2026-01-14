/// Block entity for the Flutter Display Controller.
///
/// Manages the FlutterDisplayEntity lifecycle based on redstone signal.
library;

import 'package:dart_mod_server/dart_mod_server.dart';
import 'package:minecraft_flutter_dev_common/minecraft_flutter_dev_common.dart';

/// Block entity for the Flutter Display Controller.
///
/// This block entity monitors redstone signals and spawns/despawns
/// a FlutterDisplayEntity above the block accordingly.
class FlutterDisplayControllerEntity
    extends ContainerBlockEntity<FlutterDisplayControllerContainer> {
  FlutterDisplayControllerEntity()
      : super(container: FlutterDisplayControllerContainer());

  /// The spawned FlutterDisplay instance (null if none).
  FlutterDisplay? _spawnedDisplay;

  /// Last known redstone state.
  bool _wasPowered = false;

  @override
  void serverTick() {
    // Get our position
    final pos = blockPos;
    if (pos == null) return;

    // Check redstone signal
    final world = ServerWorld.overworld;
    final signalStrength = world.getRedstoneSignal(pos);
    final isPowered = signalStrength > 0;

    // Update synced state for client display
    container.isActive.value = isPowered ? 1 : 0;

    // Handle state change
    if (isPowered && !_wasPowered) {
      // Rising edge: spawn entity
      _spawnFlutterDisplay(pos);
    } else if (!isPowered && _wasPowered) {
      // Falling edge: despawn entity
      _despawnFlutterDisplay();
    }

    _wasPowered = isPowered;
  }

  void _spawnFlutterDisplay(BlockPos pos) {
    if (_spawnedDisplay != null) return; // Already spawned

    // Spawn FlutterDisplayEntity 1 block above the controller
    final spawnX = pos.x + 0.5;
    final spawnY = pos.y + 1.5; // Center of block above
    final spawnZ = pos.z + 0.5;

    final display = FlutterDisplay.spawn(
      position: Vec3(spawnX, spawnY, spawnZ),
      route: 'clock', // Hardcoded for now (no leading slash!)
      width: container.width,
      height: container.height,
      mode: BillboardMode.vertical, // Face player horizontally
    );

    if (display != null) {
      _spawnedDisplay = display;
    }
  }

  void _despawnFlutterDisplay() {
    final display = _spawnedDisplay;
    if (display == null) return;

    // Kill the entity
    display.dispose();
    _spawnedDisplay = null;
  }

  @override
  void setRemoved() {
    // Clean up when block is broken
    _despawnFlutterDisplay();
    super.setRemoved();
  }

  @override
  Map<String, dynamic> saveAdditional() {
    final data = super.saveAdditional();
    // Save spawned entity ID so we can track it across saves
    if (_spawnedDisplay != null) {
      data['spawned_entity_id'] = _spawnedDisplay!.entityId;
    }
    data['was_powered'] = _wasPowered ? 1 : 0;
    return data;
  }

  @override
  void loadAdditional(Map<String, dynamic> nbt) {
    super.loadAdditional(nbt);
    _wasPowered = (nbt['was_powered'] as int? ?? 0) == 1;
    // Note: We don't restore _spawnedDisplay here since the entity
    // will be recreated on next power cycle. The old entity (if any)
    // would have been saved/loaded by Minecraft's entity system.
  }
}
