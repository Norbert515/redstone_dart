/// Interface for objects that can be registered in a Registry.
library;

/// Interface for objects that can be registered in a [Registry].
///
/// Implement this interface to allow a type to be registered.
abstract interface class Registrable {
  /// The unique identifier in format "namespace:path" (e.g., "mymod:my_block").
  String get id;

  /// Whether this object has been registered.
  bool get isRegistered;

  /// Called by the registry to set the handler ID after registration.
  void setHandlerId(int id);
}
