/// Base class for wrapping Java objects.
///
/// Holds a handle to a Java object and provides methods to call Java methods.
library;

import 'generic_bridge.dart';

/// Base class for Java object wrappers.
///
/// Provides a convenient Dart interface for interacting with Java objects
/// through the generic JNI bridge. Subclass this to create type-safe wrappers
/// for specific Java classes.
///
/// Example:
/// ```dart
/// class ArrayList extends JavaObject {
///   ArrayList() : super.create('java/util/ArrayList', '()V');
///
///   void add(Object element) {
///     callVoid('add', '(Ljava/lang/Object;)Z', [element]);
///   }
///
///   int size() => callInt('size', '()I');
/// }
/// ```
class JavaObject implements JavaObjectHandle {
  @override
  final int handle;

  /// The fully qualified Java class name with slashes (e.g., "java/util/ArrayList").
  final String className;

  bool _released = false;

  /// Create a JavaObject wrapper for an existing handle.
  ///
  /// Use this when you receive a handle from a JNI call that returns an object.
  JavaObject(this.handle, this.className);

  /// Create a JavaObject wrapper from an existing handle, or return null if handle is 0.
  ///
  /// This is useful for handling nullable object returns from Java methods.
  static JavaObject? fromHandle(int handle, String className) {
    if (handle == 0) return null;
    return JavaObject(handle, className);
  }

  /// Create a new Java object by calling its constructor.
  ///
  /// [className] - Fully qualified class name with slashes (e.g., "java/util/ArrayList")
  /// [ctorSig] - Constructor signature (e.g., "()V" or "(I)V")
  /// [args] - Constructor arguments (optional)
  ///
  /// Throws [JniException] if object creation fails.
  factory JavaObject.create(
    String className,
    String ctorSig, [
    List<Object?> args = const [],
  ]) {
    final handle = GenericJniBridge.createObject(className, ctorSig, args);
    if (handle == 0) {
      throw JniException('Failed to create Java object: $className');
    }
    return JavaObject(handle, className);
  }

  // ==========================================================================
  // Instance Method Calls
  // ==========================================================================

  /// Call a void method on this object.
  void callVoid(String methodName, String sig, [List<Object?> args = const []]) {
    _checkNotReleased();
    GenericJniBridge.callVoidMethod(handle, className, methodName, sig, args);
  }

  /// Call a method returning int on this object.
  int callInt(String methodName, String sig, [List<Object?> args = const []]) {
    _checkNotReleased();
    return GenericJniBridge.callIntMethod(handle, className, methodName, sig, args);
  }

  /// Call a method returning long on this object.
  int callLong(String methodName, String sig, [List<Object?> args = const []]) {
    _checkNotReleased();
    return GenericJniBridge.callLongMethod(handle, className, methodName, sig, args);
  }

  /// Call a method returning double on this object.
  double callDouble(String methodName, String sig, [List<Object?> args = const []]) {
    _checkNotReleased();
    return GenericJniBridge.callDoubleMethod(handle, className, methodName, sig, args);
  }

  /// Call a method returning float on this object.
  double callFloat(String methodName, String sig, [List<Object?> args = const []]) {
    _checkNotReleased();
    return GenericJniBridge.callFloatMethod(handle, className, methodName, sig, args);
  }

  /// Call a method returning boolean on this object.
  bool callBool(String methodName, String sig, [List<Object?> args = const []]) {
    _checkNotReleased();
    return GenericJniBridge.callBoolMethod(handle, className, methodName, sig, args);
  }

  /// Call a method returning an object on this object.
  ///
  /// Returns the handle to the returned object, or 0 if null.
  /// Use [callObjectWrapped] for a more convenient wrapped result.
  int callObject(String methodName, String sig, [List<Object?> args = const []]) {
    _checkNotReleased();
    return GenericJniBridge.callObjectMethod(handle, className, methodName, sig, args);
  }

  /// Call a method returning an object and wrap it in a JavaObject.
  ///
  /// [returnClassName] - The class name of the returned object
  ///
  /// Returns null if the Java method returned null.
  JavaObject? callObjectWrapped(
    String methodName,
    String sig,
    String returnClassName, [
    List<Object?> args = const [],
  ]) {
    final resultHandle = callObject(methodName, sig, args);
    return JavaObject.fromHandle(resultHandle, returnClassName);
  }

  /// Call a method returning String on this object.
  ///
  /// Returns null if the Java method returned null.
  String? callString(String methodName, String sig, [List<Object?> args = const []]) {
    _checkNotReleased();
    return GenericJniBridge.callStringMethod(handle, className, methodName, sig, args);
  }

  // ==========================================================================
  // Field Access
  // ==========================================================================

  /// Get an object field value.
  int getObjectField(String fieldName, String sig) {
    _checkNotReleased();
    return GenericJniBridge.getObjectField(handle, className, fieldName, sig);
  }

  /// Get an object field value wrapped in a JavaObject.
  JavaObject? getObjectFieldWrapped(String fieldName, String sig, String fieldClassName) {
    final resultHandle = getObjectField(fieldName, sig);
    return JavaObject.fromHandle(resultHandle, fieldClassName);
  }

