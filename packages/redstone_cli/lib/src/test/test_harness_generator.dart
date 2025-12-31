import 'dart:io';

import 'package:path/path.dart' as p;

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
    // Read the project's pubspec to extract dependency paths
    final projectPubspecFile = File(p.join(project.rootDir, 'pubspec.yaml'));
    String? dartMcPath;
    String? redstoneTestPath;

    if (projectPubspecFile.existsSync()) {
      final content = projectPubspecFile.readAsStringSync();
      // Simple regex to find path dependencies - this is sufficient for our use case
      final dartModServerMatch = RegExp(r'dart_mod_server:\s*\n\s*path:\s*(.+)').firstMatch(content);
      final redstoneTestMatch = RegExp(r'redstone_test:\s*\n\s*path:\s*(.+)').firstMatch(content);

      if (dartModServerMatch != null) {
        final relativePath = dartModServerMatch.group(1)!.trim();
        dartMcPath = Uri.directory(project.rootDir).resolve(relativePath).toFilePath();
      }
      if (redstoneTestMatch != null) {
        final relativePath = redstoneTestMatch.group(1)!.trim();
        redstoneTestPath = Uri.directory(project.rootDir).resolve(relativePath).toFilePath();
      }
    }

    // Create a minimal pubspec that includes dart_mod_server and redstone_test
    final harnessPubspec = '''
name: test_harness
description: Generated test harness for ${project.name}
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  # dart_mod_server package for ServerBridge and Events
  dart_mod_server:
    path: ${dartMcPath ?? '../dart_mod_server'}
  # redstone_test for test utilities
  redstone_test:
    path: ${redstoneTestPath ?? '../redstone_test'}
  # Reference the main project
  ${project.name}:
    path: ${project.rootDir}
''';

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
    buffer.writeln("import 'file://$modMainPath' as mod_main;");
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

    // Import the mod's client entry point to register blocks, items, and entities
    // Use configured client entry point or fall back to main.dart
    final modMainPath = File(project.clientEntry).existsSync()
        ? project.clientEntry
        : project.entryPoint;
    buffer.writeln("import 'file://$modMainPath' as mod_main;");
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
    buffer.writeln('  // This is important for visual tests that need custom entities to be registered');
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
    buffer.writeln('    // TODO: ClientBridge needs to be imported from dart_mod_client when available');
    buffer.writeln('    if (!_clientReady) { // && ClientBridge.isClientReady()');
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

}
