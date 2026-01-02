# Metal Rendering Integration for Flutter in Minecraft (macOS)

## Problem Statement

On macOS Apple Silicon, sharing textures between Flutter (Metal) and Minecraft (OpenGL) via IOSurface fails with the error:
```
UNSUPPORTED: unit 0 GLD_TEXTURE_INDEX_RECTANGLE is unloadable
```

This is a fundamental driver limitation - macOS's OpenGL driver cannot sample from Metal-created IOSurface-backed textures on Apple Silicon.

## Proposed Solution

Bypass OpenGL entirely for Flutter rendering on macOS by using Metal directly within Minecraft's rendering pipeline via JNI/native code.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Minecraft (Java)                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    FlutterScreen.java                    │   │
│  │  render() -> calls native renderFlutterOverlay()         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              │ JNI                               │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Native Metal Compositor (C++/ObjC)          │   │
│  │  1. Get current CAMetalDrawable from Minecraft's window  │   │
│  │  2. Composite Flutter's Metal texture onto drawable      │   │
│  │  3. Present                                              │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Metal Compositor (`metal_compositor.mm`)

A new native component that:
- Accesses Minecraft's window (NSWindow) via GLFW
- Gets the window's backing CAMetalLayer (or creates one)
- Composites Flutter's IOSurface texture on top of OpenGL content

### 2. Modified FlutterScreen.java

Instead of trying to render via OpenGL, delegates to native Metal compositor.

### 3. Window Layer Setup

Minecraft uses GLFW which creates an NSOpenGLContext. We need to overlay a CAMetalLayer on top of the OpenGL layer.

## Technical Details

### Phase 1: Access Minecraft's Window

```objc
// Get GLFW window handle from Minecraft (via LWJGL)
// LWJGL exposes: glfwGetCocoaWindow(long window) -> long (NSWindow pointer)

extern "C" void* getMinecraftNSWindow() {
    // Called from Java via JNI
    // Returns the NSWindow pointer for Minecraft's main window
}
```

**Java side (FlutterScreen.java):**
```java
import org.lwjgl.glfw.GLFWNativeCocoa;

long windowHandle = Minecraft.getInstance().getWindow().getWindow();
long nsWindowPtr = GLFWNativeCocoa.glfwGetCocoaWindow(windowHandle);
```

### Phase 2: Create Metal Overlay Layer

```objc
// metal_compositor.mm

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Cocoa/Cocoa.h>

static CAMetalLayer* g_overlay_layer = nil;
static id<MTLDevice> g_device = nil;
static id<MTLCommandQueue> g_command_queue = nil;
static id<MTLRenderPipelineState> g_pipeline_state = nil;

extern "C" bool metal_compositor_init(void* nsWindowPtr) {
    NSWindow* window = (__bridge NSWindow*)nsWindowPtr;
    NSView* contentView = [window contentView];

    // Create Metal layer as overlay
    g_device = MTLCreateSystemDefaultDevice();
    g_overlay_layer = [CAMetalLayer layer];
    g_overlay_layer.device = g_device;
    g_overlay_layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    g_overlay_layer.framebufferOnly = NO;
    g_overlay_layer.frame = contentView.bounds;
    g_overlay_layer.opaque = NO;  // Transparent background
    g_overlay_layer.backgroundColor = CGColorGetConstantColor(kCGColorClear);

    // Add as sublayer on top of OpenGL content
    [contentView.layer addSublayer:g_overlay_layer];

    // Create command queue
    g_command_queue = [g_device newCommandQueue];

    // Create render pipeline for texture blitting
    // (shader that renders a textured quad)
    setupRenderPipeline();

    return true;
}
```

### Phase 3: Composite Flutter Texture

