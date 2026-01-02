package com.redstone.flutter;

import com.mojang.blaze3d.platform.NativeImage;
import com.redstone.DartBridgeClient;
import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.input.MouseButtonEvent;
import net.minecraft.client.renderer.RenderPipelines;
import net.minecraft.client.renderer.texture.DynamicTexture;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import org.lwjgl.opengl.ARBTextureRectangle;
import org.lwjgl.opengl.GL11;
import org.lwjgl.opengl.GL12;
import org.lwjgl.opengl.GL13;
import org.lwjgl.opengl.GL15;
import org.lwjgl.opengl.GL20;
import org.lwjgl.opengl.GL30;
import org.lwjgl.system.MemoryStack;
import org.lwjgl.system.MemoryUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.ByteBuffer;
import java.nio.FloatBuffer;

/**
 * A Minecraft Screen that displays Flutter-rendered content.
 * Flutter renders to a pixel buffer which is uploaded to a dynamic texture.
 */
@Environment(EnvType.CLIENT)
public class FlutterScreen extends Screen {
    private static final Logger LOGGER = LoggerFactory.getLogger("FlutterScreen");

    // Unique identifier for the Flutter texture
    private static final Identifier FLUTTER_TEXTURE_ID = Identifier.fromNamespaceAndPath("redstone", "flutter_screen");

    private DynamicTexture dynamicTexture = null;
    private NativeImage nativeImage = null;
    private int textureWidth = 0;
    private int textureHeight = 0;
    private boolean flutterInitialized = false;

    // ==========================================================================
    // Shader-based GL_TEXTURE_RECTANGLE rendering (for Metal/IOSurface on macOS)
    // ==========================================================================
    // These are static because the shader program and VAO/VBO can be shared across
    // all FlutterScreen instances (they're just rendering infrastructure).
    private static int rectShaderProgram = 0;
    private static int rectVao = 0;
    private static int rectVbo = 0;
    private static int rectUniformTex = -1;
    private static int rectUniformTexSize = -1;
    private static boolean rectShaderInitialized = false;
    private static boolean rectShaderFailed = false;  // Prevents repeated initialization attempts

    // Vertex shader for textured quad (Core Profile compatible)
    private static final String RECT_VERTEX_SHADER = """
        #version 330 core
        layout(location = 0) in vec2 position;
        layout(location = 1) in vec2 texCoord;
        out vec2 fragTexCoord;
        void main() {
            gl_Position = vec4(position, 0.0, 1.0);
            fragTexCoord = texCoord;
        }
        """;

    // Fragment shader for GL_TEXTURE_RECTANGLE (uses pixel coordinates, not normalized)
    // The texture is BGRA from IOSurface, but OpenGL handles the format conversion
    private static final String RECT_FRAGMENT_SHADER = """
        #version 330 core
        #extension GL_ARB_texture_rectangle : enable
        uniform sampler2DRect tex;
        uniform vec2 texSize;
        in vec2 fragTexCoord;
        out vec4 fragColor;
        void main() {
            // fragTexCoord is 0-1 normalized, multiply by texSize to get pixel coords
            vec2 pixelCoord = fragTexCoord * texSize;
            // Flip Y coordinate: Flutter renders Y-down, we need Y-up for correct orientation
            pixelCoord.y = texSize.y - pixelCoord.y;
            fragColor = texture(tex, pixelCoord);
        }
        """;

    // ==========================================================================
    // FBO resources for GPU-only IOSurface → GL_TEXTURE_2D copy
    // Uses shader-based rendering (RECT texture -> FBO with 2D texture attachment)
    // ==========================================================================
    private static int fboDst = 0;                  // Destination FBO (2D texture attached)
    private static int fboDstTexture = 0;           // GL_TEXTURE_2D for Minecraft to use
    private static int fboWidth = 0;
    private static int fboHeight = 0;
    private static boolean fboInitialized = false;
    private static boolean fboFailed = false;

    // Flutter pointer phases (must match FlutterPointerPhase enum)
    private static final int PHASE_CANCEL = 0;
    private static final int PHASE_UP = 1;
    private static final int PHASE_DOWN = 2;
    private static final int PHASE_MOVE = 3;
    private static final int PHASE_ADD = 4;
    private static final int PHASE_REMOVE = 5;
    private static final int PHASE_HOVER = 6;

    // Mouse button masks
    private static final long BUTTON_PRIMARY = 1;
    private static final long BUTTON_SECONDARY = 2;
    private static final long BUTTON_MIDDLE = 4;

    private long currentButtons = 0;
    private boolean pointerAdded = false;

    public FlutterScreen(Component title) {
        super(title);
    }

    // ==========================================================================
    // Shader Initialization for GL_TEXTURE_RECTANGLE rendering
    // ==========================================================================

