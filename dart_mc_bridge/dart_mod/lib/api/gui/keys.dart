/// Key and mouse button constants for input handling.
///
/// This library provides constants for GLFW key codes and mouse buttons
/// used in Minecraft's input system.
library;

/// Common key codes for input handling.
///
/// These are GLFW key codes used by Minecraft for keyboard input.
/// Use these constants in [Screen.keyPressed] and [Screen.keyReleased].
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
///     submit();
///     return true;
///   }
///   return false;
/// }
/// ```
class Keys {
  Keys._();

  // ===========================================================================
  // Special Keys
  // ===========================================================================

  /// Escape key
  static const int escape = 256;

  /// Enter/Return key
  static const int enter = 257;

  /// Tab key
  static const int tab = 258;

  /// Backspace key
  static const int backspace = 259;

  /// Insert key
  static const int insert = 260;

  /// Delete key
  static const int delete = 261;

  /// Right arrow key
  static const int right = 262;

  /// Left arrow key
  static const int left = 263;

  /// Down arrow key
  static const int down = 264;

  /// Up arrow key
  static const int up = 265;

  /// Page Up key
  static const int pageUp = 266;

  /// Page Down key
  static const int pageDown = 267;

  /// Home key
  static const int home = 268;

  /// End key
  static const int end = 269;

  /// Caps Lock key
  static const int capsLock = 280;

  /// Scroll Lock key
  static const int scrollLock = 281;

  /// Num Lock key
  static const int numLock = 282;

  /// Print Screen key
  static const int printScreen = 283;

  /// Pause key
  static const int pause = 284;

  /// Space bar
  static const int space = 32;

  // ===========================================================================
  // Modifier Keys
  // ===========================================================================

  /// Left Shift key
  static const int leftShift = 340;

  /// Right Shift key
  static const int rightShift = 344;

  /// Left Control key
  static const int leftControl = 341;

  /// Right Control key
  static const int rightControl = 345;

  /// Left Alt key
  static const int leftAlt = 342;

  /// Right Alt key
  static const int rightAlt = 346;

  /// Left Super/Windows/Command key
  static const int leftSuper = 343;

  /// Right Super/Windows/Command key
  static const int rightSuper = 347;

  // ===========================================================================
  // Letter Keys (A-Z)
  // ===========================================================================

  static const int a = 65;
  static const int b = 66;
  static const int c = 67;
  static const int d = 68;
  static const int e = 69;
  static const int f = 70;
  static const int g = 71;
  static const int h = 72;
  static const int i = 73;
  static const int j = 74;
  static const int k = 75;
  static const int l = 76;
  static const int m = 77;
  static const int n = 78;
  static const int o = 79;
  static const int p = 80;
  static const int q = 81;
  static const int r = 82;
  static const int s = 83;
  static const int t = 84;
  static const int u = 85;
  static const int v = 86;
  static const int w = 87;
  static const int x = 88;
  static const int y = 89;
  static const int z = 90;

  // ===========================================================================
  // Number Keys (Top Row)
  // ===========================================================================

  /// 0 key (top row)
  static const int num0 = 48;

  /// 1 key (top row)
  static const int num1 = 49;

  /// 2 key (top row)
  static const int num2 = 50;

  /// 3 key (top row)
  static const int num3 = 51;

  /// 4 key (top row)
  static const int num4 = 52;

  /// 5 key (top row)
  static const int num5 = 53;

  /// 6 key (top row)
  static const int num6 = 54;

  /// 7 key (top row)
  static const int num7 = 55;

  /// 8 key (top row)
  static const int num8 = 56;

  /// 9 key (top row)
  static const int num9 = 57;

  // ===========================================================================
  // Numpad Keys
  // ===========================================================================

  /// Numpad 0
  static const int kp0 = 320;

  /// Numpad 1
  static const int kp1 = 321;

  /// Numpad 2
  static const int kp2 = 322;

  /// Numpad 3
  static const int kp3 = 323;

  /// Numpad 4
  static const int kp4 = 324;

  /// Numpad 5
  static const int kp5 = 325;

  /// Numpad 6
  static const int kp6 = 326;

  /// Numpad 7
  static const int kp7 = 327;

  /// Numpad 8
  static const int kp8 = 328;

  /// Numpad 9
  static const int kp9 = 329;

  /// Numpad decimal point
  static const int kpDecimal = 330;

  /// Numpad divide
  static const int kpDivide = 331;

  /// Numpad multiply
  static const int kpMultiply = 332;

  /// Numpad subtract
  static const int kpSubtract = 333;

  /// Numpad add
  static const int kpAdd = 334;

