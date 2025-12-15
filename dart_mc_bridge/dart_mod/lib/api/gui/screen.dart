/// Base class for custom Minecraft screens.
///
/// This library provides the [Screen] class for creating custom GUI screens
/// that integrate with Minecraft's rendering and input systems.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../src/bridge.dart';
import '../../src/jni/generic_bridge.dart';
import 'gui_graphics.dart';
import 'widgets.dart';

/// The Java class name for DartBridgeClient (client-side).
const _dartBridgeClient = 'com/example/dartbridge/DartBridgeClient';

/// Base class for custom Minecraft screens.
///
/// Extend this class and override lifecycle/input methods to create custom GUIs.
///
/// ## Example
/// ```dart
/// class MyScreen extends Screen {
///   MyScreen() : super('My Screen Title');
///
///   @override
///   void init() {
///     // Called when screen is initialized
///     // width and height are now available
///   }
///
///   @override
///   void render(GuiGraphics graphics, int mouseX, int mouseY, double partialTick) {
///     // Draw background
///     graphics.fill(0, 0, width, height, 0x80000000);
///
///     // Draw centered text
///     graphics.drawCenteredString('Hello World!', width ~/ 2, height ~/ 2);
///   }
///
///   @override
///   bool keyPressed(int keyCode, int scanCode, int modifiers) {
///     if (keyCode == Keys.escape) {
///       close();
///       return true;
///     }
///     return false;
///   }
///
///   @override
///   bool mouseClicked(double mouseX, double mouseY, int button) {
///     // Handle mouse clicks
///     return false;
///   }
/// }
///
/// // Show the screen
/// void openMyScreen() {
///   MyScreen().show();
/// }
/// ```
abstract class Screen {
  static int _nextId = 1;
  static final Map<int, Screen> _screens = {};

  final int _id;
  final String title;

  int _width = 0;
  int _height = 0;
  bool _isShowing = false;
  int _javaScreenId = 0;

  /// Creates a new screen with the given title.
  ///
  /// The title is displayed in the Minecraft window title while the screen is open.
  Screen(this.title) : _id = _nextId++ {
    _screens[_id] = this;
  }

  /// Screen width in pixels.
  ///
  /// This is set after [init] is called and reflects the current window size.
  int get width => _width;

  /// Screen height in pixels.
  ///
  /// This is set after [init] is called and reflects the current window size.
  int get height => _height;

  /// Whether this screen is currently showing.
  bool get isShowing => _isShowing;

  /// Internal screen ID used by the Dart side.
  int get id => _id;

  /// Internal Java screen ID used for rendering calls.
  int get javaScreenId => _javaScreenId;

  // ===========================================================================
  // Lifecycle Methods (override in subclass)
  // ===========================================================================

  /// Called when the screen is initialized.
  ///
  /// At this point, [width] and [height] are set to the current window size.
  /// Use this method to set up widgets, calculate positions, etc.
  void init() {}

  /// Called every game tick (20 times per second).
  ///
  /// Use this for animations, state updates, or any logic that should run
  /// at a fixed rate regardless of frame rate.
  void tick() {}