```objc
extern "C" void metal_compositor_render(
    void* iosurfacePtr,    // Flutter's IOSurface
    int surfaceWidth,
    int surfaceHeight,
    int screenX,           // Position on screen
    int screenY,
    int renderWidth,
    int renderHeight
) {
    if (g_overlay_layer == nil) return;

    @autoreleasepool {
        // Get next drawable
        id<CAMetalDrawable> drawable = [g_overlay_layer nextDrawable];
        if (drawable == nil) return;

        // Create texture from Flutter's IOSurface
        IOSurfaceRef surface = (IOSurfaceRef)iosurfacePtr;
        MTLTextureDescriptor* texDesc = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
            width:surfaceWidth
            height:surfaceHeight
            mipmapped:NO];
        texDesc.usage = MTLTextureUsageShaderRead;

        id<MTLTexture> flutterTexture = [g_device
            newTextureWithDescriptor:texDesc
            iosurface:surface
            plane:0];

        // Create command buffer
        id<MTLCommandBuffer> commandBuffer = [g_command_queue commandBuffer];

        // Create render pass (clear to transparent)
        MTLRenderPassDescriptor* passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
        passDesc.colorAttachments[0].texture = drawable.texture;
        passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
        passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
        passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;

        id<MTLRenderCommandEncoder> encoder = [commandBuffer
            renderCommandEncoderWithDescriptor:passDesc];

        // Render Flutter texture as quad at specified position
        [encoder setRenderPipelineState:g_pipeline_state];
        [encoder setFragmentTexture:flutterTexture atIndex:0];

        // Set viewport and scissor for positioning
        MTLViewport viewport = {
            .originX = (double)screenX,
            .originY = (double)screenY,
            .width = (double)renderWidth,
            .height = (double)renderHeight,
            .znear = 0.0,
            .zfar = 1.0
        };
        [encoder setViewport:viewport];

        // Draw fullscreen quad
        [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
            vertexStart:0
            vertexCount:4];

        [encoder endEncoding];

        // Present
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
}
```

### Phase 4: Metal Shaders

```metal
// flutter_composite.metal

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Fullscreen quad vertices (triangle strip)
constant float2 quadVertices[] = {
    float2(-1, -1),  // bottom-left
    float2( 1, -1),  // bottom-right
    float2(-1,  1),  // top-left
    float2( 1,  1),  // top-right
};

constant float2 quadTexCoords[] = {
    float2(0, 1),  // bottom-left (flip Y for Flutter)
    float2(1, 1),  // bottom-right
    float2(0, 0),  // top-left
    float2(1, 0),  // top-right
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    out.position = float4(quadVertices[vertexID], 0.0, 1.0);
    out.texCoord = quadTexCoords[vertexID];
    return out;
}

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> flutterTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    return flutterTexture.sample(textureSampler, in.texCoord);
}
```

### Phase 5: Java Integration

```java
// FlutterScreen.java modifications

public class FlutterScreen extends Screen {
    private static boolean metalCompositorInitialized = false;

    @Override
    protected void init() {
        super.init();

        if (!metalCompositorInitialized && isMacOS()) {
            // Get NSWindow pointer via LWJGL
            long windowHandle = Minecraft.getInstance().getWindow().getWindow();
            long nsWindowPtr = GLFWNativeCocoa.glfwGetCocoaWindow(windowHandle);

            // Initialize Metal compositor
            metalCompositorInitialized = DartBridgeClient.initMetalCompositor(nsWindowPtr);
        }
    }

    @Override
    public void render(GuiGraphics guiGraphics, int mouseX, int mouseY, float partialTick) {
        // Process Flutter tasks and render
        DartBridgeClient.processFlutterTasks();

        if (metalCompositorInitialized) {
            // Get Flutter's IOSurface info
            long iosurfacePtr = DartBridgeClient.getFlutterIOSurface();
            int width = DartBridgeClient.getFlutterTextureWidth();
            int height = DartBridgeClient.getFlutterTextureHeight();

            if (iosurfacePtr != 0 && width > 0 && height > 0) {
                // Render via Metal compositor (overlays on top of OpenGL)
                DartBridgeClient.renderMetalComposite(
                    iosurfacePtr, width, height,
                    0, 0,  // screen position
                    this.width, this.height  // render size
                );
            }
        } else {
            // Fallback to software rendering
            renderSoftwareFallback(guiGraphics);
        }
    }
}
```

## Synchronization Considerations

### OpenGL → Metal Ordering

Since Minecraft renders with OpenGL and we overlay with Metal:

1. **Option A: Layer-based compositing** (recommended)
   - CAMetalLayer sits on top of NSOpenGLLayer
   - macOS window server handles compositing
   - No explicit synchronization needed

2. **Option B: Synchronized rendering**
   - Call `glFinish()` before Metal rendering
   - Ensures OpenGL frame is complete before Metal overlay

### Flutter → Metal Ordering

- Already handled by `metal_renderer_flush_and_wait()`
- Call this before accessing the IOSurface for compositing

## File Structure

```
packages/native_mc_bridge/src/
├── metal_renderer.mm          # Existing Flutter Metal renderer
├── metal_renderer.h
├── metal_compositor.mm        # NEW: Minecraft overlay compositor
├── metal_compositor.h         # NEW
├── flutter_composite.metal    # NEW: Metal shaders
└── dart_bridge_client.cpp     # Add JNI bindings for compositor
```

