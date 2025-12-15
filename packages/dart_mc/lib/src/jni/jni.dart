/// Generic JNI bindings for calling Java methods from Dart.
///
/// This library provides a generic interface to call any Java method through JNI,
/// without needing to generate specific bindings for each class.
///
/// ## Usage
///
/// First, ensure the bridge is initialized (typically done automatically by Bridge):
/// ```dart
/// GenericJniBridge.init();
/// ```
///
/// ### Creating Objects
/// ```dart
/// // Create a new ArrayList
/// final list = JavaObject.create('java/util/ArrayList', '()V');
///
/// // Call methods on it
/// list.callVoid('add', '(Ljava/lang/Object;)Z', [someObject]);
/// final size = list.callInt('size', '()I');
///
/// // Don't forget to release when done
/// list.release();
/// ```
///
/// ### Calling Static Methods
/// ```dart
/// // Call a static method
/// final value = JavaStatic.callInt(
///   'java/lang/Integer',
///   'parseInt',
///   '(Ljava/lang/String;)I',
///   ['42'],
/// );
/// ```
///
/// ### Type-safe Wrappers
/// For frequently used classes, create wrapper classes:
/// ```dart
/// class ArrayList extends JavaObject {
///   ArrayList() : super.create('java/util/ArrayList', '()V');
///   ArrayList.fromHandle(int handle) : super(handle, 'java/util/ArrayList');
///
///   bool add(JavaObject element) => callBool('add', '(Ljava/lang/Object;)Z', [element]);
///   int get size => callInt('size', '()I');
///   JavaObject? get(int index) => callObjectWrapped('get', '(I)Ljava/lang/Object;', 'java/lang/Object', [index]);
/// }
/// ```
library;

export 'generic_bridge.dart' show GenericJniBridge, JavaObjectHandle;
export 'java_object.dart' show JavaObject, JavaStatic, JniException;
