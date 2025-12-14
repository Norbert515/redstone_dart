// Test program to verify Dart VM with callback registration
#include <iostream>
#include <dlfcn.h>
#include <thread>
#include <chrono>
#include "deps/dart_dll/include/dart_dll.h"
#include "deps/dart_dll/include/dart_api.h"
#include "src/dart_bridge.h"

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <path_to_dart_script.dart>" << std::endl;
        return 1;
    }

    const char* script_path = argv[1];
    std::cout << "=== Testing Dart VM with Callbacks ===" << std::endl;
    std::cout << "Script: " << script_path << std::endl;

    // Initialize the dart bridge (which initializes the Dart VM and runs main())
    std::cout << "\n[1] Initializing Dart bridge..." << std::endl;
    bool init_result = dart_bridge_init(script_path);
    if (!init_result) {
        std::cerr << "Failed to initialize Dart bridge" << std::endl;
        return 1;
    }
    std::cout << "[1] Dart bridge initialized!" << std::endl;

    // Test block break dispatch
    std::cout << "\n[2] Testing block break dispatch..." << std::endl;
    int32_t result = dispatch_block_break(10, 64, -20, 12345);
    std::cout << "[2] Block break result: " << result << " (1=allow, 0=cancel)" << std::endl;

    // Test block interact dispatch
    std::cout << "\n[3] Testing block interact dispatch..." << std::endl;
    result = dispatch_block_interact(5, 70, 15, 12345, 0);
    std::cout << "[3] Block interact result: " << result << std::endl;

    // Test tick dispatch
    std::cout << "\n[4] Testing tick dispatch..." << std::endl;
    for (int i = 0; i < 3; i++) {
        dispatch_tick(i);
        dart_bridge_tick(); // Process async tasks
    }
    std::cout << "[4] Tick dispatches completed" << std::endl;

    // Shutdown
    std::cout << "\n[5] Shutting down..." << std::endl;
    dart_bridge_shutdown();

    std::cout << "\n=== Test completed successfully! ===" << std::endl;
    return 0;
}
