/// Low-level FFI bindings to the generic JNI bridge.
///
/// This provides a Dart interface to call arbitrary Java methods through JNI.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ============================================================================
// Native Function Type Definitions
// ============================================================================

// Object Creation
typedef NativeCreateObject = Int64 Function(
    Pointer<Utf8> className,
    Pointer<Utf8> ctorSig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCreateObject = int Function(
    Pointer<Utf8> className,
    Pointer<Utf8> ctorSig,
    Pointer<Int64> args,
    int argCount);

// Instance Method Calls - Void
typedef NativeCallVoidMethod = Void Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallVoidMethod = void Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Instance Method Calls - Int
typedef NativeCallIntMethod = Int32 Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallIntMethod = int Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Instance Method Calls - Long
typedef NativeCallLongMethod = Int64 Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallLongMethod = int Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Instance Method Calls - Double
typedef NativeCallDoubleMethod = Double Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallDoubleMethod = double Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Instance Method Calls - Float
typedef NativeCallFloatMethod = Float Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallFloatMethod = double Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Instance Method Calls - Bool
typedef NativeCallBoolMethod = Bool Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallBoolMethod = bool Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Instance Method Calls - Object
typedef NativeCallObjectMethod = Int64 Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallObjectMethod = int Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Instance Method Calls - String
typedef NativeCallStringMethod = Pointer<Utf8> Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallStringMethod = Pointer<Utf8> Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Static Method Calls - Void
typedef NativeCallStaticVoidMethod = Void Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallStaticVoidMethod = void Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Static Method Calls - Int
typedef NativeCallStaticIntMethod = Int32 Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallStaticIntMethod = int Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Static Method Calls - Long
typedef NativeCallStaticLongMethod = Int64 Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallStaticLongMethod = int Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Static Method Calls - Object
typedef NativeCallStaticObjectMethod = Int64 Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallStaticObjectMethod = int Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Static Method Calls - String
typedef NativeCallStaticStringMethod = Pointer<Utf8> Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallStaticStringMethod = Pointer<Utf8> Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Static Method Calls - Double
typedef NativeCallStaticDoubleMethod = Double Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallStaticDoubleMethod = double Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Static Method Calls - Bool
typedef NativeCallStaticBoolMethod = Bool Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    Int32 argCount);
typedef DartCallStaticBoolMethod = bool Function(
    Pointer<Utf8> className,
    Pointer<Utf8> methodName,
    Pointer<Utf8> sig,
    Pointer<Int64> args,
    int argCount);

// Field Access - Object
typedef NativeGetObjectField = Int64 Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);
typedef DartGetObjectField = int Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);

// Field Access - Int
typedef NativeGetIntField = Int32 Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);
typedef DartGetIntField = int Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);

// Field Access - Long
typedef NativeGetLongField = Int64 Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);
typedef DartGetLongField = int Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);

// Field Access - Double
typedef NativeGetDoubleField = Double Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);
typedef DartGetDoubleField = double Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);

// Field Access - Bool
typedef NativeGetBoolField = Bool Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);
typedef DartGetBoolField = bool Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);

// Field Access - String
typedef NativeGetStringField = Pointer<Utf8> Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);
typedef DartGetStringField = Pointer<Utf8> Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);

// Field Setters
typedef NativeSetIntField = Void Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig,
    Int32 value);
typedef DartSetIntField = void Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig,
    int value);

typedef NativeSetLongField = Void Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig,
    Int64 value);
typedef DartSetLongField = void Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig,
    int value);

typedef NativeSetDoubleField = Void Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig,
    Double value);
typedef DartSetDoubleField = void Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig,
    double value);

typedef NativeSetBoolField = Void Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig,
    Bool value);
typedef DartSetBoolField = void Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig,
    bool value);

typedef NativeSetObjectField = Void Function(
    Int64 handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig,
    Int64 valueHandle);
typedef DartSetObjectField = void Function(
    int handle,
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig,
    int valueHandle);

// Static Field Access
typedef NativeGetStaticObjectField = Int64 Function(
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);
typedef DartGetStaticObjectField = int Function(
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);

typedef NativeGetStaticIntField = Int32 Function(
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);
typedef DartGetStaticIntField = int Function(
    Pointer<Utf8> className,
    Pointer<Utf8> fieldName,
    Pointer<Utf8> sig);

// Object Lifecycle
typedef NativeReleaseObject = Void Function(Int64 handle);
typedef DartReleaseObject = void Function(int handle);

typedef NativeFreeString = Void Function(Pointer<Utf8> str);
typedef DartFreeString = void Function(Pointer<Utf8> str);

