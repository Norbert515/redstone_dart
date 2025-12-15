/// Base class for container screens (inventory GUIs).
///
/// Container screens are special screens that integrate with Minecraft's
/// inventory system, allowing real item slots with proper drag-drop,
/// shift-click transfer, and item synchronization.
library;

import 'dart:ffi';

import '../../src/bridge.dart';
import '../../src/jni/generic_bridge.dart';
import 'gui_graphics.dart';

/// The Java class name for DartBridgeClient (client-side).
const _dartBridgeClient = 'com/redstone/DartBridgeClient';

/// Base class for container screens (inventory GUIs).
///
/// Extend this class to create custom inventory GUIs that can hold items.
/// Container screens differ from regular screens in that:
/// - They have real inventory slots managed by Minecraft
/// - Items can be dragged, dropped, and shift-clicked
/// - Item synchronization is handled automatically
///
/// ## Example
/// ```dart
/// class MyChestScreen extends ContainerScreen {
///   MyChestScreen() : super(title: 'My Chest', slotCount: 27);
///
///   @override
///   void init() {
///     // Set container size (standard chest size)
///     setSize(176, 166);
///
///     // Add 27 container slots (3 rows of 9)
///     for (var row = 0; row < 3; row++) {
///       for (var col = 0; col < 9; col++) {
///         addSlot(row * 9 + col, 8 + col * 18, 18 + row * 18);
///       }
///     }
///
///     // Add player inventory at standard position
///     addPlayerInventory(8, 84);
///   }
///
///   @override
///   void renderBackground(GuiGraphics graphics, int mouseX, int mouseY, double partialTick) {
///     // Draw chest background texture
///     graphics.blit(
///       'minecraft:textures/gui/container/generic_54.png',
///       leftPos, topPos, imageWidth, imageHeight,
///       0, 0, 1, 1,
///     );
///   }
/// }
/// ```
abstract class ContainerScreen {
  static final Map<int, ContainerScreen> _screens = {};

  final String title;
  final int slotCount;

  int _screenId = 0;
  int _width = 0;
  int _height = 0;
  int _leftPos = 0;
  int _topPos = 0;
  int _imageWidth = 176;
  int _imageHeight = 166;

  /// Creates a new container screen.
  ///
  /// [title] - The title displayed at the top of the screen
  /// [slotCount] - The number of container slots (not including player inventory)
  ContainerScreen({required this.title, required this.slotCount});

  /// The unique screen ID assigned by Java.
  int get screenId => _screenId;

  /// The full screen width in pixels.
  int get width => _width;

  /// The full screen height in pixels.
  int get height => _height;

  /// The X position of the GUI panel (left edge).
  int get leftPos => _leftPos;

  /// The Y position of the GUI panel (top edge).
  int get topPos => _topPos;

  /// The width of the GUI panel (not the full screen).
  int get imageWidth => _imageWidth;

  /// The height of the GUI panel (not the full screen).
  int get imageHeight => _imageHeight;

  // ===========================================================================
  // Lifecycle Methods (override in subclass)
  // ===========================================================================

  /// Called when the container screen is initialized.
  ///
  /// Use this to set up slots and configure the screen size.
  /// At this point, [width], [height], [leftPos], and [topPos] are set.
  void init() {}

  /// Called every frame to render the background.
  ///
  /// Minecraft will automatically render the slots and items on top
  /// of whatever you draw here.
  ///
  /// [graphics] - Drawing context for rendering
  /// [mouseX], [mouseY] - Current mouse position
  /// [partialTick] - Partial tick for smooth animations (0.0 to 1.0)
  void renderBackground(
      GuiGraphics graphics, int mouseX, int mouseY, double partialTick) {}

  /// Called when the container screen is closed.
  ///
  /// Use this to clean up resources.
  void onClose() {}

  // ===========================================================================
  // Slot Management
  // ===========================================================================

