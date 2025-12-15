# Dart-Minecraft Bridge - Development Commands
# Usage: just <command>

# Default recipe: show available commands
default:
    @just --list

# =============================================================================
# MINECRAFT
# =============================================================================

# Start Minecraft client with the mod
mc:
    cd myfirstmod && ./gradlew runClient

# Start Minecraft client in background
mc-bg:
    cd myfirstmod && ./gradlew runClient &

# Build the Java mod (without running)
mc-build:
    cd myfirstmod && ./gradlew classes

# Clean and rebuild the Java mod
mc-clean:
    cd myfirstmod && ./gradlew clean classes

# =============================================================================
# NATIVE LIBRARY
# =============================================================================

# Build the native C++ library
native:
    cd dart_mc_bridge/native/build && make -j4

# Rebuild native library from scratch (run cmake first)
native-clean:
    cd dart_mc_bridge/native/build && cmake .. && make -j4

# Copy native library to Minecraft run directory
native-install:
    cp dart_mc_bridge/native/build/dart_mc_bridge.dylib myfirstmod/run/natives/

# Build and install native library
native-all: native native-install

# =============================================================================
# DART
# =============================================================================

# Copy Dart mod to Minecraft mods folder
dart-install:
    cp -r dart_mc_bridge/dart_mod myfirstmod/run/mods/

# Run Dart analyzer on the mod
dart-analyze:
    cd dart_mc_bridge/dart_mod && dart analyze

# Format Dart code
dart-format:
    cd dart_mc_bridge/dart_mod && dart format .

# Get Dart dependencies
dart-deps:
    cd dart_mc_bridge/dart_mod && dart pub get

# =============================================================================
# FULL BUILD
# =============================================================================

# Build everything (native + java + copy dart)
build: native native-install dart-install mc-build

# Full rebuild from scratch
rebuild: native-clean native-install dart-install mc-clean

# Build and run Minecraft
run: build mc

# =============================================================================
# DEVELOPMENT
# =============================================================================

# Quick iteration: copy dart changes and restart MC
iterate: dart-install mc

# Start Minecraft with hot reload CLI (press 'r' to reload)
dev:
    cd dart_mc_bridge/cli && dart run bin/mc.dart

# Watch Dart files and copy on change (requires entr)
watch:
    find dart_mc_bridge/dart_mod -name "*.dart" | entr -r just dart-install

# Show Dart VM service URL (for hot reload)
dart-url:
    @echo "Dart VM Service URL: http://127.0.0.1:5858/"
    @echo "Use /darturl in-game to see this, or connect DevTools to this URL"

# =============================================================================
# UTILITIES
# =============================================================================

# Show recent Minecraft logs
logs:
    tail -50 myfirstmod/run/logs/latest.log

# Follow Minecraft logs in real-time
logs-follow:
    tail -f myfirstmod/run/logs/latest.log

# Search logs for Dart-related messages
logs-dart:
    grep -i "dart\|proxy" myfirstmod/run/logs/latest.log | tail -30

# Clean all build artifacts
clean-all:
    cd myfirstmod && ./gradlew clean
    rm -rf dart_mc_bridge/native/build/CMakeCache.txt

# =============================================================================
# REDSTONE CLI
# =============================================================================

# Activate redstone CLI globally from local source
redstone-activate:
    dart pub global activate --source path packages/redstone_cli
