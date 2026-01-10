/// Block entity callback handlers for native bridge communication.
///
/// This file sets up the FFI callbacks that route block entity events
/// from the native bridge to the Dart block entity instances.
library;

import 'dart:convert';
import 'dart:ffi';

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:ffi/ffi.dart';

import '../bridge.dart';
import '../container/container_block_entity.dart';
import 'block_entity_registry.dart';

// =============================================================================
// Native Callback Type Definitions
// =============================================================================

// void (*BlockEntityLoadCallback)(int32_t handler_id, int64_t block_pos_hash, const char* nbt_json);
typedef _BlockEntityLoadCallbackNative = Void Function(
    Int32 handlerId, Int64 blockPosHash, Pointer<Utf8> nbtJson);

// const char* (*BlockEntitySaveCallback)(int32_t handler_id, int64_t block_pos_hash);
typedef _BlockEntitySaveCallbackNative = Pointer<Utf8> Function(
    Int32 handlerId, Int64 blockPosHash);

// void (*BlockEntityTickCallback)(int32_t handler_id, int64_t block_pos_hash);
typedef _BlockEntityTickCallbackNative = Void Function(
    Int32 handlerId, Int64 blockPosHash);

// int32_t (*BlockEntityGetDataSlotCallback)(int32_t handler_id, int64_t block_pos_hash, int32_t index);
typedef _BlockEntityGetDataSlotCallbackNative = Int32 Function(
    Int32 handlerId, Int64 blockPosHash, Int32 index);

// void (*BlockEntitySetDataSlotCallback)(int32_t handler_id, int64_t block_pos_hash, int32_t index, int32_t value);
typedef _BlockEntitySetDataSlotCallbackNative = Void Function(
    Int32 handlerId, Int64 blockPosHash, Int32 index, Int32 value);

// void (*BlockEntityRemovedCallback)(int32_t handler_id, int64_t block_pos_hash);
typedef _BlockEntityRemovedCallbackNative = Void Function(
    Int32 handlerId, Int64 blockPosHash);

// void (*BlockEntitySetLevelCallback)(int32_t handler_id, int64_t block_pos_hash);
typedef _BlockEntitySetLevelCallbackNative = Void Function(
    Int32 handlerId, Int64 blockPosHash);

// void (*BlockEntityContainerOpenCallback)(int32_t handler_id, int64_t block_pos_hash);
typedef _BlockEntityContainerOpenCallbackNative = Void Function(
    Int32 handlerId, Int64 blockPosHash);

// void (*BlockEntityContainerCloseCallback)(int32_t handler_id, int64_t block_pos_hash);
typedef _BlockEntityContainerCloseCallbackNative = Void Function(
    Int32 handlerId, Int64 blockPosHash);

// =============================================================================
// Callback Handlers (called from native code)
// =============================================================================

/// Handle block entity setLevel event.
/// Called when the block entity is added to a level.
@pragma('vm:entry-point')
void _onBlockEntitySetLevel(int handlerId, int blockPosHash) {
  try {
    // Get or create instance
    final instance = BlockEntityRegistry.getOrCreate(handlerId, blockPosHash);
    instance.setLevel();
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in setLevel handler: $e\n$stack');
  }
}

/// Handle block entity loadAdditional event.
/// Called when loading saved NBT data.
@pragma('vm:entry-point')
void _onBlockEntityLoadAdditional(int handlerId, int blockPosHash, Pointer<Utf8> nbtJsonPtr) {
  try {
    final nbtJson = nbtJsonPtr.toDartString();
    final nbt = nbtJson.isNotEmpty ? jsonDecode(nbtJson) as Map<String, dynamic> : <String, dynamic>{};

    // Get or create instance (should already exist from setLevel)
    final instance = BlockEntityRegistry.getOrCreate(handlerId, blockPosHash);
    instance.loadAdditional(nbt);
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in loadAdditional handler: $e\n$stack');
  }
}

/// Handle block entity saveAdditional event.
/// Returns JSON string of saved data.
@pragma('vm:entry-point')
Pointer<Utf8> _onBlockEntitySaveAdditional(int handlerId, int blockPosHash) {
  try {
    final instance = BlockEntityRegistry.get(handlerId, blockPosHash);
    if (instance == null) {
      return '{}' as Pointer<Utf8>;
    }

    final data = instance.saveAdditional();
    final json = jsonEncode(data);

    // Allocate memory for the result string
    // Note: This memory is managed by the native side
    return json.toNativeUtf8();
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in saveAdditional handler: $e\n$stack');
    return '{}' as Pointer<Utf8>;
  }
}

/// Handle block entity tick event.
@pragma('vm:entry-point')
void _onBlockEntityTick(int handlerId, int blockPosHash) {
  try {
    final instance = BlockEntityRegistry.get(handlerId, blockPosHash);
    if (instance is TickingBlockEntity) {
      instance.serverTick();
    }
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in tick handler: $e\n$stack');
  }
}

/// Handle get data slot event.
/// Returns the value of the data slot at the given index.
@pragma('vm:entry-point')
int _onBlockEntityGetDataSlot(int handlerId, int blockPosHash, int index) {
  try {
    final instance = BlockEntityRegistry.get(handlerId, blockPosHash);
    if (instance is ProcessingBlockEntity) {
      return instance.getDataSlot(index);
    } else if (instance is ContainerBlockEntity) {
      return instance.getDataSlot(index);
    }
    return 0;
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in get data slot handler: $e\n$stack');
    return 0;
  }
}

/// Handle set data slot event.
@pragma('vm:entry-point')
void _onBlockEntitySetDataSlot(int handlerId, int blockPosHash, int index, int value) {
  try {
    final instance = BlockEntityRegistry.get(handlerId, blockPosHash);
    if (instance is ProcessingBlockEntity) {
      instance.setDataSlot(index, value);
    } else if (instance is ContainerBlockEntity) {
      instance.setDataSlot(index, value);
    }
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in set data slot handler: $e\n$stack');
  }
}

