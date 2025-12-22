/// Registry for Dart-defined items.
library;

import 'dart:convert';
import 'dart:io';

import 'custom_item.dart';
import '../src/jni/generic_bridge.dart';

/// Registry for Dart-defined items.
///
/// All items must be registered during mod initialization (before Minecraft's
/// registry freezes). Attempting to register items after initialization will fail.
///
/// Example:
/// ```dart
/// void onModInit() {
///   ItemRegistry.register(DartItem());
///   // ... register all your items
/// }
/// ```
class ItemRegistry {
  static final Map<int, CustomItem> _items = {};
  static bool _frozen = false;

  ItemRegistry._(); // Private constructor - all static

  /// Register a custom item.
  ///
  /// Must be called during mod initialization, before the registry freezes.
  /// Throws [StateError] if called after initialization.
  ///
  /// Returns the handler ID assigned to this item.
  static int register(CustomItem item) {
    if (_frozen) {
      throw StateError(
        'Cannot register items after initialization. '
        'Item: ${item.id}',
      );
    }

    if (item.isRegistered) {
      throw StateError('Item already registered: ${item.id}');
    }

    // Parse the identifier
    final parts = item.id.split(':');
    if (parts.length != 2) {
      throw ArgumentError(
        'Invalid item ID format. Expected "namespace:path", got: ${item.id}',
      );
    }
    final namespace = parts[0];
    final path = parts[1];

    // Extract combat values (use NaN for "not set")
    final combat = item.settings.combat;
    final attackDamage = combat?.attackDamage ?? double.nan;
    final attackSpeed = combat?.attackSpeed ?? double.nan;
    final attackKnockback = combat?.attackKnockback ?? double.nan;

    // Create the proxy item in Java
    final handlerId = GenericJniBridge.callStaticLongMethod(
      'com/redstone/proxy/ProxyRegistry',
      'createItem',
      '(IIZDDD)J',
      [
        item.settings.maxStackSize,
        item.settings.maxDamage,
        item.settings.fireResistant,
        attackDamage,
        attackSpeed,
        attackKnockback,
      ],
    );

    if (handlerId == 0) {
      throw StateError('Failed to create proxy item for: ${item.id}');
    }

    // Register with Minecraft's registry
    final success = GenericJniBridge.callStaticBoolMethod(
      'com/redstone/proxy/ProxyRegistry',
      'registerItem',
      '(JLjava/lang/String;Ljava/lang/String;)Z',
      [handlerId, namespace, path],
    );

    if (!success) {
      throw StateError('Failed to register item with Minecraft: ${item.id}');
    }

    // Store the item and set its handler ID
    item.setHandlerId(handlerId);
    _items[handlerId] = item;

    // Write manifest after each registration
    _writeManifest();

    print('ItemRegistry: Registered ${item.id} with handler ID $handlerId');
    return handlerId;
  }

  /// Write the item manifest to `.redstone/manifest.json`.
  ///
  /// This updates the existing manifest (which may contain blocks).
  static void _writeManifest() {
    // Read existing manifest or create new
    Map<String, dynamic> manifest = {};
    final manifestFile = File('.redstone/manifest.json');
    if (manifestFile.existsSync()) {
      try {
        manifest =
            jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parse errors, start fresh
      }
    }

    // Build items list
    final items = <Map<String, dynamic>>[];
    for (final item in _items.values) {
      final itemEntry = <String, dynamic>{
        'id': item.id,
        'model': item.model.toJson(),
      };
      items.add(itemEntry);
    }

    manifest['items'] = items;

    // Create .redstone directory if it doesn't exist
    final redstoneDir = Directory('.redstone');
    if (!redstoneDir.existsSync()) {
      redstoneDir.createSync(recursive: true);
    }

    // Write manifest with pretty formatting
    final encoder = JsonEncoder.withIndent('  ');
    manifestFile.writeAsStringSync(encoder.convert(manifest));

    print('ItemRegistry: Wrote manifest with ${items.length} items');
  }

  /// Get an item by its handler ID.
  static CustomItem? getItem(int handlerId) {
    return _items[handlerId];
  }

  /// Get all registered items.
  static Iterable<CustomItem> get allItems => _items.values;

  /// Get the number of registered items.
  static int get itemCount => _items.length;

  /// Freeze the registry.
  static void freeze() {
    _frozen = true;
    print('ItemRegistry: Frozen with ${_items.length} items registered');
  }

  /// Check if the registry is frozen.
  static bool get isFrozen => _frozen;

  // ==========================================================================
  // Internal dispatch methods - called from native code
  // ==========================================================================

  /// Dispatch an item use event.
  static int dispatchItemUse(
      int handlerId, int worldId, int playerId, int hand) {
    final item = _items[handlerId];
    if (item != null) {
      final result = item.onUse(worldId, playerId, hand);
      return result.index;
    }
    return ItemActionResult.pass.index;
  }

  /// Dispatch an item use on block event.
  static int dispatchItemUseOnBlock(
    int handlerId,
    int worldId,
    int x,
    int y,
    int z,
    int playerId,
    int hand,
  ) {
    final item = _items[handlerId];
    if (item != null) {
      final result = item.onUseOnBlock(worldId, x, y, z, playerId, hand);
      return result.index;
    }
    return ItemActionResult.pass.index;
  }

  /// Dispatch an item use on entity event.
  static int dispatchItemUseOnEntity(
    int handlerId,
    int worldId,
    int entityId,
    int playerId,
    int hand,
  ) {
    final item = _items[handlerId];
    if (item != null) {
      final result = item.onUseOnEntity(worldId, entityId, playerId, hand);
      return result.index;
    }
    return ItemActionResult.pass.index;
  }

  /// Dispatches an attack entity event to the appropriate item.
  /// Called from native code when a player attacks an entity with a custom item.
  static bool dispatchItemAttackEntity(
    int handlerId,
    int worldId,
    int attackerId,
    int targetId,
  ) {
    final item = _items[handlerId];
    if (item != null) {
      return item.onAttackEntity(worldId, attackerId, targetId);
    }
    return false;
  }
}
