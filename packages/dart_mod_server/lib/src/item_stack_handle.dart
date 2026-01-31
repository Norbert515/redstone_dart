/// Live ItemStack handle API for accessing and modifying data components.
library;

import 'dart:convert';

import 'package:dart_mod_common/src/jni/jni_internal.dart';

import 'inventory.dart';
import 'player.dart';

/// The Java class name for DartBridge.
const _dartBridge = 'com/redstone/DartBridge';

/// A handle to a live ItemStack in a player's inventory.
///
/// Unlike [ItemStack] which is a pure data snapshot, [ItemStackHandle]
/// provides live access to the actual Minecraft ItemStack, allowing you
/// to read and modify data components.
///
/// Always call [release] when done to free the handle.
///
/// Example:
/// ```dart
/// final handle = player.inventory.getHandle(0);
/// try {
///   handle.customName = 'My Sword';
///   handle.isUnbreakable = true;
///   handle.enchantments = {'minecraft:sharpness': 5};
/// } finally {
///   handle.release();
/// }
/// ```
class ItemStackHandle {
  final int _handle;
  bool _released = false;

  ItemStackHandle._(this._handle);

  /// Create a handle to an item in a player's inventory slot.
  ///
  /// Throws [StateError] if the slot is empty or handle creation fails.
  static ItemStackHandle fromPlayerSlot(Player player, int slot) {
    final handle = GenericJniBridge.callStaticLongMethod(
      _dartBridge,
      'storePlayerItemStackHandle',
      '(II)J',
      [player.id, slot],
    );
    if (handle == 0) {
      throw StateError('Failed to create handle for slot $slot');
    }
    return ItemStackHandle._(handle);
  }

  /// Release this handle. Must be called when done.
  ///
  /// After calling this, all other methods will throw [StateError].
  void release() {
    if (_released) return;
    _released = true;
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'releaseItemStackHandle',
      '(J)V',
      [_handle],
    );
  }

  void _checkReleased() {
    if (_released) throw StateError('Handle has been released');
  }

  // ==========================================================================
  // Specific Component Accessors
  // ==========================================================================

  /// Get max stack size.
  int get maxStackSize {
    _checkReleased();
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getItemMaxStackSize',
      '(J)I',
      [_handle],
    );
  }

  /// Set max stack size.
  set maxStackSize(int value) {
    _checkReleased();
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemMaxStackSize',
      '(JI)V',
      [_handle, value],
    );
  }

  /// Get current damage.
  int get damage {
    _checkReleased();
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getItemDamage',
      '(J)I',
      [_handle],
    );
  }

  /// Set current damage.
  set damage(int value) {
    _checkReleased();
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemDamage',
      '(JI)V',
      [_handle, value],
    );
  }

  /// Get max damage (durability).
  int get maxDamage {
    _checkReleased();
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getItemMaxDamage',
      '(J)I',
      [_handle],
    );
  }

  /// Set max damage (durability).
  set maxDamage(int value) {
    _checkReleased();
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemMaxDamage',
      '(JI)V',
      [_handle, value],
    );
  }

  /// Get custom name (or null if not set).
  String? get customName {
    _checkReleased();
    final result = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getItemCustomName',
      '(J)Ljava/lang/String;',
      [_handle],
    );
    return result?.isEmpty == true ? null : result;
  }

  /// Set custom name.
  set customName(String? value) {
    _checkReleased();
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemCustomName',
      '(JLjava/lang/String;)V',
      [_handle, value ?? ''],
    );
  }

  /// Get lore lines.
  List<String> get lore {
    _checkReleased();
    final json = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getItemLore',
      '(J)Ljava/lang/String;',
      [_handle],
    );
    if (json == null || json.isEmpty || json == '[]') return [];
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Set lore lines.
  set lore(List<String> value) {
    _checkReleased();
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemLore',
      '(JLjava/lang/String;)V',
      [_handle, jsonEncode(value)],
    );
  }

  /// Whether item is unbreakable.
  bool get isUnbreakable {
    _checkReleased();
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isItemUnbreakable',
      '(J)Z',
      [_handle],
    );
  }

  /// Set unbreakable state.
  set isUnbreakable(bool value) {
    _checkReleased();
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemUnbreakable',
      '(JZ)V',
      [_handle, value],
    );
  }

  /// Whether item is fire/damage resistant.
  bool get isFireResistant {
    _checkReleased();
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isItemDamageResistant',
      '(J)Z',
      [_handle],
    );
  }

  /// Set fire/damage resistant state.
  set isFireResistant(bool value) {
    _checkReleased();
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemFireResistant',
      '(JZ)V',
      [_handle, value],
    );
  }

  /// Get enchantments as map of enchantment ID to level.
  ///
  /// Example:
  /// ```dart
  /// final enchants = handle.enchantments;
  /// // {'minecraft:sharpness': 5, 'minecraft:looting': 3}
  /// ```
  Map<String, int> get enchantments {
    _checkReleased();
    final json = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getItemEnchantments',
      '(J)Ljava/lang/String;',
      [_handle],
    );
    if (json == null || json.isEmpty || json == '{}') return {};
    try {
      return (jsonDecode(json) as Map).cast<String, int>();
    } catch (_) {
      return {};
    }
  }

  /// Set enchantments from map of enchantment ID to level.
  ///
  /// Example:
  /// ```dart
  /// handle.enchantments = {
  ///   'minecraft:sharpness': 5,
  ///   'minecraft:looting': 3,
  /// };
  /// ```
  set enchantments(Map<String, int> value) {
    _checkReleased();
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemEnchantments',
      '(JLjava/lang/String;)V',
      [_handle, jsonEncode(value)],
    );
  }

  // ==========================================================================
  // Generic Component Access
  // ==========================================================================

  /// Check if a component exists.
  ///
  /// [componentId] is the component ID without namespace (e.g., 'custom_name').
  bool hasComponent(String componentId) {
    _checkReleased();
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'hasItemStackComponent',
      '(JLjava/lang/String;)Z',
      [_handle, componentId],
    );
  }

  /// Get a component value as JSON string.
  ///
  /// Returns null if the component doesn't exist.
  String? getComponentJson(String componentId) {
    _checkReleased();
    return GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getItemStackComponent',
      '(JLjava/lang/String;)Ljava/lang/String;',
      [_handle, componentId],
    );
  }

  /// Set a component value from JSON string.
  void setComponentJson(String componentId, String valueJson) {
    _checkReleased();
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setItemStackComponent',
      '(JLjava/lang/String;Ljava/lang/String;)V',
      [_handle, componentId, valueJson],
    );
  }

  /// Remove a component.
  void removeComponent(String componentId) {
    _checkReleased();
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'removeItemStackComponent',
      '(JLjava/lang/String;)V',
      [_handle, componentId],
    );
  }

  @override
  String toString() =>
      'ItemStackHandle($_handle${_released ? ', released' : ''})';
}

/// Extension to easily get handles from PlayerInventory.
extension PlayerInventoryHandleExtension on PlayerInventory {
  /// Get a handle to the item in a slot.
  ///
  /// Remember to call [ItemStackHandle.release] when done!
  ///
  /// Throws [StateError] if the slot is empty.
  ///
  /// Example:
  /// ```dart
  /// final handle = player.inventory.getHandle(0);
  /// try {
  ///   print('Item damage: ${handle.damage}');
  /// } finally {
  ///   handle.release();
  /// }
  /// ```
  ItemStackHandle getHandle(int slot) {
    return ItemStackHandle.fromPlayerSlot(player, slot);
  }
}
