import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../project/redstone_project.dart';
import '../util/logger.dart';

/// Generates a test harness entry point that runs Dart tests inside Minecraft.
///
/// The generated harness:
/// 1. Imports all specified test files
/// 2. Waits for server to be ready (Events.onServerStarted)
/// 3. Runs tests programmatically using package:test_core
/// 4. Emits structured JSON events via stdout
/// 5. Signals server shutdown
class TestHarnessGenerator {
  final RedstoneProject project;

  TestHarnessGenerator(this.project);

  /// Generate a test harness file for server-side tests.
  ///
  /// [testFiles] - List of test file paths or directories
  /// [filterArgs] - Arguments to pass to the test runner (--name, --tags, etc.)
  ///
  /// Returns the generated harness file.
  Future<File> generate({
    required List<String> testFiles,
    required List<String> filterArgs,
  }) async {
    // Resolve all test files
    final resolvedTestFiles = await _resolveTestFiles(testFiles);

    if (resolvedTestFiles.isEmpty) {
      throw StateError('No test files found in: $testFiles');
    }

    Logger.debug('Found ${resolvedTestFiles.length} test file(s)');
    for (final file in resolvedTestFiles) {
      Logger.debug('  - $file');
    }

    // Generate the harness code
    final harnessCode = _generateHarnessCode(
      testFiles: resolvedTestFiles,
      filterArgs: filterArgs,
    );

    // Write to a temporary location that will be copied by MinecraftRunner
    final harnessDir = Directory(p.join(project.rootDir, '.redstone', 'test'));
    if (!harnessDir.existsSync()) {
      harnessDir.createSync(recursive: true);
    }

    final harnessFile = File(p.join(harnessDir.path, 'test_harness.dart'));
    harnessFile.writeAsStringSync(harnessCode);

    // Create pubspec.yaml for the test harness that references the project's dependencies
    await _createHarnessPubspec(harnessDir);

    return harnessFile;
  }

  /// Generate a test harness file for client-side visual tests.
  ///
  /// [testFiles] - List of test file paths or directories
  /// [filterArgs] - Arguments to pass to the test runner (--name, --tags, etc.)
  ///
  /// Returns the generated harness file.
  Future<File> generateClientHarness({
    required List<String> testFiles,
    required List<String> filterArgs,
  }) async {
    // Resolve all test files
    final resolvedTestFiles = await _resolveTestFiles(testFiles);

    if (resolvedTestFiles.isEmpty) {
      throw StateError('No test files found in: $testFiles');
    }

    Logger.debug('Found ${resolvedTestFiles.length} client test file(s)');
    for (final file in resolvedTestFiles) {
      Logger.debug('  - $file');
    }

    // Generate the client harness code
    final harnessCode = _generateClientHarnessCode(
      testFiles: resolvedTestFiles,
      filterArgs: filterArgs,
    );

    // Write to a temporary location that will be copied by MinecraftRunner
    final harnessDir = Directory(p.join(project.rootDir, '.redstone', 'test'));
    if (!harnessDir.existsSync()) {
      harnessDir.createSync(recursive: true);
    }

    final harnessFile = File(p.join(harnessDir.path, 'client_test_harness.dart'));
    harnessFile.writeAsStringSync(harnessCode);

    // Create pubspec.yaml for the test harness that references the project's dependencies
    await _createHarnessPubspec(harnessDir);

    return harnessFile;
  }

