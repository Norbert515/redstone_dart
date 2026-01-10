/// GLFW key code constants for input simulation.
///
/// These constants match the GLFW key codes used by Minecraft for keyboard input.
/// Use these with [ClientGameContext.pressKey], [ClientGameContext.holdKey], etc.
///
/// Example:
/// ```dart
/// await game.pressKey(GlfwKeys.w); // Press W key
/// await game.holdKeyFor(GlfwKeys.space, 10); // Hold space for 10 ticks
/// ```
abstract class GlfwKeys {
  // ========================================================================
  // Special keys
  // ========================================================================

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

  // ========================================================================
  // Letter keys (A-Z)
  // ========================================================================

  /// A key
  static const int a = 65;

  /// B key
  static const int b = 66;

  /// C key
  static const int c = 67;

  /// D key
  static const int d = 68;

  /// E key
  static const int e = 69;

  /// F key
  static const int f = 70;

  /// G key
  static const int g = 71;

  /// H key
  static const int h = 72;

  /// I key
  static const int i = 73;

  /// J key
  static const int j = 74;

  /// K key
  static const int k = 75;

  /// L key
  static const int l = 76;

  /// M key
  static const int m = 77;

  /// N key
  static const int n = 78;

  /// O key
  static const int o = 79;

  /// P key
  static const int p = 80;

  /// Q key
  static const int q = 81;

  /// R key
  static const int r = 82;

  /// S key
  static const int s = 83;

  /// T key
  static const int t = 84;

  /// U key
  static const int u = 85;

  /// V key
  static const int v = 86;

  /// W key
  static const int w = 87;

  /// X key
  static const int x = 88;

  /// Y key
  static const int y = 89;

  /// Z key
  static const int z = 90;

  // ========================================================================
  // Number keys (top row)
  // ========================================================================

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

  // ========================================================================
  // Numpad keys
  // ========================================================================

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

  // ========================================================================
  // Function keys
  // ========================================================================

  /// F1 key
  static const int f1 = 290;

  /// F2 key
  static const int f2 = 291;

  /// F3 key (debug overlay in Minecraft)
  static const int f3 = 292;

  /// F4 key
  static const int f4 = 293;

  /// F5 key (toggle perspective in Minecraft)
  static const int f5 = 294;

  /// F6 key
  static const int f6 = 295;

  /// F7 key
  static const int f7 = 296;

  /// F8 key
  static const int f8 = 297;

  /// F9 key
  static const int f9 = 298;

  /// F10 key
  static const int f10 = 299;

  /// F11 key (fullscreen toggle)
  static const int f11 = 300;

  /// F12 key
  static const int f12 = 301;

  /// F13 key
  static const int f13 = 302;

  /// F14 key
  static const int f14 = 303;

  /// F15 key
  static const int f15 = 304;

  /// F16 key
  static const int f16 = 305;

  /// F17 key
  static const int f17 = 306;

  /// F18 key
  static const int f18 = 307;

  /// F19 key
  static const int f19 = 308;

  /// F20 key
  static const int f20 = 309;

  /// F21 key
  static const int f21 = 310;

  /// F22 key
  static const int f22 = 311;

  /// F23 key
  static const int f23 = 312;

  /// F24 key
  static const int f24 = 313;

  /// F25 key
  static const int f25 = 314;

  // ========================================================================
  // Modifier keys
  // ========================================================================

  /// Left Shift key
  static const int leftShift = 340;

  /// Left Control key
  static const int leftControl = 341;

  /// Left Alt key
  static const int leftAlt = 342;

  /// Left Super/Windows/Command key
  static const int leftSuper = 343;

  /// Right Shift key
  static const int rightShift = 344;

  /// Right Control key
  static const int rightControl = 345;

  /// Right Alt key
  static const int rightAlt = 346;

  /// Right Super/Windows/Command key
  static const int rightSuper = 347;

  /// Menu key
  static const int menu = 348;

  // ========================================================================
  // Punctuation and symbols
  // ========================================================================

  /// Apostrophe/single quote key
  static const int apostrophe = 39;

  /// Comma key
  static const int comma = 44;

  /// Minus key
  static const int minus = 45;

  /// Period/dot key
  static const int period = 46;

  /// Slash key
  static const int slash = 47;

  /// Semicolon key
  static const int semicolon = 59;

  /// Equals key
  static const int equal = 61;

  /// Left bracket key
  static const int leftBracket = 91;

  /// Backslash key
  static const int backslash = 92;

  /// Right bracket key
  static const int rightBracket = 93;

  /// Grave accent/backtick key
  static const int graveAccent = 96;

  // ========================================================================
  // Minecraft-specific key aliases (common Minecraft actions)
  // ========================================================================

  /// Forward movement (W)
  static const int moveForward = w;

  /// Backward movement (S)
  static const int moveBackward = s;

  /// Left strafe (A)
  static const int moveLeft = a;

  /// Right strafe (D)
  static const int moveRight = d;

  /// Jump (Space)
  static const int jump = space;

  /// Sneak/crouch (Left Shift)
  static const int sneak = leftShift;

  /// Sprint (Left Control)
  static const int sprint = leftControl;

  /// Inventory (E)
  static const int inventory = e;

  /// Drop item (Q)
  static const int drop = q;

  /// Chat (T)
  static const int chat = t;

  /// Command (/)
  static const int command = slash;

  /// Player list (Tab)
  static const int playerList = tab;
}

/// Mouse button constants for input simulation.
///
/// Use these with [ClientGameContext.click], [ClientGameContext.holdMouse], etc.
///
/// Example:
/// ```dart
/// await game.click(button: MouseButton.right); // Right click
/// await game.clickAt(100, 200, button: MouseButton.left); // Left click at position
/// ```
abstract class MouseButton {
  /// Left mouse button (primary click, attack in Minecraft)
  static const int left = 0;

  /// Right mouse button (secondary click, use/place in Minecraft)
  static const int right = 1;

  /// Middle mouse button (pick block in Minecraft)
  static const int middle = 2;

  /// Mouse button 4 (back button on some mice)
  static const int button4 = 3;

  /// Mouse button 5 (forward button on some mice)
  static const int button5 = 4;
}