/// Handle block entity setRemoved event.
@pragma('vm:entry-point')
void _onBlockEntitySetRemoved(int handlerId, int blockPosHash) {
  try {
    final instance = BlockEntityRegistry.get(handlerId, blockPosHash);
    instance?.setRemoved();
    BlockEntityRegistry.remove(handlerId, blockPosHash);
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in setRemoved handler: $e\n$stack');
  }
}

/// Handle container open event.
/// Called when a player opens a block entity's container.
@pragma('vm:entry-point')
void _onBlockEntityContainerOpen(int handlerId, int blockPosHash) {
  print('BlockEntityCallbacks: _onBlockEntityContainerOpen called! handlerId=$handlerId, blockPosHash=$blockPosHash');
  try {
    final instance = BlockEntityRegistry.get(handlerId, blockPosHash);
    print('BlockEntityCallbacks: Got instance: $instance, is ContainerOpenCloseHandler: ${instance is ContainerOpenCloseHandler}');
    if (instance is ContainerOpenCloseHandler) {
      print('BlockEntityCallbacks: Calling onContainerOpen on instance');
      instance.onContainerOpen();
    }
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in container open handler: $e\n$stack');
  }
}

/// Handle container close event.
/// Called when a player closes a block entity's container.
@pragma('vm:entry-point')
void _onBlockEntityContainerClose(int handlerId, int blockPosHash) {
  print('BlockEntityCallbacks: _onBlockEntityContainerClose called! handlerId=$handlerId, blockPosHash=$blockPosHash');
  try {
    final instance = BlockEntityRegistry.get(handlerId, blockPosHash);
    print('BlockEntityCallbacks: Got instance: $instance, is ContainerOpenCloseHandler: ${instance is ContainerOpenCloseHandler}');
    if (instance is ContainerOpenCloseHandler) {
      print('BlockEntityCallbacks: Calling onContainerClose on instance');
      instance.onContainerClose();
    }
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in container close handler: $e\n$stack');
  }
}

// =============================================================================
// Initialization
// =============================================================================

bool _initialized = false;

/// Initialize block entity callbacks.
///
/// This registers the native callbacks with the bridge. Call this once
/// during mod initialization.
void initBlockEntityCallbacks() {
  if (_initialized) return;
  if (ServerBridge.isDatagenMode) {
    _initialized = true;
    print('BlockEntityCallbacks: Skipped initialization (datagen mode)');
    return;
  }

  final lib = ServerBridge.library;

  // Register setLevel handler (called when block entity is added to level)
  final registerSetLevel = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntitySetLevelCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntitySetLevelCallbackNative>>)>(
      'server_register_block_entity_set_level_handler');
  registerSetLevel(Pointer.fromFunction<_BlockEntitySetLevelCallbackNative>(_onBlockEntitySetLevel));

  // Register loadAdditional handler (called when loading from NBT)
  final registerLoad = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntityLoadCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntityLoadCallbackNative>>)>(
      'server_register_block_entity_load_handler');
  registerLoad(Pointer.fromFunction<_BlockEntityLoadCallbackNative>(_onBlockEntityLoadAdditional));

  // Register saveAdditional handler
  final registerSave = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntitySaveCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntitySaveCallbackNative>>)>(
      'server_register_block_entity_save_handler');
  registerSave(Pointer.fromFunction<_BlockEntitySaveCallbackNative>(_onBlockEntitySaveAdditional));

  // Register tick handler
  final registerTick = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntityTickCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntityTickCallbackNative>>)>(
      'server_register_block_entity_tick_handler');
  registerTick(Pointer.fromFunction<_BlockEntityTickCallbackNative>(_onBlockEntityTick));

  // Register get data slot handler
  final registerGetDataSlot = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntityGetDataSlotCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntityGetDataSlotCallbackNative>>)>(
      'server_register_block_entity_get_data_slot_handler');
  registerGetDataSlot(
      Pointer.fromFunction<_BlockEntityGetDataSlotCallbackNative>(_onBlockEntityGetDataSlot, 0));

  // Register set data slot handler
  final registerSetDataSlot = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntitySetDataSlotCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntitySetDataSlotCallbackNative>>)>(
      'server_register_block_entity_set_data_slot_handler');
  registerSetDataSlot(
      Pointer.fromFunction<_BlockEntitySetDataSlotCallbackNative>(_onBlockEntitySetDataSlot));

  // Register setRemoved handler
  final registerRemoved = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntityRemovedCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntityRemovedCallbackNative>>)>(
      'server_register_block_entity_removed_handler');
  registerRemoved(Pointer.fromFunction<_BlockEntityRemovedCallbackNative>(_onBlockEntitySetRemoved));

  // Register container open handler
  final registerContainerOpen = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntityContainerOpenCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntityContainerOpenCallbackNative>>)>(
      'server_register_block_entity_container_open_handler');
  registerContainerOpen(Pointer.fromFunction<_BlockEntityContainerOpenCallbackNative>(_onBlockEntityContainerOpen));

  // Register container close handler
  final registerContainerClose = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntityContainerCloseCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntityContainerCloseCallbackNative>>)>(
      'server_register_block_entity_container_close_handler');
  registerContainerClose(Pointer.fromFunction<_BlockEntityContainerCloseCallbackNative>(_onBlockEntityContainerClose));

  // Enable JNI-based inventory access for block entities on the server
  BlockEntityWithInventory.enableJniInventoryAccess();

  _initialized = true;
  print('BlockEntityCallbacks: Initialized (JNI inventory access enabled)');
}