  /// Create a pubspec.yaml for the test harness directory.
  ///
  /// This allows the Dart VM to resolve packages when loading the test harness
  /// directly from its location (via DART_SCRIPT_PATH).
  Future<void> _createHarnessPubspec(Directory harnessDir) async {
    // For workspace projects, check packages/server/pubspec.yaml first
    // Fall back to root pubspec.yaml for non-workspace projects
    final serverPubspecFile = File(p.join(project.rootDir, 'packages', 'server', 'pubspec.yaml'));
    final projectPubspecFile = File(p.join(project.rootDir, 'pubspec.yaml'));

    String? dartMcPath;
    String? redstoneTestPath;

    // Try server package pubspec first (for workspace projects)
    File? pubspecToUse;
    String? baseDir;

    if (serverPubspecFile.existsSync()) {
      pubspecToUse = serverPubspecFile;
      baseDir = p.join(project.rootDir, 'packages', 'server');
      Logger.debug('Using server package pubspec for dependency resolution');
    } else if (projectPubspecFile.existsSync()) {
      pubspecToUse = projectPubspecFile;
      baseDir = project.rootDir;
    }

    if (pubspecToUse != null && baseDir != null) {
      final content = pubspecToUse.readAsStringSync();
      // Simple regex to find path dependencies - this is sufficient for our use case
      final dartModServerMatch = RegExp(r'dart_mod_server:\s*\n\s*path:\s*(.+)').firstMatch(content);
      final redstoneTestMatch = RegExp(r'redstone_test:\s*\n\s*path:\s*(.+)').firstMatch(content);

      if (dartModServerMatch != null) {
        final relativePath = dartModServerMatch.group(1)!.trim();
        dartMcPath = Uri.directory(baseDir).resolve(relativePath).toFilePath();
        Logger.debug('Found dart_mod_server at: $dartMcPath');
      }
      if (redstoneTestMatch != null) {
        final relativePath = redstoneTestMatch.group(1)!.trim();
        redstoneTestPath = Uri.directory(baseDir).resolve(relativePath).toFilePath();
        Logger.debug('Found redstone_test at: $redstoneTestPath');
      }
    }

    // Build the dependencies section
    final depsBuffer = StringBuffer();
    depsBuffer.writeln('  # dart_mod_server package for ServerBridge and Events');
    depsBuffer.writeln('  dart_mod_server:');
    depsBuffer.writeln('    path: ${dartMcPath ?? '../dart_mod_server'}');
    depsBuffer.writeln('  # redstone_test for test utilities');
    depsBuffer.writeln('  redstone_test:');
    depsBuffer.writeln('    path: ${redstoneTestPath ?? '../redstone_test'}');

    // For workspace projects, add each workspace package
    final workspacePackagesDir = Directory(p.join(project.rootDir, 'packages'));
    if (workspacePackagesDir.existsSync()) {
      Logger.debug('Found workspace packages directory, adding package references');
      for (final entity in workspacePackagesDir.listSync()) {
        if (entity is Directory) {
          final packagePubspec = File(p.join(entity.path, 'pubspec.yaml'));
          if (packagePubspec.existsSync()) {
            // Get package name from pubspec
            final content = packagePubspec.readAsStringSync();

            // Skip packages that depend on Flutter SDK
            // These require a newer Dart version than the system Dart supports
            if (content.contains('sdk: flutter')) {
              Logger.debug('  - Skipping Flutter-dependent package: ${p.basename(entity.path)}');
              continue;
            }

            final nameMatch = RegExp(r'^name:\s*(.+)$', multiLine: true).firstMatch(content);
            if (nameMatch != null) {
              final packageName = nameMatch.group(1)!.trim();
              depsBuffer.writeln('  $packageName:');
              depsBuffer.writeln('    path: ${entity.path}');
              Logger.debug('  - Added workspace package: $packageName');
            }
          }
        }
      }
    } else {
      // Non-workspace project - just reference the main project
      depsBuffer.writeln('  # Reference the main project');
      depsBuffer.writeln('  ${project.name}:');
      depsBuffer.writeln('    path: ${project.rootDir}');
    }

    // Create the pubspec
    final harnessPubspec = '''
name: test_harness
description: Generated test harness for ${project.name}
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
${depsBuffer.toString()}''';

    final pubspecFile = File(p.join(harnessDir.path, 'pubspec.yaml'));
    pubspecFile.writeAsStringSync(harnessPubspec);

    // Run pub get to create .dart_tool/package_config.json
    Logger.debug('Running pub get for test harness...');
    final result = await Process.run(
      'dart',
      ['pub', 'get'],
      workingDirectory: harnessDir.path,
    );

    if (result.exitCode != 0) {
      Logger.warning('pub get failed for test harness: ${result.stderr}');
    }
  }

