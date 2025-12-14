cmake_minimum_required(VERSION 3.21)
project(dart_mc_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Find JNI
find_package(JNI REQUIRED)

# dart_shared_library paths (configurable)
set(DART_DLL_PATH "${CMAKE_SOURCE_DIR}/deps/dart_dll" CACHE PATH "Path to dart_shared_library")

# Source files
set(SOURCES
    src/dart_bridge.cpp
    src/jni_interface.cpp
)

# Create shared library
add_library(dart_mc_bridge SHARED ${SOURCES})

# Include directories
target_include_directories(dart_mc_bridge PRIVATE
    ${JNI_INCLUDE_DIRS}
    ${DART_DLL_PATH}/include
    src
)

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

# Output naming
set_target_properties(dart_mc_bridge PROPERTIES
    PREFIX ""
    OUTPUT_NAME "dart_mc_bridge"
)

if(APPLE)
    set_target_properties(dart_mc_bridge PROPERTIES SUFFIX ".dylib")
elseif(WIN32)
    set_target_properties(dart_mc_bridge PROPERTIES SUFFIX ".dll")
else()
    set_target_properties(dart_mc_bridge PROPERTIES SUFFIX ".so")
endif()

# Install targets
install(TARGETS dart_mc_bridge
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
