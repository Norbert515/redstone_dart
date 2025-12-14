// Simple test program to verify Dart VM initialization
#include <iostream>
#include <dlfcn.h>
#include "deps/dart_dll/include/dart_dll.h"
#include "deps/dart_dll/include/dart_api.h"

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <path_to_dart_script.dart>" << std::endl;
        return 1;
    }

    const char* script_path = argv[1];
    std::cout << "Testing Dart VM initialization..." << std::endl;
    std::cout << "Script: " << script_path << std::endl;

    // Configure Dart VM
    DartDllConfig config;
    config.start_service_isolate = true;
    config.service_port = 5858;

    // Initialize
    std::cout << "Initializing Dart VM..." << std::endl;
    bool init_result = DartDll_Initialize(config);
    if (!init_result) {
        std::cerr << "Failed to initialize Dart VM" << std::endl;
        return 1;
    }
    std::cout << "Dart VM initialized!" << std::endl;

    // Build package config path
    std::string script_str(script_path);
    std::string package_config;
    size_t last_slash = script_str.find_last_of("/\\");
    if (last_slash != std::string::npos) {
        package_config = script_str.substr(0, last_slash) + "/.dart_tool/package_config.json";
    } else {
        package_config = ".dart_tool/package_config.json";
    }
    std::cout << "Package config: " << package_config << std::endl;

    // Load script
    std::cout << "Loading script..." << std::endl;
    Dart_Isolate isolate = DartDll_LoadScript(script_path, package_config.c_str());
    if (isolate == nullptr) {
        std::cerr << "Failed to load script" << std::endl;
        DartDll_Shutdown();
        return 1;
    }
    std::cout << "Script loaded!" << std::endl;

    // Enter isolate and run main
    Dart_EnterIsolate(isolate);
    Dart_EnterScope();

    Dart_Handle library = Dart_RootLibrary();
    if (Dart_IsError(library)) {
        std::cerr << "Failed to get root library: " << Dart_GetError(library) << std::endl;
        Dart_ExitScope();
        Dart_ShutdownIsolate();
        DartDll_Shutdown();
        return 1;
    }

    std::cout << "Running main()..." << std::endl;
    Dart_Handle result = Dart_Invoke(library, Dart_NewStringFromCString("main"), 0, nullptr);
    if (Dart_IsError(result)) {
        std::cerr << "Failed to invoke main(): " << Dart_GetError(result) << std::endl;
        Dart_ExitScope();
        Dart_ShutdownIsolate();
        DartDll_Shutdown();
        return 1;
    }

    // Drain microtasks
    DartDll_DrainMicrotaskQueue();

    std::cout << "main() completed successfully!" << std::endl;

    Dart_ExitScope();
    Dart_ExitIsolate();

    // Shutdown
    std::cout << "Shutting down..." << std::endl;
    Dart_EnterIsolate(isolate);
    Dart_ShutdownIsolate();
    DartDll_Shutdown();

    std::cout << "Test completed successfully!" << std::endl;
    return 0;
}
