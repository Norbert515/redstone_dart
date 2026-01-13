/// Internal JNI exports - not for public use.
///
/// This file is imported directly by dart_mod_server and dart_mod_client
/// packages that need JNI access. It is NOT exported from the main
/// dart_mod_common.dart barrel file to prevent mod developers from
/// accidentally depending on internal JNI APIs.
library;

export 'generic_bridge.dart';
export 'jni.dart';
export 'java_object.dart';
