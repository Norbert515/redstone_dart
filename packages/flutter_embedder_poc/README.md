# Flutter Embedder Proof of Concept

A minimal C++ program that embeds Flutter and renders to an OpenGL context using GLFW for window management. This is Phase 1 of integrating Flutter into Minecraft.

## Prerequisites

1. **Flutter SDK** (3.0+)
   ```bash
   flutter --version
   flutter precache  # Download engine artifacts
   ```

2. **CMake** (3.21+)
   ```bash
   cmake --version
   ```

3. **GLFW3**
   ```bash
   # macOS
   brew install glfw

   # Ubuntu/Debian
   sudo apt install libglfw3-dev

   # Windows (vcpkg)
   vcpkg install glfw3
   ```

4. **C++17 compiler**
   - macOS: Xcode Command Line Tools
   - Linux: GCC 8+ or Clang 7+
   - Windows: Visual Studio 2019+

## Building

### 1. Build the Flutter App

First, build the Flutter app to generate the asset bundle:

```bash
cd flutter_app
flutter pub get
flutter build bundle
```

This creates `flutter_app/build/flutter_assets/` with the compiled Dart code.

### 2. Build the C++ Embedder

```bash
# From the flutter_embedder_poc directory
mkdir build
cd build

# Configure (auto-detects Flutter SDK from PATH)
cmake ..

# Or specify Flutter SDK path explicitly
cmake -DFLUTTER_SDK_PATH=/path/to/flutter ..

# Build
cmake --build .
```

### 3. Run

```bash
./build/flutter_embedder_poc
```

You should see a window with a Flutter UI showing "Flutter in Minecraft!" and a clickable button.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GLFW Window                             │
│                    (OpenGL 3.3 Context)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐        ┌───────────────────────────────┐  │
│  │   main.cpp       │        │     Flutter Engine            │  │
│  │                  │        │                               │  │
│  │  - Event Loop    │◄──────►│  - Dart VM                    │  │
│  │  - Input Forward │        │  - Skia Renderer              │  │
│  │  - GL Callbacks  │        │  - Platform Channels          │  │
│  └──────────────────┘        └───────────────────────────────┘  │
│                                                                 │
│  OpenGL Callbacks:                                              │
│  • make_current    - Make GL context current                    │
│  • clear_current   - Clear GL context                           │
│  • fbo_callback    - Return FBO to render to (0 = window)       │
│  • present         - Swap buffers when frame ready              │
│  • gl_proc_resolver- Resolve GL function pointers               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Key Concepts for Minecraft Integration

This PoC demonstrates the core patterns needed for Minecraft:

### 1. OpenGL Renderer Callbacks

Flutter uses callbacks to interact with OpenGL:

```cpp
FlutterRendererConfig renderer_config = {};
renderer_config.type = kOpenGL;
renderer_config.open_gl.make_current = OnMakeCurrent;
renderer_config.open_gl.clear_current = OnClearCurrent;
renderer_config.open_gl.fbo_callback = OnFboCallback;  // Return FBO ID
renderer_config.open_gl.present = OnPresent;
```

### 2. FBO Rendering (Next Step)

Currently renders to the default framebuffer (window). For Minecraft:

```cpp
// Create FBO and texture
GLuint fbo, texture;
glGenFramebuffers(1, &fbo);
glGenTextures(1, &texture);
// ... configure texture ...
glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);

// Return FBO ID in callback
static uint32_t OnFboCallback(void* user_data) {
    return fbo;  // Flutter renders to this FBO
}

// In Minecraft, use 'texture' in GUI rendering
```

### 3. Input Forwarding

Mouse events are forwarded to Flutter:

```cpp
FlutterPointerEvent event = {};
event.phase = kFlutterPointerPhaseDown;  // or Move, Up, Hover
event.x = mouse_x * pixel_ratio;
event.y = mouse_y * pixel_ratio;
FlutterEngineSendPointerEvent(engine, &event, 1);
```

### 4. Window Metrics

Must send window size to Flutter:

```cpp
FlutterWindowMetricsEvent event = {};
event.width = width * pixel_ratio;
event.height = height * pixel_ratio;
event.pixel_ratio = pixel_ratio;
FlutterEngineSendWindowMetricsEvent(engine, &event);
```

## Next Steps for Minecraft Integration

1. **Render to FBO**: Modify `OnFboCallback` to return a custom FBO
2. **Remove GLFW**: Use Minecraft's LWJGL context instead
3. **JNI Bridge**: Create Java bindings to control the embedder
4. **Texture Integration**: Pass Flutter's texture to Minecraft's GUI renderer
5. **Input Routing**: Forward Minecraft's input events to Flutter

## Troubleshooting

### "Flutter Engine not found"

Run `flutter precache` to download engine artifacts.

### "Failed to start Flutter engine"

Check that:
1. Flutter app was built: `flutter_app/build/flutter_assets/` exists
2. ICU data file exists at the expected path
3. OpenGL 3.3+ is available

### Black window / no rendering

1. Check console for Flutter engine errors
2. Verify assets path is correct
3. Try running with `FLUTTER_ENGINE_SWITCHES=--verbose`

### HiDPI issues

The embedder handles pixel ratio automatically. If text appears too small/large, check `g_state.pixel_ratio` calculation.

## Files

```
flutter_embedder_poc/
├── CMakeLists.txt           # Build configuration
├── README.md                # This file
├── src/
│   └── main.cpp             # Embedder implementation
└── flutter_app/             # Test Flutter application
    ├── pubspec.yaml
    └── lib/
        └── main.dart
```

## References

- [Flutter Embedder API](https://github.com/flutter/engine/blob/main/shell/platform/embedder/embedder.h)
- [Flutter Custom Embedder Wiki](https://github.com/aspect-build/aspect-workflows/wiki/Flutter-Custom-Embedder)
- [go-flutter](https://github.com/nickvlow/go-flutter) - Another embedder implementation