    /**
     * Initialize the shader program and VAO/VBO for GL_TEXTURE_RECTANGLE rendering.
     * This is called lazily on first use and the resources are shared across all instances.
     * Returns true if shader is ready to use.
     */
    private static boolean initRectShader() {
        if (rectShaderInitialized) {
            return true;
        }
        if (rectShaderFailed) {
            return false;  // Don't retry if we've already failed
        }

        LOGGER.info("[FlutterScreen] Initializing GL_TEXTURE_RECTANGLE shader program...");

        try {
            // Compile vertex shader
            int vertexShader = GL20.glCreateShader(GL20.GL_VERTEX_SHADER);
            GL20.glShaderSource(vertexShader, RECT_VERTEX_SHADER);
            GL20.glCompileShader(vertexShader);

            if (GL20.glGetShaderi(vertexShader, GL20.GL_COMPILE_STATUS) == GL11.GL_FALSE) {
                String log = GL20.glGetShaderInfoLog(vertexShader);
                LOGGER.error("[FlutterScreen] Vertex shader compilation failed: {}", log);
                GL20.glDeleteShader(vertexShader);
                rectShaderFailed = true;
                return false;
            }

            // Compile fragment shader
            int fragmentShader = GL20.glCreateShader(GL20.GL_FRAGMENT_SHADER);
            GL20.glShaderSource(fragmentShader, RECT_FRAGMENT_SHADER);
            GL20.glCompileShader(fragmentShader);

            if (GL20.glGetShaderi(fragmentShader, GL20.GL_COMPILE_STATUS) == GL11.GL_FALSE) {
                String log = GL20.glGetShaderInfoLog(fragmentShader);
                LOGGER.error("[FlutterScreen] Fragment shader compilation failed: {}", log);
                GL20.glDeleteShader(vertexShader);
                GL20.glDeleteShader(fragmentShader);
                rectShaderFailed = true;
                return false;
            }

            // Link program
            rectShaderProgram = GL20.glCreateProgram();
            GL20.glAttachShader(rectShaderProgram, vertexShader);
            GL20.glAttachShader(rectShaderProgram, fragmentShader);
            GL20.glLinkProgram(rectShaderProgram);

            if (GL20.glGetProgrami(rectShaderProgram, GL20.GL_LINK_STATUS) == GL11.GL_FALSE) {
                String log = GL20.glGetProgramInfoLog(rectShaderProgram);
                LOGGER.error("[FlutterScreen] Shader program linking failed: {}", log);
                GL20.glDeleteShader(vertexShader);
                GL20.glDeleteShader(fragmentShader);
                GL20.glDeleteProgram(rectShaderProgram);
                rectShaderProgram = 0;
                rectShaderFailed = true;
                return false;
            }

            // Shaders can be deleted after linking
            GL20.glDeleteShader(vertexShader);
            GL20.glDeleteShader(fragmentShader);

            // Get uniform locations
            rectUniformTex = GL20.glGetUniformLocation(rectShaderProgram, "tex");
            rectUniformTexSize = GL20.glGetUniformLocation(rectShaderProgram, "texSize");

            LOGGER.info("[FlutterScreen] Shader program created: {}, uniforms tex={}, texSize={}",
                rectShaderProgram, rectUniformTex, rectUniformTexSize);

            // Create VAO and VBO for fullscreen quad
            // Vertices: position (x,y) and texcoord (u,v) interleaved
            // The quad covers clip space (-1,-1) to (1,1) with texcoords (0,0) to (1,1)
            float[] vertices = {
                // Position    // TexCoord
                -1.0f, -1.0f,  0.0f, 0.0f,  // Bottom-left
                 1.0f, -1.0f,  1.0f, 0.0f,  // Bottom-right
                 1.0f,  1.0f,  1.0f, 1.0f,  // Top-right
                -1.0f, -1.0f,  0.0f, 0.0f,  // Bottom-left
                 1.0f,  1.0f,  1.0f, 1.0f,  // Top-right
                -1.0f,  1.0f,  0.0f, 1.0f,  // Top-left
            };

            rectVao = GL30.glGenVertexArrays();
            GL30.glBindVertexArray(rectVao);

            rectVbo = GL15.glGenBuffers();
            GL15.glBindBuffer(GL15.GL_ARRAY_BUFFER, rectVbo);

            try (MemoryStack stack = MemoryStack.stackPush()) {
                FloatBuffer vertexBuffer = stack.mallocFloat(vertices.length);
                vertexBuffer.put(vertices).flip();
                GL15.glBufferData(GL15.GL_ARRAY_BUFFER, vertexBuffer, GL15.GL_STATIC_DRAW);
            }

            // Position attribute (location 0)
            GL20.glVertexAttribPointer(0, 2, GL11.GL_FLOAT, false, 4 * Float.BYTES, 0);
            GL20.glEnableVertexAttribArray(0);

            // TexCoord attribute (location 1)
            GL20.glVertexAttribPointer(1, 2, GL11.GL_FLOAT, false, 4 * Float.BYTES, 2 * Float.BYTES);
            GL20.glEnableVertexAttribArray(1);

            GL30.glBindVertexArray(0);
            GL15.glBindBuffer(GL15.GL_ARRAY_BUFFER, 0);

            LOGGER.info("[FlutterScreen] VAO={}, VBO={} created for rect shader", rectVao, rectVbo);

            rectShaderInitialized = true;
            return true;

        } catch (Exception e) {
            LOGGER.error("[FlutterScreen] Exception during shader initialization", e);
            rectShaderFailed = true;
            return false;
        }
    }

    /**
     * Clean up the rect shader resources.
     * Should be called when the game is shutting down.
     */
    public static void cleanupRectShader() {
        if (rectShaderProgram != 0) {
            GL20.glDeleteProgram(rectShaderProgram);
            rectShaderProgram = 0;
        }
        if (rectVbo != 0) {
            GL15.glDeleteBuffers(rectVbo);
            rectVbo = 0;
        }
        if (rectVao != 0) {
            GL30.glDeleteVertexArrays(rectVao);
            rectVao = 0;
        }
        rectUniformTex = -1;
        rectUniformTexSize = -1;
        rectShaderInitialized = false;
        rectShaderFailed = false;
    }

    /**
     * Render Metal/IOSurface content using GPU-only rendering.
     *
     * Renders the GL_TEXTURE_RECTANGLE (bound to IOSurface via CGLTexImageIOSurface2D)
     * directly to the screen using a shader. NO CPU INVOLVED.
     */
    private void renderMetalTextureWithPBO(GuiGraphics guiGraphics) {
        // Get the GL_TEXTURE_RECTANGLE ID from native (bound to IOSurface)
        int rectTextureId = DartBridgeClient.getFlutterTextureId();
        if (rectTextureId <= 0) {
            guiGraphics.drawCenteredString(
                this.font,
                "Waiting for Flutter frame...",
                this.width / 2,
                this.height / 2,
                0xFFFFFF
            );
            return;
        }

        int texWidth = DartBridgeClient.getFlutterTextureWidth();
        int texHeight = DartBridgeClient.getFlutterTextureHeight();

        if (texWidth <= 0 || texHeight <= 0) {
            return;
        }

        // Render RECT texture directly to screen
        renderRectTextureDirectly(rectTextureId, texWidth, texHeight);
    }