  /// Numpad enter
  static const int kpEnter = 335;

  /// Numpad equals
  static const int kpEqual = 336;

  // ===========================================================================
  // Function Keys
  // ===========================================================================

  static const int f1 = 290;
  static const int f2 = 291;
  static const int f3 = 292;
  static const int f4 = 293;
  static const int f5 = 294;
  static const int f6 = 295;
  static const int f7 = 296;
  static const int f8 = 297;
  static const int f9 = 298;
  static const int f10 = 299;
  static const int f11 = 300;
  static const int f12 = 301;
  static const int f13 = 302;
  static const int f14 = 303;
  static const int f15 = 304;
  static const int f16 = 305;
  static const int f17 = 306;
  static const int f18 = 307;
  static const int f19 = 308;
  static const int f20 = 309;
  static const int f21 = 310;
  static const int f22 = 311;
  static const int f23 = 312;
  static const int f24 = 313;
  static const int f25 = 314;

  // ===========================================================================
  // Symbol Keys
  // ===========================================================================

  /// Apostrophe/single quote (')
  static const int apostrophe = 39;

  /// Comma (,)
  static const int comma = 44;

  /// Minus/hyphen (-)
  static const int minus = 45;

  /// Period/full stop (.)
  static const int period = 46;

  /// Slash (/)
  static const int slash = 47;

  /// Semicolon (;)
  static const int semicolon = 59;

  /// Equal sign (=)
  static const int equal = 61;

  /// Left bracket ([)
  static const int leftBracket = 91;

  /// Backslash (\)
  static const int backslash = 92;

  /// Right bracket (])
  static const int rightBracket = 93;

  /// Grave accent/backtick (`)
  static const int graveAccent = 96;

  // ===========================================================================
  // Mouse Buttons
  // ===========================================================================

  /// Left mouse button
  static const int mouseLeft = 0;

  /// Right mouse button
  static const int mouseRight = 1;

  /// Middle mouse button (scroll wheel click)
  static const int mouseMiddle = 2;

  /// Mouse button 4 (side button)
  static const int mouse4 = 3;

  /// Mouse button 5 (side button)
  static const int mouse5 = 4;

  // ===========================================================================
  // Modifier Flags
  // ===========================================================================

  /// Shift modifier flag (for use with modifiers parameter)
  static const int modShift = 0x0001;

  /// Control modifier flag
  static const int modControl = 0x0002;

  /// Alt modifier flag
  static const int modAlt = 0x0004;

  /// Super/Windows/Command modifier flag
  static const int modSuper = 0x0008;

  /// Caps Lock modifier flag
  static const int modCapsLock = 0x0010;

  /// Num Lock modifier flag
  static const int modNumLock = 0x0020;

  // ===========================================================================
  // Utility Methods
  // ===========================================================================

  /// Check if shift is held.
  static bool isShiftDown(int modifiers) => (modifiers & modShift) != 0;

  /// Check if control is held.
  static bool isControlDown(int modifiers) => (modifiers & modControl) != 0;

  /// Check if alt is held.
  static bool isAltDown(int modifiers) => (modifiers & modAlt) != 0;

  /// Check if super/command is held.
  static bool isSuperDown(int modifiers) => (modifiers & modSuper) != 0;

  /// Get a human-readable name for a key code.
  static String getKeyName(int keyCode) {
    return switch (keyCode) {
      escape => 'Escape',
      enter => 'Enter',
      tab => 'Tab',
      backspace => 'Backspace',
      insert => 'Insert',
      delete => 'Delete',
      right => 'Right',
      left => 'Left',
      down => 'Down',
      up => 'Up',
      pageUp => 'Page Up',
      pageDown => 'Page Down',
      home => 'Home',
      end => 'End',
      space => 'Space',
      leftShift || rightShift => 'Shift',
      leftControl || rightControl => 'Control',
      leftAlt || rightAlt => 'Alt',
      _ when keyCode >= a && keyCode <= z =>
        String.fromCharCode(keyCode),
      _ when keyCode >= num0 && keyCode <= num9 =>
        String.fromCharCode(keyCode),
      _ when keyCode >= f1 && keyCode <= f12 =>
        'F${keyCode - f1 + 1}',
      _ => 'Key $keyCode',
    };
  }

  /// Get a human-readable name for a mouse button.
  static String getMouseButtonName(int button) {
    return switch (button) {
      mouseLeft => 'Left Click',
      mouseRight => 'Right Click',
      mouseMiddle => 'Middle Click',
      mouse4 => 'Mouse 4',
      mouse5 => 'Mouse 5',
      _ => 'Mouse $button',
    };
  }
}