  /// Get an int field value.
  int getIntField(String fieldName, String sig) {
    _checkNotReleased();
    return GenericJniBridge.getIntField(handle, className, fieldName, sig);
  }

  /// Get a long field value.
  int getLongField(String fieldName, String sig) {
    _checkNotReleased();
    return GenericJniBridge.getLongField(handle, className, fieldName, sig);
  }

  /// Get a double field value.
  double getDoubleField(String fieldName, String sig) {
    _checkNotReleased();
    return GenericJniBridge.getDoubleField(handle, className, fieldName, sig);
  }

  /// Get a boolean field value.
  bool getBoolField(String fieldName, String sig) {
    _checkNotReleased();
    return GenericJniBridge.getBoolField(handle, className, fieldName, sig);
  }

  /// Get a String field value.
  String? getStringField(String fieldName, String sig) {
    _checkNotReleased();
    return GenericJniBridge.getStringField(handle, className, fieldName, sig);
  }

  /// Set an int field value.
  void setIntField(String fieldName, String sig, int value) {
    _checkNotReleased();
    GenericJniBridge.setIntField(handle, className, fieldName, sig, value);
  }

  /// Set a long field value.
  void setLongField(String fieldName, String sig, int value) {
    _checkNotReleased();
    GenericJniBridge.setLongField(handle, className, fieldName, sig, value);
  }

  /// Set a double field value.
  void setDoubleField(String fieldName, String sig, double value) {
    _checkNotReleased();
    GenericJniBridge.setDoubleField(handle, className, fieldName, sig, value);
  }

  /// Set a boolean field value.
  void setBoolField(String fieldName, String sig, bool value) {
    _checkNotReleased();
    GenericJniBridge.setBoolField(handle, className, fieldName, sig, value);
  }

  /// Set an object field value.
  void setObjectField(String fieldName, String sig, int valueHandle) {
    _checkNotReleased();
    GenericJniBridge.setObjectField(handle, className, fieldName, sig, valueHandle);
  }

  /// Set an object field value from a JavaObject.
  void setObjectFieldFrom(String fieldName, String sig, JavaObject? value) {
    setObjectField(fieldName, sig, value?.handle ?? 0);
  }

  // ==========================================================================
  // Lifecycle Management
  // ==========================================================================

  /// Release the Java object reference, allowing it to be garbage collected.
  ///
  /// After calling this method, any further method calls on this object
  /// will throw a [StateError].
  void release() {
    if (!_released) {
      GenericJniBridge.releaseObject(handle);
      _released = true;
    }
  }

  /// Check if this object has been released.
  bool get isReleased => _released;

  void _checkNotReleased() {
    if (_released) {
      throw StateError('JavaObject has been released: $className');
    }
  }

  @override
  String toString() {
    if (_released) {
      return 'JavaObject($className, released)';
    }
    return 'JavaObject($className, handle=$handle)';
  }
}

/// Static method call helpers.
///
/// Use these to call static methods on Java classes without creating an instance.
class JavaStatic {
  JavaStatic._();

  /// Call a static void method.
  static void callVoid(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    GenericJniBridge.callStaticVoidMethod(className, methodName, sig, args);
  }

  /// Call a static method returning int.
  static int callInt(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    return GenericJniBridge.callStaticIntMethod(className, methodName, sig, args);
  }

  /// Call a static method returning long.
  static int callLong(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    return GenericJniBridge.callStaticLongMethod(className, methodName, sig, args);
  }

  /// Call a static method returning an object.
  static int callObject(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    return GenericJniBridge.callStaticObjectMethod(className, methodName, sig, args);
  }

  /// Call a static method returning an object and wrap it.
  static JavaObject? callObjectWrapped(
    String className,
    String methodName,
    String sig,
    String returnClassName, [
    List<Object?> args = const [],
  ]) {
    final handle = callObject(className, methodName, sig, args);
    return JavaObject.fromHandle(handle, returnClassName);
  }

  /// Call a static method returning String.
  static String? callString(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    return GenericJniBridge.callStaticStringMethod(className, methodName, sig, args);
  }

  /// Call a static method returning double.
  static double callDouble(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    return GenericJniBridge.callStaticDoubleMethod(className, methodName, sig, args);
  }

  /// Call a static method returning boolean.
  static bool callBool(
    String className,
    String methodName,
    String sig, [
    List<Object?> args = const [],
  ]) {
    return GenericJniBridge.callStaticBoolMethod(className, methodName, sig, args);
  }

  /// Get a static object field.
  static int getObjectField(String className, String fieldName, String sig) {
    return GenericJniBridge.getStaticObjectField(className, fieldName, sig);
  }

  /// Get a static object field wrapped in a JavaObject.
  static JavaObject? getObjectFieldWrapped(
    String className,
    String fieldName,
    String sig,
    String fieldClassName,
  ) {
    final handle = getObjectField(className, fieldName, sig);
    return JavaObject.fromHandle(handle, fieldClassName);
  }

  /// Get a static int field.
  static int getIntField(String className, String fieldName, String sig) {
    return GenericJniBridge.getStaticIntField(className, fieldName, sig);
  }
}

/// Exception thrown when a JNI operation fails.
class JniException implements Exception {
  final String message;

  JniException(this.message);

  @override
  String toString() => 'JniException: $message';
}
