import 'package:args/command_runner.dart';

import '../codegen/identifier_generator.dart';
import '../project/redstone_project.dart';
import '../util/logger.dart';

/// Command to generate type-safe identifiers from assets.
class GenerateCommand extends Command<int> {
  @override
  final name = 'generate';

  @override
  final description = 'Generate type-safe identifiers from assets';

  @override
  Future<int> run() async {
    final project = RedstoneProject.find();
    if (project == null) {
      Logger.error('Not in a Redstone project directory');
      return 1;
    }

    Logger.newLine();
    Logger.header('Generating identifiers for ${project.name}...');
    Logger.newLine();

    try {
      final generator = IdentifierGenerator(project);
      await generator.generate();

      Logger.success('Generated lib/generated/textures.dart');
      Logger.newLine();
      return 0;
    } catch (e) {
      Logger.error('Generation failed: $e');
      return 1;
    }
  }
}