// ============================================================================
// GenericJniBridge Class
// ============================================================================

/// Low-level generic JNI bridge bindings.
///
/// Provides FFI access to the C++ JNI dispatcher which allows calling
/// arbitrary Java methods from Dart.
class GenericJniBridge {
  static late DynamicLibrary _lib;
  static bool _initialized = false;

  /// Whether we're running in datagen mode (stub mode).
  static bool _datagenMode = false;

  /// Counter for generating fake handler IDs in datagen mode.
  static int _nextHandlerId = 1;

  // Function pointers - Object Creation
  static late DartCreateObject _createObject;

  // Function pointers - Instance Methods
  static late DartCallVoidMethod _callVoidMethod;
  static late DartCallIntMethod _callIntMethod;
  static late DartCallLongMethod _callLongMethod;
  static late DartCallDoubleMethod _callDoubleMethod;
  static late DartCallFloatMethod _callFloatMethod;
  static late DartCallBoolMethod _callBoolMethod;
  static late DartCallObjectMethod _callObjectMethod;
  static late DartCallStringMethod _callStringMethod;

  // Function pointers - Static Methods
  static late DartCallStaticVoidMethod _callStaticVoidMethod;
  static late DartCallStaticIntMethod _callStaticIntMethod;
  static late DartCallStaticLongMethod _callStaticLongMethod;
  static late DartCallStaticObjectMethod _callStaticObjectMethod;
  static late DartCallStaticStringMethod _callStaticStringMethod;
  static late DartCallStaticDoubleMethod _callStaticDoubleMethod;
  static late DartCallStaticBoolMethod _callStaticBoolMethod;

  // Function pointers - Field Access
  static late DartGetObjectField _getObjectField;
  static late DartGetIntField _getIntField;
  static late DartGetLongField _getLongField;
  static late DartGetDoubleField _getDoubleField;
  static late DartGetBoolField _getBoolField;
  static late DartGetStringField _getStringField;
  static late DartSetIntField _setIntField;
  static late DartSetLongField _setLongField;
  static late DartSetDoubleField _setDoubleField;
  static late DartSetBoolField _setBoolField;
  static late DartSetObjectField _setObjectField;

  // Function pointers - Static Fields
  static late DartGetStaticObjectField _getStaticObjectField;
  static late DartGetStaticIntField _getStaticIntField;

  // Function pointers - Lifecycle
  static late DartReleaseObject _releaseObject;
  static late DartFreeString _freeString;

