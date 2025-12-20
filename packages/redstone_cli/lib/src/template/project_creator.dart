import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../api/fabric_meta_api.dart';
import '../project/bridge_sync.dart';
import '../util/logger.dart';
import '../util/platform.dart';
import 'template_renderer.dart';

/// Configuration for creating a new project
class ProjectConfig {
  final String name;
  final String description;
  final String org;
  final String author;
  final String minecraftVersion;
  final bool empty;

  ProjectConfig({
    required this.name,
    required this.description,
    required this.org,
    required this.author,
    required this.minecraftVersion,
    this.empty = false,
  });

  /// Convert name to title case
  String get titleName {
    return name
        .split('_')
        .map((word) => word.isEmpty
            ? ''
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  /// Convert org + name to Java package path
  String get javaPackagePath => '$org.$name'.replaceAll('.', '/');

  /// Full Java package name
  String get javaPackage => '$org.$name';
}

/// Creates a new Redstone project from templates
class ProjectCreator {
  final ProjectConfig config;
  final String targetDir;
  final FabricVersions fabricVersions;
  late final TemplateRenderer _renderer;
  late final PlatformInfo _platform;

  ProjectCreator._(this.config, this.targetDir, this.fabricVersions) {
    _platform = PlatformInfo.detect();
    _renderer = TemplateRenderer({
      'project_name': config.name,
      'project_name_title': config.titleName,
      'description': config.description,
      'org': config.org,
      'author': config.author,
      'minecraft_version': fabricVersions.minecraft,
      'java_package': config.javaPackage,
      'java_package_path': config.javaPackagePath,
      // Fabric versions from Meta API
      'fabric_version': fabricVersions.fabricApi,
      'loader_version': fabricVersions.loader,
      'loom_version': fabricVersions.loom,
    });
  }

  /// Create a ProjectCreator with versions fetched from Fabric Meta API
  static Future<ProjectCreator> create(
      ProjectConfig config, String targetDir) async {
    Logger.progress('Fetching Fabric versions');
    final versions = await FabricMetaApi.getRecommendedVersions(
      minecraftVersion: config.minecraftVersion,
    );
    Logger.progressDone();
    Logger.info(
        'Using: MC ${versions.minecraft}, Loader ${versions.loader}, Fabric API ${versions.fabricApi}');

    return ProjectCreator._(config, targetDir, versions);
  }

  /// Create the project
  Future<void> createProject() async {
    // Create main directory structure
    Logger.progress('Creating project structure');
    await _createDirectories();
    Logger.progressDone();

    // Create project files from templates
    Logger.progress('Generating project files');
    await _createProjectFiles();
    Logger.progressDone();

    // Copy native libraries
    Logger.progress('Installing native libraries (${_platform.identifier})');
    await _copyNativeLibs();
    Logger.progressDone();

    // Copy bridge code (Java)
    Logger.progress('Installing Redstone bridge');
    await _copyBridgeCode();
    Logger.progressDone();

    // Write version file
    Logger.progress('Writing version info');
    await _writeVersionFile();
    Logger.progressDone();

    // Run dart pub get
    Logger.progress('Running dart pub get');
    await _runPubGet();
    Logger.progressDone();
  }

  Future<void> _createDirectories() async {
    final dirs = [
      '',
      'lib',
      'test',
      'assets/textures',
      'minecraft/src/main/java/${config.javaPackagePath}',
      'minecraft/src/main/resources/assets/${config.name}',
      'minecraft/src/main/resources/data/${config.name}',
      'minecraft/src/client/java/${config.javaPackagePath}',
      'minecraft/src/client/resources',
      'minecraft/gradle/wrapper',
      '.redstone/native',
      '.redstone/bridge/java/com/redstone/proxy',
    ];

    for (final dir in dirs) {
      Directory(p.join(targetDir, dir)).createSync(recursive: true);
    }
  }

  Future<void> _createProjectFiles() async {
    // pubspec.yaml
    await _writeFile('pubspec.yaml', _pubspecYaml());

    // lib/main.dart
    await _writeFile('lib/main.dart', _mainDart());

    // test/hello_block_test.dart
    await _writeFile('test/hello_block_test.dart', _helloBlockTest());

    // README.md
    await _writeFile('README.md', _readmeMd());

    // .gitignore
    await _writeFile('.gitignore', _gitignore());

    // analysis_options.yaml
    await _writeFile('analysis_options.yaml', _analysisOptions());

    // Minecraft/Fabric files
    await _writeFile('minecraft/build.gradle', _buildGradle());
    await _writeFile('minecraft/settings.gradle', _settingsGradle());
    await _writeFile('minecraft/gradle.properties', _gradleProperties());
    await _writeFile(
      'minecraft/src/main/resources/fabric.mod.json',
      _fabricModJson(),
    );
    await _writeFile(
      'minecraft/src/main/resources/${config.name}.mixins.json',
      _mixinsJson(),
    );

    // Gradle wrapper
    await _copyGradleWrapper();
  }

  Future<void> _copyNativeLibs() async {
    // Find the packages directory (parent of redstone_cli)
    final packagesDir = _findPackagesDir();
    if (packagesDir == null) {
      Logger.warning('Could not find packages directory, skipping native libs');
      return;
    }

    final nativeBridgeDir = Directory(p.join(packagesDir, 'native_mc_bridge'));
    final targetNativeDir = Directory(p.join(targetDir, '.redstone', 'native'));

    if (!nativeBridgeDir.existsSync()) {
      Logger.warning(
        'Native bridge package not found at ${nativeBridgeDir.path}. '
        'You may need to build it manually.',
      );
      return;
    }

    // Copy the built library (if it exists)
    final buildDir = Directory(p.join(nativeBridgeDir.path, 'build'));
    if (buildDir.existsSync()) {
      await for (final entity in buildDir.list()) {
        if (entity is File && _isNativeLib(entity.path)) {
          final targetPath = p.join(targetNativeDir.path, p.basename(entity.path));
          entity.copySync(targetPath);
        }
      }
    }

    // Copy libdart_dll from deps
    final dartDllLib = Directory(p.join(nativeBridgeDir.path, 'deps', 'dart_dll', 'lib'));
    if (dartDllLib.existsSync()) {
      await for (final entity in dartDllLib.list()) {
        if (entity is File && _isNativeLib(entity.path)) {
          final targetPath = p.join(targetNativeDir.path, p.basename(entity.path));
          entity.copySync(targetPath);
        }
      }
    }
  }

  bool _isNativeLib(String path) {
    return path.endsWith('.dylib') || path.endsWith('.so') || path.endsWith('.dll');
  }

  Future<void> _copyBridgeCode() async {
    final packagesDir = _findPackagesDir();
    if (packagesDir == null) {
      Logger.warning('Could not find packages directory, skipping bridge code');
      return;
    }

    final sourceDir = Directory(p.join(packagesDir, 'java_mc_bridge', 'src', 'main'));
    final targetBridgeDir = Directory(p.join(targetDir, '.redstone', 'bridge'));

    if (!sourceDir.existsSync()) {
      Logger.warning('Java bridge package not found at ${sourceDir.path}');
      return;
    }

    await _copyDirectory(sourceDir, targetBridgeDir);
  }

  Future<void> _writeVersionFile() async {
    // Compute content hash of bridge source
    final bridgeHash = BridgeSync.computeSourceBridgeHash();

    final versionInfo = {
      'redstone_cli_version': '0.1.0',
      'bridge_version': '0.1.0',
      'native_version': '0.1.0',
      'platform': _platform.identifier,
      'bridge_content_hash': bridgeHash,
      'created_at': DateTime.now().toIso8601String(),
    };

    final file = File(p.join(targetDir, '.redstone', 'version.json'));
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(versionInfo),
    );
  }

  Future<void> _runPubGet() async {
    final result = await Process.run(
      'dart',
      ['pub', 'get'],
      workingDirectory: targetDir,
    );
    if (result.exitCode != 0) {
      Logger.warning('dart pub get failed: ${result.stderr}');
    }
  }

  Future<void> _writeFile(String relativePath, String content) async {
    final file = File(p.join(targetDir, relativePath));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(_renderer.render(content));
  }

  Future<void> _copyGradleWrapper() async {
    // Copy gradle wrapper from CLI assets
    final cliDir = _findCliPackageDir();
    final assetsDir = cliDir != null
        ? p.join(cliDir, 'assets', 'gradle-wrapper')
        : null;

    if (assetsDir != null && Directory(assetsDir).existsSync()) {
      // Copy gradle-wrapper.jar
      final jarSrc = File(p.join(assetsDir, 'gradle-wrapper.jar'));
      if (jarSrc.existsSync()) {
        jarSrc.copySync(
            p.join(targetDir, 'minecraft/gradle/wrapper/gradle-wrapper.jar'));
      }

      // Copy gradlew script
      final gradlewSrc = File(p.join(assetsDir, 'gradlew'));
      if (gradlewSrc.existsSync()) {
        gradlewSrc.copySync(p.join(targetDir, 'minecraft/gradlew'));
      }

      // Copy gradlew.bat script
      final gradlewBatSrc = File(p.join(assetsDir, 'gradlew.bat'));
      if (gradlewBatSrc.existsSync()) {
        gradlewBatSrc.copySync(p.join(targetDir, 'minecraft/gradlew.bat'));
      }
    } else {
      // Fallback: create minimal wrapper that downloads on first run
      Logger.warning('Gradle wrapper assets not found, creating minimal wrapper');
      await _writeFile('minecraft/gradlew', _gradlewScript());
      await _writeFile('minecraft/gradlew.bat', _gradlewBatScript());
    }

    // Write gradle-wrapper.properties with correct version
    final wrapperProps = '''
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-9.2.1-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
''';

    await _writeFile(
      'minecraft/gradle/wrapper/gradle-wrapper.properties',
      wrapperProps,
    );

    // Make gradlew executable on Unix
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', p.join(targetDir, 'minecraft/gradlew')]);
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        entity.copySync(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }

  String? _findCliPackageDir() {
    // Try to find the CLI package directory
    // This works when running from source or when installed
    var dir = Directory(Platform.script.toFilePath()).parent;

    // Walk up looking for pubspec.yaml with name: redstone_cli
    for (var i = 0; i < 5; i++) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (content.contains('name: redstone_cli')) {
          return dir.path;
        }
      }
      dir = dir.parent;
    }

    // Fallback: try relative to current file
    // This is for development
    final scriptDir = Platform.script.toFilePath();
    if (scriptDir.contains('packages/redstone_cli')) {
      final idx = scriptDir.indexOf('packages/redstone_cli');
      return scriptDir.substring(0, idx + 'packages/redstone_cli'.length);
    }

    return null;
  }

