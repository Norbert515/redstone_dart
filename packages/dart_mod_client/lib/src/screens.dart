/// Client-side screen system for Minecraft GUIs.
library;

import 'package:flutter/widgets.dart';

/// Base class for Minecraft GUI screens rendered with Flutter.
///
/// Extend this class to create custom screens that can be displayed in-game.
abstract class MinecraftScreen extends StatefulWidget {
  /// The unique ID for this screen instance.
  final int screenId;

  const MinecraftScreen({super.key, required this.screenId});
}

/// State for a Minecraft screen.
abstract class MinecraftScreenState<T extends MinecraftScreen> extends State<T> {
  /// Called when the screen is initialized.
  void onInit(int width, int height) {}

  /// Called every game tick (20 times per second).
  void onTick() {}

  /// Called before rendering.
  void onRender(int mouseX, int mouseY, double partialTick) {}

  /// Called when the screen is closed.
  void onClose() {}

  /// Called when a key is pressed.
  /// Return true if the key was handled.
  bool onKeyPressed(int keyCode, int scanCode, int modifiers) => false;

  /// Called when a key is released.
  /// Return true if the key was handled.
  bool onKeyReleased(int keyCode, int scanCode, int modifiers) => false;

  /// Called when a character is typed.
  /// Return true if the character was handled.
  bool onCharTyped(int codePoint, int modifiers) => false;

  /// Called when a mouse button is clicked.
  /// Return true if the click was handled.
  bool onMouseClicked(double mouseX, double mouseY, int button) => false;

  /// Called when a mouse button is released.
  /// Return true if the release was handled.
  bool onMouseReleased(double mouseX, double mouseY, int button) => false;

  /// Called when the mouse is dragged.
  /// Return true if the drag was handled.
  bool onMouseDragged(double mouseX, double mouseY, int button, double dragX, double dragY) => false;

  /// Called when the mouse wheel is scrolled.
  /// Return true if the scroll was handled.
  bool onMouseScrolled(double mouseX, double mouseY, double deltaX, double deltaY) => false;
}

/// Registry for screen types.
class ScreenRegistry {
  static final Map<String, WidgetBuilder> _screenBuilders = {};

  /// Register a screen builder for a screen type.
  static void register(String screenType, WidgetBuilder builder) {
    _screenBuilders[screenType] = builder;
  }

  /// Get a screen builder by type.
  static WidgetBuilder? getBuilder(String screenType) {
    return _screenBuilders[screenType];
  }

  /// Check if a screen type is registered.
  static bool isRegistered(String screenType) {
    return _screenBuilders.containsKey(screenType);
  }
}