  /// Add a slot to the container at screen coordinates.
  ///
  /// [slotIndex] - The container slot index (0 to slotCount-1)
  /// [x] - X position relative to leftPos
  /// [y] - Y position relative to topPos
  ///
  /// Note: Coordinates are relative to the GUI panel, not the screen.
  void addSlot(int slotIndex, int x, int y) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'addContainerSlot',
      '(JII)V',
      [_screenId, slotIndex, x, y],
    );
  }

  /// Add the player's inventory slots at the standard position.
  ///
  /// This adds the 27 main inventory slots and 9 hotbar slots.
  /// The hotbar will be positioned 58 pixels below startY.
  ///
  /// [startX] - X position for the first slot (relative to leftPos)
  /// [startY] - Y position for the main inventory (relative to topPos)
  ///
  /// Standard positions for a 176-wide GUI:
  /// - startX: 8 (centered with 9 slots at 18px each = 162px)
  /// - startY: varies based on container size
  void addPlayerInventory(int startX, int startY) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'addPlayerInventorySlots',
      '(JII)V',
      [_screenId, startX, startY],
    );
  }

  /// Set the size of the GUI panel.
  ///
  /// This determines the centered area where slots and background are rendered.
  /// Standard sizes:
  /// - Chest: 176x166
  /// - Double chest: 176x222
  /// - Furnace: 176x166
  /// - Crafting table: 176x166
  void setSize(int width, int height) {
    _imageWidth = width;
    _imageHeight = height;
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'setContainerSize',
      '(JII)V',
      [_screenId, width, height],
    );
  }

  // ===========================================================================
  // Static Callback Handlers (called from native via C++)
  // ===========================================================================

  /// Factory function to create container screens.
  /// Set this to automatically create the appropriate screen type when Java opens a container.
  static ContainerScreen Function()? screenFactory;

  /// Handle container screen initialization callback from Java.
  static void handleInit(int screenId, int width, int height, int leftPos,
      int topPos, int imageWidth, int imageHeight) {
    // If no screen registered for this ID and we have a factory, create one
    ContainerScreen? screen = _screens[screenId];
    if (screen == null && screenFactory != null) {
      screen = screenFactory!();
      registerScreen(screenId, screen);
    }

    if (screen != null) {
      screen._screenId = screenId;
      screen._width = width;
      screen._height = height;
      screen._leftPos = leftPos;
      screen._topPos = topPos;
      screen._imageWidth = imageWidth;
      screen._imageHeight = imageHeight;
      screen.init();
    }
  }

  /// Handle container screen render background callback from Java.
  static void handleRenderBg(int screenId, int mouseX, int mouseY,
      double partialTick, int leftPos, int topPos) {
    final screen = _screens[screenId];
    if (screen == null) {
      print('ContainerScreen.handleRenderBg: screenId=$screenId NOT FOUND in $_screens');
    }
    if (screen != null) {
      screen._leftPos = leftPos;
      screen._topPos = topPos;
      final graphics = GuiGraphics.forScreen(screenId);
      screen.renderBackground(graphics, mouseX, mouseY, partialTick);
    }
  }

  /// Handle container screen close callback from Java.
  static void handleClose(int screenId) {
    final screen = _screens[screenId];
    if (screen != null) {
      screen.onClose();
      _screens.remove(screenId);
    }
  }

  /// Register a container screen instance to receive callbacks.
  ///
  /// This is called automatically when a container is opened from Java.
  /// The screen ID is assigned by Java when the container menu is created.
  static void registerScreen(int screenId, ContainerScreen screen) {
    screen._screenId = screenId;
    _screens[screenId] = screen;
  }

  /// Get a container screen by its screen ID.
  static ContainerScreen? getByScreenId(int screenId) {
    return _screens[screenId];
  }
}

// =============================================================================
// Static Callback Wrapper Functions
// These are C-callable static functions that route to ContainerScreen.handleXxx methods
// =============================================================================

/// Container screen init callback
@pragma('vm:entry-point')
void _onContainerScreenInit(int screenId, int width, int height, int leftPos,
    int topPos, int imageWidth, int imageHeight) {
  ContainerScreen.handleInit(
      screenId, width, height, leftPos, topPos, imageWidth, imageHeight);
}

/// Container screen render background callback
@pragma('vm:entry-point')
void _onContainerScreenRenderBg(int screenId, int mouseX, int mouseY,
    double partialTick, int leftPos, int topPos) {
  ContainerScreen.handleRenderBg(
      screenId, mouseX, mouseY, partialTick, leftPos, topPos);
}

/// Container screen close callback
@pragma('vm:entry-point')
void _onContainerScreenClose(int screenId) {
  ContainerScreen.handleClose(screenId);
}

// =============================================================================
// Container Screen Callback Registration
// =============================================================================

bool _containerScreenCallbacksRegistered = false;

/// Initialize and register all container screen callbacks with the C++ bridge.
///
/// This must be called during mod initialization to enable container screen
/// rendering. The function is idempotent - multiple calls are safe.
void initContainerScreenCallbacks() {
  if (_containerScreenCallbacksRegistered) return;
  _containerScreenCallbacksRegistered = true;

  Bridge.registerContainerScreenInitHandler(
      Pointer.fromFunction<ContainerScreenInitCallbackNative>(
          _onContainerScreenInit));
  Bridge.registerContainerScreenRenderBgHandler(
      Pointer.fromFunction<ContainerScreenRenderBgCallbackNative>(
          _onContainerScreenRenderBg));
  Bridge.registerContainerScreenCloseHandler(
      Pointer.fromFunction<ContainerScreenCloseCallbackNative>(
          _onContainerScreenClose));

  print('Container screen callbacks registered');
}
