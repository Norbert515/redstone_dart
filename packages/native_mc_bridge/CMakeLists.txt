cmake_minimum_required(VERSION 3.21)
project(dart_mc_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Find JNI
find_package(JNI REQUIRED)

# Dependency paths
set(FLUTTER_EMBEDDER_PATH "${CMAKE_SOURCE_DIR}/deps/flutter_embedder" CACHE PATH "Path to Flutter embedder")
set(DART_DLL_PATH "${CMAKE_SOURCE_DIR}/deps/dart_dll" CACHE PATH "Path to dart_dll")

# Source files
set(SOURCES
    src/dart_bridge.cpp
    src/dart_bridge_server.cpp
    src/dart_bridge_client.cpp
    src/jni_interface.cpp
    src/object_registry.cpp
    src/generic_jni.cpp
)

# Create shared library
add_library(dart_mc_bridge SHARED ${SOURCES})

# Include directories
target_include_directories(dart_mc_bridge PRIVATE
    ${JNI_INCLUDE_DIRS}
    ${FLUTTER_EMBEDDER_PATH}/include
    ${DART_DLL_PATH}/include
    src
)

# Find Flutter embedder library
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

# Find dart_dll library
if(WIN32)
    set(DART_DLL_LIB "${DART_DLL_PATH}/lib/dart_dll.lib")
elseif(APPLE)
    set(DART_DLL_LIB "${DART_DLL_PATH}/lib/libdart_dll.dylib")
else()
    set(DART_DLL_LIB "${DART_DLL_PATH}/lib/libdart_dll.so")
endif()

# Link libraries
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
    # Build rpath list - include directory containing the framework and dart_dll
    set(RPATH_LIST "${FLUTTER_EMBEDDER_PATH}/lib" "${DART_DLL_PATH}/lib")
    if(EXISTS "${FLUTTER_FRAMEWORK_PATH}")
        get_filename_component(FLUTTER_FRAMEWORK_DIR "${FLUTTER_FRAMEWORK_PATH}" DIRECTORY)
        list(APPEND RPATH_LIST "${FLUTTER_FRAMEWORK_DIR}")
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

message(STATUS "")
message(STATUS "=== dart_mc_bridge Configuration ===")
message(STATUS "Flutter embedder path: ${FLUTTER_EMBEDDER_PATH}")
message(STATUS "Flutter embedder library: ${FLUTTER_EMBEDDER_LIB}")
message(STATUS "dart_dll path: ${DART_DLL_PATH}")
message(STATUS "dart_dll library: ${DART_DLL_LIB}")
message(STATUS "")
