# Redstone.Dart - Development Commands

mod docs 'packages/docs'

default:
    @just --list

# =============================================================================
# REDSTONE CLI
# =============================================================================

# Activate redstone CLI globally from local source
cli-install:
    dart pub global activate --source path packages/redstone_cli

# =============================================================================
# NATIVE LIBRARY (for development)
# =============================================================================

# Build the native C++ library
native:
    cd packages/native_mc_bridge/build && make -j4

# Rebuild native library from scratch
native-clean:
    cd packages/native_mc_bridge/build && cmake .. && make -j4

# =============================================================================
# UTILITIES
# =============================================================================

# Format all Dart code
format:
    dart format packages/

# Analyze all Dart code
analyze:
    dart analyze packages/
