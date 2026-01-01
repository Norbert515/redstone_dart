/// Base class for Dart-defined block entities.
library;

import 'block_entity_settings.dart';

/// Base class for all Dart-defined block entities.
///
/// Block entities are tile entities attached to blocks that can store
/// data, perform actions, and sync state to clients.
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
///   void onLoad(Map<String, dynamic> nbt) {
///     // Load saved state
///   }
///
///   @override
///   Map<String, dynamic> onSave() {
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

  /// Called when the block entity is loaded from saved NBT data.
  ///
  /// Override to restore state when the chunk is loaded or the world starts.
  void onLoad(Map<String, dynamic> nbt) {}

  /// Called when the block entity needs to save its state to NBT.
  ///
  /// Override to persist state when the chunk is saved or the world stops.
  /// Return a map of key-value pairs to save.
  Map<String, dynamic> onSave() => {};

  /// Called when the block entity is removed from the world.
  ///
  /// Override to perform cleanup when the block is broken or replaced.
  void onRemoved() {}
}
