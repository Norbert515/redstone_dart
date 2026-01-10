/// Base class for Dart-defined block entities.
library;

import 'block_entity_settings.dart';
import '../types.dart';

// Minecraft BlockPos bit packing constants (matches Java BlockPos.asLong)
// PACKED_HORIZONTAL_LENGTH = 26 bits (for x and z)
// PACKED_Y_LENGTH = 12 bits (for y)
// Y at offset 0, Z at offset 12, X at offset 38
const int _packedHorizontalLength = 26;
const int _packedYLength = 12;
const int _zOffset = _packedYLength; // 12
const int _xOffset = _packedYLength + _packedHorizontalLength; // 38

/// Decode x coordinate from a packed BlockPos long.
int decodeBlockPosX(int packed) {
  // Signed extraction: shift left then arithmetic right
  return (packed << (64 - _xOffset - _packedHorizontalLength)) >>
      (64 - _packedHorizontalLength);
}

/// Decode y coordinate from a packed BlockPos long.
int decodeBlockPosY(int packed) {
  // Signed extraction
  return (packed << (64 - _packedYLength)) >> (64 - _packedYLength);
}

/// Decode z coordinate from a packed BlockPos long.
int decodeBlockPosZ(int packed) {
  // Signed extraction
  return (packed << (64 - _zOffset - _packedHorizontalLength)) >>
      (64 - _packedHorizontalLength);
}

/// Decode a packed BlockPos long to a BlockPos.
BlockPos decodeBlockPos(int packed) {
  return BlockPos(
    decodeBlockPosX(packed),
    decodeBlockPosY(packed),
    decodeBlockPosZ(packed),
  );
}

/// Encode a BlockPos to a packed long (matches Java BlockPos.asLong).
///
/// This is the inverse of [decodeBlockPos].
int encodeBlockPos(BlockPos pos) {
  // Mask to appropriate bit widths
  final x = pos.x & ((1 << _packedHorizontalLength) - 1);
  final y = pos.y & ((1 << _packedYLength) - 1);
  final z = pos.z & ((1 << _packedHorizontalLength) - 1);

  return (x << _xOffset) | (z << _zOffset) | y;
}

/// Base class for all Dart-defined block entities.
///
/// Block entities are tile entities attached to blocks that can store
/// data, perform actions, and sync state to clients.
///
/// The lifecycle mirrors Java's BlockEntity:
/// - [setLevel] - Called when the block entity is added to a level
/// - [loadAdditional] - Called when loading saved NBT data
/// - [saveAdditional] - Called when saving state to NBT
/// - [setRemoved] - Called when removed from the world
///
/// ## Example
///
/// ```dart
/// class MyBlockEntity extends BlockEntity {
///   MyBlockEntity() : super(
///     settings: BlockEntitySettings(id: 'mymod:my_block_entity'),
///   );
///
///   @override
///   void setLevel() {
///     // Called when block entity is added to the world
///   }
///
///   @override
///   void loadAdditional(Map<String, dynamic> nbt) {
///     // Load saved state from NBT
///   }
///
///   @override
///   Map<String, dynamic> saveAdditional() {
///     return {'myData': 42};
///   }
/// }
/// ```
abstract class BlockEntity {
  /// Settings for this block entity type.
  final BlockEntitySettings settings;

  /// Handler ID assigned by the registry.
  /// Used to route callbacks to the correct block entity type.
  int? handlerId;

  /// Hash of the block position in the world.
  /// Used to identify this specific block entity instance.
  int? blockPosHash;

  /// Creates a block entity with the given settings.
  BlockEntity({required this.settings});

  /// Get the string ID of this block entity type.
  String get id => settings.id;

  /// Get the block position of this block entity.
  /// Returns null if blockPosHash is not set.
  BlockPos? get blockPos {
    final hash = blockPosHash;
    if (hash == null) return null;
    return decodeBlockPos(hash);
  }

  /// Called when the block entity is added to a level.
  ///
  /// This is called for both newly placed blocks and blocks loaded from save.
  /// Override to perform initialization that requires access to the world.
  ///
  /// Note: [blockPos] is available when this is called.
  void setLevel() {}

  /// Called when the block entity is loaded from saved NBT data.
  ///
  /// Override to restore state when the chunk is loaded or the world starts.
  /// This is only called when there is saved data to load.
  void loadAdditional(Map<String, dynamic> nbt) {}

  /// Called when the block entity needs to save its state to NBT.
  ///
  /// Override to persist state when the chunk is saved or the world stops.
  /// Return a map of key-value pairs to save.
  Map<String, dynamic> saveAdditional() => {};

  /// Called when the block entity is removed from the world.
  ///
  /// Override to perform cleanup when the block is broken or replaced.
  void setRemoved() {}
}

/// Mixin for block entities that need to handle container open/close events.
///
/// Implement this mixin in your block entity to receive callbacks when
/// a player opens or closes the container UI.
///
/// ## Example
///
/// ```dart
/// class MyChestEntity extends ContainerBlockEntity<MyChestContainer>
///     with ContainerOpenCloseHandler {
///   @override
///   void onContainerOpen() {
///     // Start some action when player opens the chest
///   }
///
///   @override
///   void onContainerClose() {
///     // Stop when player closes the chest
///   }
/// }
/// ```
mixin ContainerOpenCloseHandler on BlockEntity {
  /// Called when a player opens this container.
  void onContainerOpen();

  /// Called when a player closes this container.
  void onContainerClose();
}
