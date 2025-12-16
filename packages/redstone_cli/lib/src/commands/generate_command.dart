import 'dart:io';

import 'package:args/command_runner.dart';

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
      Logger.info('Running mod in datagen mode...');
      final result = await Process.run(
        'dart',
        ['run', 'lib/main.dart'],
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
