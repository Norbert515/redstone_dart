import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../api/fabric_meta_api.dart';
import '../project/bridge_sync.dart';
import '../util/logger.dart';
import '../util/platform.dart';
import 'template_loader.dart';
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
      '.redstone/bridge/client/com/redstone',
    ];

    for (final dir in dirs) {
      Directory(p.join(targetDir, dir)).createSync(recursive: true);
    }
  }

  Future<void> _createProjectFiles() async {
    // Load templates from external files
    final templatesDir = await TemplateLoader.findTemplatesDir();
    final loader = TemplateLoader(templatesDir);
    await loader.load();

    // Choose template based on --empty flag
    final templateName = config.empty ? 'mod_empty' : 'mod';

    // Variables for filename rendering
    final filenameVars = {
      'project_name': config.name,
    };

    // Get all template files
    final templateFiles = await loader.getTemplateFiles(templateName, filenameVars);

    // Write each template file
    for (final templateFile in templateFiles) {
      final content = templateFile.shouldRender
          ? _renderer.render(templateFile.content)
          : templateFile.content;

      final file = File(p.join(targetDir, templateFile.relativePath));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    // Gradle wrapper (still handled separately as it involves copying binaries)
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

    // Copy main bridge code (server-side)
    final mainSourceDir = Directory(p.join(packagesDir, 'java_mc_bridge', 'src', 'main'));
    final targetBridgeDir = Directory(p.join(targetDir, '.redstone', 'bridge'));

    if (!mainSourceDir.existsSync()) {
      Logger.warning('Java bridge package not found at ${mainSourceDir.path}');
      return;
    }

    await _copyDirectory(mainSourceDir, targetBridgeDir);

    // Copy client bridge code (client-side, uses client-only APIs)
    final clientSourceDir = Directory(p.join(packagesDir, 'java_mc_bridge', 'src', 'client'));
    final targetClientBridgeDir = Directory(p.join(targetDir, '.redstone', 'bridge', 'client'));

    if (clientSourceDir.existsSync()) {
      await _copyDirectory(clientSourceDir, targetClientBridgeDir);
    }
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

  void _writeRawFile(String relativePath, String content) {
    final file = File(p.join(targetDir, relativePath));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
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
      _writeRawFile('minecraft/gradlew', _gradlewScript());
      _writeRawFile('minecraft/gradlew.bat', _gradlewBatScript());
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

    _writeRawFile(
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
