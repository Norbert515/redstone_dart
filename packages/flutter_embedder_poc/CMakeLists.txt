cmake_minimum_required(VERSION 3.21)
project(flutter_embedder_poc VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ============================================================================
# Flutter Engine Configuration
# ============================================================================
# Set this to your Flutter SDK path, or pass via -DFLUTTER_SDK_PATH=...
if(NOT DEFINED FLUTTER_SDK_PATH)
    # Try to find Flutter from PATH
    execute_process(
        COMMAND which flutter
        OUTPUT_VARIABLE FLUTTER_BIN_PATH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    if(FLUTTER_BIN_PATH)
        # Flutter bin is at <SDK>/bin/flutter, we want <SDK>
        get_filename_component(FLUTTER_SDK_PATH "${FLUTTER_BIN_PATH}" DIRECTORY)
        get_filename_component(FLUTTER_SDK_PATH "${FLUTTER_SDK_PATH}" DIRECTORY)
        message(STATUS "Auto-detected Flutter SDK: ${FLUTTER_SDK_PATH}")
    else()
        message(FATAL_ERROR
            "Flutter SDK not found. Please set FLUTTER_SDK_PATH:\n"
            "  cmake -DFLUTTER_SDK_PATH=/path/to/flutter ..."
        )
    endif()
endif()

# Determine platform-specific engine path
if(APPLE)
    # First check for local deps folder (downloaded embedder)
    set(LOCAL_EMBEDDER_FRAMEWORK "${CMAKE_SOURCE_DIR}/deps/FlutterEmbedder.framework")
    set(FLUTTER_ENGINE_DIR "${FLUTTER_SDK_PATH}/bin/cache/artifacts/engine/darwin-x64")

    if(EXISTS "${LOCAL_EMBEDDER_FRAMEWORK}/FlutterEmbedder")
        # Use downloaded embedder from deps folder
        set(FLUTTER_ENGINE_FRAMEWORK "${LOCAL_EMBEDDER_FRAMEWORK}")
        set(FLUTTER_ICU_DATA "${LOCAL_EMBEDDER_FRAMEWORK}/Resources/icudtl.dat")
        message(STATUS "Using local FlutterEmbedder from deps/")
    elseif(EXISTS "${FLUTTER_ENGINE_DIR}/FlutterEmbedder.framework")
        set(FLUTTER_ENGINE_FRAMEWORK "${FLUTTER_ENGINE_DIR}/FlutterEmbedder.framework")
        set(FLUTTER_ICU_DATA "${FLUTTER_ENGINE_DIR}/icudtl.dat")
    else()
        message(FATAL_ERROR
            "Flutter Engine not found.\n"
            "Either download it to deps/ folder or ensure it's in the SDK cache.\n"
            "Download: curl -L 'https://storage.googleapis.com/flutter_infra_release/flutter/<ENGINE_HASH>/darwin-x64/FlutterEmbedder.framework.zip' -o deps/FlutterEmbedder.framework.zip && cd deps && unzip FlutterEmbedder.framework.zip"
        )
    endif()
elseif(UNIX)
    set(FLUTTER_ENGINE_DIR "${FLUTTER_SDK_PATH}/bin/cache/artifacts/engine/linux-x64")
    set(FLUTTER_ENGINE_LIB "${FLUTTER_ENGINE_DIR}/libflutter_engine.so")

    if(NOT EXISTS "${FLUTTER_ENGINE_LIB}")
        message(FATAL_ERROR
            "Flutter Engine not found at: ${FLUTTER_ENGINE_LIB}\n"
            "Run 'flutter precache' to download engine artifacts."
        )
    endif()
elseif(WIN32)
    set(FLUTTER_ENGINE_DIR "${FLUTTER_SDK_PATH}/bin/cache/artifacts/engine/windows-x64")
    set(FLUTTER_ENGINE_LIB "${FLUTTER_ENGINE_DIR}/flutter_engine.dll")

    if(NOT EXISTS "${FLUTTER_ENGINE_LIB}")
        message(FATAL_ERROR
            "Flutter Engine not found at: ${FLUTTER_ENGINE_LIB}\n"
            "Run 'flutter precache' to download engine artifacts."
        )
    endif()
endif()

message(STATUS "Flutter Engine directory: ${FLUTTER_ENGINE_DIR}")

# ============================================================================
# Dependencies
# ============================================================================

# Find OpenGL
find_package(OpenGL REQUIRED)

# Find GLFW3
find_package(glfw3 3.3 REQUIRED)

# ============================================================================
# Executable
# ============================================================================

add_executable(flutter_embedder_poc
    src/main.cpp
)

target_include_directories(flutter_embedder_poc PRIVATE
    ${FLUTTER_ENGINE_DIR}
)

# Platform-specific linking
if(APPLE)
    # Get the directory containing the framework for -F flag
    get_filename_component(FLUTTER_FRAMEWORK_DIR "${FLUTTER_ENGINE_FRAMEWORK}" DIRECTORY)

    target_link_libraries(flutter_embedder_poc PRIVATE
        OpenGL::GL
        glfw
        "-framework FlutterEmbedder"
        "-F${FLUTTER_FRAMEWORK_DIR}"
    )

    # Set rpath for finding the framework at runtime
    set_target_properties(flutter_embedder_poc PROPERTIES
        BUILD_RPATH "${FLUTTER_FRAMEWORK_DIR}"
        INSTALL_RPATH "${FLUTTER_FRAMEWORK_DIR}"
    )

    # Include headers from the framework
    target_include_directories(flutter_embedder_poc PRIVATE
        "${FLUTTER_ENGINE_FRAMEWORK}/Headers"
    )
elseif(UNIX)
    target_link_libraries(flutter_embedder_poc PRIVATE
        OpenGL::GL
        glfw
        "${FLUTTER_ENGINE_LIB}"
    )

    set_target_properties(flutter_embedder_poc PROPERTIES
        BUILD_RPATH "${FLUTTER_ENGINE_DIR}"
        INSTALL_RPATH "${FLUTTER_ENGINE_DIR}"
    )
elseif(WIN32)
    target_link_libraries(flutter_embedder_poc PRIVATE
        OpenGL::GL
        glfw
        "${FLUTTER_ENGINE_DIR}/flutter_engine.dll.lib"
    )

    # Copy DLL to output directory
    add_custom_command(TARGET flutter_embedder_poc POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${FLUTTER_ENGINE_LIB}"
            $<TARGET_FILE_DIR:flutter_embedder_poc>
    )
endif()

# ============================================================================
# Flutter App Bundle Path
# ============================================================================

# Define where the Flutter app bundle will be
set(FLUTTER_APP_BUNDLE_PATH "${CMAKE_SOURCE_DIR}/flutter_app/build/flutter_assets")

# Use FLUTTER_ICU_DATA if set (for local deps), otherwise default to engine dir
if(NOT DEFINED FLUTTER_ICU_DATA)
    set(FLUTTER_ICU_DATA "${FLUTTER_ENGINE_DIR}/icudtl.dat")
endif()

target_compile_definitions(flutter_embedder_poc PRIVATE
    FLUTTER_ASSETS_PATH="${FLUTTER_APP_BUNDLE_PATH}"
    FLUTTER_ICU_DATA_PATH="${FLUTTER_ICU_DATA}"
)

message(STATUS "Flutter assets expected at: ${FLUTTER_APP_BUNDLE_PATH}")
message(STATUS "ICU data expected at: ${FLUTTER_ENGINE_DIR}/icudtl.dat")

# ============================================================================
# Build Instructions
# ============================================================================

message(STATUS "")
message(STATUS "=== Build Instructions ===")
message(STATUS "1. Build Flutter app: cd flutter_app && flutter build bundle")
message(STATUS "2. Build embedder: cmake --build build")
message(STATUS "3. Run: ./build/flutter_embedder_poc")
message(STATUS "")