  String? _findPackagesDir() {
    // Find the packages/ directory that contains redstone_cli, java_mc_bridge, etc.
    final cliDir = _findCliPackageDir();
    if (cliDir != null) {
      // packages/redstone_cli -> packages/
      return Directory(cliDir).parent.path;
    }

    // Fallback: look for packages directory relative to script
    final scriptDir = Platform.script.toFilePath();
    if (scriptDir.contains('packages/')) {
      final idx = scriptDir.indexOf('packages/');
      return scriptDir.substring(0, idx + 'packages'.length);
    }

    return null;
  }

  // Template content methods
  String _pubspecYaml() => '''
name: {{project_name}}
description: {{description}}
version: 1.0.0
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  ffi: ^2.1.0
  dart_mc:
    path: /Users/norbertkozsir/IdeaProjects/redstone_dart/packages/dart_mc

dev_dependencies:
  redstone_test:
    path: /Users/norbertkozsir/IdeaProjects/redstone_dart/packages/redstone_test

# Redstone configuration
redstone:
  minecraft_version: "{{minecraft_version}}"
  org: {{org}}
  author: {{author}}
''';

  String _mainDart() => '''
// {{project_name}} - A Minecraft mod built with Redstone
//
// This is your mod's entry point. Register your blocks, entities,
// and other game objects here.

// Dart MC API imports
import 'package:dart_mc/dart_mc.dart';

/// Example custom block that shows a message when right-clicked.
///
/// This demonstrates how to create custom blocks in Dart.
/// The block will appear in the creative menu under "Building Blocks".
class HelloBlock extends CustomBlock {
  HelloBlock() : super(
    id: '{{project_name}}:hello_block',
    settings: BlockSettings(
      hardness: 1.0,
      resistance: 1.0,
      requiresTool: false,
    ),
  );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    // Get player info and send a message
    final player = Players.getPlayer(playerId);
    if (player != null) {
      player.sendMessage('Hello from {{project_name_title}}! You clicked at (\$x, \$y, \$z)');
    }
    return ActionResult.success;
  }

  @override
  bool onBreak(int worldId, int x, int y, int z, int playerId) {
    print('HelloBlock broken at (\$x, \$y, \$z) by player \$playerId');
    return true; // Allow the block to be broken
  }
}

/// Main entry point for your mod.
///
/// This is called when the Dart VM is initialized by the native bridge.
void main() {
  print('{{project_name_title}} mod initialized!');

  // Initialize the native bridge
  Bridge.initialize();

  // Register proxy block handlers (required for custom blocks)
  Events.registerProxyBlockHandlers();

  // =========================================================================
  // Register your custom blocks here
  // This MUST happen before the registry freezes (during mod initialization)
  // =========================================================================
  BlockRegistry.register(HelloBlock());

  // Add more blocks here:
  // BlockRegistry.register(MyOtherBlock());

  // Freeze the block registry (no more blocks can be registered after this)
  BlockRegistry.freeze();

  // =========================================================================
  // Register event handlers (optional)
  // =========================================================================
  Events.onBlockBreak((x, y, z, playerId) {
    // Called when ANY block is broken
    // Return EventResult.deny to prevent breaking
    return EventResult.allow;
  });

  Events.onTick((tick) {
    // Called every game tick (20 times per second)
    // Use for animations, timers, etc.
  });

  print('{{project_name_title}} ready with \${BlockRegistry.blockCount} custom blocks!');
}
''';

