// Test mod script for callback testing
import 'dart:ffi';
import 'dart:io';

// Callback type definitions matching the native side
typedef BlockBreakCallbackNative = Int32 Function(
    Int32 x, Int32 y, Int32 z, Int64 playerId);
typedef BlockInteractCallbackNative = Int32 Function(
    Int32 x, Int32 y, Int32 z, Int64 playerId, Int32 hand);
typedef TickCallbackNative = Void Function(Int64 tick);

// Native function signatures
typedef RegisterBlockBreakHandlerNative = Void Function(
    Pointer<NativeFunction<BlockBreakCallbackNative>> callback);
typedef RegisterBlockBreakHandler = void Function(
    Pointer<NativeFunction<BlockBreakCallbackNative>> callback);

typedef RegisterBlockInteractHandlerNative = Void Function(
    Pointer<NativeFunction<BlockInteractCallbackNative>> callback);
typedef RegisterBlockInteractHandler = void Function(
    Pointer<NativeFunction<BlockInteractCallbackNative>> callback);

typedef RegisterTickHandlerNative = Void Function(
    Pointer<NativeFunction<TickCallbackNative>> callback);
typedef RegisterTickHandler = void Function(
    Pointer<NativeFunction<TickCallbackNative>> callback);

// Callback implementations
@pragma('vm:entry-point')
int onBlockBreak(int x, int y, int z, int playerId) {
  print('  [Dart] Block broken at ($x, $y, $z) by player $playerId');
  return 1; // Allow
}

@pragma('vm:entry-point')
int onBlockInteract(int x, int y, int z, int playerId, int hand) {
  print('  [Dart] Block interact at ($x, $y, $z) by player $playerId, hand=$hand');
  return 1; // Allow
}

@pragma('vm:entry-point')
void onTick(int tick) {
  print('  [Dart] Tick: $tick');
}

void main() {
  print('[Dart] Test mod initializing...');

  // Get the process library (symbols exported by host)
  final lib = DynamicLibrary.process();
  print('[Dart] Using process symbols');

  // Look up registration functions
  final registerBlockBreak = lib.lookupFunction<
      RegisterBlockBreakHandlerNative,
      RegisterBlockBreakHandler>('register_block_break_handler');
  final registerBlockInteract = lib.lookupFunction<
      RegisterBlockInteractHandlerNative,
      RegisterBlockInteractHandler>('register_block_interact_handler');
  final registerTick = lib.lookupFunction<
      RegisterTickHandlerNative,
      RegisterTickHandler>('register_tick_handler');

  // Register callbacks
  print('[Dart] Registering callbacks...');
  registerBlockBreak(Pointer.fromFunction<BlockBreakCallbackNative>(onBlockBreak, 0));
  registerBlockInteract(Pointer.fromFunction<BlockInteractCallbackNative>(onBlockInteract, 0));
  registerTick(Pointer.fromFunction<TickCallbackNative>(onTick));

  print('[Dart] Test mod initialized! Callbacks registered.');
}
