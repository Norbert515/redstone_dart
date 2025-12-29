cmake_minimum_required(VERSION 3.21)
project(dart_mc_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Find JNI
find_package(JNI REQUIRED)

# dart_shared_library paths (configurable)
set(DART_DLL_PATH "${CMAKE_SOURCE_DIR}/deps/dart_dll" CACHE PATH "Path to dart_shared_library")

# Flutter embedder paths (configurable)
set(FLUTTER_EMBEDDER_PATH "${CMAKE_SOURCE_DIR}/deps/flutter_embedder" CACHE PATH "Path to Flutter embedder")

# Flutter renderer path (for subprocess mode)
set(FLUTTER_RENDERER_PATH "${CMAKE_SOURCE_DIR}/../flutter_renderer" CACHE PATH "Path to flutter_renderer project")

# Option to enable Flutter support (disabled by default until Flutter engine library is available)
option(ENABLE_FLUTTER "Enable Flutter embedder support" OFF)

# Source files
set(SOURCES
    src/dart_bridge.cpp
    src/jni_interface.cpp
    src/object_registry.cpp
    src/generic_jni.cpp
)

# Add Flutter bridge sources if enabled
if(ENABLE_FLUTTER)
    list(APPEND SOURCES
        src/flutter_bridge.cpp
        "${FLUTTER_RENDERER_PATH}/src/shared_memory.cpp"
    )
endif()

# Create shared library
add_library(dart_mc_bridge SHARED ${SOURCES})

# Include directories
target_include_directories(dart_mc_bridge PRIVATE
    ${JNI_INCLUDE_DIRS}
    ${DART_DLL_PATH}/include
    src
)

# Add Flutter renderer include path if enabled (for shared_memory.h)
if(ENABLE_FLUTTER)
    target_include_directories(dart_mc_bridge PRIVATE
        "${FLUTTER_RENDERER_PATH}/src"
    )
    target_compile_definitions(dart_mc_bridge PRIVATE FLUTTER_ENABLED=1)
endif()

# Find dart_dll library
if(WIN32)
    set(DART_DLL_LIB "${DART_DLL_PATH}/lib/dart_dll.lib")
    set(DART_DLL_RUNTIME "${DART_DLL_PATH}/bin/dart_dll.dll")
elseif(APPLE)
    set(DART_DLL_LIB "${DART_DLL_PATH}/lib/libdart_dll.dylib")
else()
    set(DART_DLL_LIB "${DART_DLL_PATH}/lib/libdart_dll.so")
endif()

# Link libraries
target_link_libraries(dart_mc_bridge PRIVATE
    ${JNI_LIBRARIES}
    ${DART_DLL_LIB}
)

# Note: In subprocess mode, we don't link against Flutter engine directly
# The flutter_renderer subprocess handles that

# Platform-specific dependencies
if(WIN32)
    target_link_libraries(dart_mc_bridge PRIVATE dbghelp bcrypt ws2_32)
elseif(APPLE)
    target_link_libraries(dart_mc_bridge PRIVATE
        "-framework Cocoa"
        "-framework QuartzCore"
        "-framework Security"
    )
endif()

# Output naming - platform-specific
# Java's System.loadLibrary("dart_mc_bridge") expects:
#   macOS: dart_mc_bridge.dylib (no lib prefix)
#   Windows: dart_mc_bridge.dll (no lib prefix)
#   Linux: libdart_mc_bridge.so (with lib prefix)
if(APPLE)
    # Build rpath list
    set(RPATH_LIST "${DART_DLL_PATH}/lib")

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

# ============================================================================
# Flutter Renderer Subprocess Build
# ============================================================================

if(ENABLE_FLUTTER)
    # Add flutter_renderer as an external project or subdirectory
    # For now, provide a custom target to build it
    add_custom_target(flutter_renderer
        COMMAND ${CMAKE_COMMAND} -B "${FLUTTER_RENDERER_PATH}/build"
            -DFLUTTER_EMBEDDER_PATH="${FLUTTER_EMBEDDER_PATH}"
            "${FLUTTER_RENDERER_PATH}"
        COMMAND ${CMAKE_COMMAND} --build "${FLUTTER_RENDERER_PATH}/build"
        WORKING_DIRECTORY "${FLUTTER_RENDERER_PATH}"
        COMMENT "Building flutter_renderer subprocess..."
    )

    # Make dart_mc_bridge depend on flutter_renderer when Flutter is enabled
    add_dependencies(dart_mc_bridge flutter_renderer)

    message(STATUS "Flutter subprocess mode enabled")
    message(STATUS "Flutter renderer path: ${FLUTTER_RENDERER_PATH}")
endif()

message(STATUS "")
message(STATUS "=== dart_mc_bridge Configuration ===")
message(STATUS "Dart DLL path: ${DART_DLL_PATH}")
message(STATUS "Flutter enabled: ${ENABLE_FLUTTER}")
if(ENABLE_FLUTTER)
    message(STATUS "Flutter embedder path: ${FLUTTER_EMBEDDER_PATH}")
    message(STATUS "Flutter renderer path: ${FLUTTER_RENDERER_PATH}")
endif()
message(STATUS "")
