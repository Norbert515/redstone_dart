/// Dart API for Minecraft modding.
///
/// This library provides the public API for creating Minecraft mods in Dart.
///
/// ## Getting Started
///
/// ```dart
/// import 'package:dart_mc/dart_mc.dart';
///
/// void main() {
///   // Initialize the bridge
///   Bridge.initialize();
///
///   // Register event handlers
///   Events.registerProxyBlockHandlers();
///   Events.registerProxyEntityHandlers();
///
///   // Initialize screen and container callbacks
///   initScreenCallbacks();
///   ContainerRegistry.init();
///
///   // Register your custom blocks
///   BlockRegistry.register(MyCustomBlock());
///   BlockRegistry.freeze();
///
///   // Register your custom entities
///   EntityRegistry.register(MyCustomEntity());
///   EntityRegistry.freeze();
///
///   // Register event handlers
///   Events.onTick((tick) {
///     // Called 20 times per second
///   });
/// }
/// ```
library dart_mc;

// Core bridge and events
export 'src/bridge.dart';
export 'src/events.dart';
export 'src/types.dart';

// API classes
export 'api/block.dart';
export 'api/player.dart';
export 'api/world.dart';
export 'api/entity.dart';
export 'api/item.dart' hide ItemStack;
export 'api/inventory.dart';
export 'api/custom_block.dart';
export 'api/block_model.dart';
export 'api/block_registry.dart';
export 'api/custom_entity.dart';
export 'api/entity_registry.dart';
export 'api/custom_item.dart';
export 'api/item_model.dart';
export 'api/item_registry.dart';

// GUI
export 'api/gui/screen.dart';
export 'api/gui/gui.dart';
export 'api/gui/gui_graphics.dart';
export 'api/gui/keys.dart';
export 'api/gui/widgets.dart';
export 'api/gui/container_screen.dart';

// Inventory/Container system
export 'api/inventory/item_stack.dart';
export 'api/inventory/slot.dart';
export 'api/inventory/dart_container.dart';
export 'api/inventory/container_manager.dart';
export 'api/inventory/container_callbacks.dart' show ClickType;
export 'api/inventory/container_registry.dart';