    /**
     * Render GL_TEXTURE_RECTANGLE directly to the screen using custom shader.
     */
    private void renderRectTextureDirectly(int rectTextureId, int texWidth, int texHeight) {
        if (!initRectShader()) {
            return;
        }

        // Save OpenGL state
        int prevProgram = GL11.glGetInteger(GL20.GL_CURRENT_PROGRAM);
        int prevVao = GL11.glGetInteger(GL30.GL_VERTEX_ARRAY_BINDING);
        boolean blendEnabled = GL11.glIsEnabled(GL11.GL_BLEND);
        boolean depthEnabled = GL11.glIsEnabled(GL11.GL_DEPTH_TEST);

        try {
            GL11.glEnable(GL11.GL_BLEND);
            GL11.glBlendFunc(GL11.GL_SRC_ALPHA, GL11.GL_ONE_MINUS_SRC_ALPHA);
            GL11.glDisable(GL11.GL_DEPTH_TEST);

            GL20.glUseProgram(rectShaderProgram);

            // Bind the RECT texture
            GL13.glActiveTexture(GL13.GL_TEXTURE0);
            GL11.glBindTexture(ARBTextureRectangle.GL_TEXTURE_RECTANGLE_ARB, rectTextureId);
            GL20.glUniform1i(rectUniformTex, 0);
            GL20.glUniform2f(rectUniformTexSize, (float) texWidth, (float) texHeight);

            // Render fullscreen quad
            GL30.glBindVertexArray(rectVao);
            GL11.glDrawArrays(GL11.GL_TRIANGLES, 0, 6);

        } finally {
            GL30.glBindVertexArray(prevVao);
            GL11.glBindTexture(ARBTextureRectangle.GL_TEXTURE_RECTANGLE_ARB, 0);
            GL20.glUseProgram(prevProgram);
            if (!blendEnabled) GL11.glDisable(GL11.GL_BLEND);
            if (depthEnabled) GL11.glEnable(GL11.GL_DEPTH_TEST);
        }
    }

