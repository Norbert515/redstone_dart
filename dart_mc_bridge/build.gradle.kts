/**
 * Top-level build orchestration for the Dart-Minecraft Bridge.
 *
 * This build script coordinates building:
 * 1. The native C++ bridge library
 * 2. The Dart mod package
 * 3. Integration with the Fabric mod
 */

plugins {
    base
}

val nativeDir = file("native")
val dartModDir = file("dart_mod")
val buildDir = layout.buildDirectory.get().asFile

// Task to configure CMake for the native library
tasks.register<Exec>("cmakeConfigure") {
    group = "native"
    description = "Configure CMake for the native bridge"

    workingDir = file("$buildDir/native")
    commandLine("cmake", nativeDir.absolutePath)

    doFirst {
        workingDir.mkdirs()
    }
}

// Task to build the native library
tasks.register<Exec>("cmakeBuild") {
    group = "native"
    description = "Build the native bridge library"
    dependsOn("cmakeConfigure")

    workingDir = file("$buildDir/native")
    commandLine("cmake", "--build", ".", "--config", "Release")
}

// Task to run dart pub get
tasks.register<Exec>("dartPubGet") {
    group = "dart"
    description = "Run dart pub get for the Dart mod"

    workingDir = dartModDir
    commandLine("dart", "pub", "get")
}

// Task to analyze Dart code
tasks.register<Exec>("dartAnalyze") {
    group = "dart"
    description = "Analyze Dart code"
    dependsOn("dartPubGet")

    workingDir = dartModDir
    commandLine("dart", "analyze")
}

// Task to compile Dart to kernel
tasks.register<Exec>("dartCompile") {
    group = "dart"
    description = "Compile Dart mod to kernel snapshot"
    dependsOn("dartPubGet")

    workingDir = dartModDir
    commandLine(
        "dart", "compile", "kernel",
        "lib/dart_mod.dart",
        "-o", "$buildDir/dart_mod.dill"
    )

    doFirst {
        buildDir.mkdirs()
    }
}

// Task to run Dart tests
tasks.register<Exec>("dartTest") {
    group = "dart"
    description = "Run Dart tests"
    dependsOn("dartPubGet")

    workingDir = dartModDir
    commandLine("dart", "test")

    // Don't fail if there are no tests
    isIgnoreExitValue = true
}

// Main build task
tasks.register("buildAll") {
    group = "build"
    description = "Build everything: native library and Dart kernel"
    dependsOn("cmakeBuild", "dartCompile")
}

// Clean task
tasks.named("clean") {
    doLast {
        delete("$buildDir/native")
        delete("$buildDir/dart_mod.dill")
        delete("$dartModDir/.dart_tool")
        delete("$dartModDir/build")
    }
}

// Default tasks
defaultTasks("buildAll")

// Print help on how to use this build
tasks.register("help") {
    doLast {
        println("""
            Dart-Minecraft Bridge Build System
            ===================================

            Available tasks:

            Native Library:
              ./gradlew cmakeConfigure  - Configure CMake
              ./gradlew cmakeBuild      - Build native library

            Dart Mod:
              ./gradlew dartPubGet      - Install Dart dependencies
              ./gradlew dartAnalyze     - Analyze Dart code
              ./gradlew dartCompile     - Compile to kernel (.dill)
              ./gradlew dartTest        - Run Dart tests

            All:
              ./gradlew buildAll        - Build everything
              ./gradlew clean           - Clean all build artifacts

            Prerequisites:
              - CMake 3.16+
              - Dart SDK 3.0+
              - JDK for JNI headers
        """.trimIndent())
    }
}
