import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../assets/asset_generator.dart';
import '../project/redstone_project.dart';
import '../util/logger.dart';

class BuildCommand extends Command<int> {
  @override
  final name = 'build';

  @override
  final description = 'Build the Redstone project without running.';

  BuildCommand() {
    argParser.addFlag(
      'release',
      help: 'Build in release mode.',
      negatable: false,
    );
  }

  @override
  Future<int> run() async {
    final project = RedstoneProject.find();
    if (project == null) {
      Logger.error('No Redstone project found.');
      return 1;
    }

    Logger.newLine();
    Logger.header('Building ${project.name}...');
    Logger.newLine();

    try {
      // Step 1: Run the mod in datagen mode to generate manifest.json
      // Use the configured datagen entry point, or fall back to main_datagen.dart
      // for Flutter mods, or main.dart as the final fallback
      final datagenScript = File(project.datagenEntry);
      final mainDatagenScript = File(p.join(project.rootDir, 'lib', 'main_datagen.dart'));

      String scriptPath;
      if (datagenScript.existsSync()) {
        scriptPath = p.relative(project.datagenEntry, from: project.rootDir);
      } else if (mainDatagenScript.existsSync()) {
        scriptPath = 'lib/main_datagen.dart';
      } else {
        scriptPath = 'lib/main.dart';
      }

      Logger.progress('Running datagen');
      final datagenResult = await Process.run(
        'dart',
        ['run', scriptPath],
        workingDirectory: project.rootDir,
        environment: {'REDSTONE_DATAGEN': 'true'},
      );

      if (datagenResult.exitCode != 0) {
        Logger.progressFailed();
        Logger.error('Datagen failed:');
        Logger.info(datagenResult.stderr.toString());
        return 1;
      }
      Logger.progressDone();

      // Step 2: Generate assets (blockstates, models, textures) from manifest
      Logger.progress('Generating assets');
      final generator = AssetGenerator(project);
      await generator.generate();
      Logger.progressDone();

      // Copy Dart mod to minecraft/run/mods/
      Logger.progress('Copying Dart mod');
      await _copyDartMod(project);
      Logger.progressDone();

      // Copy native libraries
      Logger.progress('Copying native libraries');
      await _copyNativeLibs(project);
      Logger.progressDone();

      // Build Java mod
      Logger.progress('Building Java mod');
      final result = await Process.run(
        './gradlew',
        ['classes'],
        workingDirectory: project.minecraftDir,
      );
      if (result.exitCode != 0) {
        Logger.progressFailed();
        Logger.error('Gradle build failed:');
        Logger.info(result.stderr.toString());
        return 1;
      }
      Logger.progressDone();

      Logger.newLine();
      Logger.success('Build completed successfully!');
      Logger.newLine();

      return 0;
    } catch (e) {
      Logger.error('Build failed: $e');
      return 1;
    }
  }

  Future<void> _copyDartMod(RedstoneProject project) async {
    final sourceDir = Directory(project.libDir);
    final targetDir = Directory(
      p.join(project.minecraftDir, 'run', 'mods', project.name),
    );

    // Create target directory
    if (targetDir.existsSync()) {
      targetDir.deleteSync(recursive: true);
    }
    targetDir.createSync(recursive: true);

    // Copy lib/ contents
    await _copyDirectory(sourceDir, Directory(p.join(targetDir.path, 'lib')));

    // Copy pubspec.yaml
    final pubspec = File(p.join(project.rootDir, 'pubspec.yaml'));
    pubspec.copySync(p.join(targetDir.path, 'pubspec.yaml'));
  }

  Future<void> _copyNativeLibs(RedstoneProject project) async {
    final nativeDir = Directory(p.join(project.redstoneDir, 'native'));
    final targetDir = Directory(p.join(project.minecraftDir, 'run', 'natives'));

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    await for (final entity in nativeDir.list()) {
      if (entity is File) {
        final targetPath = p.join(targetDir.path, p.basename(entity.path));
        entity.copySync(targetPath);
      }
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
}