  String _readmeMd() => '''
# {{project_name_title}}

{{description}}

## Getting Started

1. Make sure you have [Redstone CLI](https://github.com/your-repo/redstone) installed
2. Run your mod:
   ```bash
   redstone run
   ```

## Project Structure

- `lib/` - Your Dart mod code
- `assets/` - Textures, sounds, and other assets
- `minecraft/` - Fabric mod configuration (usually don't need to edit)
- `.redstone/` - Managed by Redstone CLI (don't edit)

## Hot Reload

While running, press `r` to hot reload your Dart code changes!

## Learn More

- [Redstone Documentation](https://github.com/your-repo/redstone)
- [Fabric Mod Development](https://fabricmc.net/wiki/)

## Running Tests

Run your mod's tests inside a Minecraft server:

```bash
redstone test
```
''';

  String _helloBlockTest() => '''
// Tests for HelloBlock
//
// Run with: redstone test

import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  await group('HelloBlock', () async {
    await testMinecraft('can be placed in the world', (game) async {
      final pos = BlockPos(0, 64, 0);

      // Place our custom block
      game.placeBlock(pos, Block('{{project_name}}:hello_block'));

      // Verify it was placed
      final block = game.getBlock(pos);
      expect(block, isBlock('{{project_name}}:hello_block'));
    });

    await testMinecraft('can be broken', (game) async {
      final pos = BlockPos(0, 64, 0);

      // Place and then break the block
      game.placeBlock(pos, Block('{{project_name}}:hello_block'));
      game.setBlock(pos, Block.air);

      // Verify it's now air
      expect(game.getBlock(pos), isAirBlock);
    });
  });

  await group('World basics', () async {
    await testMinecraft('can access world time', (game) async {
      final time = game.world.timeOfDay;
      expect(time, greaterThanOrEqualTo(0));
    });

    await testMinecraft('can wait for ticks', (game) async {
      final startTick = game.currentTick;

      // Wait for 20 ticks (1 second in game time)
      await game.waitTicks(20);

      expect(game.currentTick, greaterThanOrEqualTo(startTick + 20));
    });
  });
}
''';

