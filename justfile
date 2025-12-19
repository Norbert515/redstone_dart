# Redstone.Dart - Development Commands

mod docs 'packages/docs'

default:
    @just --list

# =============================================================================
# REDSTONE CLI
# =============================================================================

# Activate redstone CLI globally from local source
cli-install:
    # Delete cached snapshot to force fresh compilation
    rm -f packages/redstone_cli/.dart_tool/pub/bin/redstone_cli/*.snapshot
    # Stop Gradle daemons to ensure fresh JVM args are used
    -cd packages/framework_tests/minecraft && ./gradlew --stop 2>/dev/null
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
# TESTING
# =============================================================================

# Run framework tests
test:
    cd packages/framework_tests && redstone test

# =============================================================================
# UTILITIES
# =============================================================================

# Format all Dart code
format:
    dart format packages/

# Analyze all Dart code
analyze:
    dart analyze packages/

# =============================================================================
# JAVA DEVELOPMENT
# =============================================================================

# Setup Java development environment (generates and unpacks Minecraft sources)
java-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Setting up Java development environment..."
    echo ""
    echo "📦 Generating Minecraft sources with Vineflower (best quality decompiler)..."
    cd packages/java_mc_bridge && ./gradlew genSourcesWithVineflower --quiet
    echo ""
    echo "📂 Unpacking sources to mc-sources/..."
    just java-unpack-sources
    echo ""
    echo "✅ Java development environment ready!"
    echo "   Sources available at: packages/java_mc_bridge/mc-sources/"

# Unpack Minecraft sources JAR to mc-sources/ directory
java-unpack-sources:
    #!/usr/bin/env bash
    set -euo pipefail
    PROJECT_DIR="$(pwd)/packages/java_mc_bridge"
    cd "$PROJECT_DIR"

    # Find the sources JAR in project's Loom cache (where genSources puts it)
    SOURCES_JAR=$(find "$PROJECT_DIR/.gradle/loom-cache/minecraftMaven" -name "*-sources.jar" 2>/dev/null | grep "minecraft-merged" | head -1)

    # Fallback to global Gradle cache if not found locally
    if [ -z "$SOURCES_JAR" ]; then
        SOURCES_JAR=$(find ~/.gradle/caches/fabric-loom -name "*minecraft*sources*.jar" 2>/dev/null | head -1)
    fi

    if [ -z "$SOURCES_JAR" ]; then
        echo "❌ Sources JAR not found. Run 'just java-setup' first to generate sources."
        exit 1
    fi

    # Clean and recreate mc-sources directory
    rm -rf mc-sources
    mkdir -p mc-sources

    # Unpack the sources
    cd mc-sources
    unzip -q "$SOURCES_JAR"

    echo "📂 Unpacked Minecraft sources to packages/java_mc_bridge/mc-sources/"
    echo "   Source JAR: $SOURCES_JAR"

# Clean Loom caches (useful for troubleshooting)
java-clean:
    cd packages/java_mc_bridge && ./gradlew cleanLoom