  /// Resolve test file paths and directories to a list of .dart test files.
  Future<List<String>> _resolveTestFiles(List<String> testPaths) async {
    final result = <String>[];

    for (final testPath in testPaths) {
      // Make path absolute relative to project root
      final absolutePath = p.isAbsolute(testPath)
          ? testPath
          : p.join(project.rootDir, testPath);

      if (FileSystemEntity.isDirectorySync(absolutePath)) {
        // Recursively find all _test.dart files in the directory
        final dir = Directory(absolutePath);
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('_test.dart')) {
            result.add(entity.path);
          }
        }
      } else if (FileSystemEntity.isFileSync(absolutePath)) {
        result.add(absolutePath);
      } else {
        Logger.warning('Test path not found: $testPath');
      }
    }

    return result;
  }

  /// Generate the Dart code for the test harness.
  String _generateHarnessCode({
    required List<String> testFiles,
    required List<String> filterArgs,
  }) {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// Generated test harness - do not edit');
    buffer.writeln('// ignore_for_file: depend_on_referenced_packages');
    buffer.writeln();

    // Core imports
    buffer.writeln("import 'dart:async';");
    buffer.writeln("import 'package:dart_mod_server/dart_mod_server.dart';");
    buffer.writeln("import 'package:redstone_test/redstone_test.dart';");
    buffer.writeln();

    // Import the mod's server entry point to register blocks, items, and entities
    // Use configured server entry point or fall back to main.dart
    final modMainPath = File(project.serverEntry).existsSync()
        ? project.serverEntry
        : project.entryPoint;
    final modMainUri = _getModMainImportUri(modMainPath);
    buffer.writeln("import '$modMainUri' as mod_main;");
    buffer.writeln();

    // Generate imports for each test file with unique aliases
    // Harness ends up in lib/dart_mc.dart, test files in test/
    for (var i = 0; i < testFiles.length; i++) {
      final testFile = testFiles[i];
      final relativePath = _getTestImportPath(testFile);
      buffer.writeln("import '$relativePath' as test_$i;");
    }

    buffer.writeln();

    // State tracking for tick-based polling
    // In an embedded Dart runtime, async code only progresses when the event loop
    // is pumped. Using tick events ensures the async test execution can complete.
    buffer.writeln('bool _serverReady = false;');
    buffer.writeln('bool _testsRunning = false;');
    buffer.writeln();

    // Test runner function
    buffer.writeln('Future<void> _runTests() async {');
    buffer.writeln('  if (_testsRunning) return;');
    buffer.writeln('  _testsRunning = true;');
    buffer.writeln();
    buffer.writeln('  print("Server started - running tests...");');
    buffer.writeln();
    buffer.writeln('  try {');

    // Call each test file's main function with suite events
    buffer.writeln('    // Run all test files');
    for (var i = 0; i < testFiles.length; i++) {
      final testFile = testFiles[i];
      final fileName = testFile.split('/').last;
      buffer.writeln("    emitEvent(SuiteStartEvent(name: '$fileName'));");
      buffer.writeln("    print('Running: $fileName');");
      buffer.writeln('    await test_$i.main();');
      buffer.writeln("    emitEvent(SuiteEndEvent(name: '$fileName'));");
      buffer.writeln("    print('Completed: $fileName');");
    }

    buffer.writeln('  } catch (e, st) {');
    buffer.writeln('    print("Test harness error: \$e");');
    buffer.writeln('    print(st);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  // Print summary');
    buffer.writeln('  testResults.printSummary();');
    buffer.writeln();
    buffer.writeln('  // Emit done event with final counts');
    buffer.writeln('  emitEvent(DoneEvent(');
    buffer.writeln('    passed: testResults.passed,');
    buffer.writeln('    failed: testResults.failed,');
    buffer.writeln('    skipped: testResults.skipped,');
    buffer.writeln('    exitCode: testResults.exitCode,');
    buffer.writeln('  ));');
    buffer.writeln();
    buffer.writeln('  // Stop the server and exit');
    buffer.writeln("  print('Tests complete, stopping server...');");
    buffer.writeln('  ServerBridge.stopServer();');
    buffer.writeln('}');
    buffer.writeln();

    // Main function
    buffer.writeln('void main() async {');
    buffer.writeln('  // Initialize bridge');
    buffer.writeln('  ServerBridge.initialize();');
    buffer.writeln();
    buffer.writeln('  // Run mod initialization to register blocks, items, and entities');
    buffer.writeln('  mod_main.main();');
    buffer.writeln();
    buffer.writeln('  // Mark server as ready when it starts');
    buffer.writeln('  Events.onServerStarted(() {');
    buffer.writeln('    _serverReady = true;');
    buffer.writeln('    print("Server ready, will start tests on next tick...");');
    buffer.writeln('  });');
    buffer.writeln();
    buffer.writeln('  // Use tick events to poll for server readiness and trigger test execution.');
    buffer.writeln('  // In an embedded Dart runtime, async code only progresses when the event');
    buffer.writeln('  // loop is pumped. Tick events naturally pump the event loop, ensuring');
    buffer.writeln('  // the async _runTests() function can execute to completion.');
    buffer.writeln('  Events.addTickListener((tick) {');
    buffer.writeln('    if (_serverReady && !_testsRunning) {');
    buffer.writeln('      // Run tests asynchronously so we don\'t block the tick handler');
    buffer.writeln('      Future(() => _runTests());');
    buffer.writeln('    }');
    buffer.writeln('  });');
    buffer.writeln();
    buffer.writeln('  print("Test harness initialized, waiting for server to be ready...");');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generate the Dart code for the client test harness.
  String _generateClientHarnessCode({
    required List<String> testFiles,
    required List<String> filterArgs,
  }) {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// Generated client test harness - do not edit');
    buffer.writeln('// ignore_for_file: depend_on_referenced_packages');
    buffer.writeln();

    // Core imports
    buffer.writeln("import 'dart:async';");
    buffer.writeln("import 'package:dart_mod_server/dart_mod_server.dart';");
    buffer.writeln("import 'package:redstone_test/redstone_test.dart';");
    buffer.writeln();

    // Import the mod's SERVER entry point to register blocks, items, and entities
    // The server package doesn't depend on Flutter SDK, so it can always be imported
    // Client tests still need server-side block registration for blocks to work
    final modMainPath = File(project.serverEntry).existsSync()
        ? project.serverEntry
        : project.entryPoint;
    final modMainUri = _getModMainImportUri(modMainPath);
    buffer.writeln("import '$modMainUri' as mod_main;");
    buffer.writeln();

    // Generate imports for each test file with unique aliases
    for (var i = 0; i < testFiles.length; i++) {
      final testFile = testFiles[i];
      final relativePath = _getTestImportPath(testFile);
      buffer.writeln("import '$relativePath' as test_$i;");
    }

    buffer.writeln();

    // State tracking
    buffer.writeln('bool _clientReady = false;');
    buffer.writeln('bool _testsRunning = false;');
    buffer.writeln();

    // Client ready handler function
    buffer.writeln('Future<void> _runClientTests() async {');
    buffer.writeln('  if (_testsRunning) return;');
    buffer.writeln('  _testsRunning = true;');
    buffer.writeln();
    buffer.writeln('  print("Client ready - running visual tests...");');
    buffer.writeln();
    buffer.writeln('  // Give the client a moment to stabilize');
    buffer.writeln('  await Future.delayed(Duration(seconds: 2));');
    buffer.writeln();
    buffer.writeln('  try {');

    // Call each test file's main function with suite events
    buffer.writeln('    // Run all test files');
    for (var i = 0; i < testFiles.length; i++) {
      final testFile = testFiles[i];
      final fileName = testFile.split('/').last;
      buffer.writeln("    emitEvent(SuiteStartEvent(name: '$fileName'));");
      buffer.writeln("    print('Running: $fileName');");
      buffer.writeln('    await test_$i.main();');
      buffer.writeln("    emitEvent(SuiteEndEvent(name: '$fileName'));");
      buffer.writeln("    print('Completed: $fileName');");
    }

    buffer.writeln('  } catch (e, st) {');
    buffer.writeln('    print("Test harness error: \$e");');
    buffer.writeln('    print(st);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  // Print summary');
    buffer.writeln('  testResults.printSummary();');
    buffer.writeln();
    buffer.writeln('  // Emit done event with final counts');
    buffer.writeln('  emitEvent(DoneEvent(');
    buffer.writeln('    passed: testResults.passed,');
    buffer.writeln('    failed: testResults.failed,');
    buffer.writeln('    skipped: testResults.skipped,');
    buffer.writeln('    exitCode: testResults.exitCode,');
    buffer.writeln('  ));');
    buffer.writeln();
    buffer.writeln('  // Stop the server and exit');
    buffer.writeln("  print('Tests complete, stopping server...');");
    buffer.writeln('  ServerBridge.stopServer();');
    buffer.writeln('}');
    buffer.writeln();

    // Main function for client tests - uses polling via server tick events
    buffer.writeln('void main() async {');
    buffer.writeln('  // Initialize bridge');
    buffer.writeln('  ServerBridge.initialize();');
    buffer.writeln();

    buffer.writeln('  // Run mod initialization to register blocks, items, and entities');
    buffer.writeln('  // This calls the SERVER entry point to register blocks (not the Flutter client)');
    buffer.writeln('  mod_main.main();');
    buffer.writeln();
    buffer.writeln('  // Enable visual test mode to auto-join test world');
    buffer.writeln('  // TODO: ClientBridge needs to be imported from dart_mod_client when available');
    buffer.writeln('  // ClientBridge.setVisualTestMode(true);');
    buffer.writeln();
    buffer.writeln('  // Use server tick events to poll for client readiness.');
    buffer.writeln('  // In singleplayer mode, the integrated server runs alongside the client.');
    buffer.writeln('  // This avoids needing complex FFI callbacks for client events.');
    buffer.writeln('  Events.addTickListener((tick) {');
    buffer.writeln('    // Check if client is ready (has player and world)');
    buffer.writeln('    if (!_clientReady && ClientBridge.isClientReady()) {');
    buffer.writeln('      _clientReady = true;');
    buffer.writeln('      print("Client ready detected at tick \$tick");');
    buffer.writeln('      // Run tests asynchronously so we don\'t block the tick handler');
    buffer.writeln('      Future(() => _runClientTests());');
    buffer.writeln('    }');
    buffer.writeln('  });');
    buffer.writeln();
    buffer.writeln('  print("Client test harness initialized, waiting for client to be ready...");');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Get the import path for a test file.
  ///
  /// Since the test harness is loaded directly from its location via
  /// DART_SCRIPT_PATH, we use absolute file:// URIs for imports.
  String _getTestImportPath(String filePath) {
    // Use absolute file:// URI so imports work regardless of harness location
    final absolutePath = p.isAbsolute(filePath)
        ? filePath
        : p.join(project.rootDir, filePath);
    return Uri.file(absolutePath).toString();
  }

  /// Get the import URI for the mod main entry point.
  ///
  /// For workspace projects, converts file paths to package:// URIs to ensure
  /// type consistency. When types are registered via the mod main, they should
  /// come from the same package:// URI as when they're imported in tests.
  String _getModMainImportUri(String modMainPath) {
    final packagesDir = p.join(project.rootDir, 'packages');

    // Check if this is in a workspace package
    if (modMainPath.startsWith(packagesDir)) {
      final relativeToPkgs = p.relative(modMainPath, from: packagesDir);
      final parts = p.split(relativeToPkgs);

      if (parts.length >= 2) {
        final packageDir = parts[0]; // e.g., "server"
        final restOfPath = parts.sublist(1).join('/'); // e.g., "lib/main.dart"

        // Only convert lib/ files to package URIs
        if (restOfPath.startsWith('lib/')) {
          final pubspecPath = p.join(packagesDir, packageDir, 'pubspec.yaml');
          final pubspecFile = File(pubspecPath);

          if (pubspecFile.existsSync()) {
            try {
              final pubspec = loadYaml(pubspecFile.readAsStringSync());
              final packageName = pubspec['name'] as String;
              final libPath = restOfPath.substring(4); // Remove 'lib/'
              return 'package:$packageName/$libPath';
            } catch (e) {
              Logger.debug('Failed to parse pubspec at $pubspecPath: $e');
            }
          }
        }
      }
    }

    // Fall back to file:// URI for non-workspace projects
    return Uri.file(modMainPath).toString();
  }
}
