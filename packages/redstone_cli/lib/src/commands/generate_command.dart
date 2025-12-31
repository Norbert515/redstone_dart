import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../assets/asset_generator.dart';
import '../project/redstone_project.dart';
import '../util/logger.dart';

/// Command to generate assets from mod registration.
///
/// This runs the mod in datagen mode to discover blocks/items,
/// then generates all Minecraft resource files (blockstates, models, etc.)
class GenerateCommand extends Command<int> {
  @override
  final name = 'generate';

  @override
  final description = 'Generate Minecraft assets from your mod definitions';

  @override
  Future<int> run() async {
    final project = RedstoneProject.find();
    if (project == null) {
      Logger.error('Not in a Redstone project directory');
      return 1;
    }

    Logger.newLine();
    Logger.header('Generating assets for ${project.name}...');
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

      Logger.info('Running mod in datagen mode ($scriptPath)...');
      final result = await Process.run(
        'dart',
        ['run', scriptPath],
        workingDirectory: project.rootDir,
        environment: {'REDSTONE_DATAGEN': 'true'},
      );

      if (result.exitCode != 0) {
        Logger.error('Datagen failed with exit code ${result.exitCode}');
        if (result.stdout.toString().isNotEmpty) {
          Logger.info('stdout: ${result.stdout}');
        }
        if (result.stderr.toString().isNotEmpty) {
          Logger.error('stderr: ${result.stderr}');
        }
        return 1;
      }

      Logger.success('Manifest generated');

      // Step 2: Generate all JSON assets from manifest
      Logger.info('Generating Minecraft assets...');
      final assetGenerator = AssetGenerator(project);
      await assetGenerator.generate();
      Logger.success('Generated blockstates, models, lang, and loot tables');

      Logger.newLine();
      Logger.success('Asset generation complete!');
      Logger.newLine();
      return 0;
    } catch (e, st) {
      Logger.error('Generation failed: $e');
      Logger.error('$st');
      return 1;
    }
  }
}
