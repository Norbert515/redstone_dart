#pragma once

#include <include/dart_api.h>
#include <bin/isolate_data.h>

using namespace dart::bin;

Dart_Isolate CreateKernelIsolate(const char* script_uri,
                                 const char* main,
                                 const char* package_root,
                                 const char* package_config,
                                 Dart_IsolateFlags* flags,
                                 void* isolate_data,
                                 char** error);

Dart_Isolate CreateVmServiceIsolate(const char* script_uri,
                                    const char* main,
                                    const char* package_root,
                                    const char* package_config,
                                    Dart_IsolateFlags* flags,
                                    void* isolate_data,
                                    int service_port,
                                    char** error);

Dart_Isolate CreateIsolate(bool is_main_isolate,
                           const char* script_uri,
                           const char* name,
                           const char* packages_config,
                           Dart_IsolateFlags* flags,
                           void* isolate_data,
                           char** error);

Dart_Handle SetupCoreLibraries(Dart_Isolate isolate,
                               IsolateData* isolate_data,
                               bool is_isolate_group_start,
                               const char** resolved_packages_config);

void* GetUserIsolateData(void* isolate_group_data);

void DeleteIsolateData(void* raw_isolate_group_data, void* raw_isolate_data);
void DeleteIsolateGroupData(void* raw_isolate_group_data);
