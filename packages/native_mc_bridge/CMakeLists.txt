cmake_minimum_required(VERSION 3.21)
project(dart_mc_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Build options
option(SERVER_ONLY "Build server-only library without Flutter dependencies" OFF)

# Find JNI
find_package(JNI REQUIRED)

# Dependency paths
set(DART_DLL_PATH "${CMAKE_SOURCE_DIR}/deps/dart_dll" CACHE PATH "Path to dart_dll")

# Source files - depends on build mode
if(SERVER_ONLY)
    set(SOURCES
        src/dart_bridge_server.cpp
        src/jni_interface_server.cpp
        src/object_registry.cpp
        src/generic_jni.cpp
    )
else()
    set(FLUTTER_EMBEDDER_PATH "${CMAKE_SOURCE_DIR}/deps/flutter_embedder" CACHE PATH "Path to Flutter embedder")
    set(SOURCES
        src/dart_bridge.cpp
        src/dart_bridge_server.cpp
        src/dart_bridge_client.cpp
        src/jni_interface_server.cpp
        src/jni_interface_client.cpp
        src/object_registry.cpp
        src/generic_jni.cpp
    )
    # Add Metal renderer for macOS (Objective-C++)
    if(APPLE)
        list(APPEND SOURCES src/metal_renderer.mm)
    endif()
endif()

# Create shared library
add_library(dart_mc_bridge SHARED ${SOURCES})

# Include directories and compile definitions
if(SERVER_ONLY)
    target_include_directories(dart_mc_bridge PRIVATE
        ${JNI_INCLUDE_DIRS}
        ${DART_DLL_PATH}/include
        src
    )
    # Define SERVER_ONLY_BUILD for preprocessor guards
    target_compile_definitions(dart_mc_bridge PRIVATE SERVER_ONLY_BUILD)
else()
    target_include_directories(dart_mc_bridge PRIVATE
        ${JNI_INCLUDE_DIRS}
        ${FLUTTER_EMBEDDER_PATH}/include
        ${DART_DLL_PATH}/include
        src
    )
endif()

# Find dart_dll library
if(WIN32)
    set(DART_DLL_LIB "${DART_DLL_PATH}/lib/dart_dll.lib")
elseif(APPLE)
    set(DART_DLL_LIB "${DART_DLL_PATH}/lib/libdart_dll.dylib")
else()
    set(DART_DLL_LIB "${DART_DLL_PATH}/lib/libdart_dll.so")
endif()

# Flutter embedder setup (only when not SERVER_ONLY)
if(NOT SERVER_ONLY)
    if(WIN32)
        set(FLUTTER_EMBEDDER_LIB "${FLUTTER_EMBEDDER_PATH}/lib/flutter_engine.dll.lib")
        set(FLUTTER_EMBEDDER_RUNTIME "${FLUTTER_EMBEDDER_PATH}/bin/flutter_engine.dll")
    elseif(APPLE)
        # On macOS, Flutter uses a framework - check both locations
        set(FLUTTER_FRAMEWORK_PATH "${FLUTTER_EMBEDDER_PATH}/lib/FlutterEmbedder.framework")
        if(NOT EXISTS "${FLUTTER_FRAMEWORK_PATH}")
            set(FLUTTER_FRAMEWORK_PATH "${FLUTTER_EMBEDDER_PATH}/FlutterEmbedder.framework")
        endif()
        if(EXISTS "${FLUTTER_FRAMEWORK_PATH}")
            set(FLUTTER_EMBEDDER_LIB "${FLUTTER_FRAMEWORK_PATH}")
        else()
            set(FLUTTER_EMBEDDER_LIB "${FLUTTER_EMBEDDER_PATH}/lib/libflutter_engine.dylib")
        endif()
    else()
        set(FLUTTER_EMBEDDER_LIB "${FLUTTER_EMBEDDER_PATH}/lib/libflutter_engine.so")
    endif()
endif()

# Link libraries
if(SERVER_ONLY)
    # Server-only: just JNI and dart_dll
    target_link_libraries(dart_mc_bridge PRIVATE
        ${JNI_LIBRARIES}
        ${DART_DLL_LIB}
    )
else()
    # Full build: JNI, Flutter embedder, and dart_dll
    if(APPLE AND EXISTS "${FLUTTER_FRAMEWORK_PATH}")
        # Get the directory containing the framework
        get_filename_component(FLUTTER_FRAMEWORK_DIR "${FLUTTER_FRAMEWORK_PATH}" DIRECTORY)
        target_link_libraries(dart_mc_bridge PRIVATE
            ${JNI_LIBRARIES}
            "-F${FLUTTER_FRAMEWORK_DIR}"
            "-framework FlutterEmbedder"
            ${DART_DLL_LIB}
        )
    else()
        target_link_libraries(dart_mc_bridge PRIVATE
            ${JNI_LIBRARIES}
            ${FLUTTER_EMBEDDER_LIB}
            ${DART_DLL_LIB}
        )
    endif()
endif()

# Platform-specific dependencies
if(WIN32)
    target_link_libraries(dart_mc_bridge PRIVATE dbghelp bcrypt ws2_32 opengl32)
elseif(APPLE)
    target_link_libraries(dart_mc_bridge PRIVATE
        "-framework Cocoa"
        "-framework QuartzCore"
        "-framework Security"
        "-framework OpenGL"
        "-framework Metal"
        "-framework IOSurface"
        "-framework CoreVideo"
    )
    # Enable ARC for Objective-C++ Metal code
    if(NOT SERVER_ONLY)
        set_source_files_properties(src/metal_renderer.mm PROPERTIES
            COMPILE_FLAGS "-fobjc-arc"
        )
    endif()
elseif(UNIX)
    # Linux - link GL and X11 for OpenGL support
    find_package(OpenGL)
    if(OpenGL_FOUND)
        target_link_libraries(dart_mc_bridge PRIVATE OpenGL::GL)
    endif()
endif()

# Output naming - platform-specific
# Java's System.loadLibrary("dart_mc_bridge") expects:
#   macOS: dart_mc_bridge.dylib (no lib prefix)
#   Windows: dart_mc_bridge.dll (no lib prefix)
#   Linux: libdart_mc_bridge.so (with lib prefix)
if(APPLE)
    # Build rpath list
    set(RPATH_LIST "${DART_DLL_PATH}/lib")
    if(NOT SERVER_ONLY)
        list(APPEND RPATH_LIST "${FLUTTER_EMBEDDER_PATH}/lib")
        if(EXISTS "${FLUTTER_FRAMEWORK_PATH}")
            get_filename_component(FLUTTER_FRAMEWORK_DIR "${FLUTTER_FRAMEWORK_PATH}" DIRECTORY)
            list(APPEND RPATH_LIST "${FLUTTER_FRAMEWORK_DIR}")
        endif()
    endif()

    set_target_properties(dart_mc_bridge PROPERTIES
        PREFIX ""
        OUTPUT_NAME "dart_mc_bridge"
        SUFFIX ".dylib"
        # Use absolute paths for local development (redstone test/run)
        INSTALL_RPATH "${RPATH_LIST}"
        BUILD_RPATH "${RPATH_LIST}"
    )
elseif(WIN32)
    set_target_properties(dart_mc_bridge PROPERTIES
        PREFIX ""
        OUTPUT_NAME "dart_mc_bridge"
        SUFFIX ".dll"
    )
else()
    # Linux: Keep default "lib" prefix for System.loadLibrary compatibility
    set_target_properties(dart_mc_bridge PROPERTIES
        OUTPUT_NAME "dart_mc_bridge"
        SUFFIX ".so"
    )
endif()

# Install targets
install(TARGETS dart_mc_bridge
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)

# Status messages
message(STATUS "")
message(STATUS "=== dart_mc_bridge Configuration ===")
if(SERVER_ONLY)
    message(STATUS "Build mode: SERVER_ONLY (no Flutter dependencies)")
    message(STATUS "Sources: dart_bridge_server.cpp, jni_interface_server.cpp, object_registry.cpp, generic_jni.cpp")
else()
    message(STATUS "Build mode: FULL (with Flutter embedder)")
    message(STATUS "Sources: all (dart_bridge.cpp, dart_bridge_server.cpp, dart_bridge_client.cpp, jni_interface_*.cpp, etc.)")
    message(STATUS "Flutter embedder path: ${FLUTTER_EMBEDDER_PATH}")
    message(STATUS "Flutter embedder library: ${FLUTTER_EMBEDDER_LIB}")
endif()
message(STATUS "dart_dll path: ${DART_DLL_PATH}")
message(STATUS "dart_dll library: ${DART_DLL_LIB}")
message(STATUS "")
