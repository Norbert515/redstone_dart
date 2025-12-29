cmake_minimum_required(VERSION 3.21)
project(flutter_renderer VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ============================================================================
# Flutter Engine Configuration
# ============================================================================

# Flutter embedder path (configurable)
set(FLUTTER_EMBEDDER_PATH "${CMAKE_SOURCE_DIR}/../native_mc_bridge/deps/flutter_embedder" CACHE PATH "Path to Flutter embedder")

# Find Flutter engine
if(APPLE)
    # Check for framework
    if(EXISTS "${FLUTTER_EMBEDDER_PATH}/lib/FlutterEmbedder.framework")
        set(FLUTTER_ENGINE_FRAMEWORK "${FLUTTER_EMBEDDER_PATH}/lib/FlutterEmbedder.framework")
        set(FLUTTER_INCLUDE_DIR "${FLUTTER_ENGINE_FRAMEWORK}/Headers")
        message(STATUS "Found FlutterEmbedder.framework at: ${FLUTTER_ENGINE_FRAMEWORK}")
    else()
        message(FATAL_ERROR
            "Flutter Engine not found at: ${FLUTTER_EMBEDDER_PATH}/lib/FlutterEmbedder.framework\n"
            "Please download it or set FLUTTER_EMBEDDER_PATH"
        )
    endif()
elseif(UNIX)
    set(FLUTTER_ENGINE_LIB "${FLUTTER_EMBEDDER_PATH}/lib/libflutter_engine.so")
    set(FLUTTER_INCLUDE_DIR "${FLUTTER_EMBEDDER_PATH}/include")

    if(NOT EXISTS "${FLUTTER_ENGINE_LIB}")
        message(FATAL_ERROR "Flutter Engine not found at: ${FLUTTER_ENGINE_LIB}")
    endif()
elseif(WIN32)
    set(FLUTTER_ENGINE_DLL "${FLUTTER_EMBEDDER_PATH}/lib/flutter_engine.dll")
    set(FLUTTER_ENGINE_LIB "${FLUTTER_EMBEDDER_PATH}/lib/flutter_engine.dll.lib")
    set(FLUTTER_INCLUDE_DIR "${FLUTTER_EMBEDDER_PATH}/include")

    if(NOT EXISTS "${FLUTTER_ENGINE_LIB}")
        message(FATAL_ERROR "Flutter Engine not found at: ${FLUTTER_ENGINE_LIB}")
    endif()
endif()

# ============================================================================
# Executable
# ============================================================================

add_executable(flutter_renderer
    src/main.cpp
    src/shared_memory.cpp
)

target_include_directories(flutter_renderer PRIVATE
    ${FLUTTER_INCLUDE_DIR}
    src
)

# ============================================================================
# Platform-specific linking
# ============================================================================

if(APPLE)
    # Get the directory containing the framework for -F flag
    get_filename_component(FLUTTER_FRAMEWORK_DIR "${FLUTTER_ENGINE_FRAMEWORK}" DIRECTORY)

    target_link_libraries(flutter_renderer PRIVATE
        "-framework FlutterEmbedder"
        "-F${FLUTTER_FRAMEWORK_DIR}"
    )

    # Set rpath for finding the framework at runtime
    set_target_properties(flutter_renderer PROPERTIES
        BUILD_RPATH "${FLUTTER_FRAMEWORK_DIR}"
        INSTALL_RPATH "@executable_path/../lib;${FLUTTER_FRAMEWORK_DIR}"
    )
elseif(UNIX)
    target_link_libraries(flutter_renderer PRIVATE
        "${FLUTTER_ENGINE_LIB}"
        pthread
        rt  # For shared memory
    )

    set_target_properties(flutter_renderer PROPERTIES
        BUILD_RPATH "${FLUTTER_EMBEDDER_PATH}/lib"
        INSTALL_RPATH "$ORIGIN/../lib"
    )
elseif(WIN32)
    target_link_libraries(flutter_renderer PRIVATE
        "${FLUTTER_ENGINE_LIB}"
    )

    # Copy DLL to output directory
    add_custom_command(TARGET flutter_renderer POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${FLUTTER_ENGINE_DLL}"
            $<TARGET_FILE_DIR:flutter_renderer>
    )
endif()

# ============================================================================
# Install
# ============================================================================

install(TARGETS flutter_renderer
    RUNTIME DESTINATION bin
)

# ============================================================================
# Status
# ============================================================================

message(STATUS "")
message(STATUS "=== Flutter Renderer Configuration ===")
message(STATUS "Flutter embedder path: ${FLUTTER_EMBEDDER_PATH}")
if(APPLE)
    message(STATUS "Flutter framework: ${FLUTTER_ENGINE_FRAMEWORK}")
else()
    message(STATUS "Flutter engine lib: ${FLUTTER_ENGINE_LIB}")
endif()
message(STATUS "")
