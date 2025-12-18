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

  /// Generate a test harness file.
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
      final dartMcMatch = RegExp(r'dart_mc:\s*\n\s*path:\s*(.+)').firstMatch(content);
      final redstoneTestMatch = RegExp(r'redstone_test:\s*\n\s*path:\s*(.+)').firstMatch(content);

      if (dartMcMatch != null) {
        final relativePath = dartMcMatch.group(1)!.trim();
        dartMcPath = Uri.directory(project.rootDir).resolve(relativePath).toFilePath();
      }
      if (redstoneTestMatch != null) {
        final relativePath = redstoneTestMatch.group(1)!.trim();
        redstoneTestPath = Uri.directory(project.rootDir).resolve(relativePath).toFilePath();
      }
    }

    // Create a minimal pubspec that includes dart_mc and redstone_test
    final harnessPubspec = '''
name: test_harness
description: Generated test harness for ${project.name}
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  # dart_mc package for Bridge and Events
  dart_mc:
    path: ${dartMcPath ?? '../dart_mc'}
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
    buffer.writeln("import 'package:dart_mc/dart_mc.dart';");
    buffer.writeln("import 'package:redstone_test/redstone_test.dart';");
    buffer.writeln();

    // Generate imports for each test file with unique aliases
    // Harness ends up in lib/dart_mc.dart, test files in test/
    for (var i = 0; i < testFiles.length; i++) {
      final testFile = testFiles[i];
      final relativePath = _getTestImportPath(testFile);
      buffer.writeln("import '$relativePath' as test_$i;");
    }

    buffer.writeln();

    // Main function
    buffer.writeln('void main() async {');
    buffer.writeln('  // Initialize bridge');
    buffer.writeln('  Bridge.initialize();');
    buffer.writeln();
    buffer.writeln('  // Wait for server to be ready');
    buffer.writeln('  Events.onServerStarted(() async {');
    buffer.writeln('    print("Server started - running tests...");');
    buffer.writeln();
    buffer.writeln('    try {');

    // Call each test file's main function with suite events
    buffer.writeln('      // Run all test files');
    for (var i = 0; i < testFiles.length; i++) {
      final testFile = testFiles[i];
      final fileName = testFile.split('/').last;
      buffer.writeln("      emitEvent(SuiteStartEvent(name: '$fileName'));");
      buffer.writeln("      print('Running: $fileName');");
      buffer.writeln('      await test_$i.main();');
      buffer.writeln("      emitEvent(SuiteEndEvent(name: '$fileName'));");
      buffer.writeln("      print('Completed: $fileName');");
    }

    buffer.writeln('    } catch (e, st) {');
    buffer.writeln('      print("Test harness error: \$e");');
    buffer.writeln('      print(st);');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    // Print summary');
    buffer.writeln('    testResults.printSummary();');
    buffer.writeln();
    buffer.writeln('    // Emit done event with final counts');
    buffer.writeln('    emitEvent(DoneEvent(');
    buffer.writeln('      passed: testResults.passed,');
    buffer.writeln('      failed: testResults.failed,');
    buffer.writeln('      skipped: testResults.skipped,');
    buffer.writeln('      exitCode: testResults.exitCode,');
    buffer.writeln('    ));');
    buffer.writeln();
    buffer.writeln('    // Stop the server and exit');
    buffer.writeln("    print('Tests complete, stopping server...');");
    buffer.writeln('    Bridge.stopServer();');
    buffer.writeln('  });');
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
