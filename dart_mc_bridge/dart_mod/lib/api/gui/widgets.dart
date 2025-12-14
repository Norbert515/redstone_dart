/// Native Minecraft widget classes for Dart GUI screens.
///
/// This library provides Dart wrappers around Minecraft's native widget classes,
/// including [Button] and [EditBox]. These widgets are rendered by Minecraft's
/// rendering system, providing proper hover states, focus handling, and
/// keyboard navigation.
library;

import '../../src/jni/generic_bridge.dart';

const _dartBridgeClient = 'com/example/dartbridge/DartBridgeClient';

/// Base class for native Minecraft widgets.
///
/// All widgets have a unique ID within their screen and can be controlled
/// through visibility and active state properties.
abstract class Widget {
  final int _screenId;
  final int _widgetId;

  Widget._(this._screenId, this._widgetId);

  /// The screen ID this widget belongs to.
  int get screenId => _screenId;

  /// The unique widget ID within the screen.
  int get widgetId => _widgetId;

  /// Remove this widget from the screen.
  void remove() {
    _unregisterWidget(_screenId, _widgetId);
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'removeWidget',
      '(JJ)V',
      [_screenId, _widgetId],
    );
  }

  /// Whether this widget is visible.
  set visible(bool value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'setWidgetVisible',
      '(JJZ)V',
      [_screenId, _widgetId, value],
    );
  }

  /// Whether this widget is active (can be interacted with).
  set active(bool value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'setWidgetActive',
      '(JJZ)V',
      [_screenId, _widgetId, value],
    );
  }
}

/// A clickable button widget.
///
/// Buttons are rendered using Minecraft's native button style, including
/// proper hover effects and click sounds.
///
/// Example:
/// ```dart
/// class MyScreen extends Screen {
///   late Button myButton;
///
///   @override
///   void init() {
///     myButton = addButton(
///       x: width ~/ 2 - 50,
///       y: height ~/ 2,
///       width: 100,
///       height: 20,
///       text: 'Click Me',
///       onPressed: () {
///         print('Button clicked!');
///       },
///     );
///   }
/// }
/// ```
class Button extends Widget {
  /// Callback when button is pressed.
  void Function()? onPressed;

  Button._({
    required int screenId,
    required int widgetId,
    this.onPressed,
  }) : super._(screenId, widgetId);
}

/// A text input field widget.
///
/// EditBox provides a native Minecraft text input field with proper
/// focus handling, cursor display, and text selection.
///
/// Example:
/// ```dart
/// class MyScreen extends Screen {
///   late EditBox nameInput;
///
///   @override
///   void init() {
///     nameInput = addEditBox(
///       x: 10,
///       y: 50,
///       width: 150,
///       height: 20,
///       placeholder: 'Enter name...',
///       onChanged: (text) {
///         print('Text changed: $text');
///       },
///     );
///   }
/// }
/// ```
class EditBox extends Widget {
  /// Callback when text changes.
  void Function(String)? onChanged;

  EditBox._({
    required int screenId,
    required int widgetId,
    this.onChanged,
  }) : super._(screenId, widgetId);

  /// Get the current text value.
  String get value {
    return GenericJniBridge.callStaticStringMethod(
      _dartBridgeClient,
      'getEditBoxValue',
      '(JJ)Ljava/lang/String;',
      [_screenId, _widgetId],
    ) ?? '';
  }

  /// Set the text value.
  set value(String text) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridgeClient,
      'setEditBoxValue',
      '(JJLjava/lang/String;)V',
      [_screenId, _widgetId, text],
    );
  }
}

// ===========================================================================
// Widget Registry (for callback routing)
// ===========================================================================

/// Internal registry mapping screen/widget IDs to Widget instances.
final Map<int, Map<int, Widget>> _widgetsByScreen = {};

/// Register a widget for callback routing.
void _registerWidget(int screenId, int widgetId, Widget widget) {
  _widgetsByScreen.putIfAbsent(screenId, () => {});
  _widgetsByScreen[screenId]![widgetId] = widget;
}

/// Unregister a widget.
void _unregisterWidget(int screenId, int widgetId) {
  _widgetsByScreen[screenId]?.remove(widgetId);
}

/// Unregister all widgets for a screen (called when screen closes).
void unregisterAllWidgetsForScreen(int screenId) {
  _widgetsByScreen.remove(screenId);
}

// ===========================================================================
// Callback Handlers (called from C++ via FFI)
// ===========================================================================

/// Handle widget pressed event from native code.
void handleWidgetPressed(int screenId, int widgetId) {
  final widget = _widgetsByScreen[screenId]?[widgetId];
  if (widget is Button) {
    widget.onPressed?.call();
  }
}

/// Handle widget text changed event from native code.
void handleWidgetTextChanged(int screenId, int widgetId, String text) {
  final widget = _widgetsByScreen[screenId]?[widgetId];
  if (widget is EditBox) {
    widget.onChanged?.call(text);
  }
}

// ===========================================================================
// Widget Factory Functions (used by Screen class)
// ===========================================================================

/// Create a Button widget. Used internally by Screen.addButton().
Button createButton({
  required int screenId,
  required int x,
  required int y,
  required int width,
  required int height,
  required String text,
  void Function()? onPressed,
}) {
  final widgetId = GenericJniBridge.callStaticLongMethod(
    _dartBridgeClient,
    'addButton',
    '(JIIIILjava/lang/String;)J',
    [screenId, x, y, width, height, text],
  );

  final button = Button._(
    screenId: screenId,
    widgetId: widgetId,
    onPressed: onPressed,
  );
  _registerWidget(screenId, widgetId, button);
  return button;
}

/// Create an EditBox widget. Used internally by Screen.addEditBox().
EditBox createEditBox({
  required int screenId,
  required int x,
  required int y,
  required int width,
  required int height,
  String placeholder = '',
  void Function(String)? onChanged,
}) {
  final widgetId = GenericJniBridge.callStaticLongMethod(
    _dartBridgeClient,
    'addEditBox',
    '(JIIIILjava/lang/String;)J',
    [screenId, x, y, width, height, placeholder],
  );

  final editBox = EditBox._(
    screenId: screenId,
    widgetId: widgetId,
    onChanged: onChanged,
  );
  _registerWidget(screenId, widgetId, editBox);
  return editBox;
}
