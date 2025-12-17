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

    return harnessFile;
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

  /// Get the import path for a test file relative to the harness location.
  /// The harness ends up at lib/dart_mc.dart, test files at lib/test/
  /// (test files are copied inside lib/ to work around native Dart VM path issues)
  String _getTestImportPath(String filePath) {
    // Get relative path from project root
    final relativePath = p.relative(filePath, from: project.rootDir);

    // If it's in test/, the import from lib/dart_mc.dart is ./test/...
    // (test files are copied to lib/test/ during build)
    if (relativePath.startsWith('test/') ||
        relativePath.startsWith('test${p.separator}')) {
      return './$relativePath';
    }

    // If it's in lib/, use the filename directly with ./
    if (relativePath.startsWith('lib/') ||
        relativePath.startsWith('lib${p.separator}')) {
      final libPath = relativePath.substring(4); // Remove 'lib/'
      return './$libPath';
    }

    // Fallback: assume it's in the same directory
    return './$relativePath';
  }

}