    /**
     * Initialize FBO resources for GPU blit.
     */
    private boolean initFboBlitResources(int rectTextureId, int width, int height) {
        if (fboFailed) {
            return false;
        }

        // Check if we need to (re)initialize
        if (fboInitialized && fboWidth == width && fboHeight == height) {
            return true;
        }

        LOGGER.info("[FlutterScreen] Initializing FBO resources: {}x{}", width, height);

        try {
            // Cleanup old resources
            cleanupFboResources();

            // Create destination FBO with GL_TEXTURE_2D
            fboDst = GL30.glGenFramebuffers();

            // Create destination texture (GL_TEXTURE_2D)
            fboDstTexture = GL11.glGenTextures();
            GL11.glBindTexture(GL11.GL_TEXTURE_2D, fboDstTexture);
            GL11.glTexImage2D(GL11.GL_TEXTURE_2D, 0, GL11.GL_RGBA8, width, height, 0,
                              GL11.GL_RGBA, GL11.GL_UNSIGNED_BYTE, (ByteBuffer)null);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MIN_FILTER, GL11.GL_LINEAR);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MAG_FILTER, GL11.GL_LINEAR);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_WRAP_S, GL12.GL_CLAMP_TO_EDGE);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_WRAP_T, GL12.GL_CLAMP_TO_EDGE);

            // Attach destination texture to destination FBO
            GL30.glBindFramebuffer(GL30.GL_FRAMEBUFFER, fboDst);
            GL30.glFramebufferTexture2D(GL30.GL_FRAMEBUFFER, GL30.GL_COLOR_ATTACHMENT0,
                                        GL11.GL_TEXTURE_2D, fboDstTexture, 0);

            int status = GL30.glCheckFramebufferStatus(GL30.GL_FRAMEBUFFER);
            if (status != GL30.GL_FRAMEBUFFER_COMPLETE) {
                LOGGER.error("[FlutterScreen] Destination FBO incomplete: {}", status);
                GL30.glBindFramebuffer(GL30.GL_FRAMEBUFFER, 0);
                fboFailed = true;
                return false;
            }

            GL30.glBindFramebuffer(GL30.GL_FRAMEBUFFER, 0);
            GL11.glBindTexture(GL11.GL_TEXTURE_2D, 0);

            fboWidth = width;
            fboHeight = height;
            fboInitialized = true;

            LOGGER.info("[FlutterScreen] FBO resources initialized: dstFBO={}, dstTex={}", fboDst, fboDstTexture);

            return true;

        } catch (Exception e) {
            LOGGER.error("[FlutterScreen] Failed to initialize FBO resources", e);
            fboFailed = true;
            return false;
        }
    }

    /**
     * Perform the GPU-to-GPU copy from GL_TEXTURE_RECTANGLE to GL_TEXTURE_2D.
     * Uses shader-based rendering instead of glBlitFramebuffer (which doesn't work
     * between RECT and 2D textures on macOS).
     */
    private boolean performFboBlit(int rectTextureId, int width, int height) {
        try {
            // Ensure RECT shader is initialized (we reuse it for the copy)
            if (!initRectShader()) {
                LOGGER.warn("[FlutterScreen] Failed to init rect shader for FBO copy");
                return false;
            }

            // Save current state
            int prevFbo = GL11.glGetInteger(GL30.GL_FRAMEBUFFER_BINDING);
            int prevProgram = GL11.glGetInteger(GL20.GL_CURRENT_PROGRAM);
            int prevVao = GL11.glGetInteger(GL30.GL_VERTEX_ARRAY_BINDING);
            int[] prevViewport = new int[4];
            GL11.glGetIntegerv(GL11.GL_VIEWPORT, prevViewport);
            boolean blendEnabled = GL11.glIsEnabled(GL11.GL_BLEND);
            boolean depthEnabled = GL11.glIsEnabled(GL11.GL_DEPTH_TEST);

            // Bind destination FBO as render target
            GL30.glBindFramebuffer(GL30.GL_FRAMEBUFFER, fboDst);
            GL11.glViewport(0, 0, width, height);

            // Disable blending and depth for clean copy
            GL11.glDisable(GL11.GL_BLEND);
            GL11.glDisable(GL11.GL_DEPTH_TEST);

            // Use RECT shader to render RECT texture into the FBO
            GL20.glUseProgram(rectShaderProgram);

            // Bind the RECT texture
            GL13.glActiveTexture(GL13.GL_TEXTURE0);
            GL11.glBindTexture(ARBTextureRectangle.GL_TEXTURE_RECTANGLE_ARB, rectTextureId);
            GL20.glUniform1i(rectUniformTex, 0);
            GL20.glUniform2f(rectUniformTexSize, (float) width, (float) height);

            // Render fullscreen quad
            GL30.glBindVertexArray(rectVao);
            GL11.glDrawArrays(GL11.GL_TRIANGLES, 0, 6);

            // Restore state
            GL30.glBindVertexArray(prevVao);
            GL11.glBindTexture(ARBTextureRectangle.GL_TEXTURE_RECTANGLE_ARB, 0);
            GL20.glUseProgram(prevProgram);
            GL30.glBindFramebuffer(GL30.GL_FRAMEBUFFER, prevFbo);
            GL11.glViewport(prevViewport[0], prevViewport[1], prevViewport[2], prevViewport[3]);
            if (blendEnabled) GL11.glEnable(GL11.GL_BLEND);
            if (depthEnabled) GL11.glEnable(GL11.GL_DEPTH_TEST);

            return true;

        } catch (Exception e) {
            LOGGER.error("[FlutterScreen] FBO shader copy failed", e);
            return false;
        }
    }

    // Shader and VAO for FBO texture rendering (Core Profile compatible)
    private static int fboShaderProgram = 0;
    private static int fboVao = 0;
    private static int fboVbo = 0;
    private static int fboUniformTex = -1;
    private static boolean fboShaderInitialized = false;

    private static final String FBO_VERTEX_SHADER = """
        #version 330 core
        layout(location = 0) in vec2 position;
        layout(location = 1) in vec2 texCoord;
        out vec2 fragTexCoord;
        void main() {
            gl_Position = vec4(position, 0.0, 1.0);
            fragTexCoord = texCoord;
        }
        """;

    private static final String FBO_FRAGMENT_SHADER = """
        #version 330 core
        uniform sampler2D tex;
        in vec2 fragTexCoord;
        out vec4 fragColor;
        void main() {
            fragColor = texture(tex, fragTexCoord);
        }
        """;

    /**
     * Initialize shader for FBO texture rendering.
     */
    private static boolean initFboShader() {
        if (fboShaderInitialized) return true;

        try {
            // Compile vertex shader
            int vs = GL20.glCreateShader(GL20.GL_VERTEX_SHADER);
            GL20.glShaderSource(vs, FBO_VERTEX_SHADER);
            GL20.glCompileShader(vs);
            if (GL20.glGetShaderi(vs, GL20.GL_COMPILE_STATUS) == GL11.GL_FALSE) {
                LOGGER.error("[FlutterScreen] FBO vertex shader failed: {}", GL20.glGetShaderInfoLog(vs));
                return false;
            }

            // Compile fragment shader
            int fs = GL20.glCreateShader(GL20.GL_FRAGMENT_SHADER);
            GL20.glShaderSource(fs, FBO_FRAGMENT_SHADER);
            GL20.glCompileShader(fs);
            if (GL20.glGetShaderi(fs, GL20.GL_COMPILE_STATUS) == GL11.GL_FALSE) {
                LOGGER.error("[FlutterScreen] FBO fragment shader failed: {}", GL20.glGetShaderInfoLog(fs));
                return false;
            }

            // Link program
            fboShaderProgram = GL20.glCreateProgram();
            GL20.glAttachShader(fboShaderProgram, vs);
            GL20.glAttachShader(fboShaderProgram, fs);
            GL20.glLinkProgram(fboShaderProgram);
            GL20.glDeleteShader(vs);
            GL20.glDeleteShader(fs);

            if (GL20.glGetProgrami(fboShaderProgram, GL20.GL_LINK_STATUS) == GL11.GL_FALSE) {
                LOGGER.error("[FlutterScreen] FBO shader link failed: {}", GL20.glGetProgramInfoLog(fboShaderProgram));
                return false;
            }

            fboUniformTex = GL20.glGetUniformLocation(fboShaderProgram, "tex");

            // Create VAO/VBO for fullscreen quad
            float[] vertices = {
                -1.0f, -1.0f,  0.0f, 0.0f,
                 1.0f, -1.0f,  1.0f, 0.0f,
                 1.0f,  1.0f,  1.0f, 1.0f,
                -1.0f, -1.0f,  0.0f, 0.0f,
                 1.0f,  1.0f,  1.0f, 1.0f,
                -1.0f,  1.0f,  0.0f, 1.0f,
            };

            fboVao = GL30.glGenVertexArrays();
            GL30.glBindVertexArray(fboVao);

            fboVbo = GL15.glGenBuffers();
            GL15.glBindBuffer(GL15.GL_ARRAY_BUFFER, fboVbo);

            try (MemoryStack stack = MemoryStack.stackPush()) {
                FloatBuffer buf = stack.mallocFloat(vertices.length);
                buf.put(vertices).flip();
                GL15.glBufferData(GL15.GL_ARRAY_BUFFER, buf, GL15.GL_STATIC_DRAW);
            }

            GL20.glVertexAttribPointer(0, 2, GL11.GL_FLOAT, false, 4 * Float.BYTES, 0);
            GL20.glEnableVertexAttribArray(0);
            GL20.glVertexAttribPointer(1, 2, GL11.GL_FLOAT, false, 4 * Float.BYTES, 2 * Float.BYTES);
            GL20.glEnableVertexAttribArray(1);

            GL30.glBindVertexArray(0);
            fboShaderInitialized = true;
            LOGGER.info("[FlutterScreen] FBO shader initialized");
            return true;

        } catch (Exception e) {
            LOGGER.error("[FlutterScreen] FBO shader init exception", e);
            return false;
        }
    }

    /**
     * Render the blitted GL_TEXTURE_2D using shader-based rendering (Core Profile).
     */
    private void renderFboTexture(GuiGraphics guiGraphics, int texWidth, int texHeight) {
        if (!initFboShader()) {
            renderSoftwareFallback(guiGraphics);
            return;
        }

        // Save OpenGL state
        int prevProgram = GL11.glGetInteger(GL20.GL_CURRENT_PROGRAM);
        int prevVao = GL11.glGetInteger(GL30.GL_VERTEX_ARRAY_BINDING);
        int prevTexture = GL11.glGetInteger(GL11.GL_TEXTURE_BINDING_2D);
        boolean blendEnabled = GL11.glIsEnabled(GL11.GL_BLEND);
        boolean depthEnabled = GL11.glIsEnabled(GL11.GL_DEPTH_TEST);

        try {
            GL11.glEnable(GL11.GL_BLEND);
            GL11.glBlendFunc(GL11.GL_SRC_ALPHA, GL11.GL_ONE_MINUS_SRC_ALPHA);
            GL11.glDisable(GL11.GL_DEPTH_TEST);

            GL20.glUseProgram(fboShaderProgram);
            GL13.glActiveTexture(GL13.GL_TEXTURE0);
            GL11.glBindTexture(GL11.GL_TEXTURE_2D, fboDstTexture);
            GL20.glUniform1i(fboUniformTex, 0);

            GL30.glBindVertexArray(fboVao);
            GL11.glDrawArrays(GL11.GL_TRIANGLES, 0, 6);

        } finally {
            GL30.glBindVertexArray(prevVao);
            GL11.glBindTexture(GL11.GL_TEXTURE_2D, prevTexture);
            GL20.glUseProgram(prevProgram);
            if (!blendEnabled) GL11.glDisable(GL11.GL_BLEND);
            if (depthEnabled) GL11.glEnable(GL11.GL_DEPTH_TEST);
        }
    }

    /**
     * Cleanup FBO resources.
     */
    private static void cleanupFboResources() {
        if (fboDst != 0) {
            GL30.glDeleteFramebuffers(fboDst);
            fboDst = 0;
        }
        if (fboDstTexture != 0) {
            GL11.glDeleteTextures(fboDstTexture);
            fboDstTexture = 0;
        }
        fboWidth = 0;
        fboHeight = 0;
        fboInitialized = false;
    }

    /**
     * Returns true to use the in-game UI background style (dark gradient overlay).
     * This gives the same look as inventory/crafting screens.
     */
    @Override
    public boolean isInGameUi() {
        return true;
    }

    /**
     * Returns false so the game continues running while the screen is open.
     */
    @Override
    public boolean isPauseScreen() {
        return false;
    }

    @Override
    protected void init() {
        super.init();

        // In dual-runtime mode, Flutter is initialized separately by DartModClientLoader.
        // Check the client runtime, not the server runtime.
        flutterInitialized = DartBridgeClient.isClientInitialized();

        LOGGER.info("[FlutterScreen] init() - Flutter client initialized: {}", flutterInitialized);

        if (!flutterInitialized) {
            LOGGER.warn("Flutter client runtime not initialized - screen will show placeholder");
        }

        // Notify Flutter of screen size
        if (flutterInitialized) {
            // Send FRAMEBUFFER dimensions with pixel_ratio=guiScale
            // Flutter calculates logical size = physical / pixel_ratio = GUI coordinates
            var window = this.minecraft.getWindow();
            int guiScale = window.getGuiScale();
            int fbWidth = this.width * guiScale;
            int fbHeight = this.height * guiScale;
            LOGGER.info("[FlutterScreen] Sending window metrics: {}x{} (framebuffer), pixel_ratio={}", fbWidth, fbHeight, guiScale);
            DartBridgeClient.sendWindowMetrics(fbWidth, fbHeight, (double) guiScale);
        }
    }

    /**
     * Override this to provide the path to Flutter assets.
     */
    protected String getFlutterAssetsPath() {
        return null; // Subclasses should override
    }

    /**
     * Override this to provide the path to ICU data.
     */
    protected String getFlutterIcuPath() {
        return null; // Subclasses should override
    }

    @Override
    public void render(GuiGraphics guiGraphics, int mouseX, int mouseY, float partialTick) {
        // Call super.render() first - this renders the Minecraft background
        // (dark gradient overlay because isInGameUi() returns true)
        super.render(guiGraphics, mouseX, mouseY, partialTick);

        if (!flutterInitialized) {
            // Draw placeholder text if Flutter not initialized
            guiGraphics.drawCenteredString(
                this.font,
                "Flutter not initialized",
                this.width / 2,
                this.height / 2,
                0xFFFFFF
            );
            return;
        }

        // Check which rendering path to use
        if (DartBridgeClient.isOpenGLRenderer()) {
            // OpenGL path: render Flutter's texture directly (zero-copy)
            renderFlutterTextureOpenGL(guiGraphics);
        } else {
            // Software path: copy pixels to DynamicTexture
            if (DartBridgeClient.hasNewFrame()) {
                updateTexture();
            }

            // Render the Flutter texture with alpha blending
            if (dynamicTexture != null && textureWidth > 0 && textureHeight > 0) {
                renderFlutterTexture(guiGraphics);
            } else {
                // Flutter is initialized but no frame yet
                guiGraphics.drawCenteredString(
                    this.font,
                    "Waiting for Flutter frame...",
                    this.width / 2,
                    this.height / 2,
                    0xFFFFFF
                );
            }
        }
    }

    private void updateTexture() {
        ByteBuffer pixels = DartBridgeClient.getFramePixels();
        if (pixels == null) return;

        int newWidth = DartBridgeClient.getFrameWidth();
        int newHeight = DartBridgeClient.getFrameHeight();

        if (newWidth <= 0 || newHeight <= 0) return;

        // Check if we need to recreate the texture (size changed)
        if (newWidth != textureWidth || newHeight != textureHeight) {
            cleanupTexture();
            createTexture(newWidth, newHeight);
        }

        if (nativeImage == null) return;

        // Copy pixel data from Flutter buffer to NativeImage
        // Flutter uses RGBA format, which matches NativeImage.Format.RGBA
        long srcAddress = MemoryUtil.memAddress(pixels);
        long dstAddress = nativeImage.getPointer();
        long size = (long) newWidth * newHeight * 4; // 4 bytes per pixel (RGBA)
        MemoryUtil.memCopy(srcAddress, dstAddress, size);

        // Upload to GPU
        dynamicTexture.upload();
    }

    private void createTexture(int width, int height) {
        textureWidth = width;
        textureHeight = height;

        // Create NativeImage with RGBA format
        nativeImage = new NativeImage(width, height, false);

        // Create DynamicTexture from the NativeImage
        dynamicTexture = new DynamicTexture(() -> "flutter_screen", nativeImage);

        // Register the texture with Minecraft's texture manager
        this.minecraft.getTextureManager().register(FLUTTER_TEXTURE_ID, dynamicTexture);

        LOGGER.debug("Created Flutter texture: {}x{}", width, height);
    }

    private void cleanupTexture() {
        if (dynamicTexture != null) {
            // Unregister from texture manager
            this.minecraft.getTextureManager().release(FLUTTER_TEXTURE_ID);
            dynamicTexture = null;
        }
        // Note: DynamicTexture.close() also closes the NativeImage
        nativeImage = null;
        textureWidth = 0;
        textureHeight = 0;
    }

    private void renderFlutterTexture(GuiGraphics guiGraphics) {
        // Draw the Flutter texture at 1:1 pixel ratio for sharp rendering
        // Flutter renders at pixel_ratio * screen_size, so we need to render at framebuffer resolution
        var window = this.minecraft.getWindow();
        int guiScale = window.getGuiScale();

        // Save the current pose and apply inverse GUI scale to render at framebuffer pixels
        guiGraphics.pose().pushMatrix();
        guiGraphics.pose().scale(1.0f / guiScale, 1.0f / guiScale);

        // Now coordinates are in framebuffer pixels - blit the texture at 1:1
        guiGraphics.blit(
            RenderPipelines.GUI_TEXTURED,
            FLUTTER_TEXTURE_ID,
            0, 0,                           // dest x, y (framebuffer pixels)
            0.0f, 0.0f,                     // src UV offset
            textureWidth, textureHeight,    // dest size (full texture size = framebuffer size)
            textureWidth, textureHeight,    // src region size
            textureWidth, textureHeight     // texture size
        );

        guiGraphics.pose().popMatrix();
    }

    /**
     * Render Flutter's texture directly (zero-copy path).
     *
     * On macOS with Metal renderer: Uses PBO-based rendering for GPU-accelerated transfer.
     * The IOSurface pixels are read and uploaded via double-buffered PBOs to a regular
     * GL_TEXTURE_2D, which works reliably on macOS Core Profile (unlike GL_TEXTURE_RECTANGLE).
     *
     * On Windows/Linux (OpenGL): Uses GL_TEXTURE_2D with normalized coordinates (0 to 1)
     * and immediate mode rendering (which works on compatibility profiles).
     */
    private void renderFlutterTextureOpenGL(GuiGraphics guiGraphics) {
        // On macOS with Metal renderer, use PBO-based transfer for low-latency rendering.
        // This reads pixels from IOSurface and uploads via double-buffered PBOs.
        if (DartBridgeClient.isMetalRenderer()) {
            renderMetalTextureWithPBO(guiGraphics);
            return;
        }

        int textureId = DartBridgeClient.getFlutterTextureId();
        if (textureId <= 0) {
            // No texture available yet
            guiGraphics.drawCenteredString(
                this.font,
                "Waiting for Flutter frame...",
                this.width / 2,
                this.height / 2,
                0xFFFFFF
            );
            return;
        }

        int texWidth = DartBridgeClient.getFlutterTextureWidth();
        int texHeight = DartBridgeClient.getFlutterTextureHeight();

        if (texWidth <= 0 || texHeight <= 0) {
            return;
        }

        var window = this.minecraft.getWindow();
        int screenWidth = window.getWidth();
        int screenHeight = window.getHeight();

        // On Windows/Linux with OpenGL compatibility profile, use GL_TEXTURE_2D
        int textureTarget = GL11.GL_TEXTURE_2D;

        // Save OpenGL state
        int prevProgram = GL11.glGetInteger(GL20.GL_CURRENT_PROGRAM);
        int prevTexture2D = GL11.glGetInteger(GL11.GL_TEXTURE_BINDING_2D);
        boolean blendEnabled = GL11.glIsEnabled(GL11.GL_BLEND);
        boolean depthEnabled = GL11.glIsEnabled(GL11.GL_DEPTH_TEST);

        // Set up for 2D rendering
        GL20.glUseProgram(0);  // Use fixed-function pipeline
        GL11.glEnable(textureTarget);
        GL11.glEnable(GL11.GL_BLEND);
        GL11.glBlendFunc(GL11.GL_SRC_ALPHA, GL11.GL_ONE_MINUS_SRC_ALPHA);
        GL11.glDisable(GL11.GL_DEPTH_TEST);

        // Bind Flutter's texture
        GL13.glActiveTexture(GL13.GL_TEXTURE0);
        GL11.glBindTexture(textureTarget, textureId);
        GL11.glTexParameteri(textureTarget, GL11.GL_TEXTURE_MIN_FILTER, GL11.GL_LINEAR);
        GL11.glTexParameteri(textureTarget, GL11.GL_TEXTURE_MAG_FILTER, GL11.GL_LINEAR);

        // Set up orthographic projection to match screen coordinates
        GL11.glMatrixMode(GL11.GL_PROJECTION);
        GL11.glPushMatrix();
        GL11.glLoadIdentity();
        GL11.glOrtho(0, screenWidth, screenHeight, 0, -1, 1);

        GL11.glMatrixMode(GL11.GL_MODELVIEW);
        GL11.glPushMatrix();
        GL11.glLoadIdentity();

        // Draw textured quad covering the screen
        // Flutter texture needs to be flipped vertically (Flutter renders Y-down, OpenGL is Y-up)
        // GL_TEXTURE_2D uses normalized coordinates (0 to 1)
        GL11.glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        GL11.glBegin(GL11.GL_QUADS);
        // Top-left (screen Y=0 maps to texture V=1 for vertical flip)
        GL11.glTexCoord2f(0.0f, 1.0f);
        GL11.glVertex2f(0, 0);
        // Bottom-left (screen Y=height maps to texture V=0)
        GL11.glTexCoord2f(0.0f, 0.0f);
        GL11.glVertex2f(0, screenHeight);
        // Bottom-right
        GL11.glTexCoord2f(1.0f, 0.0f);
        GL11.glVertex2f(screenWidth, screenHeight);
        // Top-right
        GL11.glTexCoord2f(1.0f, 1.0f);
        GL11.glVertex2f(screenWidth, 0);
        GL11.glEnd();

        // Restore matrices
        GL11.glMatrixMode(GL11.GL_PROJECTION);
        GL11.glPopMatrix();
        GL11.glMatrixMode(GL11.GL_MODELVIEW);
        GL11.glPopMatrix();

        // Restore OpenGL state
        GL11.glDisable(textureTarget);
        GL11.glBindTexture(GL11.GL_TEXTURE_2D, prevTexture2D);
        GL20.glUseProgram(prevProgram);
        if (!blendEnabled) GL11.glDisable(GL11.GL_BLEND);
        if (depthEnabled) GL11.glEnable(GL11.GL_DEPTH_TEST);
    }

    /**
     * Render the Metal/IOSurface-backed GL_TEXTURE_RECTANGLE using modern OpenGL shaders.
     * This is the zero-copy GPU-accelerated path on macOS.
     */
    private void renderMetalTextureWithShader(GuiGraphics guiGraphics) {
        int textureId = DartBridgeClient.getFlutterTextureId();
        if (textureId <= 0) {
            // No texture available yet - show waiting message
            guiGraphics.drawCenteredString(
                this.font,
                "Waiting for Flutter frame...",
                this.width / 2,
                this.height / 2,
                0xFFFFFF
            );
            return;
        }

        int texWidth = DartBridgeClient.getFlutterTextureWidth();
        int texHeight = DartBridgeClient.getFlutterTextureHeight();

        if (texWidth <= 0 || texHeight <= 0) {
            return;
        }

        // Initialize shader on first use
        if (!initRectShader()) {
            // Shader failed to initialize, fall back to software rendering
            LOGGER.warn("[FlutterScreen] Shader initialization failed, using software fallback");
            renderSoftwareFallback(guiGraphics);
            return;
        }

        // Save OpenGL state
        int prevProgram = GL11.glGetInteger(GL20.GL_CURRENT_PROGRAM);
        int prevVao = GL11.glGetInteger(GL30.GL_VERTEX_ARRAY_BINDING);
        int prevTextureRect = GL11.glGetInteger(ARBTextureRectangle.GL_TEXTURE_BINDING_RECTANGLE_ARB);
        boolean blendEnabled = GL11.glIsEnabled(GL11.GL_BLEND);
        boolean depthEnabled = GL11.glIsEnabled(GL11.GL_DEPTH_TEST);
        boolean cullEnabled = GL11.glIsEnabled(GL11.GL_CULL_FACE);

        try {
            // Set up for 2D rendering
            GL11.glEnable(GL11.GL_BLEND);
            GL11.glBlendFunc(GL11.GL_SRC_ALPHA, GL11.GL_ONE_MINUS_SRC_ALPHA);
            GL11.glDisable(GL11.GL_DEPTH_TEST);
            GL11.glDisable(GL11.GL_CULL_FACE);

            // Use our shader program
            GL20.glUseProgram(rectShaderProgram);

            // Bind the GL_TEXTURE_RECTANGLE texture
            GL13.glActiveTexture(GL13.GL_TEXTURE0);
            GL11.glBindTexture(ARBTextureRectangle.GL_TEXTURE_RECTANGLE_ARB, textureId);

            // Ensure IOSurface texture is synchronized and ready for sampling
            GL11.glFlush();

            // Set uniforms
            GL20.glUniform1i(rectUniformTex, 0);  // Texture unit 0
            GL20.glUniform2f(rectUniformTexSize, (float) texWidth, (float) texHeight);

            // Bind VAO and draw fullscreen quad
            GL30.glBindVertexArray(rectVao);
            GL11.glDrawArrays(GL11.GL_TRIANGLES, 0, 6);

        } finally {
            // Restore OpenGL state
            GL30.glBindVertexArray(prevVao);
            GL11.glBindTexture(ARBTextureRectangle.GL_TEXTURE_RECTANGLE_ARB, prevTextureRect);
            GL20.glUseProgram(prevProgram);

            if (!blendEnabled) GL11.glDisable(GL11.GL_BLEND);
            if (depthEnabled) GL11.glEnable(GL11.GL_DEPTH_TEST);
            if (cullEnabled) GL11.glEnable(GL11.GL_CULL_FACE);
        }
    }

    /**
     * Software fallback for Metal renderer on macOS.
     * Uses the same DynamicTexture path as the non-OpenGL renderer,
     * which works correctly with OpenGL Core Profile.
     */
    private void renderSoftwareFallback(GuiGraphics guiGraphics) {
        // Check if we have a new frame from the software renderer
        if (DartBridgeClient.hasNewFrame()) {
            updateTexture();
        }

        // Render using DynamicTexture (Minecraft's shader-based infrastructure)
        if (dynamicTexture != null && textureWidth > 0 && textureHeight > 0) {
            renderFlutterTexture(guiGraphics);
        } else {
            // Waiting for first frame
            guiGraphics.drawCenteredString(
                this.font,
                "Waiting for Flutter frame...",
                this.width / 2,
                this.height / 2,
                0xFFFFFF
            );
        }
    }

    @Override
    public void resize(int width, int height) {
        super.resize(width, height);
        if (flutterInitialized) {
            // Send FRAMEBUFFER dimensions with pixel_ratio=guiScale
            var window = this.minecraft.getWindow();
            int guiScale = window.getGuiScale();
            int fbWidth = width * guiScale;
            int fbHeight = height * guiScale;
            DartBridgeClient.sendWindowMetrics(fbWidth, fbHeight, (double) guiScale);
        }
    }

    @Override
    public boolean mouseClicked(MouseButtonEvent event, boolean bl) {
        LOGGER.debug("[FlutterScreen] mouseClicked: x={}, y={}, button={}, flutterInitialized={}", event.x(), event.y(), event.button(), flutterInitialized);
        if (flutterInitialized) {
            // Mouse coordinates are in GUI pixels - Flutter handles scaling via pixel_ratio
            double mouseX = event.x();
            double mouseY = event.y();
            int button = event.button();

            currentButtons |= getButtonMask(button);

            if (!pointerAdded) {
                DartBridgeClient.sendPointerEvent(PHASE_ADD, mouseX, mouseY, 0);
                pointerAdded = true;
            }

            DartBridgeClient.sendPointerEvent(PHASE_DOWN, mouseX, mouseY, currentButtons);
            return true; // Consume the event - Flutter handled it
        }
        return super.mouseClicked(event, bl);
    }

    @Override
    public boolean mouseReleased(MouseButtonEvent event) {
        LOGGER.debug("[FlutterScreen] mouseReleased: x={}, y={}, button={}", event.x(), event.y(), event.button());
        if (flutterInitialized) {
            // Mouse coordinates are in GUI pixels - Flutter handles scaling via pixel_ratio
            double mouseX = event.x();
            double mouseY = event.y();
            int button = event.button();

            currentButtons &= ~getButtonMask(button);
            DartBridgeClient.sendPointerEvent(PHASE_UP, mouseX, mouseY, currentButtons);
            return true; // Consume the event - Flutter handled it
        }
        return super.mouseReleased(event);
    }

    @Override
    public void mouseMoved(double mouseX, double mouseY) {
        if (flutterInitialized) {
            // Mouse coordinates are in GUI pixels - Flutter handles scaling via pixel_ratio
            if (!pointerAdded) {
                LOGGER.debug("[FlutterScreen] Pointer ADD: x={}, y={}", mouseX, mouseY);
                DartBridgeClient.sendPointerEvent(PHASE_ADD, mouseX, mouseY, 0);
                pointerAdded = true;
                // Don't send HOVER on the same frame as ADD - let Flutter process ADD first
                super.mouseMoved(mouseX, mouseY);
                return;
            }

            if (currentButtons != 0) {
                DartBridgeClient.sendPointerEvent(PHASE_MOVE, mouseX, mouseY, currentButtons);
            } else {
                DartBridgeClient.sendPointerEvent(PHASE_HOVER, mouseX, mouseY, 0);
            }
        }
        super.mouseMoved(mouseX, mouseY);
    }

    @Override
    public boolean mouseDragged(MouseButtonEvent event, double dragX, double dragY) {
        if (flutterInitialized) {
            // Mouse coordinates are in GUI pixels - Flutter handles scaling via pixel_ratio
            DartBridgeClient.sendPointerEvent(PHASE_MOVE, event.x(), event.y(), currentButtons);
            return true; // Consume the event - Flutter handled it
        }
        return super.mouseDragged(event, dragX, dragY);
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double horizontalAmount, double verticalAmount) {
        if (flutterInitialized) {
            // Mouse coordinates are in GUI pixels - Flutter handles scaling via pixel_ratio
            // Flutter handles scroll via pointer events with scroll phase
            // For now, we send scroll as a HOVER event at the scroll position
            // A more complete implementation would use Flutter's scroll event API
            // with scroll_delta_x and scroll_delta_y in the pointer event structure
            //
            // Note: The current sendPointerEvent doesn't support scroll deltas directly.
            // This is a simplified implementation that should work for basic scrolling.
            // TODO: Add dedicated scroll event support to the native bridge if needed.
            DartBridgeClient.sendPointerEvent(PHASE_HOVER, mouseX, mouseY, 0);
            return true; // Consume the event - Flutter handled it
        }
        return super.mouseScrolled(mouseX, mouseY, horizontalAmount, verticalAmount);
    }

    private long getButtonMask(int button) {
        return switch (button) {
            case 0 -> BUTTON_PRIMARY;
            case 1 -> BUTTON_SECONDARY;
            case 2 -> BUTTON_MIDDLE;
            default -> 0;
        };
    }

    @Override
    public void removed() {
        super.removed();

        // Send pointer remove event
        if (flutterInitialized && pointerAdded) {
            DartBridgeClient.sendPointerEvent(PHASE_REMOVE, 0, 0, 0);
            pointerAdded = false;
        }

        // Clean up texture
        cleanupTexture();
    }

    @Override
    public void onClose() {
        super.onClose();
        // Note: We don't shutdown Flutter here as other screens might use it
    }

    /**
     * Call this to explicitly shutdown Flutter/Dart when it's no longer needed.
     * This should typically be called when the game is closing or when
     * Flutter functionality is completely done.
     *
     * Note: This shuts down the Flutter client runtime. The server runtime
     * is managed separately by DartBridge.
     */
    public static void shutdownFlutter() {
        if (DartBridgeClient.isClientInitialized()) {
            DartBridgeClient.safeShutdownClientRuntime();
            LOGGER.info("Flutter client runtime shutdown complete");
        }
    }
}