  String _gitignore() => '''
# Dart
.dart_tool/
.packages
pubspec.lock

# Redstone managed (regenerated on redstone upgrade)
.redstone/

# Minecraft runtime
minecraft/run/
minecraft/build/
minecraft/.gradle/
minecraft/mc-sources/

# IDE
.idea/
*.iml
.vscode/

# OS
.DS_Store
Thumbs.db
''';

  String _analysisOptions() => '''
analyzer:
  exclude:
    - minecraft/run/**
    - minecraft/build/**
''';

  String _buildGradle() => '''
plugins {
    id 'net.fabricmc.fabric-loom-remap' version '{{loom_version}}'
    id 'java'
}

version = project.mod_version
group = project.maven_group

base {
    archivesName = project.archives_base_name
}

repositories {
    mavenCentral()
}

loom {
    splitEnvironmentSourceSets()

    mods {
        "{{project_name}}" {
            sourceSet sourceSets.main
            sourceSet sourceSets.client
        }
    }
}

sourceSets {
    main {
        java {
            // Include Redstone bridge code
            srcDir '../.redstone/bridge/java'
        }
    }
}

dependencies {
    minecraft "com.mojang:minecraft:\${project.minecraft_version}"
    mappings loom.officialMojangMappings()
    modImplementation "net.fabricmc:fabric-loader:\${project.loader_version}"
    modImplementation "net.fabricmc.fabric-api:fabric-api:\${project.fabric_version}"
}

processResources {
    inputs.property "version", project.version
    inputs.property "minecraft_version", project.minecraft_version
    inputs.property "loader_version", project.loader_version

    filesMatching("fabric.mod.json") {
        expand "version": project.version,
                "minecraft_version": project.minecraft_version,
                "loader_version": project.loader_version
    }
}

tasks.withType(JavaCompile).configureEach {
    it.options.release = 21
}

java {
    withSourcesJar()
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

jar {
    from("LICENSE") {
        rename { "\${it}_\${project.base.archivesName.get()}" }
    }
}

// Enable Fabric game tests (used by 'redstone test')
fabricApi {
    configureTests {
        enableGameTests = true
    }
}

// Pass DART_SCRIPT_PATH to run tasks via JVM system property
// This allows the CLI to specify the script location directly
tasks.withType(net.fabricmc.loom.task.RunGameTask).configureEach {
    // Read from Gradle project property (passed via -PdartScriptPath=...)
    if (project.hasProperty('dartScriptPath')) {
        def dartScriptPath = project.property('dartScriptPath')
        jvmArgs("-DDART_SCRIPT_PATH=\${dartScriptPath}")
    }
}
''';