  /// Called every frame to render the screen.
  ///
  /// [graphics] - Drawing context for rendering
  /// [mouseX], [mouseY] - Current mouse position
  /// [partialTick] - Partial tick for smooth animations (0.0 to 1.0)
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void render(GuiGraphics graphics, int mouseX, int mouseY, double partialTick) {
  ///   // Draw semi-transparent background
  ///   graphics.fill(0, 0, width, height, 0x80000000);
  ///
  ///   // Draw title
  ///   graphics.drawCenteredString(title, width ~/ 2, 20);
  ///
  ///   // Highlight hovered area
  ///   if (mouseX > 100 && mouseX < 200 && mouseY > 50 && mouseY < 70) {
  ///     graphics.fill(100, 50, 200, 70, 0x40FFFFFF);
  ///   }
  /// }
  /// ```
  void render(GuiGraphics graphics, int mouseX, int mouseY, double partialTick) {}

  /// Called when the screen is closed.
  ///
  /// Use this to clean up resources, save state, etc.
  void onClose() {}

  // ===========================================================================
  // Input Methods (override in subclass, return true if handled)
  // ===========================================================================

  /// Called when a key is pressed.
  ///
  /// [keyCode] - The GLFW key code (see [Keys] constants)
  /// [scanCode] - Platform-specific scan code
  /// [modifiers] - Modifier key flags (shift, ctrl, alt, etc.)
  ///
  /// Return `true` to consume the event and prevent further processing.
  /// Return `false` to allow default handling (e.g., ESC to close screen).
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool keyPressed(int keyCode, int scanCode, int modifiers) {
  ///   if (keyCode == Keys.escape) {
  ///     close();
  ///     return true;
  ///   }
  ///   if (keyCode == Keys.enter) {
  ///     submitForm();
  ///     return true;
  ///   }
  ///   return false;
  /// }
  /// ```
  bool keyPressed(int keyCode, int scanCode, int modifiers) => false;

  /// Called when a key is released.
  ///
  /// Return `true` to consume the event.
  bool keyReleased(int keyCode, int scanCode, int modifiers) => false;

  /// Called when a character is typed.
  ///
  /// [codePoint] - Unicode code point of the character
  /// [modifiers] - Modifier key flags
  ///
  /// This is useful for text input fields.
  /// Return `true` to consume the event.
  bool charTyped(int codePoint, int modifiers) => false;

  /// Called when a mouse button is clicked.
  ///
  /// [mouseX], [mouseY] - Mouse position
  /// [button] - Mouse button (0=left, 1=right, 2=middle)
  ///
  /// Return `true` to consume the event.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool mouseClicked(double mouseX, double mouseY, int button) {
  ///   if (button == Keys.mouseLeft) {
  ///     // Check if button was clicked
  ///     if (mouseX >= buttonX && mouseX <= buttonX + buttonWidth &&
  ///         mouseY >= buttonY && mouseY <= buttonY + buttonHeight) {
  ///       onButtonClick();
  ///       return true;
  ///     }
  ///   }
  ///   return false;
  /// }
  /// ```
  bool mouseClicked(double mouseX, double mouseY, int button) => false;

  /// Called when a mouse button is released.
  ///
  /// Return `true` to consume the event.
  bool mouseReleased(double mouseX, double mouseY, int button) => false;

  /// Called when the mouse is dragged (moved while button held).
  ///
  /// [dragX], [dragY] - Delta movement since last drag event
  ///
  /// Return `true` to consume the event.
  bool mouseDragged(
    double mouseX,
    double mouseY,
    int button,
    double dragX,
    double dragY,
  ) =>
      false;

  /// Called when the mouse wheel is scrolled.
  ///
  /// [deltaX] - Horizontal scroll amount
  /// [deltaY] - Vertical scroll amount (positive = up)
  ///
  /// Return `true` to consume the event.
  bool mouseScrolled(
    double mouseX,
    double mouseY,
    double deltaX,
    double deltaY,
  ) =>
      false;

  // ===========================================================================
  // Widget Creation Methods
  // ===========================================================================

  /// Add a button widget to this screen.
  ///
  /// The button uses Minecraft's native button rendering, including hover
  /// effects and click sounds.
  ///
  /// Parameters:
  /// - [x], [y] - Position of the top-left corner
  /// - [width], [height] - Size of the button
  /// - [text] - Button label text
  /// - [onPressed] - Callback when button is clicked
  ///
  /// Returns the created [Button] widget.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void init() {
  ///   addButton(
  ///     x: width ~/ 2 - 50,
  ///     y: height ~/ 2,
  ///     width: 100,
  ///     height: 20,
  ///     text: 'Click Me',
  ///     onPressed: () {
  ///       print('Button clicked!');
  ///       close();
  ///     },
  ///   );
  /// }
  /// ```
  Button addButton({
    required int x,
    required int y,
    required int width,
    required int height,
    required String text,
    void Function()? onPressed,
  }) {
    return createButton(
      screenId: _javaScreenId,
      x: x,
      y: y,
      width: width,
      height: height,
      text: text,
      onPressed: onPressed,
    );
  }

  /// Add an edit box (text input) widget to this screen.
  ///
  /// The edit box uses Minecraft's native text field rendering, including
  /// focus highlighting, cursor blinking, and text selection.
  ///
  /// Parameters:
  /// - [x], [y] - Position of the top-left corner
  /// - [width], [height] - Size of the edit box
  /// - [placeholder] - Placeholder text shown when empty
  /// - [onChanged] - Callback when text changes
  ///
  /// Returns the created [EditBox] widget.
  ///
  /// Example:
  /// ```dart
  /// late EditBox nameInput;
  ///
  /// @override
  /// void init() {
  ///   nameInput = addEditBox(
  ///     x: width ~/ 2 - 75,
  ///     y: height ~/ 2,
  ///     width: 150,
  ///     height: 20,
  ///     placeholder: 'Enter your name...',
  ///     onChanged: (text) {
  ///       print('Name changed: $text');
  ///     },
  ///   );
  /// }
  ///
  /// void submitForm() {
  ///   print('Submitted name: ${nameInput.value}');
  /// }
  /// ```
  EditBox addEditBox({
    required int x,
    required int y,
    required int width,
    required int height,
    String placeholder = '',
    void Function(String)? onChanged,
  }) {
    return createEditBox(
      screenId: _javaScreenId,
      x: x,
      y: y,
      width: width,
      height: height,
      placeholder: placeholder,
      onChanged: onChanged,
    );
  }

  // ===========================================================================
  // Screen Management
  // ===========================================================================

  /// Show this screen to the player.
  ///
  /// This creates the screen on the Java side and displays it.
  /// The [init] method will be called after the screen is created.
  void show() {
    _isShowing = true;

    // Call Java to create and show the screen
    // The Java side will call back to our static handlers
    _javaScreenId = GenericJniBridge.callStaticLongMethod(
      _dartBridgeClient,
      'createAndShowScreen',
      '(Ljava/lang/String;)J',
      [title],
    );

    // Map Java screen ID to this Dart screen
    _screensByJavaId[_javaScreenId] = this;
  }

  /// Close this screen.
  ///
  /// The [onClose] method will be called before the screen is removed.
  void close() {
    if (!_isShowing) return;

    _isShowing = false;
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'closeScreen',
      '(J)V',
      [_javaScreenId],
    );
  }

  /// Dispose of this screen (remove from registry).
  ///
  /// Call this when you're done with the screen and won't reuse it.
  void dispose() {
    _screens.remove(_id);
    _screensByJavaId.remove(_javaScreenId);
  }

  // ===========================================================================
  // Static Callback Handlers (called from native via C++)
  // ===========================================================================

  static final Map<int, Screen> _screensByJavaId = {};

  /// Handle screen initialization callback from Java.
  static void handleInit(int javaScreenId, int width, int height) {
    final screen = _screensByJavaId[javaScreenId];
    if (screen != null) {
      screen._width = width;
      screen._height = height;
      screen.init();
    }
  }

  /// Handle screen tick callback from Java.
  static void handleTick(int javaScreenId) {
    _screensByJavaId[javaScreenId]?.tick();
  }

  /// Handle screen render callback from Java.
  static void handleRender(
    int javaScreenId,
    int mouseX,
    int mouseY,
    double partialTick,
  ) {
    final screen = _screensByJavaId[javaScreenId];
    if (screen != null) {
      final graphics = GuiGraphics.forScreen(javaScreenId);
      screen.render(graphics, mouseX, mouseY, partialTick);
    }
  }

  /// Handle screen close callback from Java.
  static void handleClose(int javaScreenId) {
    final screen = _screensByJavaId[javaScreenId];
    if (screen != null) {
      screen._isShowing = false;
      screen.onClose();
      // Clean up all widgets registered for this screen
      unregisterAllWidgetsForScreen(javaScreenId);
    }
  }

  /// Handle key pressed callback from Java.
  static bool handleKeyPressed(
    int javaScreenId,
    int keyCode,
    int scanCode,
    int modifiers,
  ) {
    return _screensByJavaId[javaScreenId]
            ?.keyPressed(keyCode, scanCode, modifiers) ??
        false;
  }

  /// Handle key released callback from Java.
  static bool handleKeyReleased(
    int javaScreenId,
    int keyCode,
    int scanCode,
    int modifiers,
  ) {
    return _screensByJavaId[javaScreenId]
            ?.keyReleased(keyCode, scanCode, modifiers) ??
        false;
  }

  /// Handle char typed callback from Java.
  static bool handleCharTyped(int javaScreenId, int codePoint, int modifiers) {
    return _screensByJavaId[javaScreenId]?.charTyped(codePoint, modifiers) ??
        false;
  }

  /// Handle mouse clicked callback from Java.
  static bool handleMouseClicked(
    int javaScreenId,
    double mouseX,
    double mouseY,
    int button,
  ) {
    return _screensByJavaId[javaScreenId]?.mouseClicked(mouseX, mouseY, button) ??
        false;
  }

  /// Handle mouse released callback from Java.
  static bool handleMouseReleased(
    int javaScreenId,
    double mouseX,
    double mouseY,
    int button,
  ) {
    return _screensByJavaId[javaScreenId]
            ?.mouseReleased(mouseX, mouseY, button) ??
        false;
  }

  /// Handle mouse dragged callback from Java.
  static bool handleMouseDragged(
    int javaScreenId,
    double mouseX,
    double mouseY,
    int button,
    double dragX,
    double dragY,
  ) {
    return _screensByJavaId[javaScreenId]
            ?.mouseDragged(mouseX, mouseY, button, dragX, dragY) ??
        false;
  }

  /// Handle mouse scrolled callback from Java.
  static bool handleMouseScrolled(
    int javaScreenId,
    double mouseX,
    double mouseY,
    double deltaX,
    double deltaY,
  ) {
    return _screensByJavaId[javaScreenId]
            ?.mouseScrolled(mouseX, mouseY, deltaX, deltaY) ??
        false;
  }

  /// Get a screen by its Java screen ID.
  /// Used internally for dispatching callbacks.
  static Screen? getByJavaId(int javaScreenId) {
    return _screensByJavaId[javaScreenId];
  }

  /// Get all currently active screens.
  static Iterable<Screen> get activeScreens => _screensByJavaId.values;
}

// =============================================================================
// Static Callback Wrapper Functions
// These are C-callable static functions that route to Screen.handleXxx methods
// =============================================================================

/// Screen init callback - called when screen is initialized
@pragma('vm:entry-point')
void _onScreenInit(int screenId, int width, int height) {
  Screen.handleInit(screenId, width, height);
}

/// Screen tick callback - called every game tick
@pragma('vm:entry-point')
void _onScreenTick(int screenId) {
  Screen.handleTick(screenId);
}

/// Screen render callback - called every frame
@pragma('vm:entry-point')
void _onScreenRender(int screenId, int mouseX, int mouseY, double partialTick) {
  Screen.handleRender(screenId, mouseX, mouseY, partialTick);
}

/// Screen close callback - called when screen is closed
@pragma('vm:entry-point')
void _onScreenClose(int screenId) {
  Screen.handleClose(screenId);
}

/// Screen key pressed callback - returns true if event was handled
@pragma('vm:entry-point')
bool _onScreenKeyPressed(int screenId, int keyCode, int scanCode, int modifiers) {
  return Screen.handleKeyPressed(screenId, keyCode, scanCode, modifiers);
}

/// Screen key released callback - returns true if event was handled
@pragma('vm:entry-point')
bool _onScreenKeyReleased(int screenId, int keyCode, int scanCode, int modifiers) {
  return Screen.handleKeyReleased(screenId, keyCode, scanCode, modifiers);
}

/// Screen char typed callback - returns true if event was handled
@pragma('vm:entry-point')
bool _onScreenCharTyped(int screenId, int codePoint, int modifiers) {
  return Screen.handleCharTyped(screenId, codePoint, modifiers);
}

/// Screen mouse clicked callback - returns true if event was handled
@pragma('vm:entry-point')
bool _onScreenMouseClicked(int screenId, double mouseX, double mouseY, int button) {
  return Screen.handleMouseClicked(screenId, mouseX, mouseY, button);
}

/// Screen mouse released callback - returns true if event was handled
@pragma('vm:entry-point')
bool _onScreenMouseReleased(int screenId, double mouseX, double mouseY, int button) {
  return Screen.handleMouseReleased(screenId, mouseX, mouseY, button);
}

/// Screen mouse dragged callback - returns true if event was handled
@pragma('vm:entry-point')
bool _onScreenMouseDragged(
  int screenId,
  double mouseX,
  double mouseY,
  int button,
  double dragX,
  double dragY,
) {
  return Screen.handleMouseDragged(screenId, mouseX, mouseY, button, dragX, dragY);
}

/// Screen mouse scrolled callback - returns true if event was handled
@pragma('vm:entry-point')
bool _onScreenMouseScrolled(
  int screenId,
  double mouseX,
  double mouseY,
  double deltaX,
  double deltaY,
) {
  return Screen.handleMouseScrolled(screenId, mouseX, mouseY, deltaX, deltaY);
}

// =============================================================================
// Screen Callback Registration
// =============================================================================

bool _screenCallbacksRegistered = false;

/// Initialize and register all screen callbacks with the C++ bridge.
///
/// This must be called during mod initialization to enable screen rendering
/// and input handling. The function is idempotent - multiple calls are safe.
void initScreenCallbacks() {
  if (_screenCallbacksRegistered) return;
  _screenCallbacksRegistered = true;

  // Register void callbacks (no default return value needed)
  Bridge.registerScreenInitHandler(
    Pointer.fromFunction<ScreenInitCallbackNative>(_onScreenInit));
  Bridge.registerScreenTickHandler(
    Pointer.fromFunction<ScreenTickCallbackNative>(_onScreenTick));
  Bridge.registerScreenRenderHandler(
    Pointer.fromFunction<ScreenRenderCallbackNative>(_onScreenRender));
  Bridge.registerScreenCloseHandler(
    Pointer.fromFunction<ScreenCloseCallbackNative>(_onScreenClose));

  // Register bool callbacks (default return value false = event not handled)
  Bridge.registerScreenKeyPressedHandler(
    Pointer.fromFunction<ScreenKeyPressedCallbackNative>(_onScreenKeyPressed, false));
  Bridge.registerScreenKeyReleasedHandler(
    Pointer.fromFunction<ScreenKeyReleasedCallbackNative>(_onScreenKeyReleased, false));
  Bridge.registerScreenCharTypedHandler(
    Pointer.fromFunction<ScreenCharTypedCallbackNative>(_onScreenCharTyped, false));
  Bridge.registerScreenMouseClickedHandler(
    Pointer.fromFunction<ScreenMouseClickedCallbackNative>(_onScreenMouseClicked, false));
  Bridge.registerScreenMouseReleasedHandler(
    Pointer.fromFunction<ScreenMouseReleasedCallbackNative>(_onScreenMouseReleased, false));
  Bridge.registerScreenMouseDraggedHandler(
    Pointer.fromFunction<ScreenMouseDraggedCallbackNative>(_onScreenMouseDragged, false));
  Bridge.registerScreenMouseScrolledHandler(
    Pointer.fromFunction<ScreenMouseScrolledCallbackNative>(_onScreenMouseScrolled, false));

  // Register widget callbacks
  Bridge.registerWidgetPressedHandler(
    Pointer.fromFunction<WidgetPressedCallbackNative>(_onWidgetPressed));
  Bridge.registerWidgetTextChangedHandler(
    Pointer.fromFunction<WidgetTextChangedCallbackNative>(_onWidgetTextChanged));

  print('Screen callbacks registered');
}

// =============================================================================
// Widget Callback Wrapper Functions
// =============================================================================

/// Widget pressed callback - called when a button is pressed
@pragma('vm:entry-point')
void _onWidgetPressed(int screenId, int widgetId) {
  handleWidgetPressed(screenId, widgetId);
}

/// Widget text changed callback - called when edit box text changes
@pragma('vm:entry-point')
void _onWidgetTextChanged(int screenId, int widgetId, Pointer<Utf8> text) {
  handleWidgetTextChanged(screenId, widgetId, text.toDartString());
}