## JNI Interface

```cpp
// New functions in dart_bridge_client.cpp

// Initialize Metal compositor with Minecraft's window
JNIEXPORT jboolean JNICALL Java_com_redstone_DartBridgeClient_initMetalCompositor(
    JNIEnv* env, jclass clazz, jlong nsWindowPtr);

// Render Flutter texture via Metal compositor
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_renderMetalComposite(
    JNIEnv* env, jclass clazz,
    jlong iosurfacePtr, jint surfaceWidth, jint surfaceHeight,
    jint screenX, jint screenY, jint renderWidth, jint renderHeight);

// Get IOSurface pointer (already exists, just expose to Java)
JNIEXPORT jlong JNICALL Java_com_redstone_DartBridgeClient_getFlutterIOSurface(
    JNIEnv* env, jclass clazz);

// Cleanup
JNIEXPORT void JNICALL Java_com_redstone_DartBridgeClient_shutdownMetalCompositor(
    JNIEnv* env, jclass clazz);
```

## Build Changes

### CMakeLists.txt

```cmake
# Add Metal compositor source
set(SOURCES
    src/dart_bridge_client.cpp
    src/metal_renderer.mm
    src/metal_compositor.mm  # NEW
)

# Compile Metal shaders
if(APPLE)
    # Compile .metal to .metallib
    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/flutter_composite.metallib
        COMMAND xcrun -sdk macosx metal -c ${CMAKE_SOURCE_DIR}/src/flutter_composite.metal
                -o ${CMAKE_BINARY_DIR}/flutter_composite.air
        COMMAND xcrun -sdk macosx metallib ${CMAKE_BINARY_DIR}/flutter_composite.air
                -o ${CMAKE_BINARY_DIR}/flutter_composite.metallib
        DEPENDS ${CMAKE_SOURCE_DIR}/src/flutter_composite.metal
    )
endif()
```

## Potential Issues & Mitigations

### 1. Layer Ordering
**Issue**: Metal layer might not appear on top of OpenGL content.
**Mitigation**: Set `zPosition` on CAMetalLayer, or use `NSView` overlay instead of sublayer.

### 2. Resize Handling
**Issue**: Window resize needs to update Metal layer frame.
**Mitigation**: Add resize callback or check frame each render.

### 3. Fullscreen Mode
**Issue**: Fullscreen transitions may reset layer hierarchy.
**Mitigation**: Re-attach Metal layer after fullscreen toggle.

### 4. Input Passthrough
**Issue**: Metal layer might intercept mouse events.
**Mitigation**: Make overlay layer non-interactive or handle hit testing.

### 5. Performance
**Issue**: Additional compositing overhead.
**Mitigation**:
- Use `framebufferOnly = YES` if we don't need to read back
- Minimize draw calls (single quad)
- Consider CADisplayLink for vsync

## Testing Plan

1. **Basic rendering**: Verify Flutter content appears on screen
2. **Transparency**: Verify Minecraft world visible behind Flutter UI
3. **Input**: Verify mouse/keyboard events reach Flutter
4. **Resize**: Test window resizing
5. **Fullscreen**: Test fullscreen toggle
6. **Performance**: Measure frame times vs software fallback

## Success Criteria

- Flutter UI renders correctly over Minecraft
- No "unloadable texture" errors
- Hover events have low latency (< 16ms)
- No visible tearing or flickering
- Works on Apple Silicon Macs (M1/M2/M3/M4)

## Alternative: NSView Overlay

If CAMetalLayer sublayer doesn't work well, alternative approach:

```objc
// Create a transparent NSView with CAMetalLayer backing
@interface FlutterOverlayView : NSView
@property (nonatomic, strong) CAMetalLayer* metalLayer;
@end

@implementation FlutterOverlayView
- (CALayer*)makeBackingLayer {
    self.metalLayer = [CAMetalLayer layer];
    return self.metalLayer;
}
- (BOOL)wantsLayer { return YES; }
- (BOOL)isOpaque { return NO; }
@end

// Add as child view of Minecraft's content view
FlutterOverlayView* overlay = [[FlutterOverlayView alloc] initWithFrame:contentView.bounds];
overlay.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
[contentView addSubview:overlay positioned:NSWindowAbove relativeTo:nil];
```

This gives more control over the overlay's behavior and event handling.
