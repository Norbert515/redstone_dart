@Timeout(Duration(minutes: 10))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// E2E tests for project creation and compilation.
///
/// These tests verify that:
/// 1. Project creation works correctly
/// 2. The generated project compiles without errors
/// 3. All necessary files are in place (access widener, bridge code, etc.)
///
/// Run with: dart test test/project_creation_e2e_test.dart
void main() {
  late Directory tempDir;
  late String projectDir;

  setUpAll(() async {
    // Create a unique temp directory for tests
    tempDir = await Directory.systemTemp.createTemp('redstone_e2e_test_');
    projectDir = p.join(tempDir.path, 'test_mod');
  });

  tearDownAll(() async {
    // Clean up temp directory
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Project Creation E2E', () {
    test('redstone create generates a valid project structure', () async {
      // Find the redstone CLI
      final redstonePath = _findRedstoneCli();
      expect(redstonePath, isNotNull, reason: 'Could not find redstone CLI');

      // Create a new project
      final createResult = await Process.run(
        'dart',
        [
          'run',
          redstonePath!,
          'create',
          'test_mod',
          '--org',
          'com.test',
        ],
        workingDirectory: tempDir.path,
      );

      print('=== Create stdout ===');
      print(createResult.stdout);
      print('=== Create stderr ===');
      print(createResult.stderr);

      expect(
        createResult.exitCode,
        equals(0),
        reason: 'Project creation failed: ${createResult.stderr}',
      );

      // Verify project directory exists
      expect(
        Directory(projectDir).existsSync(),
        isTrue,
        reason: 'Project directory was not created',
      );
    });

    test('generated project has correct file structure', () {
      // Check essential files exist
      final essentialFiles = [
        'pubspec.yaml',
        'lib/main.dart',
        'minecraft/build.gradle',
        'minecraft/settings.gradle',
        'minecraft/gradle.properties',
        'minecraft/gradlew',
        'minecraft/src/main/resources/fabric.mod.json',
        '.redstone/version.json',
        '.redstone/bridge/java/com/redstone/DartBridge.java',
        '.redstone/bridge/resources/redstone.accesswidener',
      ];

      for (final file in essentialFiles) {
        final filePath = p.join(projectDir, file);
        expect(
          File(filePath).existsSync(),
          isTrue,
          reason: 'Essential file missing: $file',
        );
      }
    });

    test('build.gradle references access widener correctly', () {
      final buildGradle = File(p.join(projectDir, 'minecraft/build.gradle'));
      final content = buildGradle.readAsStringSync();

      expect(
        content.contains('accessWidenerPath'),
        isTrue,
        reason: 'build.gradle should reference accessWidenerPath',
      );

      expect(
        content.contains('.redstone/bridge/resources/redstone.accesswidener'),
        isTrue,
        reason: 'build.gradle should point to correct access widener path',
      );
    });

    test('access widener contains required field access', () {
      final accessWidener = File(
        p.join(projectDir, '.redstone/bridge/resources/redstone.accesswidener'),
      );
      final content = accessWidener.readAsStringSync();

      expect(
        content.contains('goalSelector'),
        isTrue,
        reason: 'Access widener should include goalSelector',
      );

      expect(
        content.contains('targetSelector'),
        isTrue,
        reason: 'Access widener should include targetSelector',
      );
    });

    test(
      'generated project compiles successfully',
      () async {
        // Make gradlew executable
        if (!Platform.isWindows) {
          await Process.run(
            'chmod',
            ['+x', 'gradlew'],
            workingDirectory: p.join(projectDir, 'minecraft'),
          );
        }

        // Run gradle build
        final gradlew =
            Platform.isWindows ? 'gradlew.bat' : p.join('.', 'gradlew');

        final buildResult = await Process.run(
          gradlew,
          ['build', '--no-daemon', '--warning-mode=all'],
          workingDirectory: p.join(projectDir, 'minecraft'),
          environment: {
            // Ensure we have JAVA_HOME set if available
            if (Platform.environment.containsKey('JAVA_HOME'))
              'JAVA_HOME': Platform.environment['JAVA_HOME']!,
          },
        );

        print('=== Build stdout ===');
        print(buildResult.stdout);
        print('=== Build stderr ===');
        print(buildResult.stderr);

        expect(
          buildResult.exitCode,
          equals(0),
          reason: 'Gradle build failed:\n${buildResult.stderr}',
        );

        // Verify build output exists
        final buildDir = Directory(p.join(projectDir, 'minecraft/build'));
        expect(
          buildDir.existsSync(),
          isTrue,
          reason: 'Build directory should exist after successful build',
        );
      },
      timeout: Timeout(Duration(minutes: 8)),
    );
  });
}

/// Find the redstone CLI entry point
String? _findRedstoneCli() {
  final candidates = <String>[];

  // Start from current directory
  final current = Directory.current.path;
  print('DEBUG: Current directory: $current');

  // Candidate 1: bin/redstone.dart relative to current directory
  candidates.add(p.join(current, 'bin', 'redstone.dart'));

  // Candidate 2: Walk up looking for packages/redstone_cli/bin/redstone.dart
  var walkDir = Directory.current;
  for (var i = 0; i < 5; i++) {
    candidates.add(p.join(walkDir.path, 'packages', 'redstone_cli', 'bin', 'redstone.dart'));
    walkDir = walkDir.parent;
  }

  // Candidate 3: Try relative to test file location
  final testDir = Platform.script.toFilePath();
  print('DEBUG: Platform.script: $testDir');
  if (testDir.contains('packages/redstone_cli')) {
    final idx = testDir.indexOf('packages/redstone_cli');
    final cliRoot = testDir.substring(0, idx + 'packages/redstone_cli'.length);
    candidates.add(p.join(cliRoot, 'bin', 'redstone.dart'));
  }

  // Check each candidate
  for (final candidate in candidates) {
    print('DEBUG: Checking candidate: $candidate');
    if (File(candidate).existsSync()) {
      print('DEBUG: Found CLI at: $candidate');
      return candidate;
    }
  }

  print('DEBUG: No CLI found. Listing current directory:');
  try {
    for (final entity in Directory.current.listSync()) {
      print('DEBUG:   ${entity.path}');
    }
  } catch (e) {
    print('DEBUG: Error listing directory: $e');
  }

  return null;
}
