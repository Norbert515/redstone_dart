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

// =============================================================================
// Callback Handlers (called from native code)
// =============================================================================

/// Handle block entity load event.
@pragma('vm:entry-point')
void _onBlockEntityLoad(int handlerId, int blockPosHash, Pointer<Utf8> nbtJsonPtr) {
  try {
    final nbtJson = nbtJsonPtr.toDartString();
    final nbt = nbtJson.isNotEmpty ? jsonDecode(nbtJson) as Map<String, dynamic> : <String, dynamic>{};

    // Get or create instance
    final instance = BlockEntityRegistry.getOrCreate(handlerId, blockPosHash);
    instance.onLoad(nbt);
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in load handler: $e\n$stack');
  }
}

/// Handle block entity save event.
/// Returns JSON string of saved data.
@pragma('vm:entry-point')
Pointer<Utf8> _onBlockEntitySave(int handlerId, int blockPosHash) {
  try {
    final instance = BlockEntityRegistry.get(handlerId, blockPosHash);
    if (instance == null) {
      return '{}' as Pointer<Utf8>;
    }

    final data = instance.onSave();
    final json = jsonEncode(data);

    // Allocate memory for the result string
    // Note: This memory is managed by the native side
    return json.toNativeUtf8();
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in save handler: $e\n$stack');
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
    }
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in set data slot handler: $e\n$stack');
  }
}

/// Handle block entity removed event.
@pragma('vm:entry-point')
void _onBlockEntityRemoved(int handlerId, int blockPosHash) {
  try {
    final instance = BlockEntityRegistry.get(handlerId, blockPosHash);
    instance?.onRemoved();
    BlockEntityRegistry.remove(handlerId, blockPosHash);
  } catch (e, stack) {
    print('BlockEntityCallbacks: Error in removed handler: $e\n$stack');
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

  // Register load handler
  final registerLoad = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntityLoadCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntityLoadCallbackNative>>)>(
      'server_register_block_entity_load_handler');
  registerLoad(Pointer.fromFunction<_BlockEntityLoadCallbackNative>(_onBlockEntityLoad));

  // Register save handler
  final registerSave = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntitySaveCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntitySaveCallbackNative>>)>(
      'server_register_block_entity_save_handler');
  registerSave(Pointer.fromFunction<_BlockEntitySaveCallbackNative>(_onBlockEntitySave));

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

  // Register removed handler
  final registerRemoved = lib.lookupFunction<
      Void Function(Pointer<NativeFunction<_BlockEntityRemovedCallbackNative>>),
      void Function(Pointer<NativeFunction<_BlockEntityRemovedCallbackNative>>)>(
      'server_register_block_entity_removed_handler');
  registerRemoved(Pointer.fromFunction<_BlockEntityRemovedCallbackNative>(_onBlockEntityRemoved));

  _initialized = true;
  print('BlockEntityCallbacks: Initialized');
}