  /// Initialize the bridge. Call once at startup.
  static void init() {
    if (_initialized) return;

    // Check for datagen mode via environment variable
    final datagenEnv = Platform.environment['REDSTONE_DATAGEN'];
    if (datagenEnv == 'true' || datagenEnv == '1') {
      _datagenMode = true;
      _initialized = true;
      print('GenericJniBridge: Running in DATAGEN mode (stub JNI)');
      return;
    }

    // In embedded mode, symbols are in the current process
    _lib = DynamicLibrary.process();

    // Object Creation
    _createObject = _lib
        .lookupFunction<NativeCreateObject, DartCreateObject>('jni_create_object');

    // Instance Methods
    _callVoidMethod = _lib.lookupFunction<NativeCallVoidMethod, DartCallVoidMethod>(
        'jni_call_void_method');
    _callIntMethod = _lib.lookupFunction<NativeCallIntMethod, DartCallIntMethod>(
        'jni_call_int_method');
    _callLongMethod = _lib.lookupFunction<NativeCallLongMethod, DartCallLongMethod>(
        'jni_call_long_method');
    _callDoubleMethod = _lib.lookupFunction<NativeCallDoubleMethod, DartCallDoubleMethod>(
        'jni_call_double_method');
    _callFloatMethod = _lib.lookupFunction<NativeCallFloatMethod, DartCallFloatMethod>(
        'jni_call_float_method');
    _callBoolMethod = _lib.lookupFunction<NativeCallBoolMethod, DartCallBoolMethod>(
        'jni_call_bool_method');
    _callObjectMethod = _lib.lookupFunction<NativeCallObjectMethod, DartCallObjectMethod>(
        'jni_call_object_method');
    _callStringMethod = _lib.lookupFunction<NativeCallStringMethod, DartCallStringMethod>(
        'jni_call_string_method');

    // Static Methods
    _callStaticVoidMethod =
        _lib.lookupFunction<NativeCallStaticVoidMethod, DartCallStaticVoidMethod>(
            'jni_call_static_void_method');
    _callStaticIntMethod =
        _lib.lookupFunction<NativeCallStaticIntMethod, DartCallStaticIntMethod>(
            'jni_call_static_int_method');
    _callStaticLongMethod =
        _lib.lookupFunction<NativeCallStaticLongMethod, DartCallStaticLongMethod>(
            'jni_call_static_long_method');
    _callStaticObjectMethod =
        _lib.lookupFunction<NativeCallStaticObjectMethod, DartCallStaticObjectMethod>(
            'jni_call_static_object_method');
    _callStaticStringMethod =
        _lib.lookupFunction<NativeCallStaticStringMethod, DartCallStaticStringMethod>(
            'jni_call_static_string_method');
    _callStaticDoubleMethod =
        _lib.lookupFunction<NativeCallStaticDoubleMethod, DartCallStaticDoubleMethod>(
            'jni_call_static_double_method');
    _callStaticBoolMethod =
        _lib.lookupFunction<NativeCallStaticBoolMethod, DartCallStaticBoolMethod>(
            'jni_call_static_bool_method');

    // Field Access
    _getObjectField = _lib.lookupFunction<NativeGetObjectField, DartGetObjectField>(
        'jni_get_object_field');
    _getIntField = _lib.lookupFunction<NativeGetIntField, DartGetIntField>(
        'jni_get_int_field');
    _getLongField = _lib.lookupFunction<NativeGetLongField, DartGetLongField>(
        'jni_get_long_field');
    _getDoubleField = _lib.lookupFunction<NativeGetDoubleField, DartGetDoubleField>(
        'jni_get_double_field');
    _getBoolField = _lib.lookupFunction<NativeGetBoolField, DartGetBoolField>(
        'jni_get_bool_field');
    _getStringField = _lib.lookupFunction<NativeGetStringField, DartGetStringField>(
        'jni_get_string_field');
    _setIntField = _lib.lookupFunction<NativeSetIntField, DartSetIntField>(
        'jni_set_int_field');
    _setLongField = _lib.lookupFunction<NativeSetLongField, DartSetLongField>(
        'jni_set_long_field');
    _setDoubleField = _lib.lookupFunction<NativeSetDoubleField, DartSetDoubleField>(
        'jni_set_double_field');
    _setBoolField = _lib.lookupFunction<NativeSetBoolField, DartSetBoolField>(
        'jni_set_bool_field');
    _setObjectField = _lib.lookupFunction<NativeSetObjectField, DartSetObjectField>(
        'jni_set_object_field');

    // Static Fields
    _getStaticObjectField =
        _lib.lookupFunction<NativeGetStaticObjectField, DartGetStaticObjectField>(
            'jni_get_static_object_field');
    _getStaticIntField =
        _lib.lookupFunction<NativeGetStaticIntField, DartGetStaticIntField>(
            'jni_get_static_int_field');

    // Lifecycle
    _releaseObject = _lib.lookupFunction<NativeReleaseObject, DartReleaseObject>(
        'jni_release_object');
    _freeString =
        _lib.lookupFunction<NativeFreeString, DartFreeString>('jni_free_string');

    _initialized = true;
  }

  /// Check if the bridge is initialized.
  static bool get isInitialized => _initialized;

  // ==========================================================================
  // Argument Encoding Helpers
  // ==========================================================================