  String _settingsGradle() => '''
pluginManagement {
    repositories {
        maven {
            name = 'Fabric'
            url = 'https://maven.fabricmc.net/'
        }
        gradlePluginPortal()
    }
}
''';

  String _gradleProperties() => '''
# Project
mod_version=1.0.0
maven_group={{org}}
archives_base_name={{project_name}}

# Fabric - https://fabricmc.net/develop/
minecraft_version={{minecraft_version}}
loader_version={{loader_version}}
fabric_version={{fabric_version}}

# Gradle
org.gradle.jvmargs=-Xmx2G
org.gradle.parallel=true
org.gradle.configuration-cache=false
''';

  String _fabricModJson() => '''
{
  "schemaVersion": 1,
  "id": "{{project_name}}",
  "version": "\${version}",
  "name": "{{project_name_title}}",
  "description": "{{description}}",
  "authors": ["{{author}}"],
  "contact": {},
  "license": "MIT",
  "icon": "assets/{{project_name}}/icon.png",
  "environment": "*",
  "entrypoints": {
    "main": [
      "com.redstone.DartModLoader"
    ],
    "client": []
  },
  "mixins": [
    "{{project_name}}.mixins.json"
  ],
  "depends": {
    "fabricloader": ">=\${loader_version}",
    "minecraft": "~{{minecraft_version}}",
    "java": ">=21",
    "fabric-api": "*"
  }
}
''';

  String _mixinsJson() => '''
{
  "required": true,
  "minVersion": "0.8",
  "package": "{{java_package}}.mixin",
  "compatibilityLevel": "JAVA_21",
  "mixins": [],
  "client": [],
  "injectors": {
    "defaultRequire": 1
  }
}
''';

  String _gradlewScript() => '''
#!/bin/sh
# Gradle wrapper script

# Determine the project base directory
DIRNAME="\$(dirname "\$0")"
cd "\$DIRNAME" || exit

# Download gradle wrapper jar if needed
if [ ! -f "gradle/wrapper/gradle-wrapper.jar" ]; then
    echo "Downloading Gradle wrapper..."
    mkdir -p gradle/wrapper
    curl -sL "https://github.com/gradle/gradle/raw/v8.10.0/gradle/wrapper/gradle-wrapper.jar" -o "gradle/wrapper/gradle-wrapper.jar"
fi

exec java -jar "gradle/wrapper/gradle-wrapper.jar" "\$@"
''';

  String _gradlewBatScript() => '''
@echo off
rem Gradle wrapper script for Windows

setlocal

set DIRNAME=%~dp0
cd /d "%DIRNAME%"

if not exist "gradle\\wrapper\\gradle-wrapper.jar" (
    echo Downloading Gradle wrapper...
    mkdir gradle\\wrapper 2>nul
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/gradle/gradle/raw/v8.10.0/gradle/wrapper/gradle-wrapper.jar' -OutFile 'gradle\\wrapper\\gradle-wrapper.jar'"
)

java -jar "gradle\\wrapper\\gradle-wrapper.jar" %*

endlocal
''';

  /// Get the default/latest Minecraft version from Fabric Meta API
  static Future<String> getDefaultMinecraftVersion() async {
    return await FabricMetaApi.getLatestStableGameVersion();
  }
}
