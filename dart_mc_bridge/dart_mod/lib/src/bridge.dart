/// Native bridge bindings for communicating with the C++ layer.
///
/// This file contains the FFI bindings to the native dart_mc_bridge library.
library;

import 'dart:ffi';
import 'dart:io';

import 'jni/generic_bridge.dart';

/// Callback type definitions matching the native side
typedef BlockBreakCallbackNative = Int32 Function(
    Int32 x, Int32 y, Int32 z, Int64 playerId);
typedef BlockInteractCallbackNative = Int32 Function(
    Int32 x, Int32 y, Int32 z, Int64 playerId, Int32 hand);
typedef TickCallbackNative = Void Function(Int64 tick);

/// Proxy block callback types (for custom Dart-defined blocks)
/// Returns Bool: true to allow break, false to cancel
typedef ProxyBlockBreakCallbackNative = Bool Function(
    Int64 handlerId, Int64 worldId, Int32 x, Int32 y, Int32 z, Int64 playerId);
typedef ProxyBlockUseCallbackNative = Int32 Function(
    Int64 handlerId, Int64 worldId, Int32 x, Int32 y, Int32 z,
    Int64 playerId, Int32 hand);

/// Native function signatures
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

/// Proxy block handler registration signatures
typedef RegisterProxyBlockBreakHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyBlockBreakCallbackNative>> callback);
typedef RegisterProxyBlockBreakHandler = void Function(
    Pointer<NativeFunction<ProxyBlockBreakCallbackNative>> callback);

typedef RegisterProxyBlockUseHandlerNative = Void Function(
    Pointer<NativeFunction<ProxyBlockUseCallbackNative>> callback);
typedef RegisterProxyBlockUseHandler = void Function(
    Pointer<NativeFunction<ProxyBlockUseCallbackNative>> callback);

/// Bridge to the native library.
class Bridge {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  /// Initialize the bridge by loading the native library.
  /// When running embedded in the Dart VM (via dart_dll), the symbols
  /// are already available in the current process.
  static void initialize() {
    if (_initialized) return;

    _lib = _loadLibrary();
    _initialized = true;
    print('Bridge: Native library loaded');

    // Initialize the generic JNI bridge
    GenericJniBridge.init();
    print('Bridge: Generic JNI bridge initialized');
  }

  static DynamicLibrary _loadLibrary() {
    // When running embedded, try to use the current process first
    // (symbols are exported by the host application)
    try {
      final lib = DynamicLibrary.process();
      // Verify we can find our symbols
      lib.lookup('register_block_break_handler');
      print('Bridge: Using process symbols (embedded mode)');
      return lib;
    } catch (_) {
      // Fall back to loading from file
      print('Bridge: Falling back to file loading');
    }

    final String libraryName;
    if (Platform.isWindows) {
      libraryName = 'dart_mc_bridge.dll';
    } else if (Platform.isMacOS) {
      libraryName = 'libdart_mc_bridge.dylib';
    } else {
      libraryName = 'libdart_mc_bridge.so';
    }

    // Try multiple paths to find the library
    final paths = [
      libraryName, // Current directory
      'dart_mc_bridge.dylib', // Without lib prefix (our build)
      '../native/build/$libraryName', // Build output
      '../native/build/dart_mc_bridge.dylib', // Build output without prefix
      'native/build/lib/$libraryName',
      'native/build/dart_mc_bridge.dylib',
    ];

    for (final path in paths) {
      try {
        return DynamicLibrary.open(path);
      } catch (_) {
        // Try next path
      }
    }

    throw StateError(
        'Failed to load native library. Tried paths: ${paths.join(", ")}');
  }

  /// Get the native library instance.
  static DynamicLibrary get library {
    if (_lib == null) {
      throw StateError('Bridge not initialized. Call Bridge.initialize() first.');
    }
    return _lib!;
  }

  /// Register a block break handler.
  static void registerBlockBreakHandler(
      Pointer<NativeFunction<BlockBreakCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterBlockBreakHandlerNative,
        RegisterBlockBreakHandler>('register_block_break_handler');
    register(callback);
  }

  /// Register a block interact handler.
  static void registerBlockInteractHandler(
      Pointer<NativeFunction<BlockInteractCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterBlockInteractHandlerNative,
        RegisterBlockInteractHandler>('register_block_interact_handler');
    register(callback);
  }

  /// Register a tick handler.
  static void registerTickHandler(
      Pointer<NativeFunction<TickCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterTickHandlerNative,
        RegisterTickHandler>('register_tick_handler');
    register(callback);
  }

  /// Register a proxy block break handler.
  /// This is called when a Dart-defined custom block is broken.
  static void registerProxyBlockBreakHandler(
      Pointer<NativeFunction<ProxyBlockBreakCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyBlockBreakHandlerNative,
        RegisterProxyBlockBreakHandler>('register_proxy_block_break_handler');
    register(callback);
  }

  /// Register a proxy block use handler.
  /// This is called when a Dart-defined custom block is right-clicked.
  static void registerProxyBlockUseHandler(
      Pointer<NativeFunction<ProxyBlockUseCallbackNative>> callback) {
    final register = library.lookupFunction<RegisterProxyBlockUseHandlerNative,
        RegisterProxyBlockUseHandler>('register_proxy_block_use_handler');
    register(callback);
  }
}