  /// Encode a list of arguments into a native int64 array.
  ///
  /// Supports: int, double, bool, String, and JavaObject (via handle property).
  /// Returns a [_EncodedArgs] that must be freed after use.
  static _EncodedArgs _encodeArgs(List<Object?> args) {
    if (args.isEmpty) {
      return _EncodedArgs(nullptr, []);
    }

    final ptr = calloc<Int64>(args.length);
    final allocatedStrings = <Pointer<Utf8>>[];

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == null) {
        ptr[i] = 0; // null object handle
      } else if (arg is int) {
        ptr[i] = arg;
      } else if (arg is double) {
        // Encode double bits as int64
        final bd = ByteData(8);
        bd.setFloat64(0, arg, Endian.host);
        ptr[i] = bd.getInt64(0, Endian.host);
      } else if (arg is bool) {
        ptr[i] = arg ? 1 : 0;
      } else if (arg is String) {
        final strPtr = arg.toNativeUtf8();
        allocatedStrings.add(strPtr);
        ptr[i] = strPtr.address;
      } else if (arg is JavaObjectHandle) {
        ptr[i] = arg.handle;
      } else {
        // Clean up already allocated memory
        for (final str in allocatedStrings) {
          calloc.free(str);
        }
        calloc.free(ptr);
        throw ArgumentError('Unsupported argument type: ${arg.runtimeType}');
      }
    }

    return _EncodedArgs(ptr, allocatedStrings);
  }

  // ==========================================================================
  // Object Creation
  // ==========================================================================

  /// Create a new Java object.
  ///
  /// [className] - Fully qualified class name with slashes (e.g., "java/util/ArrayList")
  /// [ctorSig] - Constructor signature (e.g., "()V" or "(I)V")
  /// [args] - Constructor arguments
  ///
  /// Returns handle to the new object, or 0 on failure.
  static int createObject(
    String className,
    String ctorSig, [
    List<Object?> args = const [],
  ]) {
    final classNamePtr = className.toNativeUtf8();
    final ctorSigPtr = ctorSig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      return _createObject(
        classNamePtr,
        ctorSigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(ctorSigPtr);
      encodedArgs.free();
    }
  }

  // ==========================================================================
  // Instance Method Calls
  // ==========================================================================

  /// Call a void method on an object.
  static void callVoidMethod(
    int handle,
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      _callVoidMethod(
        handle,
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a method returning int.
  static int callIntMethod(
    int handle,
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      return _callIntMethod(
        handle,
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a method returning long.
  static int callLongMethod(
    int handle,
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      return _callLongMethod(
        handle,
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a method returning double.
  static double callDoubleMethod(
    int handle,
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      return _callDoubleMethod(
        handle,
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a method returning float.
  static double callFloatMethod(
    int handle,
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      return _callFloatMethod(
        handle,
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a method returning boolean.
  static bool callBoolMethod(
    int handle,
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      return _callBoolMethod(
        handle,
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a method returning an object.
  ///
  /// Returns handle to the returned object, or 0 if null/failure.
  static int callObjectMethod(
    int handle,
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      return _callObjectMethod(
        handle,
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a method returning String.
  ///
  /// Returns the string value, or null if the Java method returned null.
  static String? callStringMethod(
    int handle,
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      final resultPtr = _callStringMethod(
        handle,
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );

      if (resultPtr == nullptr) return null;

      final result = resultPtr.toDartString();
      _freeString(resultPtr);
      return result;
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  // ==========================================================================
  // Static Method Calls
  // ==========================================================================

  /// Call a static void method.
  static void callStaticVoidMethod(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    // In datagen mode, no-op
    if (_datagenMode) {
      return;
    }

    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      _callStaticVoidMethod(
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a static method returning int.
  static int callStaticIntMethod(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    // In datagen mode, return 0
    if (_datagenMode) {
      print('[GenericJniBridge] callStaticIntMethod in DATAGEN mode, returning 0');
      return 0;
    }

    if (!_initialized) {
      print('[GenericJniBridge] callStaticIntMethod called but NOT INITIALIZED!');
      return 0;
    }

    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      final result = _callStaticIntMethod(
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
      return result;
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a static method returning long.
  static int callStaticLongMethod(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    // In datagen mode, return incrementing handler IDs
    if (_datagenMode) {
      return _nextHandlerId++;
    }

    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      return _callStaticLongMethod(
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a static method returning an object.
  static int callStaticObjectMethod(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    // In datagen mode, return 0 (null handle)
    if (_datagenMode) {
      return 0;
    }

    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      return _callStaticObjectMethod(
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a static method returning String.
  static String? callStaticStringMethod(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    // In datagen mode, return null
    if (_datagenMode) {
      return null;
    }

    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      final resultPtr = _callStaticStringMethod(
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );

      if (resultPtr == nullptr) return null;

      final result = resultPtr.toDartString();
      _freeString(resultPtr);
      return result;
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a static method returning double.
  static double callStaticDoubleMethod(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    // In datagen mode, return 0.0
    if (_datagenMode) {
      return 0.0;
    }

    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      return _callStaticDoubleMethod(
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  /// Call a static method returning boolean.
  static bool callStaticBoolMethod(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    // In datagen mode, return true (success)
    if (_datagenMode) {
      return true;
    }

    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();
    final encodedArgs = _encodeArgs(args);

    try {
      return _callStaticBoolMethod(
        classNamePtr,
        methodNamePtr,
        sigPtr,
        encodedArgs.ptr,
        args.length,
      );
    } finally {
      calloc.free(classNamePtr);
      calloc.free(methodNamePtr);
      calloc.free(sigPtr);
      encodedArgs.free();
    }
  }

  // ==========================================================================
  // Field Access
  // ==========================================================================

  /// Get an object field value.
  static int getObjectField(
    int handle,
    String className,
    String fieldName,
    String sig,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      return _getObjectField(handle, classNamePtr, fieldNamePtr, sigPtr);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  /// Get an int field value.
  static int getIntField(
    int handle,
    String className,
    String fieldName,
    String sig,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      return _getIntField(handle, classNamePtr, fieldNamePtr, sigPtr);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  /// Get a long field value.
  static int getLongField(
    int handle,
    String className,
    String fieldName,
    String sig,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      return _getLongField(handle, classNamePtr, fieldNamePtr, sigPtr);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  /// Get a double field value.
  static double getDoubleField(
    int handle,
    String className,
    String fieldName,
    String sig,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      return _getDoubleField(handle, classNamePtr, fieldNamePtr, sigPtr);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  /// Get a boolean field value.
  static bool getBoolField(
    int handle,
    String className,
    String fieldName,
    String sig,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      return _getBoolField(handle, classNamePtr, fieldNamePtr, sigPtr);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  /// Get a String field value.
  static String? getStringField(
    int handle,
    String className,
    String fieldName,
    String sig,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      final resultPtr = _getStringField(handle, classNamePtr, fieldNamePtr, sigPtr);
      if (resultPtr == nullptr) return null;

      final result = resultPtr.toDartString();
      _freeString(resultPtr);
      return result;
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  /// Set an int field value.
  static void setIntField(
    int handle,
    String className,
    String fieldName,
    String sig,
    int value,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      _setIntField(handle, classNamePtr, fieldNamePtr, sigPtr, value);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  /// Set a long field value.
  static void setLongField(
    int handle,
    String className,
    String fieldName,
    String sig,
    int value,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      _setLongField(handle, classNamePtr, fieldNamePtr, sigPtr, value);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  /// Set a double field value.
  static void setDoubleField(
    int handle,
    String className,
    String fieldName,
    String sig,
    double value,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      _setDoubleField(handle, classNamePtr, fieldNamePtr, sigPtr, value);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  /// Set a boolean field value.
  static void setBoolField(
    int handle,
    String className,
    String fieldName,
    String sig,
    bool value,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      _setBoolField(handle, classNamePtr, fieldNamePtr, sigPtr, value);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  /// Set an object field value.
  static void setObjectField(
    int handle,
    String className,
    String fieldName,
    String sig,
    int valueHandle,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      _setObjectField(handle, classNamePtr, fieldNamePtr, sigPtr, valueHandle);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  // ==========================================================================
  // Static Field Access
  // ==========================================================================

  /// Get a static object field value.
  static int getStaticObjectField(
    String className,
    String fieldName,
    String sig,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      return _getStaticObjectField(classNamePtr, fieldNamePtr, sigPtr);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  /// Get a static int field value.
  static int getStaticIntField(
    String className,
    String fieldName,
    String sig,
  ) {
    final classNamePtr = className.toNativeUtf8();
    final fieldNamePtr = fieldName.toNativeUtf8();
    final sigPtr = sig.toNativeUtf8();

    try {
      return _getStaticIntField(classNamePtr, fieldNamePtr, sigPtr);
    } finally {
      calloc.free(classNamePtr);
      calloc.free(fieldNamePtr);
      calloc.free(sigPtr);
    }
  }

  // ==========================================================================
  // Object Lifecycle
  // ==========================================================================

  /// Release an object handle, allowing Java to garbage collect it.
  static void releaseObject(int handle) {
    _releaseObject(handle);
  }

  /// Free a string returned by native code. (Internal use)
  static void freeString(Pointer<Utf8> str) {
    _freeString(str);
  }
}

// ============================================================================
// Helper Classes
// ============================================================================

/// Interface for objects that hold a Java object handle.
abstract interface class JavaObjectHandle {
  int get handle;
}

/// Helper class for managing encoded arguments and their cleanup.
class _EncodedArgs {
  final Pointer<Int64> ptr;
  final List<Pointer<Utf8>> _allocatedStrings;

  _EncodedArgs(this.ptr, this._allocatedStrings);

  void free() {
    for (final str in _allocatedStrings) {
      calloc.free(str);
    }
    if (ptr != nullptr) {
      calloc.free(ptr);
    }
  }
}
